# Kubernetes — Advanced Topics Deep Dive

## Pod Communication + 3-Tier Architecture + HPA + VPA + Scaling + Production Issues

### Theory → YAML Examples → Real Use Cases → Interview Questions

-----

## README

**This file covers:** Advanced Kubernetes patterns asked at mid-level and senior interviews
**Prerequisite:** Kubernetes Complete Deep Dive (architecture, pods, services, deployments)
**Target level:** Mid-level to Senior DevOps/Cloud Engineer

### Priority sections:

|Section                       |Why it matters                                         |
|------------------------------|-------------------------------------------------------|
|Part 1 — Pod Communication    |“How do pods talk to each other?” — every K8s interview|
|Part 2 — 3-Tier Architecture  |Design question — shows real-world thinking            |
|Part 3 — HPA                  |On your resume — own every detail                      |
|Part 5 — Stateful vs Stateless|Fundamental design decision                            |
|Part 7 — Production Issues    |“Debug CrashLoopBackOff” — scenario questions          |

-----

## 📌 TABLE OF CONTENTS

> Click any link to jump directly to that section

|# |Section                                                                   |Key Topics                                                                  |
|--|--------------------------------------------------------------------------|----------------------------------------------------------------------------|
|1 |[Pod Communication](#part-1--pod-communication)                           |Pod IPs, DNS resolution, CoreDNS, Service routing, debugging                |
|2 |[3-Tier Architecture](#part-2--3-tier-architecture-in-kubernetes)         |Frontend + API + DB YAMLs, Ingress, communication flow                      |
|3 |[HPA — Horizontal Pod Autoscaler](#part-3--hpa--horizontal-pod-autoscaler)|Internals, multi-metric YAML, behavior, debugging, real use case            |
|4 |[VPA — Vertical Pod Autoscaler](#part-4--vpa--vertical-pod-autoscaler)    |Modes, config, HPA+VPA conflict, best practice                              |
|5 |[Stateful vs Stateless](#part-5--stateful-vs-stateless)                   |Decision guide, side-by-side table, Redis example                           |
|6 |[Networking and Services](#part-6--networking-and-services-deep-dive)     |Service types, routing mechanism, Ingress vs LB                             |
|7 |[Cluster Scaling — Full Picture](#part-7--cluster-scaling--full-picture)  |HPA+VPA+CA together, PodDisruptionBudget, CA config                         |
|8 |[Common Production Issues](#part-8--common-production-issues)             |7 issues: CrashLoop, ImagePull, Pending PVC, selector mismatch, probes, RBAC|
|9 |[Pod Scheduling](#part-9--pod-scheduling-taints-tolerations-affinity)     |nodeSelector, affinity, anti-affinity, taints, topology spread              |
|10|[Resource Management + QoS](#part-10--resource-management-and-qos-classes)|Requests vs limits, QoS classes, LimitRange, ResourceQuota                  |
|11|[Multi-Container Pod Patterns](#part-11--multi-container-pod-patterns)    |Sidecar, Init, Ambassador, Adapter — with full YAML examples                |
|12|[Jobs and CronJobs](#part-12--jobs-and-cronjobs)                          |One-time jobs, parallel jobs, scheduled CronJobs                            |
|13|[DaemonSet](#part-13--daemonset)                                          |Node-level agents, use cases, node-exporter YAML                            |
|14|[ConfigMaps and Secrets](#part-14--configmaps-and-secrets-in-depth)       |All usage patterns, security deep dive, External Secrets, Vault             |
|15|[RBAC Complete Guide](#part-15--rbac-complete-guide)                      |Role, ClusterRole, RoleBinding, ServiceAccount, common mistakes             |
|16|[Kubernetes Security](#part-16--kubernetes-security-pod-security)         |securityContext, Pod Security Standards, capabilities                       |
|17|[Helm Basics](#part-17--helm-basics-for-devops)                           |Charts, releases, values, upgrade, rollback, chart structure                |
|18|[Kubernetes Observability](#part-18--kubernetes-observability)            |kube-prometheus-stack, ServiceMonitor, key metrics, alerts                  |
|19|[Deployment Strategies](#part-19--deployment-strategies-complete)         |Recreate, Rolling, Blue-Green, Canary — with YAML and commands              |
|20|[GitOps with ArgoCD](#part-20--gitops-with-argocd)                        |GitOps principles, ArgoCD install, Application YAML, workflow               |
|21|[Interview Prep Answers](#part-21--complete-interview-prep-answers)       |Production issue story, multi-tenant SaaS design                            |
|— |[kubectl Cheat Sheet](#kubectl-commands-every-devops-engineer-must-know)  |All essential commands, abbreviations, decision tree                        |

### ⚡ Quick Jump by Topic:

> [Scheduling](#part-9--pod-scheduling-taints-tolerations-affinity) · [QoS Classes](#part-10--resource-management-and-qos-classes) · [Sidecar/Init Containers](#part-11--multi-container-pod-patterns) · [Jobs/CronJobs](#part-12--jobs-and-cronjobs) · [DaemonSet](#part-13--daemonset) · [ConfigMaps](#part-14--configmaps-and-secrets-in-depth) · [RBAC](#part-15--rbac-complete-guide) · [Security](#part-16--kubernetes-security-pod-security) · [Helm](#part-17--helm-basics-for-devops) · [Observability](#part-18--kubernetes-observability) · [Deployment Strategies](#part-19--deployment-strategies-complete) · [GitOps/ArgoCD](#part-20--gitops-with-argocd) · [kubectl Cheatsheet](#kubectl-commands-every-devops-engineer-must-know)

-----

## PART 1 — POD COMMUNICATION

### How Pods Get IPs

```
Every pod in Kubernetes gets its own unique IP address.
Assigned by: CNI plugin (Calico, Flannel, Cilium, aws-node on EKS)

Pod IPs:
  Ephemeral — change every time pod is recreated
  Unique within cluster — no two pods share an IP
  Routable within cluster — any pod can reach any other pod IP directly

Problem:
  Pod A wants to call Pod B
  Pod B IP today: 10.244.0.5
  Pod B crashes, gets rescheduled
  Pod B IP now:   10.244.1.8  (different!)
  Pod A has the old IP → connection fails

Solution: Services
  Service gets a stable virtual IP (ClusterIP) that NEVER changes
  DNS name: my-service.namespace.svc.cluster.local
  Service routes to pods by label selector
  Pods come and go — Service stays stable
```

### Pod-to-Pod Communication Patterns

```
Pattern 1: Direct pod IP (avoid in production)
  Pod A → 10.244.0.5 → Pod B
  Breaks when Pod B restarts
  Use only for: debugging, testing

Pattern 2: Via Service + DNS (standard)
  Pod A → api-service.default.svc.cluster.local → Service → Pod B
  Service selects healthy pods by label
  DNS resolves to stable ClusterIP

Pattern 3: Via Service (same namespace short form)
  Pod A → api-service → Service → Pod B
  Works only within SAME namespace

Pattern 4: Via Service (cross-namespace full FQDN)
  Pod A (in frontend ns) → api-service.backend.svc.cluster.local → Pod B (in backend ns)
  Must use full FQDN for cross-namespace
```

### DNS Resolution Inside Kubernetes

```
CoreDNS runs in kube-system namespace
Every pod's /etc/resolv.conf points to CoreDNS ClusterIP

# Inside a pod:
cat /etc/resolv.conf
# nameserver 10.96.0.10          ← CoreDNS ClusterIP
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5

DNS name formats:
  service-name                                  → same namespace (short)
  service-name.namespace                        → cross-namespace (medium)
  service-name.namespace.svc                   → with svc
  service-name.namespace.svc.cluster.local     → fully qualified (FQDN)

All 4 resolve to the same ClusterIP for services in the same cluster.

Real example — judicialsolutions.in:
  Frontend pod calling API:
    http://judicial-api                                   ← same namespace
    http://judicial-api.production.svc.cluster.local     ← cross-namespace

  API pod calling database:
    postgres://postgres-db.production.svc.cluster.local:5432/mydb
```

### Hands-on: Debug Pod Communication

```bash
# Test DNS resolution from inside a pod
kubectl exec -it my-pod -- nslookup api-service
kubectl exec -it my-pod -- nslookup api-service.production.svc.cluster.local

# Test HTTP connectivity between pods
kubectl exec -it frontend-pod -- curl http://api-service:8080/health
kubectl exec -it frontend-pod -- curl http://api-service.backend.svc.cluster.local:8080/health

# Test TCP connectivity (check if port is reachable)
kubectl exec -it my-pod -- nc -zv api-service 8080

# Check DNS config in pod
kubectl exec -it my-pod -- cat /etc/resolv.conf

# See all endpoints behind a service (which pods are reachable)
kubectl get endpoints api-service
# NAME          ENDPOINTS                         AGE
# api-service   10.244.0.5:8080,10.244.1.8:8080  5m

# Run a debug pod for network testing
kubectl run debug --image=busybox --restart=Never --rm -it -- sh
# Inside: nslookup api-service, wget -qO- http://api-service:8080/health

# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Interview Question:

**“How does Pod A communicate with Pod B in Kubernetes?”**

```
Never use Pod IPs directly — they change when pods restart.

Standard flow:
  1. Deploy Pod B behind a Service (ClusterIP)
  2. Service has stable DNS: api-service.namespace.svc.cluster.local
  3. Pod A calls: http://api-service:8080/endpoint (same namespace)
     or:          http://api-service.other-ns.svc.cluster.local:8080
  4. CoreDNS resolves service name → ClusterIP
  5. kube-proxy routes ClusterIP → one of the healthy pod IPs
  6. Traffic reaches Pod B

If Pod B restarts and gets new IP:
  Service selector picks up new pod (same labels)
  Service endpoints list updated automatically
  Pod A's next call routes to new pod — no configuration change needed
```

-----

## PART 2 — 3-TIER ARCHITECTURE IN KUBERNETES

### Architecture Overview

```
External Traffic
      │
      ▼
  Ingress Controller (Nginx / ALB)
      │
      │ routes /        → Frontend Service
      │ routes /api/    → API Service
      │
      ▼
┌─────────────────────────────────────────────────────┐
│                   FRONTEND TIER                      │
│   Deployment (stateless, 3 replicas)                │
│   React/Next.js served by Nginx                     │
│   Service: ClusterIP (Ingress routes to it)         │
└─────────────────────┬───────────────────────────────┘
                      │ http://api-service:8080
                      ▼
┌─────────────────────────────────────────────────────┐
│                    API TIER                          │
│   Deployment (stateless, 3 replicas)                │
│   Python FastAPI / Node.js / Go                     │
│   Service: ClusterIP                                │
│   HPA: scales 3→20 pods based on CPU               │
└─────────────────────┬───────────────────────────────┘
                      │ postgres://db-service:5432
                      ▼
┌─────────────────────────────────────────────────────┐
│                  DATABASE TIER                       │
│   StatefulSet (ordered, stable identity)            │
│   PostgreSQL with PVC (persistent storage)          │
│   Service: ClusterIP (headless for StatefulSet)     │
│   VolumeClaimTemplate: 20Gi per pod                 │
└─────────────────────────────────────────────────────┘
```

### Frontend Tier — Stateless Deployment

```yaml
# frontend-deployment.yaml
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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: judicial-frontend
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: judicial-frontend:1.2.3
        ports:
        - containerPort: 3000
        env:
        - name: REACT_APP_API_URL
          value: "http://judicial-api:8080"    # ← talks to API via Service name
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
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10

---
# frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: judicial-frontend
  namespace: production
spec:
  selector:
    app: judicial-frontend   # ← matches pods with this label
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP            # internal only — Ingress handles external
```

### API Tier — Stateless Deployment with HPA

```yaml
# api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: production
  labels:
    app: judicial-api
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: judicial-api
  template:
    metadata:
      labels:
        app: judicial-api
        tier: api
    spec:
      serviceAccountName: judicial-api-sa   # for IRSA on EKS
      containers:
      - name: api
        image: judicial-api:1.2.3
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          value: "judicial-db"              # ← talks to DB via Service name
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: db_name
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db_password
        resources:
          requests:
            cpu: "200m"                     # ← REQUIRED for HPA to work
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10

---
# api-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: judicial-api
  namespace: production
spec:
  selector:
    app: judicial-api
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

### Database Tier — StatefulSet with PVC

```yaml
# db-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: judicial-db
  namespace: production
spec:
  serviceName: judicial-db    # ← REQUIRED: links to headless service
  replicas: 1                 # for primary-only setup
  selector:
    matchLabels:
      app: judicial-db
  template:
    metadata:
      labels:
        app: judicial-db
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: judicial
        - name: POSTGRES_USER
          value: appuser
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-data           # ← mounts the PVC
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        readinessProbe:
          exec:
            command: ["pg_isready", "-U", "appuser", "-d", "judicial"]
          initialDelaySeconds: 15
          periodSeconds: 5

  volumeClaimTemplates:         # ← creates PVC per pod automatically
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3
      resources:
        requests:
          storage: 20Gi

---
# db-service.yaml (headless — gives stable DNS per pod)
apiVersion: v1
kind: Service
metadata:
  name: judicial-db
  namespace: production
spec:
  clusterIP: None             # ← headless: returns pod IPs directly
  selector:
    app: judicial-db
  ports:
  - port: 5432
    targetPort: 5432
# DNS: judicial-db-0.judicial-db.production.svc.cluster.local
#      ^^pod name^^  ^^service^^  ^^namespace^^
```

### Ingress — Exposing to External Traffic

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: judicial-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - judicialsolutions.in
    - api.judicialsolutions.in
    secretName: judicial-tls
  rules:
  - host: judicialsolutions.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: judicial-frontend   # ← routes to frontend service
            port:
              number: 80
  - host: api.judicialsolutions.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: judicial-api        # ← routes to API service
            port:
              number: 8080
```

### Communication Flow Summary

```
Browser → Ingress (nginx) → judicial-frontend Service → Frontend Pods
                          ↓
                    Frontend calls: http://judicial-api:8080
                          ↓
                    judicial-api Service → API Pods
                          ↓
                    API calls: postgres://judicial-db:5432
                          ↓
                    judicial-db Service (headless) → PostgreSQL Pod
                          ↓
                    PostgreSQL reads/writes PVC (EBS volume)
```

-----

## PART 3 — HPA — HORIZONTAL POD AUTOSCALER

### How HPA Works Internally

```
HPA Controller (runs in control plane):
  1. Polls Metrics Server every 15 seconds (default)
  2. Gets current metric value (e.g., CPU = 85%)
  3. Compares to target (e.g., targetUtilization = 70%)
  4. Calculates desired replicas:
     desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)
     = ceil(3 × 85 / 70)
     = ceil(3.64)
     = 4 pods
  5. Updates Deployment spec.replicas = 4
  6. Deployment creates new pod
  7. Wait for stabilization before next scale decision

Scale-up:   immediately when needed (no delay by default)
Scale-down: waits 5 minutes (stabilizationWindowSeconds=300)
            prevents thrashing — don't scale down if load might return

Requirements for HPA to work:
  ✓ metrics-server must be running in cluster
  ✓ resources.requests MUST be set on containers
  ✓ scaleTargetRef must point to valid Deployment/StatefulSet
  ✗ Without resources.requests: HPA shows <unknown>/70% → won't scale
```

### Complete HPA Configuration

```yaml
# hpa.yaml — HPA with multiple metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: judicial-api-hpa
  namespace: production
spec:
  # What to scale
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api          # ← must match Deployment name exactly

  # Replica bounds
  minReplicas: 2                # never go below 2 (always HA)
  maxReplicas: 20               # never exceed 20

  # Metrics to scale on
  metrics:
  # Metric 1: CPU (most common)
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # scale up if avg CPU > 70% of request

  # Metric 2: Memory
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # scale up if avg memory > 80% of request

  # Metric 3: Custom metric (requests per second via Prometheus adapter)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"     # scale if > 100 req/sec per pod

  # Scaling behavior (fine-tuning)
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0   # scale up immediately
      policies:
      - type: Percent
        value: 100                    # can double pod count at once
        periodSeconds: 15
      - type: Pods
        value: 4                      # or add max 4 pods at once
        periodSeconds: 15
      selectPolicy: Max               # use whichever allows more pods

    scaleDown:
      stabilizationWindowSeconds: 300  # wait 5 min before scaling down
      policies:
      - type: Percent
        value: 25                      # remove max 25% of pods at once
        periodSeconds: 60              # wait 60s between each scale-down
      selectPolicy: Min                # be conservative on scale-down
```

### HPA Debugging

```bash
# Check HPA status
kubectl get hpa -n production
# NAME               REFERENCE          TARGETS         MINPODS  MAXPODS  REPLICAS
# judicial-api-hpa   Deployment/api     45%/70%         2        20       3
# judicial-api-hpa   Deployment/api     <unknown>/70%   2        20       3  ← BAD

# <unknown> means HPA can't get metrics — common causes:
# 1. metrics-server not installed
# 2. resources.requests not set on container
# 3. scaleTargetRef is wrong

# Describe HPA for detailed events
kubectl describe hpa judicial-api-hpa -n production
# Events section shows WHY it scaled or didn't

# Check if metrics-server is running
kubectl get pods -n kube-system | grep metrics-server
kubectl top pods -n production  # if this works, metrics-server is OK

# Check current pod resource usage
kubectl top pods -n production -l app=judicial-api

# Watch HPA in real time
kubectl get hpa -n production -w

# Generate load to test HPA
kubectl run load-gen \
  --image=busybox \
  --restart=Never \
  --rm -it \
  -- /bin/sh -c "while true; do wget -q -O- http://judicial-api.production:8080/health; done"
```

### HPA Common Issues and Fixes

```
Issue 1: HPA shows <unknown>/70%
  Cause:  resources.requests not set → HPA can't calculate %
  Fix:    add requests to container spec:
            resources:
              requests:
                cpu: "200m"
                memory: "256Mi"

Issue 2: HPA not scaling up despite high CPU
  Cause A: metrics-server not installed
    Fix: kubectl apply -f metrics-server.yaml
  Cause B: pods already at maxReplicas
    Fix: increase maxReplicas
  Cause C: stabilizationWindowSeconds too high
    Fix: reduce stabilizationWindowSeconds for scaleUp

Issue 3: HPA scaling down too aggressively
  Cause: default scale-down is fast
  Fix:   add scaleDown stabilizationWindowSeconds: 300

Issue 4: HPA and Deployment replicas conflict
  You manually set: kubectl scale deployment api --replicas=5
  HPA then adjusts back to its calculation
  Solution: let HPA manage replicas — don't scale manually when HPA is active

Issue 5: HPA on StatefulSet
  StatefulSets CAN be HPA targets, but be careful:
  - Database StatefulSets: don't HPA (data sharding complexity)
  - Worker StatefulSets (e.g., Kafka consumers): HPA is fine
```

### Real Use Case: HPA for judicialsolutions.in

```yaml
# Scenario: Legal filing deadline day — 100x normal traffic
# Normal: 3 pods handling 50 req/sec
# Deadline day: 5000 req/sec (court filing deadline)

# HPA config for this scenario:
spec:
  minReplicas: 3          # always 3 for normal operation
  maxReplicas: 50         # allow massive scale on deadline day
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60   # scale earlier (60% not 80%)
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0       # scale immediately
      policies:
      - type: Percent
        value: 200                        # can triple pod count
          periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 600     # wait 10 min after deadline

# Result:
# 08:00 - deadline day starts, traffic spikes
# 08:01 - CPU hits 80%, HPA triggers
# 08:02 - scales from 3 → 9 → 27 pods (doubling each 30s)
# 08:10 - 50 pods running, traffic handled
# 18:00 - deadline passes, traffic drops
# 18:10 - HPA waits 10 minutes
# 18:20 - starts scaling down (25% per 60s)
# 19:00 - back to 3 pods
```

-----

## PART 4 — VPA — VERTICAL POD AUTOSCALER

### HPA vs VPA — The Core Difference

```
HPA (Horizontal): adds/removes PODS
  3 pods → 6 pods (more workers)
  Each pod keeps same CPU/memory
  Best for: stateless services, web APIs

VPA (Vertical): changes CPU/memory PER POD
  Pod with 200m CPU → 500m CPU (bigger pod)
  Same number of pods
  Best for: stateful services, databases, apps that can't scale horizontally
  Also useful for: right-sizing (finding optimal resource values)
```

### VPA Modes

```
Off:      VPA only provides RECOMMENDATIONS — no automatic changes
          Use for: learning what resources your app actually needs
          kubectl describe vpa → see "Lower Bound", "Target", "Upper Bound"

Initial:  Sets resources only when POD IS CREATED
          Running pods are NOT changed
          Safe: no pod restarts during operation
          Use for: auto-set correct values at startup

Recreate: Changes resources by EVICTING and RESTARTING pods
          Pod gets new resources on restart
          Brief disruption
          Use for: when recommendations are known to be accurate

Auto:     Same as Recreate (also applies to running pods)
          Currently same behavior as Recreate
          Future: may support in-place updates (no restart)
```

### VPA Configuration

```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: judicial-api-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  updatePolicy:
    updateMode: "Off"         # Start with Off — just get recommendations first
  resourcePolicy:
    containerPolicies:
    - containerName: api      # must match container name in Deployment
      controlledResources:
      - cpu
      - memory
      minAllowed:
        cpu: 100m             # VPA won't go below this
        memory: 128Mi
      maxAllowed:
        cpu: 4                # VPA won't go above this
        memory: 8Gi
      controlledValues: RequestsAndLimits  # adjust both requests AND limits
```

```bash
# Install VPA (requires separate installation)
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh

# Check VPA recommendations
kubectl describe vpa judicial-api-vpa -n production
# Output shows:
# Recommendation:
#   Container Recommendations:
#     Container Name:  api
#     Lower Bound:
#       Cpu:     100m
#       Memory:  128Mi
#     Target:
#       Cpu:     350m         ← VPA recommends 350m (you set 200m — too low)
#       Memory:  400Mi        ← VPA recommends 400Mi (you set 256Mi — too low)
#     Upper Bound:
#       Cpu:     1500m
#       Memory:  2Gi

# Apply recommendations manually (update Deployment)
# OR switch VPA updateMode to "Auto" to apply automatically
```

### HPA + VPA — Conflict and Best Practice

```
PROBLEM: Running HPA and VPA on same Deployment:
  HPA sees CPU at 70% → wants to scale to 6 pods
  VPA sees CPU request too low → wants to increase CPU to 500m
  Both act simultaneously → unpredictable behavior → thrashing

RULE: Never run HPA and VPA on the same resource metric

Safe combinations:
  ✓ HPA on CPU/memory + VPA in "Off" mode (recommendations only)
  ✓ HPA on CPU + VPA on memory (different metrics — experimental)
  ✓ HPA on custom metric (req/sec) + VPA on CPU/memory
  ✗ HPA on CPU + VPA Auto on CPU = CONFLICT — don't do this

Best practice workflow:
  Step 1: Run VPA in "Off" mode for 1-2 weeks
  Step 2: Review recommendations (kubectl describe vpa)
  Step 3: Apply recommendations manually to Deployment
  Step 4: Switch to HPA for scaling
  Step 5: Keep VPA in "Off" mode for ongoing recommendations

VPA is most useful for:
  Databases (StatefulSet — can't scale horizontally easily)
  Batch jobs (run once, right-size for efficiency)
  Memory-intensive apps (Java heaps, ML models)
  Right-sizing before moving to HPA
```

-----

## PART 5 — STATEFUL VS STATELESS

### Stateless Applications

```
Definition: Each request is independent
            Server doesn't remember anything about previous requests
            Any pod can handle any request

Characteristics:
  No data stored in pod memory across requests
  Sessions stored externally (Redis, database)
  Any pod restarts without data loss
  Easy to scale horizontally (just add more pods)
  Easy to update (rolling update, blue-green)

Examples:
  REST APIs (FastAPI, Express, Flask, Spring Boot)
  Web servers (Nginx serving static files)
  Microservices (stateless business logic)
  Worker processes (reading from queue, processing, done)

Use: Deployment
  Pods are interchangeable — any pod = any other pod
  Random pod names: api-7d9f8c-abc12
  
  spec:
    replicas: 3  # 3 identical, replaceable pods
    strategy:
      type: RollingUpdate
```

### Stateful Applications

```
Definition: Maintains state across requests
            Each pod has a unique identity
            Data must persist even if pod restarts

Characteristics:
  Data stored in pod (memory) or attached storage (PVC)
  Pod identity matters — pod-0 is different from pod-1
  Ordered startup/shutdown (pod-0 before pod-1)
  Stable network identity (DNS hostname per pod)
  Each pod gets its own PVC (data not shared)

Examples:
  Databases: PostgreSQL, MySQL, MongoDB, Cassandra
  Distributed systems: Kafka, Zookeeper, Elasticsearch
  Caches with persistence: Redis (with AOF/RDB)
  Message queues: RabbitMQ

Use: StatefulSet
  Pods have stable names: db-0, db-1, db-2
  Stable DNS: db-0.db-service.namespace.svc.cluster.local
  Each pod has own PVC: data-db-0, data-db-1, data-db-2
  Ordered: db-0 starts before db-1 before db-2
```

### Side-by-Side Comparison

```
Feature              Stateless (Deployment)     Stateful (StatefulSet)
─────────────────────────────────────────────────────────────────────
Pod names            Random (api-xyz-abc)       Stable (db-0, db-1)
Pod DNS              Unstable (changes)          Stable (db-0.svc...)
Storage              Shared or none             Each pod gets own PVC
Scaling              Any order                  Ordered (0 → 1 → 2)
Deletion             Any order                  Reverse order (2 → 1 → 0)
Rolling update       Random                     Ordered (highest first)
Use case             APIs, web servers           Databases, queues
Restart              Random pod replaced        Same pod name, same PVC
Examples             judicial-api, frontend      PostgreSQL, Kafka

Question to ask yourself:
  "If I restart this pod, does it matter which pod gets which request?"
  YES → Stateless → Deployment
  NO  → Stateful → StatefulSet
  
  "Does each pod need its own persistent data?"
  YES → StatefulSet with volumeClaimTemplates
  NO  → Deployment with shared volume or no volume
```

### Real Example: Redis

```yaml
# Redis can be EITHER depending on use:

# Stateless (cache only — data loss OK):
apiVersion: apps/v1
kind: Deployment    # ← OK if cache miss = just slower response
metadata:
  name: redis-cache
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command: ["redis-server", "--maxmemory-policy", "allkeys-lru"]
        # No PVC — data lost on restart = cache miss = just re-fetch from DB

# Stateful (persistent session store — data loss = user logout):
apiVersion: apps/v1
kind: StatefulSet   # ← required if data must survive pod restart
metadata:
  name: redis-sessions
spec:
  serviceName: redis-sessions
  replicas: 1
  template:
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command: ["redis-server", "--appendonly", "yes"]  # persistence on
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
```

-----

## PART 6 — NETWORKING AND SERVICES DEEP DIVE

### Service → Pod Routing Mechanism

```
How does a Service route to pods?

1. You create a Service with a selector:
   selector:
     app: judicial-api

2. Endpoints controller watches for pods matching the selector
   Healthy pods → added to Endpoints object
   Unhealthy/missing pods → removed from Endpoints

3. kube-proxy on each node watches Endpoints
   Sets up iptables/IPVS rules:
   "Traffic to ClusterIP:port → load balance to pod IPs in Endpoints"

4. Pod calls: http://judicial-api:8080
   CoreDNS resolves: judicial-api → 10.96.45.100 (ClusterIP)
   iptables on the node translates: 10.96.45.100:8080 → 10.244.0.5:8080 (pod IP)

kubectl get endpoints — shows current pod IPs behind each service:
  kubectl get endpoints judicial-api -n production
  # NAME           ENDPOINTS                          AGE
  # judicial-api   10.244.0.5:8080,10.244.1.8:8080   5m

  If ENDPOINTS shows <none>:
    → Service selector doesn't match any pod labels
    → All pods are unhealthy (readiness probe failing)
    → Pods don't exist yet
```

### Service Types — When to Use Each

```
ClusterIP (default):
  Internal only — pods talk to each other
  Suitable for: ALL inter-service communication inside cluster
  Never expose: databases, internal APIs
  
  judicial-frontend → judicial-api (ClusterIP) → judicial-db (ClusterIP)

NodePort:
  Exposes service on a port on EVERY node (30000-32767)
  Access: <any-node-ip>:<nodeport>
  Suitable for: development, testing, when no cloud LB available
  Avoid in production: awkward ports, need to know node IP

LoadBalancer:
  Creates cloud load balancer (ALB, NLB on AWS)
  Gets external IP automatically
  Suitable for: services that need their own external IP
  Avoid at scale: one LB per service = expensive
               Use Ingress instead (one LB for all services)

ExternalName:
  Maps service name to external DNS
  judicial-db-external → legacy-db.company.com
  Useful: migrating from external to in-cluster DB
          Change ExternalName → internal service name
          No app code change needed

Headless (clusterIP: None):
  Returns individual pod IPs (no load balancing)
  Required for StatefulSets (need to reach specific pod)
  DB primary-replica: can connect to db-0 specifically
  
  DNS for headless:
    Service DNS → returns all pod IPs (no single ClusterIP)
    Pod DNS: pod-0.service.namespace.svc.cluster.local → pod-0's IP
```

### Ingress vs LoadBalancer Service

```
Problem with LoadBalancer per service:
  10 microservices = 10 LoadBalancers = 10 cloud LBs = expensive (~$20/month each)
  No path routing within same domain
  No SSL management

Solution: Ingress (one LB for everything)
  1 Ingress Controller (Nginx) = 1 cloud LB
  Routes to many services by path/hostname
  SSL termination at Ingress level (cert-manager auto-renews)
  
  One LB → Ingress → /api → API Service
                   → /web → Web Service
                   → /admin → Admin Service
  
Ingress Controller options:
  nginx:    most popular, feature-rich
  traefik:  dynamic config, dashboard
  aws-alb:  native AWS ALB (uses ALB annotations)
  haproxy:  high performance
  
Your setup (from Minikube project):
  minikube addons enable ingress  → installs nginx ingress controller
  3 services, 1 Ingress → path-based routing to each service
```

-----

## PART 7 — CLUSTER SCALING — FULL PICTURE

### Three Levels of Autoscaling

```
Level 1: HPA — scales PODS
  When: individual pods getting overloaded (high CPU/memory/custom metric)
  How: Deployment spec.replicas updated (e.g., 3 → 9 pods)
  Speed: seconds to minutes
  Cost: more pods on same nodes (uses existing capacity)

Level 2: VPA — tunes pod RESOURCES
  When: pods are over/under-resourced (wasting CPU or getting OOMKilled)
  How: container requests/limits updated (e.g., 200m → 500m CPU)
  Speed: pod restart required (minutes)
  Cost: more CPU/memory per pod on same nodes

Level 3: Cluster Autoscaler — scales NODES
  When: pods can't be scheduled (Pending) because nodes are full
  How: calls cloud API to add EC2 instances to node group
  Speed: 1-5 minutes (new node provision time)
  Cost: new nodes = more AWS bill

Full auto-scaling story:
  Traffic increases
      ↓
  HPA: 3 pods → 9 pods (scale out horizontally)
      ↓
  All existing nodes are now full
  New pods stuck in Pending state
      ↓
  Cluster Autoscaler: detects Pending pods
  Calls AWS: add 2 more nodes to EKS node group
      ↓
  New nodes join cluster (1-2 minutes)
      ↓
  Scheduler places Pending pods on new nodes
      ↓
  9 pods running, traffic handled
      ↓
  Traffic decreases
      ↓
  HPA: 9 pods → 3 pods (scale in)
      ↓
  Nodes underutilized for 10 minutes
      ↓
  Cluster Autoscaler: drain and terminate spare nodes
```

### Cluster Autoscaler Configuration

```yaml
# cluster-autoscaler deployment (EKS)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: cluster-autoscaler
        image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.29.0
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste        # prefer nodes that waste least
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/judicial-cluster
        - --balance-similar-node-groups  # keep node groups balanced
        - --scale-down-enabled=true
        - --scale-down-unneeded-time=10m  # node idle for 10m before removal
        - --scale-down-utilization-threshold=0.5  # below 50% = idle
```

```bash
# Check Cluster Autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=50

# Check for unschedulable pods (CA trigger)
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Check node group status
kubectl get nodes
# New nodes appear here when CA scales up

# Check CA events
kubectl describe configmap cluster-autoscaler-status -n kube-system
```

### PodDisruptionBudget — Protect During Scaling

```yaml
# Ensure minimum pods always running during:
# - Node drain (CA scaling down)
# - Rolling updates
# - Manual maintenance

apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: judicial-api-pdb
  namespace: production
spec:
  minAvailable: 2          # always keep at least 2 pods running
  # OR: maxUnavailable: 1  # allow at most 1 pod to be down
  selector:
    matchLabels:
      app: judicial-api

# Effect:
# Cluster Autoscaler draining node → won't evict pod if it would violate PDB
# Rolling update → won't take down more than 1 pod if only 3 are running
```

-----

## PART 8 — COMMON PRODUCTION ISSUES

### Issue 1: HPA Not Scaling

```
Symptom: kubectl get hpa shows <unknown>/70% or stuck at same replicas

Cause A: No metrics-server
  Diagnosis: kubectl top pods → "error: Metrics API not available"
  Fix: kubectl apply -f metrics-server.yaml

Cause B: Missing resources.requests on container
  Diagnosis: kubectl describe hpa → "missing request for cpu"
  Fix: add resources.requests to container:
    resources:
      requests:
        cpu: "200m"      # REQUIRED — HPA calculates % of this
        memory: "256Mi"

Cause C: Wrong scaleTargetRef
  Diagnosis: kubectl describe hpa → "deployments.apps not found"
  Fix: check name matches exactly:
    scaleTargetRef:
      apiVersion: apps/v1
      kind: Deployment
      name: judicial-api   # must match deployment name exactly

Cause D: Custom metrics not available
  Diagnosis: kubectl describe hpa → "no metrics returned from custom metrics API"
  Fix: install Prometheus Adapter + verify metric name is correct
```

### Issue 2: CrashLoopBackOff

```
Symptom: Pod STATUS = CrashLoopBackOff, restart count keeps increasing

What it means:
  Container keeps crashing → K8s keeps restarting → exponential delay
  1s → 2s → 4s → 8s → up to 5 minutes between restarts

Diagnosis steps:
  # Step 1: Get logs from PREVIOUS (crashed) container
  kubectl logs my-pod --previous
  # Most important command — shows what the app printed before dying

  # Step 2: Check exit code
  kubectl describe pod my-pod | grep -A5 "Last State"
  # Exit Code 0   = app exited normally (not a long-running process?)
  # Exit Code 1   = app crashed (check logs for error)
  # Exit Code 137 = OOMKilled (memory limit too low)
  # Exit Code 139 = Segfault
  # Exit Code 143 = SIGTERM not handled

  # Step 3: Check events
  kubectl describe pod my-pod | tail -30

Common causes and fixes:
  App crashes on startup → check logs for error, fix the bug
  Missing env var:  Error: DB_HOST not set
    Fix: add env var to Deployment or reference ConfigMap/Secret
  OOMKilled (exit 137): app using more memory than limit
    Fix: kubectl set resources deployment/api --limits=memory=1Gi
  Config file missing: cannot open /app/config.yaml
    Fix: mount ConfigMap as volume
  DB connection refused at startup:
    Fix: add initContainer to wait for DB
    Or: add retry logic in application
  Wrong CMD/ENTRYPOINT: command not found
    Fix: kubectl exec to inspect image: docker run --rm -it myimage:latest /bin/sh
```

### Issue 3: ImagePullBackOff

```
Symptom: Pod STATUS = ImagePullBackOff or ErrImagePull

What it means: Kubernetes can't pull the container image

Diagnosis:
  kubectl describe pod my-pod | grep -A5 "Events"
  # "Failed to pull image: rpc error: code = Unknown..."
  # "401 Unauthorized" → auth issue
  # "manifest unknown" → image/tag doesn't exist

Cause A: Wrong image name or tag
  Fix: verify image exists: aws ecr describe-images --repository-name judicial-api
  Fix: check tag in deployment: kubectl get deployment api -o yaml | grep image

Cause B: Private registry — missing credentials
  Fix: create image pull secret:
  kubectl create secret docker-registry regcred \
    --docker-server=ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password)

  # Reference in pod spec:
  spec:
    imagePullSecrets:
    - name: regcred

Cause C: On EKS — node IAM role missing ECR permissions
  Fix: add AmazonEC2ContainerRegistryReadOnly to node group IAM role

Cause D: Wrong platform (arm64 image on amd64 nodes)
  Fix: build multi-platform image or use correct architecture
```

### Issue 4: Pending PVCs

```
Symptom: PVC STATUS = Pending, pod stays in ContainerCreating

Diagnosis:
  kubectl describe pvc my-pvc
  # Events: "no persistent volumes available for this claim..."

Cause A: StorageClass doesn't exist
  kubectl get storageclass
  Fix: create StorageClass or use correct name in PVC

Cause B: No PersistentVolumes available (static provisioning)
  Fix: use dynamic provisioning (StorageClass with provisioner)
  OR: manually create PV that matches PVC claims

Cause C: PVC requests more storage than available PV
  PVC requests 100Gi but PV is only 50Gi
  Fix: adjust PVC request size

Cause D: AccessMode mismatch
  PV has ReadWriteOnce but PVC requests ReadWriteMany
  Fix: match access modes, or use EFS (supports RWX)

Cause E: Wrong namespace
  PV is cluster-scoped but PVC is namespace-scoped
  Fix: ensure PVC is in correct namespace

After fixing:
  kubectl get pvc   # should show Bound
  kubectl get pods  # pod should move from ContainerCreating → Running
```

### Issue 5: Service Selector/Port Mismatch

```
Symptom: Service exists but no traffic reaching pods
         curl http://my-service → connection refused or 503

Diagnosis:
  # Check if ANY endpoints are registered
  kubectl get endpoints my-service
  # "NAME       ENDPOINTS   AGE"
  # "my-svc     <none>      5m"  ← PROBLEM: no pods selected

Step 1: Compare service selector vs pod labels
  kubectl describe service my-svc | grep Selector
  # Selector: app=judicial-api

  kubectl get pods --show-labels | grep judicial
  # my-pod   Running   app=judicial_api  ← underscore vs hyphen! MISMATCH

  Fix: match exactly:
  service selector:  app: judicial-api
  pod labels:        app: judicial-api   (same!)

Step 2: Check port mismatch
  kubectl describe service my-svc | grep Port
  # Port: 80/TCP, TargetPort: 8080/TCP

  kubectl describe pod my-pod | grep Port
  # Port: 3000/TCP  ← pod listens on 3000, service targets 8080!

  Fix: targetPort in Service must match containerPort in Pod

Step 3: Check pod is Ready (readiness probe)
  kubectl get pods
  # READY 0/1 → readiness probe failing → pod not added to endpoints

  Fix: fix readiness probe or fix what the probe is checking
```

### Issue 6: Faulty Readiness/Liveness Probes

```
Symptoms:
  Readiness probe failing: pod Running but READY = 0/1
                           No traffic sent to pod
                           Service shows 0 endpoints
  
  Liveness probe failing:  pod keeps restarting
                           kubectl describe shows: "Liveness probe failed"

Common mistakes:

Mistake 1: Wrong path
  livenessProbe:
    httpGet:
      path: /healthz     # app exposes /health not /healthz
  Fix: match exactly what your app exposes

Mistake 2: initialDelaySeconds too short
  app takes 60s to start, probe checks after 5s → fails → restart loop
  Fix: increase initialDelaySeconds or use startupProbe:
    startupProbe:
      httpGet:
        path: /health
        port: 8080
      failureThreshold: 30    # 30 × 10s = 5 minutes for startup
      periodSeconds: 10

Mistake 3: App binding to wrong interface
  App listens on 127.0.0.1:8080 → probe (from kubelet) can't reach it
  Fix: app must listen on 0.0.0.0:8080

Mistake 4: Liveness probe too strict on startup
  Java app: slow startup, liveness kills it before it's ready
  Fix: separate startupProbe from livenessProbe:
    startupProbe:   failureThreshold=30 (5 min grace)
    livenessProbe:  failureThreshold=3 (strict once started)

Debugging:
  kubectl describe pod my-pod | grep -A10 "Liveness\|Readiness"
  kubectl events --field-selector involvedObject.name=my-pod
```

### Issue 7: NetworkPolicy / RBAC Blocking Traffic

```
NetworkPolicy blocking:
  Symptom: pod can't reach service even though service exists
           curl from pod-a to service-b → timeout (not refused)
           
  Diagnosis:
    kubectl get networkpolicy -A          # list all policies
    kubectl describe networkpolicy deny-all -n production
    
  Fix: add explicit allow rule:
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-api-to-db
      namespace: production
    spec:
      podSelector:
        matchLabels:
          app: judicial-db    # applies to DB pods
      ingress:
      - from:
        - podSelector:
            matchLabels:
              app: judicial-api   # only API pods allowed
        ports:
        - port: 5432

RBAC blocking (pods can't call K8s API):
  Symptom: pod logs show "forbidden: User cannot list pods"
           
  Diagnosis:
    kubectl auth can-i list pods \
      --as system:serviceaccount:production:judicial-api-sa
    # no → missing permission

  Fix: create Role and RoleBinding:
    kind: Role
    rules:
    - apiGroups: [""]
      resources: ["pods", "configmaps"]
      verbs: ["get", "list", "watch"]
    ---
    kind: RoleBinding
    subjects:
    - kind: ServiceAccount
      name: judicial-api-sa
    roleRef:
      kind: Role
      name: pod-reader
```

-----

## INTERVIEW QUESTIONS

**Q: How do pods in a Kubernetes cluster discover and communicate with each other?**

```
Pods use Services + DNS for stable communication:

1. Services provide a stable virtual IP (ClusterIP) and DNS name
   Service DNS: service-name.namespace.svc.cluster.local

2. CoreDNS resolves the service name to ClusterIP

3. kube-proxy routes ClusterIP → healthy pod IPs via iptables/IPVS

4. Readiness probes ensure only healthy pods receive traffic
   Pods failing readiness → removed from service endpoints

Example in a 3-tier app:
  Frontend calls:  http://judicial-api:8080    (same namespace)
  API calls:       postgres://judicial-db:5432
  All DNS resolves via CoreDNS to stable ClusterIP
  Pod restarts, IP changes — Service endpoint updated automatically
  Application code never needs to change
```

**Q: When would you use a StatefulSet vs a Deployment?**

```
Use Deployment (stateless) when:
  Any request can go to any pod
  Pod identity doesn't matter
  No per-pod persistent storage
  Examples: REST API, web server, worker processes

Use StatefulSet (stateful) when:
  Pod identity matters (pod-0 is different from pod-1)
  Each pod needs its own persistent storage (own PVC)
  Ordered startup/shutdown required
  Stable DNS per pod needed (db-0.svc.cluster.local)
  Examples: PostgreSQL, Kafka, Elasticsearch, Redis with persistence

The key question:
  "If this pod restarts and comes back with a different IP,
   does it need access to the same data it had before?"
  YES → StatefulSet   NO → Deployment
```

**Q: HPA shows <unknown>/70% — why and how do you fix it?**

```
Root cause: HPA can't calculate CPU percentage

Most common reason:
  resources.requests NOT set on the container
  HPA calculates: (actual CPU / requested CPU) × 100
  No requests = no denominator = <unknown>

Fix:
  Add to container spec:
  resources:
    requests:
      cpu: "200m"    ← REQUIRED for HPA CPU scaling

Secondary reasons:
  metrics-server not installed → kubectl top pods fails
  Fix: install metrics-server
  
  scaleTargetRef wrong name → HPA can't find deployment
  Fix: verify deployment name matches exactly

After fix:
  kubectl describe hpa → should show "ScalingActive: True"
  kubectl get hpa → should show "45%/70%" not "<unknown>"
```

**Q: Walk me through the complete auto-scaling story in Kubernetes.**

```
Three levels working together:

1. HPA (pod level):
   Metrics Server detects CPU rising → HPA adds pods
   3 pods → 9 pods in 2-3 minutes

2. Cluster Autoscaler (node level):
   9 pods can't fit on existing 3 nodes → pods stuck Pending
   CA detects Pending pods → calls AWS to add node
   New node joins → pods scheduled → all running

3. Scale-down:
   Traffic drops → HPA reduces pods → 9 → 3
   Nodes become underutilized
   CA waits 10 minutes → drains node → terminates it

PodDisruptionBudget prevents:
   CA from evicting too many pods during scale-down
   Always keeps minAvailable pods running

This is the complete picture — HPA + CA work together automatically
```

-----

## QUICK REFERENCE

### HPA Troubleshooting Checklist

```
□ metrics-server running? kubectl get pods -n kube-system | grep metrics
□ kubectl top pods works? (if no, metrics-server issue)
□ resources.requests set? kubectl get deployment -o yaml | grep requests
□ scaleTargetRef name matches deployment name?
□ HPA describe shows any error events?
□ Pods at maxReplicas? (can't scale further)
```

### Service Not Working Checklist

```
□ kubectl get endpoints my-svc → should show pod IPs, not <none>
□ Service selector matches pod labels exactly? (case-sensitive, hyphen vs underscore)
□ targetPort matches containerPort in pod?
□ Pod is Ready (not just Running)? kubectl get pods → READY 1/1?
□ NetworkPolicy allowing traffic?
□ App listening on 0.0.0.0 (not 127.0.0.1)?
```

### StatefulSet vs Deployment Quick Reference

```
                    Deployment          StatefulSet
Pod names:          api-xyz-abc         db-0, db-1
Pod DNS:            unstable            stable (db-0.svc...)
Storage:            shared/none         own PVC per pod
Scale order:        any                 0 → 1 → 2 (up)
Delete order:       any                 2 → 1 → 0 (down)
Use for:            APIs, web servers    DBs, Kafka, Elasticsearch
```

### Common Exit Codes

```
0   → Normal exit (check: should it be long-running?)
1   → General error (check logs --previous)
137 → OOMKilled (increase memory limit)
139 → Segmentation fault (app bug)
143 → SIGTERM not handled (fix graceful shutdown)
```

-----

## PART 9 — POD SCHEDULING (TAINTS, TOLERATIONS, AFFINITY)

### Why Pod Scheduling Matters

```
Default scheduler: places pods on any node with enough resources
Problem: you often need more control:
  - Run GPU workloads ONLY on GPU nodes
  - Spread pods across AZs (avoid single AZ failure)
  - Keep frontend and backend pods close (low latency)
  - Prevent dev pods from sharing nodes with prod
  - Reserve nodes exclusively for critical workloads

Tools:
  nodeSelector:       simple label matching (hard requirement)
  nodeAffinity:       flexible label matching (hard or soft)
  podAffinity:        schedule near other pods
  podAntiAffinity:    spread away from other pods
  taints:             repel pods from nodes
  tolerations:        allow pods onto tainted nodes
```

### nodeSelector (Simple)

```yaml
# Label a node first
# kubectl label nodes node-1 hardware=gpu

spec:
  nodeSelector:
    hardware: gpu           # pod ONLY goes to nodes with this label
  containers:
  - name: ml-job
    image: tensorflow:latest

# Hard requirement — if no matching node exists, pod stays Pending
# Use for: simple, stable requirements
```

### Node Affinity (Flexible)

```yaml
spec:
  affinity:
    nodeAffinity:

      # HARD requirement — must match (like nodeSelector but richer syntax)
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values:
            - ap-south-1a
            - ap-south-1b            # must be in these AZs

      # SOFT preference — try to match, but schedule anywhere if not possible
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80                   # higher weight = stronger preference
        preference:
          matchExpressions:
          - key: node.kubernetes.io/instance-type
            operator: In
            values:
            - m5.large               # prefer m5.large but not mandatory

      # Operators: In, NotIn, Exists, DoesNotExist, Gt, Lt
```

### Pod Affinity and Anti-Affinity

```yaml
spec:
  affinity:

    # Schedule THIS pod NEAR other pods with matching labels
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - cache                  # schedule near Redis cache pods
        topologyKey: kubernetes.io/hostname  # "near" = same node
      # Use case: app + Redis on same node → low-latency cache access

    # Schedule THIS pod AWAY from other pods (spread out)
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - judicial-api           # don't co-locate API pods
        topologyKey: kubernetes.io/hostname  # each pod on different node
      # Use case: HA — if one node dies, not all API pods are lost

      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: judicial-api
          topologyKey: topology.kubernetes.io/zone  # spread across AZs
      # Use case: prefer pods in different AZs (soft — not hard block)
```

### Taints and Tolerations

```
Taints: applied to NODES — repel pods
Tolerations: applied to PODS — allow onto tainted nodes

Taint effects:
  NoSchedule:        new pods without toleration won't be scheduled
  PreferNoSchedule:  soft version — try to avoid
  NoExecute:         new pods can't schedule AND existing pods evicted

Real use cases:
  GPU node:     taint with gpu=true:NoSchedule
                Only GPU workloads (with toleration) go there
                Regular pods don't accidentally consume GPU nodes

  Spot instance: taint with spot=true:NoSchedule
                Only fault-tolerant batch jobs go on spot
                Production APIs stay on on-demand

  Dedicated:     taint with dedicated=monitoring:NoSchedule
                Only monitoring stack runs on these nodes
                Rest of workloads go elsewhere
```

```bash
# Add taint to node
kubectl taint nodes node-1 gpu=true:NoSchedule
kubectl taint nodes node-1 spot=true:PreferNoSchedule

# Remove taint (note the - at end)
kubectl taint nodes node-1 gpu=true:NoSchedule-

# Check taints on nodes
kubectl describe nodes | grep Taint
```

```yaml
# Pod tolerates the taint
spec:
  tolerations:
  - key: gpu
    operator: Equal
    value: "true"
    effect: NoSchedule        # must match the taint exactly

  - key: spot
    operator: Exists          # tolerate any value for this key
    effect: NoSchedule

  # Still need nodeSelector/affinity to ACTIVELY choose the GPU node
  # Toleration = permission to go there
  # Affinity/nodeSelector = actually go there
  nodeSelector:
    hardware: gpu
```

### Topology Spread Constraints (Production HA)

```yaml
# Ensure pods spread evenly across zones AND nodes
spec:
  topologySpreadConstraints:

  # Spread across availability zones
  - maxSkew: 1                           # max difference between zones
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule     # hard: don't schedule if can't spread
    labelSelector:
      matchLabels:
        app: judicial-api

  # Also spread across individual nodes within zones
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway    # soft: try to spread but not mandatory
    labelSelector:
      matchLabels:
        app: judicial-api

# Result: 6 pods spread across 3 AZs → 2 pods per AZ
# If one AZ fails: 4/6 pods still running (66% capacity)
# Without this: all 6 pods might be in one AZ → AZ failure = total outage
```

-----

## PART 10 — RESOURCE MANAGEMENT AND QOS CLASSES

### Requests vs Limits — The Difference

```
requests:
  What Kubernetes GUARANTEES to the container
  Used by scheduler to find a node with enough capacity
  Pod only scheduled on node if node has >= requested resources free
  Container ALWAYS gets at least this much

limits:
  Maximum a container can use
  CPU:    throttled if exceeded (not killed)
  Memory: killed (OOMKilled exit code 137) if exceeded

Example:
  requests.cpu: 200m    → scheduler reserves 200m on the node
  limits.cpu:   500m    → container can burst up to 500m, throttled above
  
  requests.memory: 256Mi → scheduler reserves 256Mi
  limits.memory:   512Mi → OOMKilled if container uses > 512Mi
```

### QoS Classes (Who Gets Evicted First)

```
Kubernetes assigns QoS class based on requests/limits:

1. BestEffort (evicted FIRST):
   No requests or limits set at all
   Gets whatever is leftover on the node
   First evicted when node is under pressure
   
   containers:
   - name: app
     image: myapp  # no resources block

2. Burstable (evicted SECOND):
   Has some requests OR requests < limits
   Gets guaranteed minimum, can burst
   
   resources:
     requests:
       memory: 128Mi
       cpu: 100m
     limits:
       memory: 512Mi
       cpu: 500m

3. Guaranteed (evicted LAST):
   requests == limits for ALL resources
   Gets exactly what it requests — no more, no less
   Most stable, never evicted for resource pressure
   More expensive (can't burst above requests)
   
   resources:
     requests:
       memory: 256Mi    # same value
       cpu: 200m
     limits:
       memory: 256Mi    # same value
       cpu: 200m

Production guidance:
  Critical services (API, DB): Guaranteed QoS
  Background jobs: Burstable
  Dev/test: BestEffort
  
  Never run production without resource limits → BestEffort = risky
```

### LimitRange — Default Limits for Namespace

```yaml
# Automatically apply default limits to all pods in namespace
# Protects against: pods with no limits consuming all node resources
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:              # applied if no limits specified
      memory: 256Mi
      cpu: 200m
    defaultRequest:       # applied if no requests specified
      memory: 128Mi
      cpu: 100m
    max:                  # no container can exceed these
      memory: 4Gi
      cpu: 4
    min:                  # no container can go below these
      memory: 64Mi
      cpu: 50m
  
  - type: Pod
    max:
      memory: 8Gi         # total for all containers in pod
      cpu: 8

  - type: PersistentVolumeClaim
    max:
      storage: 100Gi      # no PVC can claim more than 100Gi
    min:
      storage: 1Gi
```

### ResourceQuota — Namespace Budget

```yaml
# Cap total resources a namespace can consume
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # Compute budget
    requests.cpu: "20"           # total CPU requests in namespace
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi

    # Object count limits
    pods: "100"                  # max 100 pods
    services: "20"
    persistentvolumeclaims: "30"
    secrets: "100"
    configmaps: "100"

    # Service type restrictions
    services.loadbalancers: "5"
    services.nodeports: "0"      # ban NodePort in production

    # Storage
    requests.storage: "500Gi"   # total PVC storage budget
```

-----

## PART 11 — MULTI-CONTAINER POD PATTERNS

### Why Multiple Containers in One Pod?

```
Containers in same pod share:
  Network namespace (same IP, same ports)
  Storage volumes (can share files)
  Lifecycle (start/stop together)

Use when: containers are tightly coupled and must be deployed together
Don't use when: containers have independent scaling needs

4 patterns:
  1. Sidecar:      helper container enhancing main container
  2. Init:         setup before main container starts
  3. Ambassador:   proxy for external communication
  4. Adapter:      transform main container's output
```

### Pattern 1: Sidecar

```yaml
# Sidecar: adds functionality to main container
# Example: log shipper running alongside app

spec:
  volumes:
  - name: shared-logs
    emptyDir: {}              # shared between containers

  containers:
  # Main container: your app
  - name: judicial-api
    image: judicial-api:1.2.3
    volumeMounts:
    - name: shared-logs
      mountPath: /app/logs    # writes logs here

  # Sidecar: ships logs to centralized logging
  - name: log-shipper
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/app  # reads logs written by main container
      readOnly: true
    env:
    - name: ELASTICSEARCH_HOST
      value: "elasticsearch.monitoring.svc.cluster.local"

# Other sidecar examples:
# - Envoy proxy (service mesh) — handles mTLS, retries, circuit breaking
# - Config reloader — watches for config changes, signals main app
# - Metrics collector — exposes app metrics to Prometheus
```

### Pattern 2: Init Container

```yaml
# Init containers: run BEFORE main containers start
# Must complete successfully before main container starts
# If init fails: pod restarts until init succeeds

spec:
  initContainers:

  # Init 1: Wait for database to be ready
  - name: wait-for-db
    image: busybox:1.35
    command:
    - /bin/sh
    - -c
    - |
      until nc -z judicial-db.production.svc.cluster.local 5432; do
        echo "Waiting for database..."
        sleep 2
      done
      echo "Database is ready!"

  # Init 2: Run database migrations
  - name: run-migrations
    image: judicial-api:1.2.3
    command: ["python", "manage.py", "migrate"]
    env:
    - name: DB_HOST
      value: judicial-db

  # Main container: only starts after BOTH inits complete
  containers:
  - name: judicial-api
    image: judicial-api:1.2.3
    ports:
    - containerPort: 8080

# Use cases for init containers:
# - Wait for dependencies (DB, cache, API) before starting
# - Run database migrations
# - Clone git repo or download config
# - Set up permissions on volumes
# - Register service in service registry
```

### Pattern 3: Ambassador

```yaml
# Ambassador: proxy that simplifies external access
# Main container always talks to localhost
# Ambassador handles the complex routing

spec:
  containers:
  # Main container: connects to localhost:5432 (simple)
  - name: judicial-api
    image: judicial-api:1.2.3
    env:
    - name: DB_HOST
      value: localhost         # always connects to localhost

  # Ambassador: handles real DB connection complexity
  - name: db-proxy
    image: haproxy:latest
    # Proxies localhost:5432 → actual DB cluster with failover
    # Handles: connection pooling, SSL, failover, retry
    volumeMounts:
    - name: haproxy-config
      mountPath: /usr/local/etc/haproxy

# Use case: main app is simple, proxy handles:
# - DB connection pooling
# - SSL termination
# - Multi-datacenter routing
# - Authentication to external service
```

### Pattern 4: Adapter

```yaml
# Adapter: transforms output of main container
# Standardizes format without modifying main container

spec:
  volumes:
  - name: metrics-vol
    emptyDir: {}

  containers:
  # Main container: legacy app that outputs metrics in old format
  - name: legacy-app
    image: old-app:1.0
    volumeMounts:
    - name: metrics-vol
      mountPath: /app/metrics   # writes metrics in legacy format

  # Adapter: converts to Prometheus format
  - name: metrics-adapter
    image: custom-exporter:latest
    volumeMounts:
    - name: metrics-vol
      mountPath: /input
      readOnly: true
    ports:
    - containerPort: 9090      # exposes Prometheus /metrics endpoint

# Prometheus scrapes adapter (port 9090) not the legacy app directly
# Legacy app unchanged — adapter transforms its output
```

-----

## PART 12 — JOBS AND CRONJOBS

### Kubernetes Job

```yaml
# Job: run pod(s) to COMPLETION (not forever like Deployment)
# Pod exits 0 = job done
# Pod fails = retried up to backoffLimit

apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: production
spec:
  completions: 1          # number of successful completions needed
  parallelism: 1          # how many pods run at once
  backoffLimit: 3         # retry up to 3 times on failure
  activeDeadlineSeconds: 300  # fail job if not done in 5 minutes

  template:
    spec:
      restartPolicy: OnFailure  # REQUIRED for Jobs (not Always)
      containers:
      - name: migrate
        image: judicial-api:1.2.3
        command: ["python", "manage.py", "migrate"]
        env:
        - name: DB_HOST
          value: judicial-db

# Parallel job example (batch processing)
spec:
  completions: 100        # need to process 100 items
  parallelism: 10         # run 10 pods at once
  # Total time: roughly sequential_time / 10

# Monitor job
# kubectl get jobs
# kubectl describe job db-migration
# kubectl logs job/db-migration
```

### CronJob

```yaml
# CronJob: run Job on a schedule (like cron)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-report
  namespace: production
spec:
  schedule: "0 2 * * *"         # 2am every day (UTC)
  # schedule: "*/5 * * * *"     # every 5 minutes
  # schedule: "0 9 * * 1-5"     # 9am Mon-Fri
  # Cron format: minute hour day month weekday

  timeZone: "Asia/Kolkata"      # use IST (K8s 1.27+)
  
  concurrencyPolicy: Forbid     # don't run new job if previous still running
  # Allow:   allow concurrent runs
  # Forbid:  skip if previous running
  # Replace: cancel previous, start new

  successfulJobsHistoryLimit: 3  # keep last 3 successful jobs
  failedJobsHistoryLimit: 1      # keep last 1 failed job

  startingDeadlineSeconds: 60   # fail if can't start within 60s of schedule

  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: report-generator
            image: judicial-reports:latest
            command: ["python", "generate_report.py", "--date=$(date +%Y-%m-%d)"]

# kubectl get cronjobs
# kubectl get jobs --watch    # watch triggered jobs
# Manually trigger: kubectl create job --from=cronjob/daily-report manual-run
```

-----

## PART 13 — DAEMONSET

### What is a DaemonSet?

```
DaemonSet: ensures ONE pod runs on EVERY node
  New node added to cluster → DaemonSet pod automatically created on it
  Node removed → pod garbage collected
  
Use for node-level agents that must run everywhere:
  Log collectors:     Fluentd, Filebeat → collect logs from all nodes
  Monitoring agents:  Prometheus node-exporter, Datadog agent
  Network plugins:    Calico, Cilium → must run on every node
  Security agents:    Falco, Wazuh → must monitor every node
  Storage:            Ceph, GlusterFS daemons

NOT for:
  Regular applications (use Deployment)
  Apps needing multiple replicas per node (DaemonSet gives exactly 1)
```

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  updateStrategy:
    type: RollingUpdate          # update one node at a time
    rollingUpdate:
      maxUnavailable: 1

  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      # Run on all nodes including control plane
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule

      hostNetwork: true          # use host network (for network monitoring)
      hostPID: true              # access host PIDs (for process monitoring)

      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
          hostPort: 9100         # accessible on node IP:9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534

      volumes:
      - name: proc
        hostPath:
          path: /proc            # access host /proc filesystem
      - name: sys
        hostPath:
          path: /sys

# kubectl get daemonsets -A    # shows all DaemonSets
# kubectl get pods -o wide | grep node-exporter  # one per node
```

-----

## PART 14 — CONFIGMAPS AND SECRETS IN DEPTH

### ConfigMap — All Usage Patterns

```yaml
# ConfigMap: store non-sensitive configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  # Simple key-value
  db_host: "judicial-db.production.svc.cluster.local"
  db_port: "5432"
  log_level: "info"
  max_connections: "100"

  # Full config file as a key
  nginx.conf: |
    server {
        listen 80;
        location / {
            proxy_pass http://judicial-api:8080;
        }
    }

  # JSON config
  feature_flags.json: |
    {
      "new_ui": true,
      "dark_mode": false,
      "beta_features": ["analytics", "export"]
    }
```

```yaml
# Use ConfigMap — 3 ways:

# Way 1: All keys as env vars
spec:
  containers:
  - name: api
    envFrom:
    - configMapRef:
        name: app-config          # all keys become env vars

# Way 2: Specific key as env var
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db_host

# Way 3: Mount as files in a directory
    volumeMounts:
    - name: config
      mountPath: /app/config      # creates files in this dir
    # /app/config/db_host (contains "judicial-db...")
    # /app/config/nginx.conf (contains nginx config)
    # /app/config/feature_flags.json

  volumes:
  - name: config
    configMap:
      name: app-config

# Mount specific file with specific name
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf         # mount only this key as this file

  volumes:
  - name: nginx-config
    configMap:
      name: app-config
      items:
      - key: nginx.conf           # which key
        path: nginx.conf          # filename in container
```

### Secrets — Secure Configuration

```yaml
# Secret: store sensitive data (base64 encoded, not encrypted by default)
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
stringData:                       # auto base64-encodes
  db_password: "MyStr0ngP@ssw0rd"
  api_key: "sk-1234567890abcdef"
  jwt_secret: "super-secret-jwt-signing-key"

---
# TLS secret (for Ingress)
apiVersion: v1
kind: Secret
metadata:
  name: judicial-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>

---
# Docker registry secret
apiVersion: v1
kind: Secret
metadata:
  name: ecr-credentials
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

```yaml
# Use Secrets — same patterns as ConfigMap:

# Way 1: As env vars (visible in process env — less secure)
spec:
  containers:
  - name: api
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db_password

# Way 2: Mount as files (more secure — not in env)
    volumeMounts:
    - name: secrets
      mountPath: /run/secrets
      readOnly: true
    # File: /run/secrets/db_password

  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
      defaultMode: 0400           # read-only for owner only

# Application reads from file (more secure than env var):
# with open('/run/secrets/db_password') as f:
#     password = f.read().strip()
```

### Secrets Security Deep Dive

```
Default: base64 encoded in etcd (NOT encrypted — just encoded)
  echo "bXlwYXNzd29yZA==" | base64 -d  → mypassword
  Anyone with etcd access can read all secrets

Making Secrets more secure:

Option 1: Encryption at rest (built-in)
  Configure EncryptionConfiguration on API server
  Encrypts with AES-GCM before writing to etcd
  Transparent to pods

Option 2: External Secrets Operator (recommended for AWS)
  Secrets live in AWS Secrets Manager (properly encrypted)
  External Secrets Operator syncs into K8s Secrets
  Auto-rotates when AWS secret rotates
  
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: app-secrets
  spec:
    refreshInterval: 1h
    secretStoreRef:
      name: aws-secrets-manager
      kind: SecretStore
    target:
      name: app-secrets        # creates this K8s Secret
    data:
    - secretKey: db_password
      remoteRef:
        key: judicial/prod/db
        property: password

Option 3: Vault (HashiCorp)
  Vault Agent sidecar injects secrets as files
  Secrets never stored in etcd
  Full audit trail of every secret access
  Dynamic secrets with auto-rotation

RBAC for Secrets:
  Never give developers get/list access to production secrets
  Use dedicated ServiceAccounts with minimal permissions
  kubectl get secret → shows all secrets (restrict this)
```

-----

## PART 15 — RBAC COMPLETE GUIDE

### RBAC Components

```
4 objects:

Role:           permissions within a NAMESPACE
ClusterRole:    permissions cluster-wide (or reused in any namespace)
RoleBinding:    bind Role/ClusterRole to Subject in a NAMESPACE
ClusterRoleBinding: bind ClusterRole to Subject cluster-wide

Subject (who gets permissions):
  User:           human user (authenticated via certificates, OIDC)
  Group:          collection of users
  ServiceAccount: pod identity (most common in DevOps)
```

```yaml
# Role: namespace-scoped permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: production
rules:
# Rule 1: full access to pods and their logs
- apiGroups: [""]                  # "" = core API group
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "delete"]

# Rule 2: read deployments
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]

# Rule 3: read configmaps (not secrets)
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]

# Rule 4: read services
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]

---
# RoleBinding: assign role to user
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: production
subjects:
- kind: User
  name: aditya
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: devops-team              # all users in this group
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```

```yaml
# ClusterRole: permissions available cluster-wide
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]

---
# ServiceAccount + Role for pods
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judicial-api-sa
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/judicial-role  # IRSA

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: judicial-api-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["app-config"]  # only THIS configmap, not all
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["app-secrets"] # only THIS secret

---
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

```bash
# Check permissions
kubectl auth can-i list pods -n production
kubectl auth can-i list pods --as developer-john -n production
kubectl auth can-i list pods --as system:serviceaccount:production:judicial-api-sa

# List all permissions for a service account
kubectl auth can-i --list \
  --as system:serviceaccount:production:judicial-api-sa \
  -n production

# Check who can access secrets (audit)
kubectl get rolebindings,clusterrolebindings -A \
  -o json | jq '.items[] | select(.subjects[]?.name == "developer-john")'
```

### Common RBAC Mistakes

```
Mistake 1: Too broad permissions
  Bad:  verbs: ["*"]  resources: ["*"]  ← admin access to everything
  Good: verbs: ["get", "list"] resources: ["pods", "logs"]

Mistake 2: Not restricting by resourceNames
  Bad:  resources: ["secrets"] verbs: ["get"]
        → can get ANY secret including production DB password
  Good: resources: ["secrets"] verbs: ["get"]
        resourceNames: ["app-secrets"]  ← only specific secret

Mistake 3: ClusterRoleBinding when RoleBinding is enough
  Bad:  ClusterRoleBinding → gives permission in ALL namespaces
  Good: RoleBinding in specific namespace

Mistake 4: Attaching roles directly to users (use groups/SA)
  Easier to manage: add user to group, group has role
  Don't manage permissions per individual user
```

-----

## PART 16 — KUBERNETES SECURITY (POD SECURITY)

### securityContext — Container Security

```yaml
spec:
  # Pod-level security context
  securityContext:
    runAsNonRoot: true          # reject if container runs as root
    runAsUser: 1001             # run as this UID
    runAsGroup: 1001
    fsGroup: 1001               # volume files owned by this group
    seccompProfile:
      type: RuntimeDefault      # restrict syscalls (security hardening)

  containers:
  - name: api
    image: judicial-api:latest
    
    # Container-level security context (overrides pod level)
    securityContext:
      allowPrivilegeEscalation: false  # can't gain more privileges than parent
      readOnlyRootFilesystem: true     # can't write to container filesystem
      capabilities:
        drop:
        - ALL                         # drop all Linux capabilities
        add:
        - NET_BIND_SERVICE            # only add what's needed (bind port <1024)
      runAsNonRoot: true
      runAsUser: 1001

    # If readOnlyRootFilesystem=true, need writable dirs via volumes:
    volumeMounts:
    - name: tmp
      mountPath: /tmp                 # allow writes to /tmp
    - name: cache
      mountPath: /app/.cache

  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

### Pod Security Standards (K8s 1.25+)

```
Replaced PodSecurityPolicy (deprecated in 1.21, removed in 1.25)
Applied at NAMESPACE level via labels

Three policy levels:
  privileged:  no restrictions (for system namespaces)
  baseline:    minimal restrictions (prevents known privilege escalation)
  restricted:  heavily restricted (best practice for production)

Three enforcement modes:
  enforce: reject violating pods
  audit:   allow but log violations
  warn:    allow but warn user

Apply to namespace:
  kubectl label namespace production \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/audit=restricted \
    pod-security.kubernetes.io/warn=restricted

Restricted policy requires:
  No privileged containers
  No privilege escalation (allowPrivilegeEscalation: false)
  Non-root user (runAsNonRoot: true)
  Drop ALL capabilities
  Seccomp profile set
  No hostNetwork, hostPID, hostIPC
```

-----

## PART 17 — HELM BASICS FOR DEVOPS

### What is Helm?

```
Helm = package manager for Kubernetes (like apt/yum for Linux)
Charts = packaged K8s applications (templates + default values)
Release = installed instance of a chart
Repository = collection of charts (like npm registry)

Problems Helm solves:
  50 YAML files for one application → one helm install
  Dev/staging/prod differences → values files
  Version history → helm rollback
  Dependency management → chart dependencies

Helm concepts:
  Chart:     directory with templates + Chart.yaml + values.yaml
  Values:    configuration that gets injected into templates
  Release:   one installation of a chart (can install same chart multiple times)
  Namespace: each release in a namespace
```

```bash
# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add chart repository
helm repo add stable https://charts.helm.sh/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Search for charts
helm search repo nginx
helm search hub prometheus

# Install chart
helm install my-release nginx/nginx-ingress \
  --namespace ingress-nginx \
  --create-namespace \
  --values my-values.yaml

# List releases
helm list -A

# Upgrade release
helm upgrade my-release nginx/nginx-ingress \
  --values my-values.yaml

# Rollback
helm rollback my-release 1  # rollback to revision 1
helm history my-release     # see all revisions

# Uninstall
helm uninstall my-release -n ingress-nginx

# Template rendering (dry run — see generated YAML)
helm template my-release ./my-chart --values values.yaml

# Install with debug
helm install my-release ./my-chart --dry-run --debug
```

### Simple Chart Structure

```
my-app/
├── Chart.yaml           # chart metadata
├── values.yaml          # default values
├── templates/
│   ├── deployment.yaml  # templates using {{ .Values.xxx }}
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── hpa.yaml
│   └── _helpers.tpl     # reusable template snippets
└── charts/              # chart dependencies
```

```yaml
# values.yaml (defaults)
replicaCount: 3
image:
  repository: judicial-api
  tag: "1.2.3"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  host: api.judicialsolutions.in

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-api        # release name prefix
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: api
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

```bash
# Override values for different environments
# Production:
helm install judicial-prod ./judicial-chart \
  --values values-prod.yaml            # prod-specific values
  --set image.tag=1.3.0               # override specific value
  --namespace production

# Staging:
helm install judicial-staging ./judicial-chart \
  --values values-staging.yaml \
  --set replicaCount=1 \
  --namespace staging
```

-----

## PART 18 — KUBERNETES OBSERVABILITY

### Prometheus + Grafana in Kubernetes

```bash
# Install kube-prometheus-stack (Prometheus + Grafana + AlertManager + exporters)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# What gets installed:
# - Prometheus (metrics collection)
# - Grafana (dashboards)
# - AlertManager (alert routing)
# - node-exporter (DaemonSet — host metrics on every node)
# - kube-state-metrics (K8s object metrics)
# - Various pre-built dashboards
```

### Scraping Your Application

```yaml
# Add to your pod/deployment to enable Prometheus scraping
metadata:
  annotations:
    prometheus.io/scrape: "true"   # tell Prometheus to scrape this pod
    prometheus.io/port: "8080"     # port where /metrics is exposed
    prometheus.io/path: "/metrics" # path (default is /metrics)

# OR use ServiceMonitor (recommended with kube-prometheus-stack)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: judicial-api-monitor
  namespace: monitoring
  labels:
    release: monitoring           # must match Prometheus selector label
spec:
  selector:
    matchLabels:
      app: judicial-api          # selects the Service to scrape
  namespaceSelector:
    matchNames:
    - production
  endpoints:
  - port: http                   # port name in the Service
    path: /metrics
    interval: 15s
```

### Key Kubernetes Metrics to Monitor

```
Cluster health:
  kube_node_status_condition{condition="Ready",status="true"}
  kube_node_status_allocatable{resource="cpu"}
  kube_pod_status_phase{phase="Pending"}      ← watch for stuck pods

Deployment health:
  kube_deployment_status_replicas_available
  kube_deployment_status_replicas_unavailable ← should be 0
  kube_deployment_spec_replicas               ← desired count

Pod metrics:
  container_cpu_usage_seconds_total
  container_memory_working_set_bytes
  container_restarts_total                    ← alert if increasing

HPA metrics:
  kube_horizontalpodautoscaler_status_current_replicas
  kube_horizontalpodautoscaler_status_desired_replicas
  kube_horizontalpodautoscaler_spec_max_replicas

PVC metrics:
  kubelet_volume_stats_used_bytes
  kubelet_volume_stats_capacity_bytes
  (used/capacity * 100) → alert if > 85%

Key alerts to configure:
  PodNotReady:          pod not ready for > 5 minutes
  DeploymentReplicas:   available < desired for > 5 minutes
  ContainerOOMKilled:   container killed for memory
  PVCAlmostFull:        volume > 85% used
  NodeNotReady:         node not ready for > 5 minutes
  HPA maxed out:        current replicas = max replicas for > 10 min
```

-----

## PART 19 — DEPLOYMENT STRATEGIES COMPLETE

### 4 Deployment Strategies

```
1. Recreate:
   All old pods deleted → all new pods created
   Downtime: yes (brief gap)
   Use for: DB schema changes that break old version
            Apps that can't run two versions simultaneously
   
   strategy:
     type: Recreate

2. Rolling Update (default):
   Gradual replacement — no downtime
   At all times: mix of old and new pods
   Use for: most stateless applications
   
   strategy:
     type: RollingUpdate
     rollingUpdate:
       maxUnavailable: 1   # max 1 pod down at a time
       maxSurge: 1         # max 1 extra pod during update

3. Blue-Green:
   Run new version alongside old, switch traffic instantly
   Rollback: instant (switch traffic back)
   Use for: zero-risk deployments, instant rollback needed
   
   How: two Deployments (blue v1, green v2)
        Service selector switches between them
        
4. Canary:
   Small % of traffic to new version
   Gradually increase if stable
   Use for: test new version with real traffic (limited risk)
   
   How: two Deployments (stable 9 replicas, canary 1 replica)
        Same Service label → 10% to canary
        Monitor → increase canary replicas → decrease stable
```

### Rolling Update Deep Dive

```yaml
# Detailed rolling update with verification
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1   # at least 5 pods always running (HA)
      maxSurge: 2         # max 8 pods total during update

  # minReadySeconds: how long pod must be ready before it's considered stable
  minReadySeconds: 30     # new pod must be healthy for 30s before moving on
  
  # progressDeadlineSeconds: fail rollout if not done in this time
  progressDeadlineSeconds: 600  # fail if update takes > 10 minutes
```

```bash
# Rolling update
kubectl set image deployment/judicial-api \
  api=judicial-api:1.3.0 \
  --record                        # record change cause in history

# Monitor rollout
kubectl rollout status deployment/judicial-api
# Waiting for deployment "judicial-api" rollout to finish:
# 2 out of 6 new replicas have been updated...
# 4 out of 6 new replicas have been updated...
# 6 out of 6 new replicas have been updated...
# deployment "judicial-api" successfully rolled out

# View history
kubectl rollout history deployment/judicial-api
# REVISION  CHANGE-CAUSE
# 1         kubectl apply --image=judicial-api:1.0.0
# 2         kubectl apply --image=judicial-api:1.1.0
# 3         kubectl set image --image=judicial-api:1.3.0

# Rollback to previous
kubectl rollout undo deployment/judicial-api

# Rollback to specific revision
kubectl rollout undo deployment/judicial-api --to-revision=2

# Pause mid-rollout (for canary testing)
kubectl rollout pause deployment/judicial-api
kubectl rollout resume deployment/judicial-api

# Check if rollout is healthy
kubectl rollout status deployment/judicial-api --timeout=5m
# exit code 1 if not complete within 5 minutes (good for CI/CD)
```

-----

## PART 20 — GITOPS WITH ARGOCD

### GitOps Principles

```
GitOps = Git as single source of truth for cluster state
  All K8s manifests in git
  Any change to cluster MUST go through git (PR, review, merge)
  ArgoCD/Flux continuously syncs cluster to match git state
  Drift detection: alerts if cluster differs from git

Benefits:
  Full audit trail (git history = deployment history)
  Rollback = git revert (instant)
  No direct kubectl access needed for devs (ArgoCD applies)
  Disaster recovery: re-apply git state → cluster restored
  Peer review for all infrastructure changes

ArgoCD: most popular GitOps tool for Kubernetes
```

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# or expose via Ingress

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Login
argocd login localhost:8080
```

```yaml
# ArgoCD Application (what to deploy, from where, to where)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: judicial-api
  namespace: argocd
spec:
  project: default

  # Source: where manifests live
  source:
    repoURL: https://github.com/adityagaurav13a/cloud_learning
    targetRevision: main
    path: k8s/judicial-api         # folder with K8s YAML files

  # Destination: where to deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: production

  # Auto-sync policy
  syncPolicy:
    automated:
      prune: true          # delete resources removed from git
      selfHeal: true       # revert manual kubectl changes
      allowEmpty: false    # don't sync if no resources
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### GitOps Workflow

```
Developer makes change:
  1. Edit deployment.yaml in feature branch
  2. Create PR → team reviews → merge to main
  
ArgoCD detects change (polls every 3 min or via webhook):
  3. ArgoCD pulls new manifests from git
  4. Compares with cluster state (diff)
  5. Applies changes (kubectl apply equivalent)
  6. Reports sync status (Synced/OutOfSync/Degraded)

If someone runs kubectl manually:
  7. Cluster state drifts from git
  8. ArgoCD detects drift (selfHeal=true)
  9. Reverts manual change automatically
  10. Your git is ALWAYS what's deployed

Rollback:
  11. git revert the commit
  12. ArgoCD automatically applies old manifests
  No need to remember what was deployed before
```

-----

## PART 21 — COMPLETE INTERVIEW PREP ANSWERS

### “Tell me about a time you debugged a Kubernetes production issue”

```
Use your real experience:

"We had a CrashLoopBackOff on our judicial-api pods in EKS.

1. First I ran kubectl logs judicial-api-xyz --previous
   Saw: "OOMKilled" (exit code 137)
   
2. kubectl describe pod showed memory limit was 256Mi
   kubectl top pod showed it was consistently using 240Mi (near limit)
   
3. Traffic had doubled (court deadline season)
   More concurrent requests = more memory per request
   
4. Fix 1: increased memory limit to 512Mi
   kubectl set resources deployment/judicial-api --limits=memory=512Mi
   
5. Fix 2: added HPA with memory metric
   So it scales horizontally before hitting limit again
   
6. Root cause: memory limit set based on normal traffic, not peak
   
7. Prevention: VPA in Off mode gave us a recommendation of 400Mi
   We updated our Helm values to 512Mi (with buffer)
   Added CloudWatch alarm for memory > 80% of limit"

This answer shows: systematic debugging, root cause analysis,
multiple solutions, prevention mindset
```

### “How would you design Kubernetes for a production multi-tenant SaaS?”

```
Answer structure:

1. Namespace isolation per tenant
   Each customer → dedicated namespace
   ResourceQuota per namespace (limit their resource usage)
   NetworkPolicy: namespaces can't communicate (isolation)
   RBAC: customer's service accounts only access their namespace

2. Shared control plane, dedicated node pools (optional)
   Economy: all tenants on shared nodes (with ResourceQuota)
   Premium: dedicated node pool per tier with taints/tolerations

3. Ingress routing by tenant
   customer-a.judicial.com → namespace: customer-a
   customer-b.judicial.com → namespace: customer-b
   One Ingress controller, many tenants

4. Observability per tenant
   Labels: tenant=customer-a on all resources
   Grafana: per-tenant dashboards with tenant filter
   Alerts: per-tenant SLO tracking

5. Deployment: ArgoCD ApplicationSet (deploys same app to all namespaces)
   One chart + one values template → N tenant deployments
   Tenant-specific values (DB connection, feature flags) via ExternalSecret

6. Cost allocation: resource tags per namespace → billing per tenant
```

-----

## UPDATED QUICK REFERENCE

### kubectl Commands Every DevOps Engineer Must Know

```bash
# ─── CLUSTER INFO ──────────────────────────────────────────────
kubectl cluster-info
kubectl get nodes -o wide                        # nodes with IPs
kubectl top nodes                                # resource usage
kubectl describe node <n>                        # node details + conditions

# ─── PODS ──────────────────────────────────────────────────────
kubectl get pods -A                              # all namespaces
kubectl get pods -o wide                         # with node assignment
kubectl get pods --show-labels
kubectl get pods -l app=judicial-api             # by label
kubectl describe pod <n>                         # full details + events
kubectl logs <pod> -f                            # follow logs
kubectl logs <pod> --previous                    # previous container logs
kubectl logs <pod> -c <container>                # specific container
kubectl exec -it <pod> -- bash                   # shell into pod
kubectl exec <pod> -- env                        # env vars
kubectl port-forward <pod> 8080:8080             # local access
kubectl delete pod <n> --grace-period=0 --force  # force delete

# ─── DEPLOYMENTS ────────────────────────────────────────────────
kubectl get deployments
kubectl describe deployment <n>
kubectl scale deployment <n> --replicas=5
kubectl set image deployment/<n> container=image:tag
kubectl rollout status deployment/<n>
kubectl rollout history deployment/<n>
kubectl rollout undo deployment/<n>
kubectl rollout pause/resume deployment/<n>

# ─── SERVICES ────────────────────────────────────────────────────
kubectl get services
kubectl describe service <n>
kubectl get endpoints <n>                        # pods behind service

# ─── CONFIGS & SECRETS ───────────────────────────────────────────
kubectl get configmaps / cm
kubectl describe cm <n>
kubectl get secrets
kubectl get secret <n> -o jsonpath='{.data.key}' | base64 -d  # decode

# ─── STORAGE ─────────────────────────────────────────────────────
kubectl get pvc -A
kubectl get pv
kubectl describe pvc <n>

# ─── EVENTS & DEBUGGING ──────────────────────────────────────────
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n production --field-selector type=Warning
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# ─── RBAC ────────────────────────────────────────────────────────
kubectl auth can-i list pods -n production
kubectl auth can-i --list -n production
kubectl get roles,rolebindings -n production
kubectl get clusterroles,clusterrolebindings

# ─── MULTI-RESOURCE ──────────────────────────────────────────────
kubectl get all -n production                    # everything in namespace
kubectl get all -A                               # everything everywhere
kubectl apply -f ./k8s/ --recursive              # apply all in directory
kubectl delete -f deployment.yaml                # delete from file

# ─── CONTEXT & NAMESPACE ─────────────────────────────────────────
kubectl config get-contexts
kubectl config use-context my-cluster
kubectl config set-context --current --namespace=production
kubens production                               # quick namespace switch (kubens tool)
```

### Resource Abbreviations

```
po   = pods                    cm   = configmaps
svc  = services                pvc  = persistentvolumeclaims
deploy = deployments           pv   = persistentvolumes
rs   = replicasets             sa   = serviceaccounts
sts  = statefulsets            ns   = namespaces
ds   = daemonsets              hpa  = horizontalpodautoscalers
job  = jobs                    ing  = ingresses
cj   = cronjobs                ep   = endpoints
```

### Kubernetes Object Decision Tree

```
What am I deploying?

Is it a batch job (runs and finishes)?
  Yes → Job (one-time) or CronJob (scheduled)

Is it a node-level daemon?
  Yes → DaemonSet

Does each pod need stable identity + own persistent storage?
  Yes → StatefulSet (databases, Kafka, Elasticsearch)
  No  → Deployment (APIs, web servers, workers)

Does it need to be exposed externally?
  Just HTTP/HTTPS → Ingress (one LB for all services)
  Need own IP/port → LoadBalancer Service
  Internal only → ClusterIP Service

Does it need to auto-scale?
  Based on traffic/CPU → HPA
  Based on resource right-sizing → VPA
  Need more nodes? → Cluster Autoscaler (automatic with proper config)
```