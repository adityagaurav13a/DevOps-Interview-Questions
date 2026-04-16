# Delivering Stateful Applications — Complete Guide

## StatefulSets + Persistent Storage + Databases + Real-World Patterns

### Why It’s Hard → How to Do It Right → Production Patterns

-----

## README

**This answers:** “How do we deliver stateful applications + deploy 3-tier app in production VPC?”
**Covers:** StatefulSet, PV/PVC, PostgreSQL/Redis/Kafka HA, migrations, backup/restore,
complete 3-tier VPC architecture, Terraform IaC, end-to-end CI/CD pipeline
**Target level:** Mid-level to Senior DevOps/Cloud Engineer

### Power phrases:

- *“StatefulSet gives stable pod name, stable DNS, and stable PVC — that’s how data survives restarts”*
- *“For production databases: use RDS. For in-cluster needs: use an operator like Zalando”*
- *“3-tier: public subnet=ALB, private subnet=EKS nodes, data subnet=RDS+ElastiCache”*
- *“Every tier has its own subnet, security group, and route table — defence in depth”*
- *“WaitForFirstConsumer ensures EBS is created in the same AZ as the pod”*

-----

## 📌 TABLE OF CONTENTS

|# |Section                                                                             |Key Topics                                       |
|--|------------------------------------------------------------------------------------|-------------------------------------------------|
|1 |[Why Stateful is Hard](#part-1--why-stateful-is-hard)                               |Stateless vs stateful, 5 core challenges         |
|2 |[StatefulSet Deep Dive](#part-2--statefulset-deep-dive)                             |Stable names, DNS, PVC, ordered ops, full YAML   |
|3 |[Persistent Storage](#part-3--persistent-storage)                                   |PV, PVC, StorageClass, EBS vs EFS, reclaim policy|
|4 |[Databases in K8s vs Managed](#part-4--databases-in-k8s-vs-managed-services)        |When to use RDS vs K8s, decision guide           |
|5 |[PostgreSQL HA in K8s](#part-5--postgresql-ha-in-kubernetes)                        |Operator, Patroni, PgBouncer, failover flow      |
|6 |[Redis in Kubernetes](#part-6--redis-in-kubernetes)                                 |Patterns, StatefulSet, RDB vs AOF                |
|7 |[Kafka in Kubernetes](#part-7--kafka-in-kubernetes)                                 |Strimzi, broker config, multi-AZ                 |
|8 |[Data Migration + Schema Changes](#part-8--data-migration-and-schema-changes)       |Zero-downtime, Expand/Contract, Flyway           |
|9 |[Backup and Restore](#part-9--backup-and-restore-strategy)                          |WAL-G, Velero, RPO/RTO, restore testing          |
|10|[Multi-AZ for Stateful Apps](#part-10--multi-az-for-stateful-apps)                  |AZ problem, EBS vs EFS, WaitForFirstConsumer     |
|11|[Complete Production Patterns](#part-11--complete-production-patterns)              |RDS pattern, operator pattern, hybrid            |
|12|[**3-Tier App in VPC — Full Guide**](#part-12--3-tier-application-deployment-in-vpc)|**Complete VPC + K8s + DB deployment**           |
|13|[3-Tier with Terraform IaC](#part-13--3-tier-infrastructure-as-code-terraform)      |Full Terraform for VPC + EKS + RDS               |
|14|[3-Tier CI/CD Pipeline](#part-14--3-tier-cicd-pipeline)                             |End-to-end GitHub Actions pipeline               |
|15|[Interview Questions](#part-15--interview-questions)                                |8 Q&As — stateful + 3-tier + VPC                 |

### ⚡ Quick Jump:

> [StatefulSet](#part-2--statefulset-deep-dive) · [PVC/Storage](#part-3--persistent-storage) · [PostgreSQL HA](#part-5--postgresql-ha-in-kubernetes) · [Redis](#part-6--redis-in-kubernetes) · [Migrations](#part-8--data-migration-and-schema-changes) · [Backup/Restore](#part-9--backup-and-restore-strategy) · [**3-Tier VPC**](#part-12--3-tier-application-deployment-in-vpc) · [Terraform IaC](#part-13--3-tier-infrastructure-as-code-terraform) · [CI/CD Pipeline](#part-14--3-tier-cicd-pipeline)

-----

## PART 1 — WHY STATEFUL IS HARD

### Stateless vs Stateful — The Fundamental Difference

```
STATELESS (easy):
  Each request is independent
  Pod dies → create new pod → same behaviour
  Data lives outside the pod (DB, cache, S3)
  Any pod = any other pod (interchangeable)
  
  Examples: REST API, web server, worker, Lambda

STATEFUL (hard):
  Pod keeps data across requests
  Pod dies → new pod MUST find the old data
  Data lives INSIDE or ATTACHED to the pod
  Each pod has unique identity (pod-0 ≠ pod-1)
  
  Examples: PostgreSQL, Redis, Kafka, Elasticsearch

The Big Problem:
  Kubernetes was DESIGNED for stateless apps
  Everything in K8s is ephemeral by default:
    Pod deleted → its local disk gone
    Pod moved to new node → leaves its disk behind
    Pod restarted → starts fresh (like a new process)
  
  For a database, this is catastrophic:
    "Your EC2 died, we restarted your DB pod on a new node"
    "Oh sorry, all your data was on the old node's disk. It's gone."
```

### What Makes Stateful Delivery Complex

```
Challenge 1: Storage
  Pod needs PERSISTENT disk that:
    Survives pod restarts
    Follows pod if rescheduled (or stays where pod MUST run)
    Is NOT shared with other pods (each DB has its own data)
  
  Solution: PersistentVolume (EBS in AWS) attached per pod

Challenge 2: Identity
  In PostgreSQL cluster:
    postgres-0 = PRIMARY (accepts writes)
    postgres-1 = REPLICA (reads only)
  
  If postgres-0 is replaced by a new pod:
    New pod MUST know it's postgres-0 (not postgres-2)
    New pod MUST get postgres-0's data (not empty disk)
    Other pods MUST be able to find postgres-0 by stable DNS name
  
  Solution: StatefulSet (stable pod name + stable DNS + stable PVC)

Challenge 3: Ordering
  PostgreSQL cluster startup:
    postgres-0 (primary) MUST start first
    postgres-1 (replica) starts after → connects to postgres-0
    postgres-2 (replica) starts after → connects to postgres-0
  
  If all start simultaneously → chaos (who is primary?)
  
  Solution: StatefulSet ordered startup (0 before 1 before 2)

Challenge 4: Scaling
  Stateless: scale to 10 pods → all 10 identical, all handle traffic
  Stateful:  scale to 3 PostgreSQL pods → need to:
               Configure replication between them
               Know which is primary vs replica
               Not write to replicas
  
  Solution: Operators (custom controllers that understand the app)

Challenge 5: Upgrades
  Stateless: rolling update, any pod can be replaced any time
  Stateful:  upgrade postgres-2 first (replica, safe)
             Then postgres-1
             Then postgres-0 (primary) last — needs failover first
  
  Solution: StatefulSet orderedReady update strategy
```

-----

## PART 2 — STATEFULSET DEEP DIVE

### What StatefulSet Gives You

```
1. Stable Pod Names:
   Deployment: api-7d9f8c-abc12 (random suffix, changes each restart)
   StatefulSet: postgres-0, postgres-1, postgres-2 (always same names)

2. Stable Network Identity (DNS):
   postgres-0.postgres-svc.production.svc.cluster.local  ← always this
   postgres-1.postgres-svc.production.svc.cluster.local
   
   Even if pod restarts, it gets the SAME DNS name

3. Stable Storage (VolumeClaimTemplates):
   postgres-0 always gets PVC "data-postgres-0"
   postgres-1 always gets PVC "data-postgres-1"
   
   Pod restarts → new pod has SAME PVC (same data)
   PVC is NOT deleted when pod is deleted

4. Ordered Operations:
   Startup:  0 → 1 → 2 (sequential, each waits for previous)
   Shutdown: 2 → 1 → 0 (reverse order)
   Updates:  2 → 1 → 0 (highest index first = replicas before primary)
```

### StatefulSet vs Deployment — Visual

```
DEPLOYMENT (stateless):

Deploy 3 replicas:
  api-abc01 ──→ [Pod] (random name)
  api-abc02 ──→ [Pod] (random name)  All start simultaneously
  api-abc03 ──→ [Pod] (random name)

Delete api-abc01:
  api-xyz99 ──→ [Pod] (new name, new IP, fresh start)
  
  Shared PVC (if any) or no PVC

STATEFULSET (stateful):

Deploy 3 replicas:
  postgres-0 ──→ [Pod] ← starts FIRST, waits until Running
  postgres-1 ──→ [Pod] ← starts SECOND (after 0 is running)
  postgres-2 ──→ [Pod] ← starts THIRD (after 1 is running)

Delete postgres-0:
  postgres-0 ──→ [Pod] (SAME name, gets data-postgres-0 PVC back)
  
  data-postgres-0 (PVC) survives pod deletion — data intact!
  New postgres-0 connects to its own old disk
```

### Complete StatefulSet YAML

```yaml
# statefulset.yaml — PostgreSQL StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  # REQUIRED: links to headless service for stable DNS
  serviceName: postgres-headless
  
  replicas: 3
  
  selector:
    matchLabels:
      app: postgres
  
  # Update strategy — ordered (highest pod first)
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0          # update all pods (increase to pause mid-update)
  
  # Pod management policy
  podManagementPolicy: OrderedReady   # default (sequential)
  # podManagementPolicy: Parallel     # all pods at once (use for some apps)
  
  template:
    metadata:
      labels:
        app: postgres
    spec:
      # Don't schedule two postgres pods on same node
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: postgres
            topologyKey: kubernetes.io/hostname    # one pod per node
      
      # Spread across AZs
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: postgres
      
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        
        env:
        - name: POSTGRES_DB
          value: judicial
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata    # subdirectory (avoid lost+found issue)
        
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data      # where postgres stores data
        - name: config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 15
          periodSeconds: 5
          failureThreshold: 6
        
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
      
      volumes:
      - name: config
        configMap:
          name: postgres-config
  
  # CRITICAL: PVC template — each pod gets its own PVC
  volumeClaimTemplates:
  - metadata:
      name: data              # PVC name: "data-postgres-0", "data-postgres-1", etc.
    spec:
      accessModes: ["ReadWriteOnce"]   # one pod at a time
      storageClassName: gp3            # AWS EBS gp3
      resources:
        requests:
          storage: 100Gi
```

### Headless Service — The DNS Magic

```yaml
# Headless service: no single ClusterIP, returns individual pod IPs
# This is what gives each pod its stable DNS name

apiVersion: v1
kind: Service
metadata:
  name: postgres-headless    # MUST match StatefulSet.spec.serviceName
  namespace: production
spec:
  clusterIP: None            # HEADLESS — no virtual IP
  selector:
    app: postgres
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432

# DNS entries created:
# postgres-0.postgres-headless.production.svc.cluster.local → pod-0 IP
# postgres-1.postgres-headless.production.svc.cluster.local → pod-1 IP
# postgres-2.postgres-headless.production.svc.cluster.local → pod-2 IP

# Also a regular service for clients (routes to primary only via label)
---
apiVersion: v1
kind: Service
metadata:
  name: postgres             # app uses this (stable endpoint)
  namespace: production
spec:
  selector:
    app: postgres
    role: primary            # only route to primary pod
  ports:
  - port: 5432
    targetPort: 5432
```

-----

## PART 3 — PERSISTENT STORAGE

### The Storage Hierarchy

```
StorageClass
    │
    │ defines HOW to provision
    │ (AWS EBS gp3, EFS, etc.)
    ▼
PersistentVolume (PV)
    │
    │ actual disk resource
    │ (AWS EBS volume, EFS filesystem)
    ▼
PersistentVolumeClaim (PVC)
    │
    │ pod's request for storage
    │ "I need 100Gi of gp3 storage"
    ▼
Pod
    │
    │ mounts the PVC as a directory
    ▼
Application writes to /var/lib/postgresql/data
```

### StorageClass — Defining Storage Types

```yaml
# StorageClass for AWS EBS gp3 (fast SSD, most common for databases)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com          # AWS EBS CSI driver
parameters:
  type: gp3
  iops: "3000"                        # 3000 IOPS baseline (free with gp3)
  throughput: "125"                   # 125 MB/s baseline
  encrypted: "true"                   # encrypt at rest
reclaimPolicy: Retain                 # KEEP volume when PVC deleted (important!)
volumeBindingMode: WaitForFirstConsumer  # create in same AZ as pod
allowVolumeExpansion: true            # allow growing the volume

---
# StorageClass for AWS EFS (NFS — multiple pods can mount)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678           # your EFS file system ID
  directoryPerms: "700"
reclaimPolicy: Retain
```

### Reclaim Policy — CRITICAL Decision

```
Delete (default for most StorageClasses):
  PVC deleted → PV deleted → EBS VOLUME DELETED → DATA GONE
  
  Use for: non-critical data, temp storage, development
  
Retain:
  PVC deleted → PV marked "Released" → EBS VOLUME KEPT
  Admin must manually delete or recycle
  
  Use for: PRODUCTION DATABASES — always use Retain
           Accidentally delete PVC? Data still on EBS, can recover

Real scenario:
  DBA runs: kubectl delete pvc data-postgres-0
  
  With Delete policy: 100GB of production data → GONE immediately
  With Retain policy: EBS volume kept → admin can recover
  
  ALWAYS use reclaimPolicy: Retain for production databases
```

### PVC Lifecycle with StatefulSet

```
StatefulSet created:
  postgres-0 starts → PVC "data-postgres-0" created (100GB EBS)
  postgres-1 starts → PVC "data-postgres-1" created (100GB EBS)
  postgres-2 starts → PVC "data-postgres-2" created (100GB EBS)

postgres-0 pod deleted (crash, node failure):
  Pod gone BUT PVC "data-postgres-0" STAYS (PVC survives pod death)
  New postgres-0 pod created
  New pod finds PVC "data-postgres-0" (still exists)
  New pod mounts same EBS volume → same data → database intact!

StatefulSet SCALED DOWN (postgres-2 removed):
  Pod postgres-2 deleted
  PVC "data-postgres-2" STAYS (K8s does NOT delete PVCs on scale-down)
  You must manually delete it if you want to free the storage
  This is intentional — prevents accidental data loss!

StatefulSet DELETED entirely:
  All pods deleted
  All PVCs STAY (with Retain policy)
  All EBS volumes STAY
  Data preserved — can restore by recreating StatefulSet

Key insight: PVCs have a lifecycle INDEPENDENT of pods
             Only deleted manually or by PVC deletion
```

### Storage Classes Comparison

```
EBS gp3 (AWS Block Storage):
  Access mode: ReadWriteOnce (one pod, one node at a time)
  Performance: up to 16,000 IOPS, 1000 MB/s
  Use for: databases (PostgreSQL, MySQL), high-performance storage
  AZ specific: volume lives in ONE AZ → pod must be in same AZ
  Cost: $0.08/GB/month
  CANNOT be shared between pods

EBS io2 (High Performance):
  Access mode: ReadWriteOnce OR ReadWriteOncePod
  io2 Block Express: up to 256,000 IOPS (for Oracle, SAP HANA)
  Multi-Attach: attach to multiple EC2s in same AZ (rare, complex)
  Cost: $0.125/GB/month + $0.065/provisioned IOPS

EFS (AWS Elastic File System — NFS):
  Access mode: ReadWriteMany (many pods on many nodes)
  Performance: scales automatically, but higher latency than EBS
  Use for: shared uploads, shared config, content management
  Multi-AZ: available across all AZs in region
  Cost: $0.30/GB/month (more expensive than EBS)
  
  When to use EFS:
    Multiple pods need to READ the same files
    Shared upload directory (user uploads, media)
    Legacy app that writes to NFS
    StatefulSet where pod needs to move across AZs freely

Decision:
  Database → EBS gp3 (performance, cost)
  Shared files → EFS (multi-AZ, multi-pod)
  Archives → S3 (cheapest, accessed via API not filesystem)
```

-----

## PART 4 — DATABASES IN K8s vs MANAGED SERVICES

### The Big Question: Run in K8s or Use Managed Service?

```
RUNNING DATABASES IN KUBERNETES:

Advantages:
  Everything in one place (K8s cluster)
  Consistent tooling (kubectl for everything)
  Potential cost savings (no managed service premium)
  Full control over version, config, tuning

Disadvantages (and they're serious):
  YOU are responsible for:
    High availability (replication setup, failover)
    Backup automation (schedule, retention, restore testing)
    Version upgrades (without data loss, ideally zero-downtime)
    Point-in-time recovery
    WAL archiving
    Connection pooling (PgBouncer, etc.)
    Performance tuning
    Monitoring (pg_stat_activity, slow queries, bloat)
    Security (encryption, network isolation, least privilege)
    Storage management (growing volumes, IOPS tuning)
  
  These are HARD problems. DBAs spend careers on them.
  Getting any of them wrong = data loss or outage.

MANAGED SERVICES (RDS, CloudSQL, Atlas):

Advantages:
  AWS/GCP does the hard stuff:
    Automated backups (daily snapshots, transaction log)
    Point-in-time restore (any second in last 35 days)
    Multi-AZ failover (automatic, ~60 seconds)
    Minor version auto-upgrade
    Storage auto-scaling
    Performance Insights (query profiling built in)
    Encryption at rest (one checkbox)
    
  You focus on: schema design, query optimization, business logic

Disadvantages:
  More expensive than EC2 + EBS (~30-50% premium)
  Less control over exact version, tuning parameters
  Tied to cloud provider
  Some features only in specific versions (not latest sometimes)
```

### When to Run Databases in Kubernetes

```
YES, run in K8s when:
  Development / Staging environments
    Cost matters more than resilience
    Dev DB can be recreated from scratch
    
  Simple, low-stakes data
    Cache data that can be lost (Redis without persistence)
    Data easily re-derived from other sources
    
  You have dedicated DBA expertise
    Team that manages K8s databases professionally
    Operators like Zalando postgres-operator, Percona operator
    
  Specific version or config requirements
    RDS doesn't support your PostgreSQL extension
    Need custom plugin
    
  Cost at scale
    Running hundreds of small databases → RDS overhead significant
    Custom operators handle this well at scale

NO, don't run in K8s when:
  Production with real user data (use RDS/managed)
  No DBA expertise on team
  Small team — don't want to own database operations
  Compliance requires managed service audit logs
  Financial, healthcare data — RDS has better compliance tools
```

### Practical Rule

```
Developer Rule:
  "If your database has production user data, use a managed service.
   If you're comfortable losing the data, run it in K8s."

Team Size Rule:
  1-10 engineers:   use managed services (no time for DB ops)
  10-50 engineers:  still probably managed services
  50+ engineers:    maybe consider K8s with dedicated DB operator + DBA

My recommendation for judicialsolutions.in:
  PostgreSQL → AWS RDS (managed) — you have real user case data
  Redis → ElastiCache OR in K8s (depends on persistence needs)
  
  Why not K8s for Postgres?
    You don't want to manage WAL archiving, failover, backups
    RDS handles all of that for ~$80/month
    That's cheap compared to the engineering time to run it yourself
```

-----

## PART 5 — POSTGRESQL HA IN KUBERNETES

### If You Must Run PostgreSQL in K8s — Use an Operator

```
Don't write a StatefulSet from scratch for PostgreSQL
Use an OPERATOR that understands PostgreSQL:

Zalando postgres-operator (most popular):
  Creates PostgreSQL clusters with:
    Automatic primary election
    Streaming replication configured automatically
    Automatic failover
    Backup to S3 (WAL-G)
    Connection pooling (PgBouncer built-in)
    
  You declare what you want:
    "I want a 3-node PostgreSQL 16 cluster with 100GB storage"
  Operator figures out: primary, replicas, replication config

Percona Operator for PostgreSQL:
  Similar to Zalando, more enterprise features
  Point-in-time recovery built-in
  
CloudNativePG (CNPG):
  Kubernetes-native PostgreSQL operator
  Growing in popularity
  Excellent backup/restore tooling
```

### Zalando PostgreSQL Operator — Simple Cluster

```yaml
# Install operator first:
# kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/master/docs/manifests/minimal-postgres-manifest.yaml

# Create PostgreSQL cluster
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: judicial-postgres
  namespace: production
spec:
  teamId: "judicial"
  volume:
    size: 100Gi
    storageClass: gp3
  numberOfInstances: 3         # 1 primary + 2 replicas
  
  postgresql:
    version: "16"
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      work_mem: "4MB"
      maintenance_work_mem: "64MB"
      
  users:
    judicial_app:              # creates this user
    - superuser
    - createdb
  
  databases:
    judicial_db: judicial_app  # database owned by user
  
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"
  
  # Backup configuration
  backup:
    retention: "7 days"

# What operator creates automatically:
# - StatefulSet with 3 pods
# - Headless service
# - Primary service (routes to primary only)
# - Replica service (routes to replicas)
# - Configures pg_hba.conf, recovery.conf
# - Sets up streaming replication
# - Handles failover automatically
```

### How Failover Works (Patroni under the hood)

```
Zalando operator uses Patroni for HA:

Normal operation:
  postgres-0: PRIMARY (accepts reads + writes)
  postgres-1: REPLICA (streaming from primary, reads only)
  postgres-2: REPLICA (streaming from primary, reads only)
  
  Patroni election state stored in: etcd or K8s API
  Leader lease: postgres-0 holds the "leader" key
  
  App connects to: master service → routed to postgres-0

postgres-0 dies:
  
  Step 1: Patroni detects heartbeat missing (~5 seconds)
  Step 2: Leader lease expires
  Step 3: postgres-1 and postgres-2 race for the leader lease
  Step 4: postgres-1 wins → promotes itself to PRIMARY
  Step 5: postgres-1 updates K8s service selector (master → postgres-1)
  Step 6: postgres-2 reconfigures to follow postgres-1

  Total time: 15-30 seconds
  
  App: existing connections fail (brief)
       Reconnects → hits master service → now points to postgres-1
       Back online: 15-30 seconds after failure

App connection best practice:
  Use connection pool (PgBouncer) in front of PostgreSQL
  PgBouncer handles failover transparently to your app
  
  Or: retry logic in app (connect with retry on failure)
```

### Connection Pooling with PgBouncer

```yaml
# PgBouncer sits between your app and PostgreSQL
# Reduces connection overhead (PostgreSQL is expensive per connection)
# Lambda creates 1000 connections → PgBouncer pools them to 20 connections

apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
  namespace: production
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: pgbouncer
        image: bitnami/pgbouncer:latest
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRESQL_HOST
          value: judicial-postgres          # K8s service for PostgreSQL
        - name: POSTGRESQL_PORT
          value: "5432"
        - name: PGBOUNCER_DATABASE
          value: judicial_db
        - name: PGBOUNCER_POOL_MODE
          value: transaction                # best for web apps
        - name: PGBOUNCER_MAX_CLIENT_CONN
          value: "1000"                    # max client connections
        - name: PGBOUNCER_DEFAULT_POOL_SIZE
          value: "20"                      # actual connections to PostgreSQL

# App connects to: pgbouncer-service:5432
# PgBouncer forwards to: judicial-postgres:5432 (max 20 connections)
# 1000 Lambda functions → 20 real PostgreSQL connections
# Without PgBouncer: 1000 connections → PostgreSQL crashes (max 200)
```

-----

## PART 6 — REDIS IN KUBERNETES

### Redis Deployment Patterns

```
Pattern 1: Single Pod (dev/cache only)
  One Redis pod, no persistence
  Data lost on pod restart (fine for cache)
  Deployment (not StatefulSet — no stable identity needed)
  
  When: pure cache, session data OK to lose

Pattern 2: Redis with Persistence (single pod)
  One Redis pod + EBS volume
  Data survives pod restart
  StatefulSet with PVC
  Still single point of failure (pod/node dies = brief outage)
  
  When: session store, rate limiting state, small dataset

Pattern 3: Redis Sentinel (HA, no sharding)
  1 Primary + N Replicas + 3 Sentinels
  Sentinels monitor and handle failover
  StatefulSet for Redis + Deployment for Sentinel
  
  When: HA required, dataset fits on one node (<50GB)

Pattern 4: Redis Cluster (HA + sharding)
  6 pods minimum (3 primary + 3 replica)
  Data sharded across primaries
  Built-in failover via cluster protocol
  
  When: large datasets, high throughput, need sharding
```

### Redis with Persistence — StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: production
spec:
  serviceName: redis-headless
  replicas: 1            # single for simple persistence use case
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        
        command:
        - redis-server
        - --appendonly yes            # AOF persistence (every write logged)
        - --appendfsync everysec      # fsync every second (balance perf/safety)
        - --save 900 1                # RDB snapshot: save if 1 key changed in 900s
        - --save 300 10               # save if 10 keys changed in 300s
        - --save 60 10000             # save if 10000 keys changed in 60s
        - --requirepass $(REDIS_PASSWORD)
        - --maxmemory 1gb
        - --maxmemory-policy allkeys-lru  # evict LRU keys when full
        
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secrets
              key: password
        
        resources:
          requests:
            cpu: "100m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"         # must be >= maxmemory
        
        volumeMounts:
        - name: data
          mountPath: /data          # redis writes RDB and AOF here
        
        readinessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 5
          periodSeconds: 5
  
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3
      resources:
        requests:
          storage: 10Gi

---
# Headless service for stable DNS
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
  - port: 6379

---
# Regular service for app connections
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
```

### Redis Persistence Modes Explained

```
RDB (Redis Database) — Snapshot:
  Point-in-time snapshot of all data
  Written to disk periodically (configurable)
  Compact binary format
  Fast restart (load from RDB file)
  Data loss: everything since last snapshot (could be minutes)
  
  save 900 1      → snapshot if 1 key changed in 15 min
  save 300 10     → snapshot if 10 keys changed in 5 min
  save 60 10000   → snapshot if 10K keys changed in 1 min

AOF (Append Only File) — Log:
  Every write operation appended to log file
  Can replay log to reconstruct dataset
  Much less data loss (everysec = max 1 second loss)
  Larger file than RDB, slower restart
  
  appendfsync always     → write + fsync every operation (slowest, safest)
  appendfsync everysec   → fsync once per second (balanced — RECOMMENDED)
  appendfsync no         → let OS decide (fastest, least safe)

Use both (recommended for production):
  RDB: fast restart, compact backup
  AOF: minimal data loss between snapshots
  Redis loads AOF on startup (more complete)

For cache-only Redis:
  No persistence needed
  Save memory and I/O overhead
  comment out all save lines, appendonly no
```

-----

## PART 7 — KAFKA IN KUBERNETES

### Kafka Basics for Context

```
Kafka = distributed event streaming platform
  Messages published to TOPICS
  Topics split into PARTITIONS (for parallelism)
  Partitions replicated across BROKERS (for fault tolerance)
  Consumers read from partitions

Why Kafka needs StatefulSet:
  Broker-0 always holds partition data for its assigned partitions
  Broker-0's data must survive restarts
  Other brokers need stable addresses to replicate to/from broker-0
  Ordered restart (shutdown cleanly before new one starts)
```

### Strimzi Operator — Kafka in K8s

```
Don't write Kafka StatefulSet from scratch
Use Strimzi operator (industry standard for Kafka on K8s)

Strimzi provides:
  KafkaCluster CRD: declare your cluster, operator handles rest
  Automatic TLS between brokers and clients
  Cruise Control for partition rebalancing
  Kafka Connect, Kafka Bridge
  Mirror Maker 2 (multi-cluster replication)
```

```yaml
# Install Strimzi operator first
# kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka'

# Create Kafka cluster
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: judicial-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 3                   # 3 broker pods: kafka-0, kafka-1, kafka-2
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3      # replicate consumer offsets
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3            # all topics replicated 3x
      min.insync.replicas: 2                   # need 2 in-sync before ack
    storage:
      type: persistent-claim
      size: 100Gi
      class: gp3
      deleteClaim: false                       # keep PVC when cluster deleted
    resources:
      requests:
        cpu: "500m"
        memory: "2Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
  
  zookeeper:                       # Kafka <3.4 needs Zookeeper
    replicas: 3
    storage:
      type: persistent-claim
      size: 10Gi
      class: gp3
  
  entityOperator:
    topicOperator: {}              # manages Kafka topics via K8s CRD
    userOperator: {}               # manages Kafka users via K8s CRD
```

-----

## PART 8 — DATA MIGRATION AND SCHEMA CHANGES

### The Zero-Downtime Database Migration Problem

```
Problem:
  You have PostgreSQL with 1M rows of production data
  New version of your app needs a new column / changed schema
  
  Naive approach: stop app → run migration → start new app
  Result: downtime (unacceptable for production)

Zero-downtime approach: Expand/Contract pattern

Phase 1: EXPAND (backward compatible schema change)
  Add new column (nullable or with default)
  Both old app (v1) and new app (v2) work with new schema
  Deploy migration: ALTER TABLE cases ADD COLUMN priority INT DEFAULT 0;
  
  Old app: ignores the new column (SQL selects don't break)
  New app: reads and writes the new column
  
Phase 2: DEPLOY NEW APP
  Rolling update: mix of v1 and v2 pods running simultaneously
  Both work because schema is compatible with both versions
  Zero downtime
  
Phase 3: BACKFILL (fill new column for existing rows)
  Run as background job while app is running
  UPDATE cases SET priority = 0 WHERE priority IS NULL;
  Use batches to avoid locking table (1000 rows at a time)
  
Phase 4: CONTRACT (make column non-nullable, drop old column)
  Only after 100% pods are on new version
  ALTER TABLE cases ALTER COLUMN priority SET NOT NULL;
  
  For removing old columns: separate deployment after full rollout
  Never remove column in same deploy as v2 app
```

### Database Migrations in CI/CD

```yaml
# Option 1: Init container in deployment
spec:
  initContainers:
  - name: migrate
    image: judicial-api:1.3.0       # same image as app
    command: ["python", "manage.py", "migrate"]
    env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: db-secrets
          key: url
  
  containers:
  - name: api
    image: judicial-api:1.3.0
  
  # Init container runs migration BEFORE any app pod starts
  # If migration fails: app pod never starts → deployment fails
  # Safe for simple, backward-compatible migrations

# Option 2: Kubernetes Job (recommended for complex migrations)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate-v1-3-0
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: migrate
        image: judicial-api:1.3.0
        command: ["python", "manage.py", "migrate", "--no-input"]
      
# Run before deployment:
# kubectl apply -f migrate-job.yaml
# kubectl wait --for=condition=complete job/db-migrate-v1-3-0 --timeout=5m
# kubectl apply -f deployment.yaml   # only deploy if migration succeeded
```

### Flyway / Liquibase — Database Version Control

```
Track schema changes in version-controlled migration files:

migrations/
├── V1__initial_schema.sql      # V<version>__<description>.sql
├── V2__add_cases_table.sql
├── V3__add_priority_column.sql
└── V4__add_documents_index.sql

Flyway tracks which migrations have run (in schema_version table)
Each run: checks which migrations not yet applied → runs them
Idempotent: safe to run multiple times

# Docker: run migration before deploying
docker run --rm \
  flyway/flyway:latest \
  -url=jdbc:postgresql://db:5432/judicial \
  -user=admin \
  -password=secret \
  migrate

# In Kubernetes:
# Job that runs Flyway before rolling update
# If Flyway fails → don't deploy new app version
```

-----

## PART 9 — BACKUP AND RESTORE STRATEGY

### What Needs Backing Up

```
Stateful data to back up:
  Database (PostgreSQL): MOST CRITICAL
    Full backup: pg_dump or pg_basebackup (snapshot of all data)
    WAL archiving: continuous log of changes (enables PITR)
    
  Redis: if using AOF/RDB persistence
    RDB file: periodic snapshot
    
  Uploaded files: if stored in pod (should be in S3!)
  
  Kubernetes resources: not usually backed up separately
    Your YAML files are in git (source of truth)
    But: secrets, PVCs, CRDs might need backup (Velero)

What NOT to backup separately:
  Kubernetes YAML manifests: in git
  Docker images: in ECR (versioned)
  Stateless app data: nothing to back up
```

### PostgreSQL Backup with WAL-G

```yaml
# WAL-G: lightweight WAL archiving + backup tool for PostgreSQL
# Stores backups directly to S3

# Postgres pod with WAL-G sidecar
spec:
  containers:
  - name: postgres
    image: postgres:16
    env:
    - name: WALG_S3_PREFIX
      value: s3://judicial-backups/postgres
    - name: AWS_REGION
      value: ap-south-1
    # WAL archiving: send every WAL file to S3 immediately
    command:
    - postgres
    - -c
    - archive_mode=on
    - -c
    - archive_command=wal-g wal-push %p
    - -c
    - archive_timeout=60

# Backup CronJob — daily full backup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"          # 2am daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            command:
            - /bin/sh
            - -c
            - |
              # Take full backup and push to S3
              wal-g backup-push /var/lib/postgresql/data
              
              # Keep only last 7 full backups
              wal-g delete retain FULL 7 --confirm
            env:
            - name: WALG_S3_PREFIX
              value: s3://judicial-backups/postgres
          restartPolicy: OnFailure
```

### Velero — Backup Entire K8s Cluster State

```bash
# Velero backs up: K8s objects + PVC data (via volume snapshots)

# Install Velero with AWS
velero install \
  --provider aws \
  --bucket judicial-velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=ap-south-1 \
  --snapshot-location-config region=ap-south-1 \
  --use-node-agent                    # for PVC backup

# Create backup schedule
velero schedule create daily \
  --schedule="0 1 * * *" \
  --include-namespaces production \
  --ttl 720h                          # keep for 30 days

# Manual backup before risky operation
velero backup create pre-migration-backup \
  --include-namespaces production

# List backups
velero backup get

# Restore everything
velero restore create \
  --from-backup daily-20240322010000

# Restore specific namespace
velero restore create \
  --from-backup daily-20240322010000 \
  --include-namespaces production
```

### Backup Testing — Often Forgotten

```
Backups are useless unless you test restores.

Monthly restore test:
  1. Take backup
  2. Create new PostgreSQL instance (different namespace)
  3. Restore backup to new instance
  4. Run data validation:
     - Row counts match? SELECT COUNT(*) FROM cases
     - Recent data present? SELECT MAX(created_at) FROM cases
     - FK constraints valid? CHECK CONSTRAINTS
  5. Run app against restored DB (staging test)
  6. Document: restore time, data completeness

Metrics to track:
  RPO (Recovery Point Objective): how old is the restored data?
    WAL archiving + PITR: < 1 minute data loss
    Daily snapshot: up to 24 hours data loss
    
  RTO (Recovery Time Objective): how long does restore take?
    100GB PostgreSQL: ~30 minutes to restore
    + application start time
    + smoke tests
    Total: ~45-60 minutes

Set RTO/RPO goals BEFORE an incident, not during.
"How much data can we lose? How long can we be down?"
These answers determine your backup strategy.
```

-----

## PART 10 — MULTI-AZ FOR STATEFUL APPS

### The AZ Problem for Stateful Apps

```
Stateless app + multi-AZ = easy
  Pod-1 (AZ-1a), Pod-2 (AZ-1b), Pod-3 (AZ-1c)
  Any pod can serve any request
  AZ fails → other pods handle it

Stateful app + multi-AZ = HARD

PostgreSQL challenge:
  Primary can only be in ONE AZ
  Replicas in other AZs (streaming replication)
  AZ of primary fails → Patroni promotes replica (15-30 sec)
  AZ of replica fails → no data loss, primary unaffected
  
  PROBLEM with EBS:
    Primary runs in AZ-1a with EBS volume in AZ-1a
    Primary pod can NEVER move to AZ-1b (EBS volume is AZ-specific)
    If AZ-1a dies permanently: EBS volume in AZ-1a also gone
    New primary = AZ-1b replica (already has streamed copy of data)
    Old primary's EBS = lost (but already replicated to AZ-1b)
  
Redis challenge:
  Single Redis with EBS: AZ-specific, no cross-AZ failover
  Redis Sentinel/Cluster: replica in each AZ, failover works
  
Kafka:
  Partitions replicated across brokers in different AZs
  min.insync.replicas=2: data written to 2 AZs before ack
  Broker in AZ fails: partition leader election in seconds
```

### StorageClass: WaitForFirstConsumer

```yaml
# CRITICAL for multi-AZ + EBS:
# Without this: PVC might be created in AZ-1a, pod scheduled in AZ-1b
# With this:    PVC created in same AZ as pod (after pod is scheduled)

kind: StorageClass
spec:
  volumeBindingMode: WaitForFirstConsumer
  # PVC is not provisioned immediately
  # Wait until a pod is scheduled, then create EBS in THAT pod's AZ

# Without this setting:
  PVC created → EBS in AZ-1a (random)
  Pod scheduled → AZ-1b (random)
  Pod tries to mount EBS from AZ-1a → FAILS (EBS is AZ-specific!)
  Pod stuck in Pending state

# With WaitForFirstConsumer:
  PVC created → no EBS yet (waiting)
  Pod scheduled → lands on node in AZ-1c
  EBS created in AZ-1c → attached to pod
  Works!
```

### Multi-AZ Storage Options

```
Option 1: EBS per pod (AZ-specific)
  Each pod has its own EBS in its AZ
  AZ fails: pod + EBS lost, but data replicated to other AZs via app
  Recovery: new pod in another AZ + restore from replica
  Best for: databases with application-level replication (PostgreSQL streaming)

Option 2: EFS (multi-AZ NFS)
  Single EFS filesystem accessible from all AZs
  Multiple pods can mount same EFS (ReadWriteMany)
  AZ fails: pods in other AZs continue reading/writing same EFS
  Downside: higher latency than EBS (NFS vs block storage)
  Best for: shared files, not for databases (latency too high)

Option 3: Portworx / OpenEBS (storage operators)
  Sync EBS volumes across AZs at storage layer
  More complex to set up and operate
  Gives you EBS performance + multi-AZ resilience
  Best for: complex stateful workloads requiring storage HA

Practical guidance:
  PostgreSQL: EBS per pod + Patroni for app-level HA (industry standard)
  Redis: EBS per pod + Sentinel/Cluster for app-level HA
  Shared files: EFS (multi-AZ by design)
  Don't try to make EBS multi-AZ with storage operators unless you know exactly what you're doing
```

-----

## PART 11 — COMPLETE PRODUCTION PATTERNS

### Pattern 1: PostgreSQL with RDS (Recommended)

```
Architecture:
  Your pods (in K8s) → RDS PostgreSQL (outside K8s)
  
  RDS handles:
    Multi-AZ failover (automatic, ~60 seconds)
    Daily automated backups (35 days retention)
    Point-in-time recovery
    Storage auto-scaling
    Minor version upgrades
  
  You configure:
    Instance size (t3.medium, m5.large, etc.)
    VPC/subnet (private subnet, not public!)
    Security group (allow from K8s node security group only)
    Parameter groups (max_connections, work_mem, etc.)
    
  K8s side:
    Store RDS endpoint in ConfigMap
    Store password in Secret (or External Secrets from Secrets Manager)
    No PVC needed (RDS handles storage)
    
  Connection:
    App pod → RDS Proxy (connection pooling) → RDS Primary
    RDS Proxy handles: connection pooling, failover transparency

# ExternalName service: give RDS a stable K8s DNS name
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: production
spec:
  type: ExternalName
  externalName: judicial-prod.cluster-xxx.ap-south-1.rds.amazonaws.com
  # App uses: postgres:5432 (K8s DNS)
  # K8s resolves to: RDS endpoint
  # If you migrate RDS: change ExternalName, app unchanged
```

### Pattern 2: Stateful App with Operator (In-Cluster)

```
Use when: you need K8s-native DB, team has DB expertise

Stack:
  Zalando postgres-operator → creates PostgreSQL cluster
  PgBouncer → connection pooling
  WAL-G → continuous archiving to S3
  Patroni → handles failover (built into operator)
  
Deployment flow:
  1. Install postgres-operator (one-time cluster setup)
  2. Create PostgreSQL CRD (your cluster spec)
  3. Operator creates: StatefulSet, Services, PVCs, Patroni config
  4. Deploy PgBouncer in front of PostgreSQL
  5. App connects to PgBouncer service

Backup flow:
  Patroni + WAL-G: continuous WAL archiving to S3
  Daily basebackup CronJob: full base backup to S3
  Velero: backup K8s objects (StatefulSet, PVCs, Secrets)
  
  RPO: < 5 seconds (WAL archiving interval)
  RTO: 30-60 minutes (restore base backup + replay WAL)
```

### Pattern 3: Hybrid (K8s App + Managed DB)

```
Most teams settle here — best of both worlds:

In Kubernetes:
  Your application pods (stateless)
  Redis for caching (K8s, can lose data — cache miss okay)
  Kafka for events (in-cluster with Strimzi)

Managed services:
  PostgreSQL → RDS Multi-AZ
  MySQL → RDS Multi-AZ
  "Real" Redis with persistence → ElastiCache

Why this split:
  App pods: K8s is excellent for stateless → use it
  Databases: managed services better for production → use them
  Redis: depends on persistence needs
    Cache only (OK to lose) → K8s (cheaper)
    Session store (must persist) → ElastiCache

This is what most production K8s systems look like.
```

### Pattern 4: Stateful App Delivery Pipeline

```
How you actually deliver a stateful app update:

Step 1: Schema migration (before new code)
  Create migration file: V5__add_hearings_table.sql
  Run migration Job in K8s:
    kubectl apply -f db-migrate-job.yaml
    kubectl wait --for=condition=complete job/db-migrate-v5
  Migration backward-compatible: old app still works

Step 2: Deploy new app version (rolling update)
  New pods start (using new schema features)
  Old pods still running (compatible with new schema)
  Zero downtime rolling update

Step 3: Verify
  Smoke tests against new pods
  Check DB for new data being written correctly

Step 4: Cleanup (next sprint, after confident)
  If old columns removed: run CONTRACT migration
  ALTER TABLE hearings DROP COLUMN old_field;
  This requires all pods on new version (they no longer use old_field)

Step 5: Backup verification
  After major schema change: verify backup works
  Test restore to staging
```

-----

## PART 15 — INTERVIEW QUESTIONS

**Q1: How do you deliver a stateful application in Kubernetes?**

```
"Delivering stateful apps requires several things working together:

1. StatefulSet instead of Deployment:
   Stable pod names (postgres-0, postgres-1)
   Stable DNS per pod (postgres-0.svc.cluster.local)
   Ordered startup/shutdown
   Each pod gets its own PVC (not shared)

2. Persistent Storage (PVC):
   volumeClaimTemplates in StatefulSet
   Each pod gets dedicated EBS volume
   PVC survives pod deletion — data persists
   StorageClass: WaitForFirstConsumer (creates EBS in same AZ as pod)
   reclaimPolicy: Retain (EBS not deleted when PVC deleted)

3. Application-level HA (for databases):
   Don't rely on K8s for DB failover — use an Operator
   Zalando postgres-operator → Patroni handles primary election
   Redis Sentinel or Cluster → handles Redis failover

4. Headless Service:
   clusterIP: None → gives each pod stable DNS
   Regular service → routes to primary only (via label)

5. Backup:
   WAL-G for PostgreSQL (continuous archiving to S3)
   Velero for K8s objects + PVC snapshots

In practice:
   For production user data: use managed service (RDS, ElastiCache)
   For in-cluster stateful needs: use operator (Strimzi, Zalando)
   Never write StatefulSet for databases from scratch"
```

**Q2: What happens to data when a pod in a StatefulSet restarts?**

```
"The data is NOT lost — this is the key feature of StatefulSet.

When postgres-0 crashes:
  Pod postgres-0 is deleted
  PVC 'data-postgres-0' STAYS (independent of pod lifecycle)
  EBS volume behind that PVC stays mounted in AWS
  
K8s creates new postgres-0 pod:
  New pod looks for PVC named 'data-postgres-0' (same name as old pod)
  Finds existing PVC → mounts the same EBS volume
  PostgreSQL starts, finds existing data directory
  Resumes from where it left off (or recovers from WAL)

Contrast with Deployment:
  Pod dies → new pod might run on different node
  No stable PVC name — gets new random PVC or ephemeral storage
  Data gone

This is why naming matters:
  StatefulSet pod name: postgres-0 (always same)
  PVC name: data-postgres-0 (matches pod name via template)
  Even after restart: pod name same → finds same PVC → same data"
```

**Q3: Why can’t you just use Deployment for a database?**

```
"Three fundamental problems:

1. No stable identity:
   Deployment pod names are random (postgres-7d9f8-abc12)
   If pod dies, new pod has different name
   PVC naming based on pod name → new pod creates new PVC (empty!)
   StatefulSet: always postgres-0 → always finds data-postgres-0

2. No ordered startup:
   Deployment starts all pods simultaneously
   PostgreSQL cluster: if all 3 start at once → conflict (who is primary?)
   StatefulSet: postgres-0 starts first → becomes primary
               postgres-1 starts after → connects to postgres-0 as replica

3. No stable network identity:
   Deployment pod: pod-abc12.service.svc.cluster.local (random)
   Replica can't find primary by stable address
   StatefulSet: postgres-0.postgres-headless.svc.cluster.local (always stable)
   Replica knows exactly where to find primary

These three together make StatefulSet necessary for databases."
```

**Q4: How do you handle database migrations with zero downtime?**

```
"The Expand/Contract pattern:

Phase 1 (Expand): backward-compatible schema change
  ALTER TABLE cases ADD COLUMN priority INT DEFAULT 0;
  Both old (v1) and new (v2) app work with this schema
  
Phase 2: Deploy new app (rolling update)
  Mix of v1 and v2 pods running — both work with new schema
  Zero downtime rolling update
  
Phase 3: Backfill
  UPDATE cases SET priority = 0 WHERE priority IS NULL;
  Done in batches (1000 rows) to avoid table lock

Phase 4 (Contract): remove old columns (next release)
  Only AFTER 100% pods are on v2
  ALTER TABLE cases DROP COLUMN old_field;
  
In practice:
  I use Flyway for migration versioning
  CIpipeline runs Flyway before deploying new app image
  If migration fails → deployment stops (never deploy app without schema)
  
  kubectl apply -f flyway-job.yaml
  kubectl wait --for=condition=complete job/db-migrate-v5 --timeout=5m
  # Only proceed with app deployment if job completed successfully
  kubectl apply -f deployment.yaml"
```

**Q5: What is the difference between RDB and AOF in Redis?**

```
"Two persistence mechanisms:

RDB (snapshotting):
  Periodic point-in-time snapshot of all data
  Config: save 900 1 (snapshot if 1 key changes in 15 min)
  Compact binary file (fast restart)
  Data loss risk: everything since last snapshot (could be minutes)
  Use: fastest restart, acceptable data loss window

AOF (append-only file):
  Every write command appended to log
  appendfsync everysec: sync to disk once per second
  Max data loss: 1 second
  Larger file, slower restart (replay all commands)
  Use: minimal data loss required

Best practice: use BOTH
  RDB: fast restart from binary snapshot
  AOF: minimal data loss between snapshots
  Redis loads AOF on startup (more complete than RDB)

For cache-only Redis:
  No persistence needed
  Disable both: more memory efficient, less I/O
  Worst case: cache miss, re-fetch from DB"
```

-----

## PART 12 — 3-TIER APPLICATION DEPLOYMENT IN VPC

### What is 3-Tier Architecture?

```
3-tier = classic production architecture separating:
  Tier 1 — Presentation (Frontend):  what users see and interact with
  Tier 2 — Application (Backend API): business logic, data processing
  Tier 3 — Data (Database/Cache):    stores and retrieves data

Why separate into tiers?
  Security:    each tier only talks to adjacent tiers (not skip layers)
  Scalability: scale each tier independently based on load
  Maintainability: change one tier without affecting others
  Resilience:  isolate failures to one tier

Real example (judicialsolutions.in):
  Tier 1: React frontend served via CloudFront + S3
  Tier 2: FastAPI backend running on EKS (judicial-api pods)
  Tier 3: PostgreSQL on RDS + Redis on ElastiCache
```

### VPC Design for 3-Tier

```
Core rule: each tier lives in its own SUBNET TYPE
           each subnet type has its own security posture

SUBNET TYPES:

Public Subnet:
  Has route to Internet Gateway
  Resources here: ALB, NAT Gateway, Bastion Host
  NOT for: EC2 app servers, databases
  Why public: ALB must accept internet traffic

Private Subnet (App):
  No route to Internet Gateway
  Has route through NAT Gateway (outbound only)
  Resources here: EKS nodes, EC2 app servers, Lambda
  Outbound internet: via NAT GW (to pull images, call APIs)
  Inbound: ONLY from ALB (via security group rule)

Data Subnet (Isolated):
  No internet route at all (no NAT GW either)
  Resources here: RDS, ElastiCache, internal DBs
  Inbound: ONLY from app subnet (via security group rule)
  Why most isolated: databases should never reach internet

VPC Layout (ap-south-1, 3 AZs):

  10.0.0.0/16 (VPC)
  ├── 10.0.1.0/24  PUBLIC  AZ-1a  ← ALB, NAT GW
  ├── 10.0.2.0/24  PUBLIC  AZ-1b  ← ALB, NAT GW
  ├── 10.0.3.0/24  PUBLIC  AZ-1c  ← ALB, NAT GW
  ├── 10.0.11.0/24 PRIVATE AZ-1a  ← EKS nodes, pods
  ├── 10.0.12.0/24 PRIVATE AZ-1b  ← EKS nodes, pods
  ├── 10.0.13.0/24 PRIVATE AZ-1c  ← EKS nodes, pods
  ├── 10.0.21.0/24 DATA    AZ-1a  ← RDS primary
  ├── 10.0.22.0/24 DATA    AZ-1b  ← RDS standby, ElastiCache
  └── 10.0.23.0/24 DATA    AZ-1c  ← ElastiCache replica
```

### Complete 3-Tier Network Architecture

```
INTERNET
    │
    │ HTTPS:443 / HTTP:80
    ▼
┌─────────────────────────────────────────────────────────┐
│              PUBLIC SUBNETS (10.0.1-3.0/24)             │
│                                                         │
│   ┌──────────────────────────────────────────────────┐  │
│   │     APPLICATION LOAD BALANCER (ALB)              │  │
│   │     - Spans all 3 AZs automatically              │  │
│   │     - SSL termination (ACM certificate)          │  │
│   │     - WAF attached (blocks OWASP Top 10)         │  │
│   │     - Routes: / → frontend, /api → backend       │  │
│   └──────────────────────────────────────────────────┘  │
│                                                         │
│   NAT-GW-1a    NAT-GW-1b    NAT-GW-1c                  │
│   (EIP)        (EIP)        (EIP)                       │
└─────────────────────────────────────────────────────────┘
                    │ (only ALB can connect to app tier)
                    │ Security Group: allow 8080 from ALB-SG
                    ▼
┌─────────────────────────────────────────────────────────┐
│             PRIVATE SUBNETS (10.0.11-13.0/24)           │
│                                                         │
│  AZ-1a              AZ-1b              AZ-1c            │
│  EC2 Node-1         EC2 Node-2         EC2 Node-3       │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐    │
│  │[api-pod-1] │    │[api-pod-2] │    │[api-pod-3] │    │
│  │[api-pod-4] │    │[api-pod-5] │    │[api-pod-6] │    │
│  │[fe-pod-1]  │    │[fe-pod-2]  │    │[fe-pod-3]  │    │
│  └────────────┘    └────────────┘    └────────────┘    │
│                                                         │
│  Outbound: via NAT-GW-1a/1b/1c (same AZ)              │
│  (pulls ECR images, calls AWS APIs)                     │
└─────────────────────────────────────────────────────────┘
                    │ (only app pods can connect to data tier)
                    │ Security Group: allow 5432 from Node-SG
                    ▼
┌─────────────────────────────────────────────────────────┐
│               DATA SUBNETS (10.0.21-23.0/24)            │
│                                                         │
│  AZ-1a                        AZ-1b                    │
│  ┌───────────────────┐        ┌───────────────────┐    │
│  │  RDS PostgreSQL   │◄──────►│  RDS Standby      │    │
│  │  PRIMARY          │  sync  │  (Multi-AZ)       │    │
│  └───────────────────┘        └───────────────────┘    │
│                                                         │
│  AZ-1b                        AZ-1c                    │
│  ┌───────────────────┐        ┌───────────────────┐    │
│  │ ElastiCache Redis │◄──────►│ ElastiCache Redis │    │
│  │ PRIMARY           │  repl  │ REPLICA           │    │
│  └───────────────────┘        └───────────────────┘    │
│                                                         │
│  NO internet access — completely isolated               │
└─────────────────────────────────────────────────────────┘
```

### Security Groups — Defence in Depth

```
Security Group 1: ALB-SG (internet-facing)
  Inbound:
    HTTPS 443  from 0.0.0.0/0   ← internet users
    HTTP  80   from 0.0.0.0/0   ← redirect to HTTPS
  Outbound:
    HTTP  8080 to App-SG        ← only to app tier

Security Group 2: App-SG (EKS nodes / pods)
  Inbound:
    HTTP  8080 from ALB-SG      ← ONLY from ALB
    SSH   22   from Bastion-SG  ← ONLY for admin
    All        from App-SG      ← pods talking to each other
  Outbound:
    HTTPS 443  to 0.0.0.0/0    ← via NAT GW (ECR, APIs)
    5432       to Data-SG       ← PostgreSQL
    6379       to Data-SG       ← Redis

Security Group 3: Data-SG (RDS + ElastiCache)
  Inbound:
    5432  from App-SG           ← ONLY from app tier
    6379  from App-SG           ← ONLY from app tier
  Outbound:
    NONE  (databases don't initiate connections)

Security Group 4: Bastion-SG (admin access)
  Inbound:
    SSH 22 from <your-office-IP>/32  ← only from office
  Outbound:
    SSH 22 to App-SG                 ← can reach nodes
    
Key principle:
  Never allow 0.0.0.0/0 on inbound for App-SG or Data-SG
  Reference security groups (not IP ranges) for internal traffic
  Each SG is as narrow as possible (least privilege networking)
```

### Route Tables — Traffic Routing Per Subnet

```
Public Route Table (attached to public subnets):
  10.0.0.0/16  → local            (VPC internal traffic)
  0.0.0.0/0    → igw-xxxxxxxx     (internet via IGW)

Private Route Table AZ-1a (attached to private subnet 1a):
  10.0.0.0/16  → local            (VPC internal traffic)
  0.0.0.0/0    → nat-gw-1a        (internet via NAT GW in same AZ)
  
  [Critical: NAT GW must be in same AZ as private subnet
   Cross-AZ NAT = $0.01/GB extra + single point of failure]

Private Route Table AZ-1b:
  10.0.0.0/16  → local
  0.0.0.0/0    → nat-gw-1b

Private Route Table AZ-1c:
  10.0.0.0/16  → local
  0.0.0.0/0    → nat-gw-1c

Data Route Table (attached to data subnets):
  10.0.0.0/16  → local            (VPC internal ONLY)
  [NO 0.0.0.0/0 route — no internet access at all]

VPC Endpoints (bypass NAT GW — free for S3/DynamoDB):
  S3 Endpoint:        attached to private route tables
  DynamoDB Endpoint:  attached to private route tables
  SSM Endpoint:       interface endpoint (for Systems Manager access)
  
  Without endpoints: pod → NAT GW → internet → S3 ($$$)
  With endpoints:    pod → VPC endpoint → S3 (free, private)
```

### Step-by-Step: Deploy 3-Tier App

```
Step 1: VPC and Networking
  Create VPC (10.0.0.0/16)
  Create 9 subnets (3 public, 3 private, 3 data)
  Create Internet Gateway → attach to VPC
  Create 3 Elastic IPs (for NAT Gateways)
  Create 3 NAT Gateways (one per public subnet)
  Create route tables (public, private-1a/1b/1c, data)
  Associate route tables to subnets
  Create VPC endpoints for S3, DynamoDB

Step 2: Security Groups
  Create ALB-SG (allow 80/443 inbound from internet)
  Create App-SG (allow 8080 from ALB-SG)
  Create Data-SG (allow 5432/6379 from App-SG)
  Create Bastion-SG (allow 22 from office IP)

Step 3: Data Tier
  RDS Subnet Group (using data subnets)
  RDS PostgreSQL Multi-AZ (in data subnets, Data-SG)
  ElastiCache Subnet Group (using data subnets)
  ElastiCache Redis (in data subnets, Data-SG)

Step 4: EKS Cluster (App Tier)
  EKS control plane (in private subnets)
  Node group (in private subnets, App-SG)
  IAM roles (IRSA for pods to access AWS services)
  Install: AWS Load Balancer Controller, Cluster Autoscaler

Step 5: Application Deployment
  Create K8s namespace: production
  Create Secrets (DB password from Secrets Manager)
  Deploy backend API (Deployment + Service)
  Deploy frontend (Deployment + Service)
  Create Ingress (ALB annotations → creates real ALB)

Step 6: DNS and SSL
  ACM certificate for your domain
  Route53: ALIAS record → ALB DNS name
  CloudFront (optional): CDN for global users

Step 7: Observability
  CloudWatch Container Insights
  Prometheus + Grafana
  Alarms on: error rate, latency, DB connections
```

### Complete Kubernetes Manifests for 3-Tier

```yaml
# ─── NAMESPACE ──────────────────────────────────────────────────
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production

---
# ─── SECRETS (from AWS Secrets Manager via External Secrets) ────
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: app-secrets
  data:
  - secretKey: db_password
    remoteRef:
      key: judicial/prod
      property: db_password
  - secretKey: redis_password
    remoteRef:
      key: judicial/prod
      property: redis_password

---
# ─── CONFIGMAP ──────────────────────────────────────────────────
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  DB_HOST: "judicial-prod.cluster-xxx.ap-south-1.rds.amazonaws.com"
  DB_PORT: "5432"
  DB_NAME: "judicial"
  REDIS_HOST: "judicial-cache.xxx.cache.amazonaws.com"
  REDIS_PORT: "6379"
  ENVIRONMENT: "production"
  LOG_LEVEL: "info"

---
# ─── BACKEND API DEPLOYMENT (Tier 2) ────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: production
  labels:
    app: judicial-api
    tier: backend
    version: "1.3.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: judicial-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  minReadySeconds: 20
  template:
    metadata:
      labels:
        app: judicial-api
        tier: backend
    spec:
      serviceAccountName: judicial-api-sa    # IRSA → AWS access
      
      # Spread across AZs
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: judicial-api
      
      terminationGracePeriodSeconds: 60
      
      # Init: wait for DB before starting
      initContainers:
      - name: wait-for-db
        image: busybox:1.35
        command:
        - /bin/sh
        - -c
        - |
          until nc -z $DB_HOST $DB_PORT; do
            echo "Waiting for database..."
            sleep 3
          done
          echo "Database ready!"
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_PORT
      
      containers:
      - name: judicial-api
        image: ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:1.3.0
        ports:
        - containerPort: 8080
          name: http
        
        # All config from ConfigMap
        envFrom:
        - configMapRef:
            name: app-config
        
        # Sensitive values from Secret
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db_password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: redis_password
        
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 5
          successThreshold: 2
          failureThreshold: 3
        
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
        
        # Read-only filesystem (security hardening)
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false

---
# ─── BACKEND SERVICE ─────────────────────────────────────────────
apiVersion: v1
kind: Service
metadata:
  name: judicial-api-svc
  namespace: production
spec:
  selector:
    app: judicial-api
  ports:
  - name: http
    port: 80
    targetPort: 8080
  type: ClusterIP           # internal only — ALB connects via Ingress

---
# ─── FRONTEND DEPLOYMENT (Tier 1) ───────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-frontend
  namespace: production
  labels:
    app: judicial-frontend
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: judicial-frontend
  template:
    metadata:
      labels:
        app: judicial-frontend
        tier: frontend
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: judicial-frontend
      
      containers:
      - name: frontend
        image: ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/judicial-frontend:1.3.0
        ports:
        - containerPort: 3000
        env:
        - name: REACT_APP_API_URL
          value: "https://api.judicialsolutions.in"
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5

---
# ─── FRONTEND SERVICE ────────────────────────────────────────────
apiVersion: v1
kind: Service
metadata:
  name: judicial-frontend-svc
  namespace: production
spec:
  selector:
    app: judicial-frontend
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP

---
# ─── INGRESS (creates real AWS ALB) ─────────────────────────────
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: judicial-ingress
  namespace: production
  annotations:
    # AWS Load Balancer Controller annotations
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip         # route to pod IPs directly
    
    # SSL
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT:certificate/xxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    
    # Health checks
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
    
    # WAF
    alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:ap-south-1:ACCOUNT:regional/webacl/xxx
    
    # Access logs
    alb.ingress.kubernetes.io/load-balancer-attributes: |
      access_logs.s3.enabled=true,
      access_logs.s3.bucket=judicial-alb-logs,
      idle_timeout.timeout_seconds=60
    
    # Subnets (public subnets for internet-facing)
    alb.ingress.kubernetes.io/subnets: subnet-public-1a,subnet-public-1b,subnet-public-1c
    
    # Security group
    alb.ingress.kubernetes.io/security-groups: sg-alb-xxxxxxxx
spec:
  rules:
  # API backend
  - host: api.judicialsolutions.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: judicial-api-svc
            port:
              number: 80
  
  # Frontend
  - host: judicialsolutions.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: judicial-frontend-svc
            port:
              number: 80

---
# ─── HPA FOR BACKEND ─────────────────────────────────────────────
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: judicial-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 65

---
# ─── PDB FOR BACKEND ─────────────────────────────────────────────
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: judicial-api-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: judicial-api
```

### How Traffic Flows — Request to Response

```
User visits https://judicialsolutions.in/cases

Step 1: DNS Resolution
  Route53: judicialsolutions.in → ALIAS → ALB DNS
  ALB DNS: judicial-xxx.ap-south-1.elb.amazonaws.com → ALB IPs

Step 2: ALB receives HTTPS request
  ALB terminates SSL (decrypts using ACM certificate)
  WAF checks request (block if OWASP violation)
  Route rule: judicialsolutions.in/ → forward to judicial-frontend-svc

Step 3: ALB → Pod (private subnet)
  ALB target type: ip → routes directly to pod IP
  Pod IP: 10.0.11.47 (private subnet AZ-1a)
  Traffic: stays within VPC (no internet hop)

Step 4: Frontend pod serves React app
  Browser loads React, makes API call to:
  https://api.judicialsolutions.in/cases

Step 5: API request → ALB → Backend pod
  ALB routes api.judicialsolutions.in → judicial-api-svc
  Pod 10.0.12.89 (private subnet AZ-1b) handles request

Step 6: Backend pod queries database
  pod → RDS PostgreSQL (10.0.21.5, data subnet)
  Connection: private subnet → data subnet (same VPC, no internet)
  Security group: allows 5432 from App-SG → Data-SG

Step 7: Backend pod queries Redis cache
  pod → ElastiCache Redis (10.0.22.10, data subnet)
  Cache hit: return cached response (< 1ms)
  Cache miss: query RDS, store in Redis, return response

Step 8: Response flows back
  Backend → ALB → User (encrypted HTTPS)

Data flow is entirely within AWS private network:
  Internet → ALB (public subnet)
  ALB → Pods (private subnet) — PRIVATE
  Pods → RDS (data subnet) — PRIVATE
  No database traffic ever reaches internet
```

### Connecting EKS Pods to RDS — The Right Way

```bash
# Step 1: Create RDS in data subnets
aws rds create-db-instance \
  --db-instance-identifier judicial-prod \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 16.3 \
  --master-username admin \
  --master-user-password $(aws secretsmanager get-secret-value \
    --secret-id judicial/prod \
    --query 'SecretString' \
    --output text | jq -r .db_password) \
  --db-subnet-group-name judicial-data-subnet-group \  # data subnets
  --vpc-security-group-ids sg-data-xxxxxxxx \          # Data-SG
  --multi-az \
  --storage-encrypted \
  --allocated-storage 100 \
  --storage-type gp3 \
  --no-publicly-accessible                             # CRITICAL: no public access

# Step 2: Store endpoint in ConfigMap (not secret — not sensitive)
kubectl create configmap app-config \
  --from-literal=DB_HOST=$(aws rds describe-db-instances \
    --db-instance-identifier judicial-prod \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text) \
  -n production

# Step 3: Store password in K8s Secret (from Secrets Manager)
# Use External Secrets Operator — don't manually create K8s secrets

# Step 4: Test connectivity from pod
kubectl run db-test --image=postgres:16-alpine \
  --restart=Never --rm -it -n production \
  -- psql -h $DB_HOST -U admin -d judicial -c "SELECT version();"

# Step 5: Verify security group is correct
# From pod: nc -zv $DB_HOST 5432 should succeed
# From internet: nc -zv $DB_HOST 5432 should timeout (no public access)
```

-----

## PART 13 — 3-TIER INFRASTRUCTURE AS CODE (TERRAFORM)

### Project Structure

```
terraform/
├── main.tf                    ← root module, calls all modules
├── variables.tf               ← input variables
├── outputs.tf                 ← output values
├── terraform.tfvars           ← variable values (don't commit secrets)
├── providers.tf               ← AWS provider config
├── backend.tf                 ← S3 + DynamoDB state backend
│
└── modules/
    ├── vpc/                   ← VPC, subnets, IGW, NAT GW, routes
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security_groups/       ← ALB-SG, App-SG, Data-SG
    ├── eks/                   ← EKS cluster + node groups
    ├── rds/                   ← PostgreSQL Multi-AZ
    ├── elasticache/           ← Redis
    └── alb/                   ← ALB + target groups (optional)
```

### Backend Config (Remote State)

```hcl
# backend.tf — store state in S3, lock with DynamoDB
terraform {
  backend "s3" {
    bucket         = "judicial-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true                    # encrypt state file
    dynamodb_table = "judicial-tf-locks"     # state locking
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "judicial-solutions"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devops-team"
    }
  }
}
```

### VPC Module

```hcl
# modules/vpc/main.tf

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true          # REQUIRED for EKS
  enable_dns_support   = true

  tags = { Name = "${var.project}-${var.env}-vpc" }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.azs[count.index]
  
  map_public_ip_on_launch = true       # EC2s in public subnet get public IP

  tags = {
    Name = "${var.project}-${var.env}-public-${var.azs[count.index]}"
    # EKS needs these tags to discover subnets for ALB
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private Subnets (App Tier)
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project}-${var.env}-private-${var.azs[count.index]}"
    # EKS internal LB tag
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Data Subnets (DB Tier)
resource "aws_subnet" "data" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project}-${var.env}-data-${var.azs[count.index]}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-${var.env}-igw" }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags   = { Name = "${var.project}-${var.env}-nat-eip-${var.azs[count.index]}" }
}

# NAT Gateways — ONE PER AZ (HA)
resource "aws_nat_gateway" "main" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id  # NAT GW goes in PUBLIC subnet
  
  tags = { Name = "${var.project}-${var.env}-nat-${var.azs[count.index]}" }
  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = { Name = "${var.project}-${var.env}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables — ONE PER AZ (routes to same-AZ NAT GW)
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id  # same AZ NAT GW
  }
  
  tags = { Name = "${var.project}-${var.env}-rt-private-${var.azs[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data Route Table — NO internet access
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
  # No routes except local (implicit)
  tags   = { Name = "${var.project}-${var.env}-rt-data" }
}

resource "aws_route_table_association" "data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# VPC Endpoints (free for S3 and DynamoDB)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags              = { Name = "${var.project}-${var.env}-s3-endpoint" }
}
```

### Security Groups Module

```hcl
# modules/security_groups/main.tf

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.env}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet (redirect to HTTPS)"
  }

  egress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "To app tier only"
  }
}

# App Security Group (EKS Nodes)
resource "aws_security_group" "app" {
  name        = "${var.project}-${var.env}-app-sg"
  description = "App tier / EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "From ALB only"
  }

  # Allow all traffic within app SG (pod-to-pod communication)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Pod-to-pod within cluster"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # outbound via NAT GW
    description = "All outbound (via NAT GW)"
  }
}

# Data Security Group (RDS + ElastiCache)
resource "aws_security_group" "data" {
  name        = "${var.project}-${var.env}-data-sg"
  description = "Data tier (RDS, ElastiCache)"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "PostgreSQL from app tier only"
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Redis from app tier only"
  }

  # No egress — databases don't initiate connections
}
```

### RDS Module

```hcl
# modules/rds/main.tf

resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.env}-db-subnet-group"
  subnet_ids  = var.data_subnet_ids    # data subnets only
  description = "RDS subnet group for ${var.project}"
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres16"
  name   = "${var.project}-${var.env}-pg16"

  parameter {
    name  = "max_connections"
    value = "200"
  }
  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/4}"  # 25% of RAM
  }
  parameter {
    name  = "log_slow_autovacuum"
    value = "1"
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project}-${var.env}"
  engine            = "postgres"
  engine_version    = "16.3"
  instance_class    = var.db_instance_class  # e.g., "db.t3.medium"
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password  # from Secrets Manager via data source
  
  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.data_sg_id]
  publicly_accessible    = false          # NEVER public
  
  # High Availability
  multi_az = true                         # standby in different AZ
  
  # Storage
  allocated_storage     = 100
  max_allocated_storage = 500             # auto-scale up to 500GB
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn
  
  # Backup
  backup_retention_period   = 7           # 7 days PITR
  backup_window             = "03:00-04:00"  # 3am UTC
  maintenance_window        = "sun:04:00-sun:05:00"
  delete_automated_backups  = false
  
  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres.name
  
  # Protection
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project}-${var.env}-final-snapshot"
  
  # Monitoring
  monitoring_interval          = 60
  monitoring_role_arn          = var.rds_monitoring_role_arn
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = { Name = "${var.project}-${var.env}-postgres" }
}

# Outputs
output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}
output "address" {
  value = aws_db_instance.postgres.address
}
```

### Main Module — Wiring It All Together

```hcl
# main.tf — root module

module "vpc" {
  source = "./modules/vpc"
  
  project      = var.project
  env          = var.environment
  vpc_cidr     = "10.0.0.0/16"
  azs          = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  cluster_name = var.cluster_name
  region       = var.aws_region
}

module "security_groups" {
  source = "./modules/security_groups"
  
  project = var.project
  env     = var.environment
  vpc_id  = module.vpc.vpc_id
}

module "rds" {
  source = "./modules/rds"
  
  project          = var.project
  env              = var.environment
  data_subnet_ids  = module.vpc.data_subnet_ids
  data_sg_id       = module.security_groups.data_sg_id
  db_instance_class = "db.t3.medium"
  db_name          = "judicial"
  db_username      = "admin"
  db_password      = data.aws_secretsmanager_secret_version.db.secret_string
  kms_key_arn      = aws_kms_key.rds.arn
}

module "elasticache" {
  source = "./modules/elasticache"
  
  project         = var.project
  env             = var.environment
  data_subnet_ids = module.vpc.data_subnet_ids
  data_sg_id      = module.security_groups.data_sg_id
  node_type       = "cache.t3.micro"
}

module "eks" {
  source = "./modules/eks"
  
  project            = var.project
  env                = var.environment
  cluster_name       = var.cluster_name
  private_subnet_ids = module.vpc.private_subnet_ids
  app_sg_id          = module.security_groups.app_sg_id
  node_instance_types = ["m5.large", "m5.xlarge"]
  min_nodes          = 3
  max_nodes          = 15
}

# Pass RDS endpoint to EKS via ConfigMap
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = "production"
  }
  data = {
    DB_HOST    = module.rds.address
    DB_PORT    = "5432"
    REDIS_HOST = module.elasticache.primary_endpoint
    REDIS_PORT = "6379"
  }
  depends_on = [module.eks]
}
```

-----

## PART 14 — 3-TIER CI/CD PIPELINE

### Full GitHub Actions Pipeline

```yaml
# .github/workflows/3tier-deploy.yml
name: 3-Tier App Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: ap-south-1
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT }}.dkr.ecr.ap-south-1.amazonaws.com
  EKS_CLUSTER: judicial-prod

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ─── TEST BOTH TIERS IN PARALLEL ────────────────────────────────
  test-backend:
    name: Test Backend API
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip
      - run: pip install -r requirements.txt pytest pytest-cov
      - run: |
          pytest tests/ \
            --cov=src \
            --cov-fail-under=80 \
            -v
      - uses: actions/upload-artifact@v4
        with:
          name: backend-test-results
          path: coverage.xml

  test-frontend:
    name: Test Frontend
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: npm
          cache-dependency-path: frontend/package-lock.json
      - run: cd frontend && npm ci
      - run: cd frontend && npm test -- --coverage --watchAll=false

  # ─── BUILD BOTH IMAGES IN PARALLEL ──────────────────────────────
  build-backend:
    name: Build Backend Image
    needs: [test-backend]
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image: ${{ steps.image.outputs.full }}
      tag: ${{ steps.image.outputs.tag }}
    steps:
      - uses: actions/checkout@v4
      - id: image
        run: |
          TAG="${GITHUB_SHA::8}"
          echo "tag=${TAG}" >> $GITHUB_OUTPUT
          echo "full=${{ env.ECR_REGISTRY }}/judicial-api:${TAG}" >> $GITHUB_OUTPUT
      - uses: docker/setup-buildx-action@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: ${{ steps.image.outputs.full }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
      # Security scan
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.image.outputs.full }}
          severity: CRITICAL,HIGH
          exit-code: 1

  build-frontend:
    name: Build Frontend Image
    needs: [test-frontend]
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image: ${{ steps.image.outputs.full }}
    steps:
      - uses: actions/checkout@v4
      - id: image
        run: |
          TAG="${GITHUB_SHA::8}"
          echo "full=${{ env.ECR_REGISTRY }}/judicial-frontend:${TAG}" >> $GITHUB_OUTPUT
      - uses: docker/setup-buildx-action@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2
      - uses: docker/build-push-action@v5
        with:
          context: frontend/
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: ${{ steps.image.outputs.full }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ─── DB MIGRATION (before app deploy) ──────────────────────────
  db-migrate:
    name: Database Migration
    needs: [build-backend]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.STAGING_AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - run: aws eks update-kubeconfig --name judicial-staging --region ${{ env.AWS_REGION }}
      - name: Run DB migration Job
        run: |
          # Create migration job from the new image
          cat <<EOF | kubectl apply -f -
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: db-migrate-${{ needs.build-backend.outputs.tag }}
            namespace: staging
          spec:
            backoffLimit: 2
            template:
              spec:
                restartPolicy: OnFailure
                containers:
                - name: migrate
                  image: ${{ needs.build-backend.outputs.image }}
                  command: ["python", "manage.py", "migrate", "--no-input"]
                  envFrom:
                  - configMapRef:
                      name: app-config
                  env:
                  - name: DB_PASSWORD
                    valueFrom:
                      secretKeyRef:
                        name: app-secrets
                        key: db_password
          EOF
          
          # Wait for migration to complete
          kubectl wait \
            --for=condition=complete \
            job/db-migrate-${{ needs.build-backend.outputs.tag }} \
            -n staging \
            --timeout=5m

  # ─── DEPLOY TO STAGING ──────────────────────────────────────────
  deploy-staging:
    name: Deploy to Staging
    needs: [build-backend, build-frontend, db-migrate]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.judicialsolutions.in
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.STAGING_AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - run: aws eks update-kubeconfig --name judicial-staging --region ${{ env.AWS_REGION }}
      
      # Deploy backend (rolling update)
      - name: Deploy API
        run: |
          kubectl set image deployment/judicial-api \
            judicial-api=${{ needs.build-backend.outputs.image }} \
            -n staging
          kubectl rollout status deployment/judicial-api -n staging --timeout=5m
      
      # Deploy frontend
      - name: Deploy Frontend
        run: |
          kubectl set image deployment/judicial-frontend \
            frontend=${{ needs.build-frontend.outputs.image }} \
            -n staging
          kubectl rollout status deployment/judicial-frontend -n staging --timeout=5m
      
      # Smoke tests
      - name: Smoke Tests
        run: |
          sleep 20
          curl -sf https://staging.judicialsolutions.in/ || exit 1
          curl -sf https://staging-api.judicialsolutions.in/health || exit 1
          echo "✅ Staging smoke tests passed"

  # ─── DEPLOY TO PRODUCTION (manual approval) ─────────────────────
  deploy-production:
    name: Deploy to Production
    needs: [deploy-staging]
    runs-on: ubuntu-latest
    environment:
      name: production                   # requires manual approval in GitHub
      url: https://judicialsolutions.in
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PROD_AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - run: aws eks update-kubeconfig --name ${{ env.EKS_CLUSTER }} --region ${{ env.AWS_REGION }}
      
      # Deploy API with zero downtime
      - name: Deploy API (Zero Downtime)
        run: |
          kubectl set image deployment/judicial-api \
            judicial-api=${{ needs.build-backend.outputs.image }} \
            -n production
          
          kubectl rollout status deployment/judicial-api \
            -n production --timeout=10m || {
              echo "Rollout failed — rolling back!"
              kubectl rollout undo deployment/judicial-api -n production
              exit 1
            }
      
      # Deploy frontend
      - name: Deploy Frontend
        run: |
          kubectl set image deployment/judicial-frontend \
            frontend=${{ needs.build-frontend.outputs.image }} \
            -n production
          kubectl rollout status deployment/judicial-frontend -n production --timeout=5m
      
      # Production smoke tests
      - name: Production Smoke Tests
        run: |
          sleep 30
          curl -sf https://judicialsolutions.in/ || exit 1
          curl -sf https://api.judicialsolutions.in/health || exit 1
          # Test actual API functionality
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            https://api.judicialsolutions.in/api/cases)
          [ "$STATUS" == "401" ] || [ "$STATUS" == "200" ] || exit 1
          echo "✅ Production smoke tests passed"
      
      # Tag release
      - name: Tag Release
        run: |
          git tag "prod-${{ needs.build-backend.outputs.tag }}-$(date +%Y%m%d)"
          git push origin --tags
```

-----

## PART 15 — INTERVIEW QUESTIONS

**Q1: How do you deliver a stateful application in Kubernetes?**

```
"Stateful app delivery requires four things working together:

1. StatefulSet not Deployment:
   Stable pod names (postgres-0), stable DNS per pod,
   ordered startup, each pod gets its own PVC

2. PersistentVolumeClaim with Retain policy:
   volumeClaimTemplates in StatefulSet
   Each pod gets its own EBS volume
   PVC survives pod deletion — critical for data persistence
   reclaimPolicy: Retain → EBS not deleted if PVC accidentally deleted

3. Operator for HA (don't write replication config yourself):
   PostgreSQL → Zalando postgres-operator (Patroni handles failover)
   Redis → Sentinel or Cluster
   Kafka → Strimzi operator

4. Application-aware backup:
   WAL-G for continuous PostgreSQL archiving to S3
   Velero for K8s object + PVC snapshot backup

For production user data: I prefer RDS over in-cluster PostgreSQL.
RDS handles Multi-AZ failover, PITR, backups, storage scaling —
all the hard parts. The extra cost (~$80/month) is worth not owning
database operations on top of Kubernetes operations."
```

**Q2: Design a 3-tier application deployment on AWS. Walk me through it.**

```
"I'd design it with strict subnet separation:

Tier 1 — Frontend (Public Subnet):
  Static React app → S3 + CloudFront
  No servers needed — pure CDN delivery
  CloudFront handles SSL, global distribution, caching

Tier 2 — Backend API (Private Subnet):
  EKS cluster (EC2 nodes in private subnets, 3 AZs)
  ALB in public subnet → routes to pods in private subnet
  Pods get VPC IPs, talk to each other via ClusterIP Services
  No public IP on nodes — all inbound via ALB only

Tier 3 — Data (Data Subnet, most isolated):
  RDS PostgreSQL Multi-AZ (no internet access)
  ElastiCache Redis (no internet access)
  No NAT Gateway route — completely isolated

Security model:
  ALB-SG: allows 443 from internet
  App-SG: allows 8080 only from ALB-SG
  Data-SG: allows 5432/6379 only from App-SG
  No lateral movement: compromise of one tier can't directly reach data tier

EKS pods access AWS services (ECR, Secrets Manager) via:
  NAT Gateway (same AZ) for internet-bound traffic
  VPC Endpoints for S3, DynamoDB (free, no NAT GW needed)

I provision this with Terraform modules:
  vpc module → subnets, IGW, NAT GWs, route tables
  security_groups module → 3 SGs with correct rules
  eks module → cluster + node groups in private subnets
  rds module → PostgreSQL in data subnets
  The whole stack deploys in ~15 minutes"
```

**Q3: Why do you put the database in data subnets, not private subnets?**

```
"Defence in depth — separate subnet types allow separate network controls.

If everything is in 'private' subnets:
  A compromised app pod has direct network path to database
  Only security group prevents lateral movement
  One misconfigured SG rule = database exposed to entire private subnet

With data subnets:
  Data subnet has NO NAT Gateway route — no outbound internet at all
  Even if an attacker compromises an app pod:
    They can query the DB (if they have credentials) but
    They CANNOT exfiltrate data to internet from the DB itself
    They CANNOT install reverse shells on the DB (no outbound)
  
  Separate route table for data subnets: ONLY local VPC traffic
  Separate SG (Data-SG): only accepts connections from App-SG

Additional benefit: compliance
  PCI-DSS, HIPAA require database isolation
  'No internet access to database network' is an explicit requirement
  Data subnet satisfies this cleanly"
```

**Q4: What is WaitForFirstConsumer in StorageClass and why does it matter?**

```
"WaitForFirstConsumer tells Kubernetes:
  Don't create the EBS volume when the PVC is created
  Wait until a pod is scheduled to a node first
  Then create the EBS volume in the SAME AZ as that node

Without it (Immediate binding):
  PVC created → EBS provisioned immediately → random AZ (say AZ-1a)
  Pod scheduled → node happens to be in AZ-1b
  Pod tries to mount EBS from AZ-1a → FAILS (EBS is AZ-specific)
  Pod stuck in Pending state forever

With WaitForFirstConsumer:
  PVC created → no EBS yet (status: Pending)
  Scheduler picks node in AZ-1c for the pod
  EBS created in AZ-1c → pod mounts successfully

This is critical in multi-AZ StatefulSet deployments.
Without it: random chance whether your DB pods can mount storage.
With it: guaranteed to work."
```

**Q5: How do you do zero-downtime schema migrations?**

```
"The Expand/Contract pattern — never change schema in a breaking way:

Phase 1: Expand (backward compatible)
  Add new column with default: ALTER TABLE cases ADD COLUMN priority INT DEFAULT 0
  Both v1 app (ignores new column) and v2 app (uses it) work
  Run as Job before deployment: verify migration succeeded before proceeding

Phase 2: Deploy new app (rolling update)
  Mix of v1 and v2 pods running simultaneously
  All work with the new schema
  Zero downtime

Phase 3: Backfill (background)
  UPDATE cases SET priority = 0 WHERE priority IS NULL
  Run in batches of 1000 to avoid long table locks

Phase 4: Contract (next release)
  Only after 100% pods on v2 (which no longer uses old columns)
  DROP old column or make non-nullable

In CI/CD:
  Job runs migration before deployment YAML applied
  kubectl wait --for=condition=complete job/db-migrate → then deploy
  If migration fails → deployment never happens"
```

**Q6: How does traffic flow from a user to the database in your 3-tier setup?**

```
Internet User
    ↓ HTTPS:443
Route53 → ALIAS → ALB (public subnet, ALB-SG)
    ↓ HTTP:8080 (decrypted, internal)
ALB → Pod (private subnet, App-SG, Pod IP: 10.0.11.47)
    ↓ TCP:5432 (within VPC)
Pod → RDS (data subnet, Data-SG, 10.0.21.5)

Key security properties:
  1. User never sees app server IP (ALB is the public face)
  2. Database is never reachable from internet (no public IP, no internet route)
  3. App pod reaches DB via private VPC routing (no NAT GW needed)
  4. Security groups enforce: internet → ALB → app → DB (no skip-layer)
  5. All data in transit: encrypted (HTTPS to ALB, SSL to RDS)
  6. All data at rest: encrypted (EBS gp3 encrypted, RDS encrypted)
```

**Q7: What happens if the primary RDS instance fails in your 3-tier setup?**

```
Timeline:
  T+0s:   RDS primary in AZ-1a fails (hardware failure, zone issue)
  T+5s:   RDS health checks detect failure
  T+30s:  AWS initiates automatic failover
  T+60s:  Standby in AZ-1b promoted to primary
  T+60s:  DNS record updated (same endpoint, new IP)
  T+90s:  App pods reconnect to same RDS endpoint (DNS TTL ~5 seconds for RDS)
  T+90s:  Traffic flows normally through new primary in AZ-1b

During failover:
  Existing DB connections fail (~60 seconds of errors)
  App should have connection retry logic (e.g., 3 retries with backoff)
  New connections after DNS update succeed immediately

Kubernetes protection:
  Readiness probe on pods: if DB unreachable, pod marked not-ready
  ALB removes not-ready pods from targets
  Result: users see 503 for ~60 seconds, not 500 errors

Prevention (RDS Proxy):
  RDS Proxy sits between pods and RDS
  Proxy holds connection pool
  During RDS failover: proxy transparently reconnects to new primary
  App never sees the failover — connections resume from pool
  Downtime to app: near-zero (< 5 seconds)"
```

**Q8: Describe your Terraform module structure for this 3-tier setup.**

```
"I use a module-per-concern pattern:

terraform/
├── main.tf           → calls all modules, wires outputs as inputs
├── backend.tf        → S3 state + DynamoDB lock
├── variables.tf      → environment, region, project
└── modules/
    ├── vpc/          → VPC, 9 subnets, IGW, 3 NAT GWs, route tables, VPC endpoints
    ├── security_groups/ → ALB-SG, App-SG, Data-SG (SGs reference each other)
    ├── rds/          → PostgreSQL Multi-AZ, subnet group, parameter group
    ├── elasticache/  → Redis with replica, subnet group
    └── eks/          → cluster, managed node group, OIDC provider for IRSA

Each module outputs what other modules need:
  vpc outputs: vpc_id, public/private/data subnet IDs
  security_groups inputs: vpc_id from vpc module
  rds inputs: data_subnet_ids, data_sg_id from vpc + sg modules
  eks inputs: private_subnet_ids, app_sg_id

Plan → Review → Apply:
  terraform plan -out=tfplan          # show what changes
  terraform apply tfplan              # apply (asks no questions)

In CI/CD:
  PR: terraform plan (shows diff in PR comment)
  Merge: terraform apply (auto-applies to staging)
  Prod: manual terraform apply from protected branch"
```