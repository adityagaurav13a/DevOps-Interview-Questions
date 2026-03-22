# Kubernetes Complete Deep Dive
## Architecture + Workloads + Networking + Storage + Autoscaling + Security
### Theory → Interview Questions → Hands-on Steps

---

## README — How to Use This Document

**Total sections:** 11
**Your strongest sections (real experience):** Deployments, HPA, Rolling Updates, Ingress (Minikube project)
**Focus areas for interviews:** Architecture internals, Services networking, RBAC

### Priority questions to memorise:
| Section | Topic | Why it matters |
|---|---|---|
| Part 1 | Control plane components | Asked in every K8s interview |
| Part 2 | Pod lifecycle phases | Debugging question trap |
| Part 3 | Deployment vs ReplicaSet | Most confused concept |
| Part 4 | ClusterIP vs NodePort vs LB | Networking fundamentals |
| Part 5 | Ingress vs LoadBalancer | Your real project — own this |
| Part 7 | HPA trigger mechanism | You listed this on resume |
| Part 10 | RBAC — Role vs ClusterRole | Security questions |

### Power phrases:
- *"etcd is the single source of truth — everything in K8s is stored there"*
- *"A ReplicaSet ensures desired state — Deployment manages ReplicaSets"*
- *"ClusterIP is only reachable inside the cluster — Ingress exposes externally"*
- *"HPA scales pods, Cluster Autoscaler scales nodes"*
- *"I've set this up hands-on on Minikube with Nginx Ingress routing 3 services"*

---

## PART 1 — KUBERNETES ARCHITECTURE

### The Big Picture

```
                    ┌─────────────────────────────────────┐
                    │         CONTROL PLANE               │
                    │                                     │
                    │  ┌──────────┐  ┌────────────────┐  │
                    │  │   etcd   │  │  API Server    │  │
                    │  └──────────┘  └────────────────┘  │
                    │  ┌──────────┐  ┌────────────────┐  │
                    │  │Scheduler │  │Ctrl Manager    │  │
                    │  └──────────┘  └────────────────┘  │
                    └─────────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
    ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
    │   WORKER NODE 1  │ │   WORKER NODE 2  │ │   WORKER NODE 3  │
    │                  │ │                  │ │                  │
    │  ┌────────────┐  │ │  ┌────────────┐  │ │  ┌────────────┐  │
    │  │  kubelet   │  │ │  │  kubelet   │  │ │  │  kubelet   │  │
    │  │  kube-proxy│  │ │  │  kube-proxy│  │ │  │  kube-proxy│  │
    │  │  container │  │ │  │  container │  │ │  │  container │  │
    │  │  runtime   │  │ │  │  runtime   │  │ │  │  runtime   │  │
    │  └────────────┘  │ │  └────────────┘  │ │  └────────────┘  │
    │  Pod  Pod  Pod   │ │  Pod  Pod        │ │  Pod  Pod  Pod   │
    └──────────────────┘ └──────────────────┘ └──────────────────┘
```

### Control Plane Components

```
1. API Server (kube-apiserver):
   - Front door to Kubernetes
   - All communication goes through API server (kubectl, kubelet, controllers)
   - Validates and processes all REST requests
   - Writes to etcd
   - Stateless — can run multiple replicas for HA

2. etcd:
   - Distributed key-value store
   - Single source of truth for ALL cluster state
   - Stores: pods, services, configs, secrets, node info
   - RAFT consensus algorithm — requires odd number (3, 5, 7)
   - If etcd is gone → cluster is gone (backup etcd = backup cluster)

3. Scheduler (kube-scheduler):
   - Watches for unscheduled pods
   - Selects best node based on:
     resources available, taints/tolerations,
     affinity/anti-affinity, node selectors
   - Does NOT start the pod — just assigns it to a node
   - Writes nodeName to pod spec

4. Controller Manager (kube-controller-manager):
   - Runs control loops (reconciliation loops)
   - ReplicaSet controller: ensures desired replica count
   - Deployment controller: manages rolling updates
   - Node controller: detects node failures
   - Service Account controller: creates default service accounts
   - Each controller watches etcd for desired state
     and takes action to reach desired state

5. Cloud Controller Manager (cloud-specific):
   - Manages cloud resources: LoadBalancers, volumes, nodes
   - Specific to AWS (EKS), GCP (GKE), Azure (AKS)
```

### Worker Node Components

```
1. kubelet:
   - Agent running on every node
   - Watches API server for pods assigned to its node
   - Starts/stops containers via container runtime
   - Reports node and pod status back to API server
   - Runs liveness/readiness probes

2. kube-proxy:
   - Network proxy on every node
   - Maintains iptables/IPVS rules for Service routing
   - When you call a Service ClusterIP → kube-proxy routes to pod

3. Container Runtime:
   - Actually runs containers
   - containerd (default in modern K8s)
   - CRI-O (alternative)
   - NOT Docker (Docker was removed in K8s 1.24)

4. CNI Plugin (Container Network Interface):
   - Provides pod networking
   - Calico, Flannel, Weave, Cilium
   - Assigns IP to each pod
   - Enables pod-to-pod communication across nodes
```

### What Happens When You Run `kubectl apply -f deployment.yaml`

```
1. kubectl reads deployment.yaml
2. kubectl sends POST request to API Server
3. API Server validates the request (auth, schema)
4. API Server writes Deployment to etcd
5. Deployment Controller (in Controller Manager) sees new Deployment
6. Controller creates a ReplicaSet
7. ReplicaSet Controller sees new ReplicaSet, creates Pods
8. Pods are created in etcd with status: Pending
9. Scheduler sees Pending pods, selects nodes
10. Scheduler writes nodeName to pod spec in etcd
11. kubelet on selected node sees pod assigned to it
12. kubelet tells container runtime to pull image and start container
13. Container starts, kubelet updates pod status: Running
14. API Server updates etcd with Running status
```

### Interview Question:
**"What is the role of etcd in Kubernetes?"**

```
etcd is a distributed key-value store that serves as Kubernetes'
backing store for ALL cluster data.

Everything about your cluster is stored in etcd:
  - Pod definitions and their current state
  - Service definitions
  - ConfigMaps and Secrets
  - Node information
  - RBAC policies
  - Namespaces

Key properties:
  - Uses RAFT consensus — data is consistent across replicas
  - Must have odd number of nodes (3,5,7) for quorum
  - API server is the ONLY component that reads/writes etcd directly
  - All other components communicate through API server

Why it matters for operations:
  - etcd backup = cluster backup
  - etcd failure = cluster failure
  - Run: etcdctl snapshot save backup.db regularly
```

### Hands-on: Explore cluster components

```bash
# Check control plane components
kubectl get pods -n kube-system

# Check nodes
kubectl get nodes -o wide

# Check node details
kubectl describe node <node-name>

# See all API resources
kubectl api-resources

# Check component status (older clusters)
kubectl get componentstatuses

# On Minikube
minikube start
kubectl cluster-info
kubectl get all -A  # everything in all namespaces
```

---

## PART 2 — PODS, REPLICASETS, DEPLOYMENTS

### Pod — The Atomic Unit

```
Pod = smallest deployable unit in Kubernetes
     = one or more containers sharing:
       - same network namespace (same IP, same ports)
       - same storage volumes
       - same lifecycle (start/stop together)

When to use multiple containers in one pod (sidecar pattern):
  Main container: your application
  Sidecar: log shipper, proxy, config reloader
  
  They must be tightly coupled — deployed and scaled together
  
When NOT to use multiple containers:
  Independent services → separate pods
  Different scaling needs → separate pods
```

### Pod Lifecycle Phases

```
Pending:
  Pod accepted by cluster, not yet running
  Waiting for: node assignment, image pull, resource availability

Running:
  At least one container is running
  Others may be starting or restarting

Succeeded:
  All containers exited with status 0
  Will not be restarted (for Jobs)

Failed:
  All containers exited, at least one exited with non-zero
  Will not be restarted (unless restartPolicy allows)

Unknown:
  Pod state cannot be determined
  Usually: node communication issue

CrashLoopBackOff:
  Not a phase — it's a status
  Container keeps crashing → K8s keeps restarting with increasing delay
  1s, 2s, 4s, 8s... up to 5 minutes between restarts
```

### Pod YAML — Every Field Explained

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: judicial-api
  namespace: production
  labels:
    app: judicial-api        # used by Services to select pods
    version: "1.2.3"
  annotations:
    prometheus.io/scrape: "true"   # not for selection, for metadata

spec:
  containers:
  - name: api
    image: adityagaurav/judicial-api:1.2.3
    
    ports:
    - containerPort: 8080    # documentation only, doesn't publish
    
    resources:
      requests:              # minimum guaranteed resources
        memory: "128Mi"
        cpu: "100m"          # 100m = 0.1 CPU core
      limits:                # maximum allowed resources
        memory: "512Mi"
        cpu: "500m"
    
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db_host
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db_password
    
    # Probes
    livenessProbe:           # restart container if fails
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
      failureThreshold: 3
    
    readinessProbe:          # remove from service if fails
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
    
    startupProbe:            # disable liveness during slow startup
      httpGet:
        path: /health
        port: 8080
      failureThreshold: 30   # 30 * 10s = 5 minutes for startup
      periodSeconds: 10
  
  restartPolicy: Always      # Always, OnFailure, Never
  
  serviceAccountName: judicial-api-sa  # IAM role via IRSA on EKS
```

### Liveness vs Readiness vs Startup Probes

```
Liveness probe:
  "Is this container alive or should it be restarted?"
  Fails → container is restarted
  Use for: detecting deadlocks, hung processes
  
Readiness probe:
  "Is this container ready to receive traffic?"
  Fails → pod removed from Service endpoints (no traffic sent)
  Container NOT restarted — just no traffic until ready again
  Use for: waiting for DB connection, cache warming, startup checks
  
Startup probe:
  "Has the application started yet?"
  Disables liveness/readiness until startup probe succeeds
  Use for: slow-starting applications (Java, .NET)
  Prevents liveness from killing pod during legitimate slow startup

Interview trap:
  "Your pods keep restarting every 2 minutes. Liveness or Readiness issue?"
  Restarts = Liveness probe failing
  Traffic not reaching = Readiness probe failing
```

### ReplicaSet

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: judicial-api-rs
spec:
  replicas: 3              # desired number of pods
  selector:
    matchLabels:
      app: judicial-api    # manages pods with this label
  template:                # pod template
    metadata:
      labels:
        app: judicial-api  # MUST match selector
    spec:
      containers:
      - name: api
        image: judicial-api:1.2.3
```

```
ReplicaSet's job: ensure exactly N pods with matching labels exist
  Too few → create more
  Too many → delete some
  Pod crashes → creates replacement

Why not use ReplicaSet directly?
  ReplicaSet can't do rolling updates
  To update image: delete all pods at once → downtime
  Deployment manages ReplicaSets and handles rolling updates
```

### Deployment — The Right Way to Run Apps

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: production
spec:
  replicas: 3
  
  selector:
    matchLabels:
      app: judicial-api
  
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # max pods unavailable during update
      maxSurge: 1            # max extra pods during update
  
  template:
    metadata:
      labels:
        app: judicial-api
    spec:
      containers:
      - name: api
        image: judicial-api:1.2.3
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

```
Deployment manages ReplicaSets:

v1 deployment:  ReplicaSet-A (3 pods) running
Update to v2:   
  Create ReplicaSet-B (0 pods)
  Scale up B:   ReplicaSet-A (2 pods) + ReplicaSet-B (1 pod)
  Continue:     ReplicaSet-A (1 pod) + ReplicaSet-B (2 pods)
  Complete:     ReplicaSet-A (0 pods) + ReplicaSet-B (3 pods)
  ReplicaSet-A kept (0 replicas) for rollback

Rollback:
  kubectl rollout undo deployment/judicial-api
  → scales ReplicaSet-A back to 3, scales B to 0
  → instant rollback, no image pull needed
```

### Hands-on: Deploy and manage

```bash
# Create deployment
kubectl apply -f deployment.yaml

# Check deployment
kubectl get deployments
kubectl describe deployment judicial-api

# Check ReplicaSets (see old ones kept for rollback)
kubectl get replicasets

# Check pods
kubectl get pods -l app=judicial-api

# Scale manually
kubectl scale deployment judicial-api --replicas=5

# Update image
kubectl set image deployment/judicial-api \
  api=judicial-api:1.3.0

# Watch rollout
kubectl rollout status deployment/judicial-api

# Rollback
kubectl rollout undo deployment/judicial-api

# Rollback to specific version
kubectl rollout history deployment/judicial-api
kubectl rollout undo deployment/judicial-api --to-revision=2

# Pause/resume rollout
kubectl rollout pause deployment/judicial-api
kubectl rollout resume deployment/judicial-api
```

---

## PART 3 — ROLLING UPDATES + ROLLBACKS

### Rolling Update Strategy Deep Dive

```
Initial state: 3 pods running v1
Update to v2 with maxUnavailable=1, maxSurge=1

Step 1: Start (3 v1 pods)
  [v1] [v1] [v1]

Step 2: Create 1 v2 pod (surge)
  [v1] [v1] [v1] [v2-starting]
  
Step 3: v2 pod ready, terminate 1 v1 pod
  [v1] [v1] [v2]

Step 4: Create another v2 pod
  [v1] [v1] [v2] [v2-starting]
  
Step 5: v2 ready, terminate v1
  [v1] [v2] [v2]

Step 6: Final v2 pod
  [v2] [v2] [v2]

At no point: fewer than 2 pods available (maxUnavailable=1)
At no point: more than 4 pods total (3 + maxSurge=1)
```

### Recreate Strategy

```yaml
strategy:
  type: Recreate
  # ALL pods deleted, then new ones created
  # Brief downtime — use only when:
  # - New version incompatible with old (DB schema change)
  # - Stateful app that can't run two versions simultaneously
```

### Rollback Scenarios

```bash
# Scenario 1: New version has bug, rollback immediately
kubectl rollout undo deployment/judicial-api
# → instantly switches back to previous ReplicaSet

# Scenario 2: Rollback to specific version
kubectl rollout history deployment/judicial-api
# REVISION  CHANGE-CAUSE
# 1         Initial deployment
# 2         Updated image to v1.1
# 3         Updated image to v1.2 (buggy)

kubectl rollout undo deployment/judicial-api --to-revision=2

# Scenario 3: Annotate deployments for better history
kubectl annotate deployment/judicial-api \
  kubernetes.io/change-cause="Updated to v1.2 - added payment feature"

# Scenario 4: Check if rollout is stuck
kubectl rollout status deployment/judicial-api --timeout=5m
# exits 1 if not complete within 5 min → good for CI/CD

# Scenario 5: Canary deployment (manual)
# Run both versions simultaneously with different weights:
# Deployment-stable: 9 replicas (v1)
# Deployment-canary: 1 replica (v2)
# Same Service selector → 10% traffic to v2
```

---

## PART 4 — SERVICES

### Why Services?

```
Problem:
  Pods are ephemeral — they get new IPs when recreated
  Pod IP: 10.244.0.5 (today) → 10.244.1.8 (after crash/reschedule)
  How do other pods find the service? → They can't use pod IPs

Solution: Service
  Stable virtual IP (ClusterIP) that never changes
  DNS name: my-service.namespace.svc.cluster.local
  Routes to matching pods via label selector
  kube-proxy maintains iptables rules for routing
```

### Service Types

#### ClusterIP (default — internal only)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: judicial-api-svc
spec:
  type: ClusterIP      # only reachable INSIDE cluster
  selector:
    app: judicial-api  # routes to pods with this label
  ports:
  - port: 80           # service port (what others call)
    targetPort: 8080   # pod port (where app listens)
    protocol: TCP
```

```
Use when:
  Microservice-to-microservice communication
  Frontend calling backend (both inside cluster)
  Database accessed by app pods

DNS: judicial-api-svc.production.svc.cluster.local
     judicial-api-svc.production (short form)
     judicial-api-svc (same namespace)
```

#### NodePort (external access via node IP)

```yaml
spec:
  type: NodePort
  selector:
    app: judicial-api
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080    # port on every node (30000-32767)
```

```
Access: http://<any-node-ip>:30080
Use when:
  Development/testing
  No cloud load balancer available
  Simple external access

Problems:
  Need to know node IP (changes)
  Awkward port numbers (30000+)
  No load balancing between nodes
  Not for production web apps
```

#### LoadBalancer (production external access)

```yaml
spec:
  type: LoadBalancer
  selector:
    app: judicial-api
  ports:
  - port: 80
    targetPort: 8080
```

```
Creates:
  Cloud load balancer (ALB/NLB on AWS, GCP LB on GKE)
  Gets external IP automatically
  Routes internet traffic → nodes → pods

Use when:
  Production external services
  Each service that needs its own external IP

Problems:
  One LoadBalancer per service = expensive
  100 services = 100 load balancers
  Solution: Use Ingress (one LB for many services)
```

#### ExternalName

```yaml
spec:
  type: ExternalName
  externalName: my-database.rds.amazonaws.com
```

```
Maps service name to external DNS name
Use when: referencing external services by stable internal name
  App calls: my-db-service → resolves to RDS endpoint
  If you migrate DB, only change ExternalName → no app changes
```

### Headless Service (no ClusterIP)

```yaml
spec:
  clusterIP: None     # headless — no virtual IP
  selector:
    app: my-statefulset
```

```
Returns individual pod IPs directly (not load balanced)
Use for:
  StatefulSets (need to reach specific pods — pod-0, pod-1)
  Service discovery where client handles load balancing
  Databases (PostgreSQL primary/replica — need specific addresses)
```

### Interview Question:
**"What's the difference between ClusterIP, NodePort, and LoadBalancer?"**

```
ClusterIP:
  Virtual IP only reachable INSIDE cluster
  Use for: internal service-to-service communication

NodePort:
  Opens a port on EVERY node
  Reachable from outside at <node-ip>:<nodeport>
  Use for: dev/testing when you need external access

LoadBalancer:
  Creates cloud load balancer with external IP
  Use for: production external-facing services
  Problem: one LB per service = expensive at scale

The hierarchy: LoadBalancer builds on NodePort builds on ClusterIP
  Creating a LoadBalancer also creates NodePort and ClusterIP
```

---

## PART 5 — INGRESS + INGRESS CONTROLLER

### Why Ingress?

```
Problem with LoadBalancer services:
  100 services = 100 cloud load balancers = expensive
  No path-based routing
  No SSL termination at K8s level
  No virtual hosting

Solution: Ingress
  ONE load balancer for all services
  Path-based routing: /api → api-service, /web → web-service
  Host-based routing: api.example.com → api, web.example.com → web
  SSL termination
```

### Ingress Architecture

```
Internet
    │
    ▼
Cloud Load Balancer (one per cluster)
    │
    ▼
Ingress Controller (Nginx, Traefik, ALB Ingress Controller)
    │ reads Ingress rules
    ├── /api/* → api-service:8080
    ├── /web/* → web-service:3000
    └── /admin → admin-service:9000
```

### Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: judicial-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx         # which ingress controller to use
  
  tls:
  - hosts:
    - judicialsolutions.in
    secretName: judicial-tls      # TLS certificate secret
  
  rules:
  - host: judicialsolutions.in    # host-based routing
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: judicial-api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: judicial-frontend-svc
            port:
              number: 80
```

### Path Types

```
Exact:    /foo matches only /foo (not /foo/bar)
Prefix:   /foo matches /foo, /foo/bar, /foo/bar/baz
ImplementationSpecific: depends on ingress controller
```

### Your Minikube Ingress Setup (from your project)

```bash
# Enable ingress on Minikube
minikube addons enable ingress

# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Apply your 3-service fake shop ingress
kubectl apply -f ingress.yaml

# Get Minikube IP
minikube ip

# Add to /etc/hosts (for local DNS)
echo "$(minikube ip) shop.local" >> /etc/hosts

# Test routing
curl http://shop.local/products    # → products service
curl http://shop.local/orders      # → orders service
curl http://shop.local/users       # → users service
```

```yaml
# Your fake shop ingress (from cloud_learning repo)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: shop.local
    http:
      paths:
      - path: /products
        pathType: Prefix
        backend:
          service:
            name: products-svc
            port:
              number: 80
      - path: /orders
        pathType: Prefix
        backend:
          service:
            name: orders-svc
            port:
              number: 80
      - path: /users
        pathType: Prefix
        backend:
          service:
            name: users-svc
            port:
              number: 80
```

### Interview Question:
**"What's the difference between Ingress and a LoadBalancer Service?"**

```
LoadBalancer Service:
  One cloud load balancer per service
  L4 load balancing (TCP/UDP)
  No path/host routing
  Expensive at scale (100 services = 100 LBs)

Ingress:
  One cloud load balancer for entire cluster
  L7 load balancing (HTTP/HTTPS)
  Path-based and host-based routing
  SSL termination
  Cost-effective at scale

Ingress requires: Ingress Controller (Nginx, Traefik, AWS ALB Controller)
Ingress Controller: the actual reverse proxy doing the routing
Ingress Resource: the routing rules (which path → which service)
```

---

## PART 6 — CONFIGMAPS + SECRETS

### ConfigMap — Non-Sensitive Configuration

```yaml
# Create ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  # Simple key-value
  db_host: "postgres-service"
  db_port: "5432"
  log_level: "info"
  
  # Multi-line (config file)
  app.properties: |
    server.port=8080
    spring.datasource.url=jdbc:postgresql://postgres:5432/mydb
    logging.level.root=INFO
```

```yaml
# Use ConfigMap in Pod — method 1: env vars
spec:
  containers:
  - name: api
    envFrom:
    - configMapRef:
        name: app-config    # all keys become env vars
    
    # Or specific key:
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db_host

# Use ConfigMap in Pod — method 2: volume (file)
    volumeMounts:
    - name: config-volume
      mountPath: /app/config
  
  volumes:
  - name: config-volume
    configMap:
      name: app-config
# Files created: /app/config/db_host, /app/config/db_port, /app/config/app.properties
```

### Secret — Sensitive Data

```yaml
# Secret (base64 encoded — NOT encrypted by default)
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db_password: bXlzZWNyZXQxMjM=   # base64 of "mysecret123"
  api_key: c2VjcmV0a2V5MTIz         # base64 encoded
```

```bash
# Create secret from command line
kubectl create secret generic app-secrets \
  --from-literal=db_password=mysecret123 \
  --from-literal=api_key=secretkey123

# Create from file
kubectl create secret generic tls-certs \
  --from-file=tls.crt=./cert.crt \
  --from-file=tls.key=./cert.key

# View secret (base64 decoded)
kubectl get secret app-secrets -o jsonpath='{.data.db_password}' | base64 -d

# Update secret
kubectl create secret generic app-secrets \
  --from-literal=db_password=newpassword \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Important: Secrets are NOT encrypted by default

```
Default: base64 encoded in etcd (not encrypted — anyone with etcd access can read)

Enable encryption at rest:
  EncryptionConfiguration in API server
  Encrypts secrets with AES-GCM before writing to etcd

Better: Use external secret management
  AWS Secrets Manager + External Secrets Operator
  HashiCorp Vault + Vault Agent Injector
  
External Secrets Operator:
  CRD that syncs AWS Secrets Manager secrets into K8s Secrets
  Rotation: automatically syncs when secret rotated in AWS
```

```yaml
# External Secrets Operator example
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: app-secrets     # creates this K8s secret
  data:
  - secretKey: db_password
    remoteRef:
      key: judicial/prod/db    # AWS Secrets Manager path
      property: password
```

---

## PART 7 — HPA + VPA + CLUSTER AUTOSCALER

### HPA — Horizontal Pod Autoscaler

```
Scales NUMBER of pods based on metrics
CPU, memory, custom metrics (Prometheus)

How it works:
  1. Metrics Server collects pod CPU/memory
  2. HPA controller polls Metrics Server every 15 seconds
  3. Compares current metric vs target
  4. Scales deployment up or down
  5. Scale-up: immediate when needed
  6. Scale-down: waits 5 minutes (--horizontal-pod-autoscaler-downscale-stabilization)
```

```yaml
# HPA based on CPU
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: judicial-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  
  minReplicas: 2      # never scale below this
  maxReplicas: 20     # never scale above this
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70    # scale up if CPU > 70%
  
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80    # scale up if memory > 80%
  
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0    # scale up immediately
      policies:
      - type: Percent
        value: 100                     # double pods at a time
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300  # wait 5 min before scale down
      policies:
      - type: Percent
        value: 25                      # remove 25% at a time
        periodSeconds: 60
```

```bash
# Install Metrics Server (required for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Apply HPA
kubectl apply -f hpa.yaml

# Check HPA status
kubectl get hpa
# NAME              REFERENCE            TARGETS   MINPODS   MAXPODS   REPLICAS
# judicial-api-hpa  Deployment/judicial  45%/70%   2         20        3

kubectl describe hpa judicial-api-hpa

# Generate load to trigger scaling
kubectl run load-generator \
  --image=busybox \
  --restart=Never \
  -- /bin/sh -c "while true; do wget -q -O- http://judicial-api-svc; done"

# Watch HPA scale up
kubectl get hpa -w
```

### HPA with Custom Metrics (Prometheus)

```yaml
# Scale based on custom metric (requests per second)
metrics:
- type: Pods
  pods:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "100"    # 100 req/sec per pod

- type: External
  external:
    metric:
      name: sqs_queue_depth
      selector:
        matchLabels:
          queue: judicial-queue
    target:
      type: AverageValue
      averageValue: "30"    # 30 messages per pod
```

### VPA — Vertical Pod Autoscaler

```
Adjusts CPU/memory REQUESTS of pods (not replica count)
Useful when: single-threaded apps that can't scale horizontally

Modes:
  Off:      Only provides recommendations, no automatic changes
  Initial:  Sets resources only at pod creation
  Auto:     Evicts and restarts pods with new resource values
  Recreate: Same as Auto

Limitation: cannot be used with HPA on same metric (both adjusting CPU)
  Use HPA for CPU-based scaling
  Use VPA for memory right-sizing
```

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: judicial-api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: api
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 2
        memory: 2Gi
```

### Cluster Autoscaler

```
Scales NUMBER of NODES (not pods)
Triggers when: pods can't be scheduled due to insufficient node resources

How it works:
  1. Pod is Pending (no node has enough CPU/memory)
  2. Cluster Autoscaler detects Pending pods
  3. Calculates how many nodes needed
  4. Calls cloud API to add nodes (AWS Auto Scaling Group)
  5. New nodes join cluster
  6. Scheduler places Pending pods on new nodes
  7. During low usage: identifies underutilized nodes
  8. Drains and terminates those nodes

Scale-up: ~1-2 minutes (time to provision new node)
Scale-down: waits 10 minutes of low utilization

Works with:
  HPA: HPA scales pods → pods can't fit → Cluster Autoscaler adds nodes
  This is the complete auto-scaling picture in Kubernetes
```

```
Full auto-scaling flow:
  Traffic increases
      ↓
  HPA creates more pods
      ↓
  Pods are Pending (no resources on existing nodes)
      ↓
  Cluster Autoscaler adds node(s)
      ↓
  Pods scheduled on new nodes
      ↓
  Traffic decreases
      ↓
  HPA removes pods
      ↓
  Nodes underutilized
      ↓
  Cluster Autoscaler removes nodes
```

---

## PART 8 — PERSISTENT VOLUMES + PVC

### Why Persistent Storage?

```
Pod storage is ephemeral:
  Pod deleted → all data gone
  Pod rescheduled to different node → data left behind

Solution: Persistent Volumes
  Storage that exists independently of pods
  Pod can be deleted and recreated — data persists
  Pod can move to different node — PVC follows
```

### Storage Hierarchy

```
StorageClass → defines HOW to provision storage (AWS EBS, NFS, etc.)
PersistentVolume (PV) → actual storage resource
PersistentVolumeClaim (PVC) → pod's request for storage
Pod → uses PVC
```

### Dynamic Provisioning (modern approach)

```yaml
# StorageClass — defines storage type
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com     # AWS EBS CSI driver
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete             # Delete or Retain when PVC deleted
volumeBindingMode: WaitForFirstConsumer  # provision when pod scheduled
```

```yaml
# PersistentVolumeClaim — request storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: judicial-data-pvc
spec:
  storageClassName: fast-ssd
  accessModes:
  - ReadWriteOnce              # RWO: one node at a time
  resources:
    requests:
      storage: 20Gi
```

```yaml
# Pod uses PVC
spec:
  containers:
  - name: api
    volumeMounts:
    - name: data
      mountPath: /app/data
  
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: judicial-data-pvc
```

### Access Modes

```
ReadWriteOnce (RWO):
  Mounted by ONE node at a time (single pod usually)
  AWS EBS, GCP PD — block storage
  Most common

ReadOnlyMany (ROX):
  Mounted as read-only by MANY nodes simultaneously
  Static content, model files

ReadWriteMany (RWX):
  Mounted as read-write by MANY nodes simultaneously
  AWS EFS (NFS-based), Azure Files
  Use for: shared upload storage, distributed app storage

ReadWriteOncePod (RWOP):
  Mounted by ONE pod only (even within same node)
  Most restrictive
```

### Reclaim Policies

```
Retain:
  PV not deleted when PVC is deleted
  Data preserved — admin must manually clean up
  Use for: production databases (accidental deletion protection)

Delete:
  PV and underlying storage deleted when PVC deleted
  Use for: non-critical data, development

Recycle (deprecated):
  Wipes PV and makes it available again (rm -rf /thevolume/*)
```

---

## PART 9 — RBAC IN KUBERNETES

### RBAC Components

```
Role:
  Defines permissions (verbs on resources)
  Namespace-scoped (only applies within one namespace)

ClusterRole:
  Defines permissions
  Cluster-scoped (applies to all namespaces OR cluster resources)

RoleBinding:
  Binds Role to Subject (user/group/serviceaccount)
  Namespace-scoped

ClusterRoleBinding:
  Binds ClusterRole to Subject
  Cluster-scoped

Subject:
  Who gets the permissions:
  - User (human, external auth)
  - Group (set of users)
  - ServiceAccount (pod identity)
```

### Role and RoleBinding

```yaml
# Role — what's allowed in this namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]              # "" = core API group
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
```

```yaml
# RoleBinding — who gets the role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: developer-john       # user name from authentication
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: my-service-account
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### ClusterRole and ClusterRoleBinding

```yaml
# ClusterRole — cluster-wide permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
```

```yaml
# ClusterRoleBinding — applies cluster-wide
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes-global
subjects:
- kind: User
  name: ops-team
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

### Common RBAC Verbs

```
get       → read single resource
list      → read list of resources
watch     → stream updates (kubectl get pods -w)
create    → create resource
update    → modify existing resource
patch     → partial update
delete    → delete resource
deletecollection → delete multiple
exec      → execute in pod (pods/exec)
portforward → port forward to pod (pods/portforward)
```

### ServiceAccount for Pods

```yaml
# Create ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judicial-api-sa
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/judicial-role  # IRSA on EKS

---
# Role for the ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: judicial-api-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update"]  # for rolling restart

---
# Bind role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: judicial-api-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: judicial-api-sa
  namespace: production
roleRef:
  kind: Role
  name: judicial-api-role
  apiGroup: rbac.authorization.k8s.io
```

```yaml
# Pod uses the ServiceAccount
spec:
  serviceAccountName: judicial-api-sa
  containers:
  - name: api
    image: judicial-api:latest
```

### Hands-on RBAC

```bash
# Check your current permissions
kubectl auth can-i list pods
kubectl auth can-i delete deployments --namespace production

# Check permissions for another user
kubectl auth can-i list pods \
  --as developer-john \
  --namespace production

# Check all permissions for a service account
kubectl auth can-i --list \
  --as system:serviceaccount:production:judicial-api-sa

# View all roles
kubectl get roles --all-namespaces
kubectl get clusterroles | grep -v system

# Describe a role
kubectl describe role pod-reader -n production
```

---

## PART 10 — NAMESPACES + RESOURCE QUOTAS

### Namespaces

```
Virtual clusters within a physical cluster
Use for:
  - Environment separation (dev/staging/prod in same cluster)
  - Team separation (team-a, team-b)
  - Resource isolation

Default namespaces:
  default:      where resources go if no namespace specified
  kube-system:  K8s system components (api-server, scheduler, etc.)
  kube-public:  publicly accessible data
  kube-node-lease: node heartbeat leases

What's NOT namespace-scoped:
  Nodes, PersistentVolumes, StorageClasses, ClusterRoles
```

```bash
# Create namespace
kubectl create namespace production
kubectl apply -f namespace.yaml

# Switch context to namespace
kubectl config set-context --current --namespace=production

# Or use -n flag
kubectl get pods -n production

# View all resources in a namespace
kubectl get all -n production

# Delete namespace (deletes EVERYTHING inside)
kubectl delete namespace old-dev
```

### Resource Quotas

```yaml
# Limit total resources in a namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # Compute
    requests.cpu: "20"         # total CPU requests in namespace
    requests.memory: 40Gi      # total memory requests
    limits.cpu: "40"
    limits.memory: 80Gi
    
    # Object count
    pods: "100"
    services: "20"
    persistentvolumeclaims: "20"
    secrets: "50"
    configmaps: "50"
    
    # LoadBalancer services
    services.loadbalancers: "5"
    services.nodeports: "0"    # ban NodePort in production
```

### LimitRange

```yaml
# Set default and max limits per container
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:               # applied if no limits specified in pod
      memory: 256Mi
      cpu: 200m
    defaultRequest:        # applied if no requests specified
      memory: 128Mi
      cpu: 100m
    max:                   # maximum allowed per container
      memory: 2Gi
      cpu: 2
    min:                   # minimum required per container
      memory: 64Mi
      cpu: 50m
  
  - type: Pod
    max:
      memory: 4Gi          # total across all containers in pod
      cpu: 4
```

---

## PART 11 — COMPLETE HANDS-ON EXAMPLES

### Deploy a Complete Application on Minikube

```bash
# Start Minikube with enough resources
minikube start --cpus 4 --memory 8192

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server

# Create namespace
kubectl create namespace judicial

# Apply all manifests
kubectl apply -f k8s/ -n judicial

# Check everything
kubectl get all -n judicial
```

### Complete Application Manifests

```yaml
# 1-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: judicial
data:
  DB_HOST: "postgres-svc"
  DB_PORT: "5432"
  LOG_LEVEL: "info"

---
# 2-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: judicial
type: Opaque
stringData:             # stringData auto-encodes to base64
  DB_PASSWORD: "mysecretpassword"
  API_KEY: "secretapikey123"

---
# 3-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: judicial
spec:
  replicas: 2
  selector:
    matchLabels:
      app: judicial-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: judicial-api
    spec:
      containers:
      - name: api
        image: judicial-api:latest
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secrets
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
# 4-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: judicial-api-svc
  namespace: judicial
spec:
  selector:
    app: judicial-api
  ports:
  - port: 80
    targetPort: 8080

---
# 5-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: judicial-api-hpa
  namespace: judicial
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

---
# 6-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: judicial-ingress
  namespace: judicial
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: judicial.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: judicial-api-svc
            port:
              number: 80
```

---

## INTERVIEW QUESTIONS RAPID FIRE

**Q: What is the difference between a Deployment and a StatefulSet?**

```
Deployment:
  Pods are interchangeable — any pod can replace any other
  Pods get random names: judicial-api-abc123, judicial-api-xyz789
  No stable network identity
  No ordered deployment/deletion
  Use for: stateless apps — APIs, web apps, workers

StatefulSet:
  Pods have stable, unique identities: postgres-0, postgres-1, postgres-2
  Stable network hostname: postgres-0.postgres-svc
  Ordered deployment (0 before 1 before 2)
  Ordered deletion (2 before 1 before 0)
  Each pod gets its own PVC (data not shared)
  Use for: databases, Kafka, Zookeeper, Elasticsearch
```

---

**Q: What happens when a node fails in Kubernetes?**

```
1. Node controller detects node is unreachable
   (no heartbeat for node-monitor-grace-period = 40s default)

2. Node status changes to NotReady

3. After pod-eviction-timeout (5 min default):
   All pods on failed node are marked for eviction

4. New pods created on healthy nodes
   (ReplicaSet controller sees fewer pods than desired)

5. Failed pods in Terminating state until:
   - Node recovers OR
   - Manually forced: kubectl delete pod --force --grace-period=0

6. Persistent volumes attached to failed node:
   After node-failure timeout, volume detached and attached to new node
   (may take several minutes for AWS EBS)
```

---

**Q: How does Kubernetes know where to schedule a pod?**

```
Scheduler considers:

1. Node selectors / nodeAffinity
   nodeName: specific-node          → exact node
   nodeSelector: {disktype: ssd}    → nodes with label
   nodeAffinity: preferred/required → flexible matching

2. Taints and Tolerations
   Node taint: special=gpu:NoSchedule → only pods that tolerate this
   Pod toleration: allows scheduling on tainted node
   Use for: dedicated nodes, GPU nodes, spot instances

3. Resource availability
   Pod requests: 500m CPU, 256Mi memory
   Scheduler only places on nodes with sufficient free resources

4. Pod affinity/anti-affinity
   Affinity: schedule near other pods (latency reduction)
   Anti-affinity: spread pods across nodes (high availability)

5. Topology spread constraints
   Spread pods evenly across zones/nodes
```

---

**Q: What is a DaemonSet and when do you use it?**

```
DaemonSet ensures ONE pod runs on EVERY node
  New node added → DaemonSet pod automatically created on it
  Node removed → pod garbage collected

Use for:
  Log collectors (Fluentd, Filebeat)
  Monitoring agents (Prometheus node-exporter, Datadog)
  Network plugins (Calico, Cilium)
  Storage agents (Ceph)

kubectl get daemonsets -n kube-system
# See: kube-proxy, aws-node, kube-proxy — all DaemonSets
```

---

**Q: Your pod is stuck in Pending state. What do you check?**

```
kubectl describe pod stuck-pod

Look for Events section at the bottom:

1. "Insufficient cpu/memory"
   → Node has no resources
   → Solution: add resources, scale down other deployments, add node

2. "No nodes are available that match all of the following predicates"
   → nodeSelector or nodeAffinity doesn't match any node
   → Solution: check labels on nodes, fix selector

3. "0/3 nodes are available: 3 node(s) had taint..."
   → Node tainted, pod doesn't tolerate it
   → Solution: add toleration to pod OR remove taint from node

4. "pod has unbound immediate PersistentVolumeClaims"
   → PVC not bound (no matching PV or StorageClass issue)
   → Solution: check PVC status: kubectl get pvc

5. "Unschedulable"
   → Cluster autoscaler scaling up nodes
   → Wait 1-2 minutes

6. "ImagePullBackOff" shows in Waiting status (not Pending)
   → Image pull fails: wrong image name, registry auth issue
```

---

**Q: What is the difference between kubectl apply and kubectl create?**

```
kubectl create:
  Creates resource — fails if already exists
  Imperative: "create this"
  Use for: one-time creation, learning

kubectl apply:
  Creates resource if not exists, updates if exists
  Declarative: "desired state is this"
  Stores last-applied config as annotation
  Use for: production, CI/CD, GitOps

kubectl replace:
  Replaces existing resource
  Fails if resource doesn't exist
  Deletes and recreates (unlike apply which patches)

Best practice:
  Always use kubectl apply in automation
  Store all manifests in git
  Apply from CI/CD pipeline
```

---

## QUICK REFERENCE

### Essential kubectl commands:
```bash
# Context and cluster
kubectl config get-contexts
kubectl config use-context my-cluster
kubectl config set-context --current --namespace=production

# Get resources
kubectl get pods,svc,deployments -n production
kubectl get all -A                          # everything everywhere
kubectl get pods -o wide                    # show node assignment
kubectl get pods --sort-by=.status.startTime

# Describe and debug
kubectl describe pod <name>
kubectl logs <pod> -f                      # follow logs
kubectl logs <pod> --previous             # previous container
kubectl exec -it <pod> -- bash
kubectl port-forward pod/<name> 8080:8080 # local access

# Edit live
kubectl edit deployment judicial-api
kubectl set image deployment/api api=image:v2
kubectl scale deployment api --replicas=5

# Rollout
kubectl rollout status deployment/api
kubectl rollout history deployment/api
kubectl rollout undo deployment/api
kubectl rollout pause deployment/api
kubectl rollout resume deployment/api

# Debugging
kubectl get events --sort-by='.lastTimestamp'
kubectl top pods
kubectl top nodes
kubectl auth can-i list pods

# Cleanup
kubectl delete pod <name> --grace-period=0 --force
kubectl delete all -l app=judicial-api
```

### Resource abbreviations:
```
po = pods
svc = services
deploy = deployments
rs = replicasets
cm = configmaps
pvc = persistentvolumeclaims
pv = persistentvolumes
sa = serviceaccounts
ns = namespaces
hpa = horizontalpodautoscalers
ing = ingresses
```

### Pod status meanings:
```
Pending:           Not scheduled yet
ContainerCreating: Image pulling
Running:           At least one container running
Completed:         All containers exited 0
Error:             Container exited non-zero
CrashLoopBackOff:  Container keeps crashing
OOMKilled:         Container exceeded memory limit
Evicted:           Removed due to node pressure
Terminating:       Being deleted
ImagePullBackOff:  Cannot pull image
ErrImagePull:      Image pull error (before backoff)
```
