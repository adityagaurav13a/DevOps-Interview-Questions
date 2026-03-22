# Kubernetes Scenario-Based Interview Questions
## Basic → Intermediate → Advanced → Expert
### Every question: Scenario → What they're testing → Complete Answer

---

## README

**Total questions:** 80
**Levels:** Basic (Q1-20), Intermediate (Q21-45), Advanced (Q46-65), Expert (Q66-80)
**Format:** Real scenario → diagnosis → fix → prevention

### How to use:
- **Beginner interviews:** Focus on Q1–Q20
- **Mid-level interviews:** Q1–Q45 (all of basic + intermediate)
- **Senior interviews:** Q1–Q80 (everything)
- **Practice out loud** — time yourself, aim for 90 seconds per answer

### Your strongest scenarios (real experience):
| Question | Your project |
|---|---|
| Q8 | CrashLoopBackOff (EKS production work) |
| Q12 | Rolling update + rollback (EKS) |
| Q18 | HPA scaling (EKS with HPA configured) |
| Q23 | Ingress routing (Minikube fake shop) |
| Q29 | EKS pod can't pull from ECR |

### Power phrases:
- *"I've debugged CrashLoopBackOff in production — first thing I check is kubectl logs --previous"*
- *"I built a 3-service Nginx Ingress on Minikube — here's exactly how path routing works"*
- *"HPA scales pods, Cluster Autoscaler scales nodes — they work together"*
- *"etcd is the single source of truth — losing it means losing the cluster"*

---

## SECTION 1 — BASIC (Q1–Q20)
### For freshers and engineers new to Kubernetes

---

**Q1. You deployed an app with `kubectl apply -f deployment.yaml` but no pods are running. What do you do?**

What they're testing: basic debugging flow

```bash
# Step 1: Check deployment status
kubectl get deployments
# Look at READY column — 0/3 means 0 pods ready out of 3 desired

# Step 2: Check pods
kubectl get pods
# Look at STATUS column

# Step 3: Describe the deployment
kubectl describe deployment my-app
# Look at Events section at bottom

# Step 4: Describe a pod
kubectl describe pod my-app-abc123
# Most detailed info — Events show exactly what failed

# Step 5: Check logs if pod exists
kubectl logs my-app-abc123

# Common causes you'll find:
# - ImagePullBackOff → wrong image name or registry auth issue
# - Pending → no resources on nodes, wrong node selector
# - CrashLoopBackOff → app crashing at startup
# - CreateContainerConfigError → missing ConfigMap or Secret
```

---

**Q2. You ran `kubectl get pods` and a pod shows `ImagePullBackOff`. What caused this and how do you fix it?**

What they're testing: image pull debugging

```bash
# Describe the pod to see exact error
kubectl describe pod failing-pod
# Look at Events:
# Failed to pull image "myapp:ltest": rpc error:
# code = Unknown desc = failed to pull and unpack image:
# ... manifest unknown

# Root causes:

# 1. Typo in image name or tag
#    myapp:ltest → should be myapp:latest
#    Fix: correct the image in deployment.yaml

# 2. Image doesn't exist in registry
#    Check: docker pull myapp:latest
#    Fix: build and push the image first

# 3. Private registry — missing credentials
#    Fix: create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=123456.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password)

#    Reference in pod spec:
spec:
  imagePullSecrets:
  - name: regcred
  containers:
  - image: 123456.dkr.ecr.../myapp:latest

# 4. Wrong platform (arm64 image on amd64 node)
#    Fix: build multi-platform image

# 5. Docker Hub rate limit
#    Fix: docker login or use ECR mirror
```

---

**Q3. Your pod is running but you can't access it from your browser. What's wrong?**

What they're testing: Service and port concepts

```bash
# Step 1: Verify pod is actually running and on which port
kubectl get pods -o wide
kubectl describe pod my-pod | grep -A5 Ports

# Step 2: Check if a Service exists
kubectl get services
# If no service → pod has no stable IP or routing

# Step 3: Check Service selector matches pod labels
kubectl describe service my-svc
# Endpoints: <none>  ← means selector doesn't match any pod

kubectl get pods --show-labels
# Compare pod labels with service selector

# Step 4: Check Service type
kubectl get svc my-svc -o yaml | grep type
# ClusterIP → only internal access
# NodePort → access via node IP + nodePort
# LoadBalancer → access via external IP

# Step 5: Test connectivity inside cluster first
kubectl run test --rm -it --image=busybox \
  -- wget -qO- http://my-svc:80

# Step 6: Port-forward to test pod directly
kubectl port-forward pod/my-pod 8080:8080
# Now access: http://localhost:8080

# Fix: create correct service
kubectl expose deployment my-app \
  --type=LoadBalancer \
  --port=80 \
  --target-port=8080
```

---

**Q4. You need to check the logs of a container that keeps restarting. The container is not running long enough to get logs. How do you see what crashed?**

What they're testing: container restart debugging

```bash
# --previous flag gets logs from the PREVIOUS (crashed) container
kubectl logs my-pod --previous

# If multiple containers in the pod
kubectl logs my-pod -c container-name --previous

# Get last 100 lines
kubectl logs my-pod --previous --tail=100

# Follow logs of current container
kubectl logs my-pod -f

# Check restart count and last state
kubectl describe pod my-pod
# Look for:
#   Last State: Terminated
#     Reason: OOMKilled / Error / Completed
#     Exit Code: 137 (OOM) / 1 (error) / 0 (normal)
#   Restart Count: 5

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep my-pod
```

---

**Q5. You want to run a one-off command inside a running pod. How do you do it?**

What they're testing: kubectl exec

```bash
# Open interactive shell
kubectl exec -it my-pod -- bash
kubectl exec -it my-pod -- sh    # if no bash

# Run single command
kubectl exec my-pod -- env       # list environment variables
kubectl exec my-pod -- cat /app/config.yaml
kubectl exec my-pod -- ls -la /app

# Multi-container pod — specify container
kubectl exec -it my-pod -c api-container -- bash

# Run in specific namespace
kubectl exec -it my-pod -n production -- bash

# If no shell available (distroless)
# Can't exec — use kubectl debug instead
kubectl debug -it my-pod \
  --image=busybox \
  --target=my-container

# Real use cases:
kubectl exec postgres-pod -- psql -U postgres -c "SELECT version();"
kubectl exec redis-pod -- redis-cli PING
kubectl exec nginx-pod -- nginx -t  # test config
```

---

**Q6. You need to update the Docker image in a running deployment to a new version. How do you do it without downtime?**

What they're testing: rolling update knowledge

```bash
# Method 1: kubectl set image (quick)
kubectl set image deployment/my-app \
  container-name=myimage:v2.0 \
  --record  # records in rollout history

# Method 2: kubectl edit (manual edit)
kubectl edit deployment my-app
# Change image: myimage:v1.0 → myimage:v2.0
# Save and exit → rolling update starts automatically

# Method 3: kubectl apply (recommended for production)
# Update image in deployment.yaml, then:
kubectl apply -f deployment.yaml

# Watch the rolling update happen
kubectl rollout status deployment/my-app
# Waiting for deployment "my-app" rollout to finish:
# 1 out of 3 new replicas have been updated...

# Verify new version is running
kubectl get pods -l app=my-app
kubectl describe pod <new-pod> | grep Image

# Zero downtime because:
# RollingUpdate creates new pod, waits until ready,
# then terminates old pod — at least N-1 pods always running
```

---

**Q7. Your team needs read-only access to pods in the staging namespace but nothing else. How do you set this up?**

What they're testing: basic RBAC

```yaml
# Step 1: Create Role in staging namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: staging
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

```yaml
# Step 2: Bind role to team
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-pod-reader
  namespace: staging
subjects:
- kind: Group
  name: dev-team         # group from your auth provider
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
# Verify
kubectl auth can-i list pods \
  --as developer-john \
  --namespace staging
# yes

kubectl auth can-i delete pods \
  --as developer-john \
  --namespace staging
# no

kubectl auth can-i list pods \
  --as developer-john \
  --namespace production
# no (role is namespace-scoped)
```

---

**Q8. Your pod is in CrashLoopBackOff. Walk me through your debugging process.**

What they're testing: systematic debugging — your real experience

```bash
# Step 1: Check the status and restart count
kubectl get pods
# NAME          READY   STATUS             RESTARTS   AGE
# my-app-xyz    0/1     CrashLoopBackOff   5          10m

# Step 2: Get logs from crashed container
kubectl logs my-app-xyz --previous
# This shows output from BEFORE the crash

# Step 3: Describe pod for full context
kubectl describe pod my-app-xyz
# Look for:
#   Exit Code → tells you HOW it crashed
#   OOMKilled → memory limit too low
#   Error (exit 1) → app error
#   Completed (exit 0) → not a daemon process

# Step 4: Common causes and fixes:

# A. Application error at startup
#    Logs show: ModuleNotFoundError, Connection refused, etc.
#    Fix: debug the app code, check env vars, check DB connectivity

# B. OOMKilled (exit 137)
#    Fix: increase memory limit
kubectl set resources deployment/my-app \
  --limits=memory=512Mi

# C. Config/Secret missing
#    Error: secret "app-secrets" not found
#    Fix: kubectl create secret generic app-secrets ...

# D. Wrong command/entrypoint
#    App not a long-running process
#    Fix: ensure CMD runs a daemon, not a one-shot script

# E. Liveness probe too aggressive
#    Probe fails before app starts → container killed → repeat
#    Fix: increase initialDelaySeconds

# Step 5: Run with shell to debug interactively
kubectl run debug \
  --image=myimage:latest \
  --restart=Never \
  --rm -it \
  -- /bin/sh
# Manually run the startup command and see what happens
```

---

**Q9. How do you check what resources (CPU and memory) your pods are currently consuming?**

What they're testing: monitoring basics

```bash
# Current usage (requires metrics-server)
kubectl top pods
# NAME          CPU(cores)   MEMORY(bytes)
# my-app-abc    45m          128Mi
# my-app-xyz    52m          134Mi

# Specific namespace
kubectl top pods -n production

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory

# Node usage
kubectl top nodes

# Check requested vs actual
kubectl describe pod my-app-abc | grep -A3 Requests
kubectl describe pod my-app-abc | grep -A3 Limits

# If metrics-server not installed:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Watch HPA decisions
kubectl describe hpa my-hpa
# Shows current metrics vs targets
```

---

**Q10. You need to temporarily stop all traffic to a specific pod for maintenance without deleting it. How?**

What they're testing: label manipulation for traffic management

```bash
# Method 1: Remove pod from Service by changing labels
# Service selector: app=my-app
# Remove or change the label on the pod:
kubectl label pod my-app-abc123 app=my-app-maintenance --overwrite

# Now Service no longer routes traffic to this pod
# Pod still running, can be debugged/maintained

# Restore:
kubectl label pod my-app-abc123 app=my-app --overwrite

# Method 2: Cordon the node (prevents new pods, doesn't stop existing)
kubectl cordon node-1
# Node marked Unschedulable — no new pods placed here

# Method 3: Drain the node (evicts all pods, good for node maintenance)
kubectl drain node-1 \
  --ignore-daemonsets \
  --delete-emptydir-data

# Restore node:
kubectl uncordon node-1

# Method 4: Scale to 0 (removes all pods)
kubectl scale deployment my-app --replicas=0
# No traffic, no pods running
# Restore: kubectl scale deployment my-app --replicas=3
```

---

**Q11. You need to pass different database connection strings to pods in dev vs production. How do you manage this?**

What they're testing: ConfigMap and environment management

```bash
# Create environment-specific ConfigMaps
kubectl create configmap app-config-dev \
  --from-literal=DB_HOST=dev-postgres \
  --from-literal=DB_NAME=myapp_dev \
  --namespace dev

kubectl create configmap app-config-prod \
  --from-literal=DB_HOST=prod-postgres.rds.amazonaws.com \
  --from-literal=DB_NAME=myapp_prod \
  --namespace production
```

```yaml
# deployment-dev.yaml
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: app-config-dev  # use dev config
```

```yaml
# deployment-prod.yaml
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: app-config-prod  # use prod config
```

```bash
# Apply to correct namespace
kubectl apply -f deployment-dev.yaml -n dev
kubectl apply -f deployment-prod.yaml -n production

# Or use Helm / Kustomize for proper environment management
# kustomize/overlays/prod/kustomization.yaml:
#   configMapGenerator:
#   - name: app-config
#     literals:
#     - DB_HOST=prod-postgres.rds.amazonaws.com
```

---

**Q12. You deployed a new version and users are reporting errors. How do you roll back to the previous version?**

What they're testing: rollback — your real EKS experience

```bash
# Check rollout history
kubectl rollout history deployment/my-app
# REVISION  CHANGE-CAUSE
# 1         Initial deployment v1.0
# 2         Updated to v1.1
# 3         Updated to v1.2 (current — buggy)

# Rollback to previous version (v1.1)
kubectl rollout undo deployment/my-app
# deployment.apps/my-app rolled back

# Watch rollback happen
kubectl rollout status deployment/my-app

# Rollback to specific revision
kubectl rollout undo deployment/my-app --to-revision=1

# Verify old version is running
kubectl describe deployment my-app | grep Image
# Image: myapp:v1.1

# Verify pods are healthy
kubectl get pods -l app=my-app
kubectl logs -l app=my-app --tail=20

# Speed tip: rollback is instant because old ReplicaSet still exists
# No image pull needed — containers already on nodes
# Recovery time: 30-60 seconds typically
```

---

**Q13. How do you make a Kubernetes Secret more secure than just base64 encoding?**

What they're testing: secrets security awareness

```
Problem with default Secrets:
  base64 is NOT encryption — it's just encoding
  Anyone with etcd access can decode secrets instantly
  Secrets visible to anyone with kubectl get secret rights

Solutions (pick based on environment):

Option 1: Encryption at rest (built-in K8s)
  Enable EncryptionConfiguration on API server
  Encrypts secrets in etcd with AES-GCM
  Transparent to pods — no code change needed

Option 2: External Secrets Operator (recommended for AWS)
  Secrets live in AWS Secrets Manager (properly encrypted)
  External Secrets Operator syncs into K8s Secrets
  Auto-rotates when AWS secret changes

Option 3: Vault (HashiCorp)
  Secrets never touch etcd
  Vault Agent sidecar injects secrets as files
  Full audit log of every secret access

Option 4: Sealed Secrets (GitOps)
  Encrypt secrets with public key before committing to git
  Only cluster's private key can decrypt
  Enables storing encrypted secrets in git safely

Option 5: RBAC restrictions (minimum)
  Restrict who can get/list secrets
  Avoid: kubectl get secrets -A (too broad)
  Grant: only specific ServiceAccounts access specific secrets
```

---

**Q14. Your application needs to store files that persist even when pods restart. How do you set this up?**

What they're testing: PVC/PV basics

```yaml
# Step 1: Create PVC (claim storage)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: production
spec:
  storageClassName: gp3  # AWS EBS gp3
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

```yaml
# Step 2: Mount PVC in Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: data
          mountPath: /app/uploads  # where app writes files
      
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: app-data-pvc
```

```bash
# Check PVC is bound
kubectl get pvc
# NAME           STATUS   VOLUME                  CAPACITY   STORAGECLASS
# app-data-pvc   Bound    pvc-abc123              10Gi       gp3

# Verify data survives pod restart
kubectl exec my-app-pod -- sh -c "echo 'test' > /app/uploads/test.txt"
kubectl delete pod my-app-pod  # pod restarts
kubectl exec new-my-app-pod -- cat /app/uploads/test.txt
# test  ← data survived!
```

---

**Q15. How do you run a database like PostgreSQL in Kubernetes properly?**

What they're testing: StatefulSet understanding

```yaml
# Use StatefulSet (not Deployment) for databases
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  
  volumeClaimTemplates:  # each pod gets its own PVC
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
```

```yaml
# Headless service for stable DNS
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None  # headless
  selector:
    app: postgres
  ports:
  - port: 5432
# DNS: postgres-0.postgres-headless.default.svc.cluster.local
```

```
Why StatefulSet for databases:
  ✓ Stable pod names: postgres-0, postgres-1
  ✓ Stable DNS hostnames for each pod
  ✓ Each pod gets own PVC (data not shared accidentally)
  ✓ Ordered startup (postgres-0 before postgres-1)
  ✓ Ordered deletion (postgres-1 deleted before postgres-0)

Production reality:
  For critical databases → use managed service (RDS, CloudSQL)
  Self-managed DB in K8s is complex (backups, HA, failover)
  Use K8s for stateless apps, managed services for stateful data
```

---

**Q16. How do you prevent a single bad pod from taking all CPU and memory on a node?**

What they're testing: resource limits

```yaml
# Set resource limits on every container
spec:
  containers:
  - name: app
    resources:
      requests:          # guaranteed resources — used for scheduling
        memory: "128Mi"
        cpu: "100m"
      limits:            # maximum allowed — enforced at runtime
        memory: "512Mi"  # exceed this → OOMKilled
        cpu: "500m"      # exceed this → CPU throttled (not killed)
```

```yaml
# LimitRange: enforce limits for entire namespace
# Any pod without limits gets these defaults
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:
      memory: 256Mi
      cpu: 200m
    defaultRequest:
      memory: 128Mi
      cpu: 100m
    max:
      memory: 2Gi
      cpu: 2
```

```yaml
# ResourceQuota: cap total resources per namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
```

```
CPU behavior:
  Request: guaranteed minimum (pod scheduled only if available)
  Limit: maximum — CPU throttled if exceeded (not killed)

Memory behavior:
  Request: guaranteed minimum
  Limit: maximum — OOMKilled if exceeded
  Memory cannot be throttled like CPU — must kill the process
```

---

**Q17. Your pods need to read AWS S3 but you don't want to store access keys in the pod. How do you do this on EKS?**

What they're testing: IRSA (IAM Roles for Service Accounts)

```bash
# Step 1: Associate OIDC provider with cluster
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --approve

# Step 2: Create IAM role with trust policy for K8s service account
eksctl create iamserviceaccount \
  --cluster my-cluster \
  --namespace production \
  --name judicial-api-sa \
  --attach-policy-arn arn:aws:iam::ACCOUNT:policy/S3ReadPolicy \
  --approve
```

```yaml
# Step 3: Use service account in pod
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judicial-api-sa
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/judicial-role

---
spec:
  serviceAccountName: judicial-api-sa  # pod uses this SA
  containers:
  - name: api
    image: judicial-api:latest
    # No AWS credentials needed — SDK auto-detects IRSA
```

```python
# In your Python code — no credentials needed
import boto3
s3 = boto3.client('s3')  # automatically uses IRSA token
s3.list_objects_v2(Bucket='judicial-bucket')
```

---

**Q18. Your application traffic doubled but response time is suffering. How do you auto-scale?**

What they're testing: HPA setup — your EKS experience

```bash
# First: ensure metrics-server is running
kubectl get pods -n kube-system | grep metrics-server
```

```yaml
# HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: judicial-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

```bash
# Apply and monitor
kubectl apply -f hpa.yaml

# Watch scaling in action
kubectl get hpa -w
# NAME              TARGETS    MINPODS  MAXPODS  REPLICAS
# judicial-api-hpa  45%/70%    2        20       3
# judicial-api-hpa  78%/70%    2        20       3  ← scaling up
# judicial-api-hpa  78%/70%    2        20       5  ← scaled to 5

# Generate test load
kubectl run load-test \
  --image=busybox \
  --restart=Never \
  --rm -it \
  -- /bin/sh -c "while true; do wget -q -O- http://judicial-api-svc; done"

# Requirements for HPA to work:
# 1. metrics-server installed
# 2. resource requests set on containers (HPA calculates % of request)
# 3. Deployment (not just pods directly)
```

---

**Q19. You want to ensure your application always has at least 2 pods running during node failures or updates. How?**

What they're testing: PodDisruptionBudget

```yaml
# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: judicial-pdb
spec:
  minAvailable: 2        # always keep at least 2 pods running
  # OR:
  # maxUnavailable: 1   # allow max 1 pod down at a time
  selector:
    matchLabels:
      app: judicial-api
```

```bash
# Apply PDB
kubectl apply -f pdb.yaml

# PDB prevents:
# - kubectl drain from evicting too many pods at once
# - Node maintenance from taking down all replicas
# - Rolling updates from leaving service degraded

# Check PDB status
kubectl get pdb
# NAME           MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS
# judicial-pdb   2               N/A               1

# During node drain:
# kubectl drain will wait if evicting pod would violate PDB
# You'll see: "evicting pod judicial-api-xyz... blocked by PDB"
# Node drain completes only when safe (other pods healthy first)

# For HA: set replicas >= 3 with minAvailable=2
# Allows 1 pod down at any time
```

---

**Q20. Your cluster has 3 nodes but all pods are being scheduled on just one node. Why and how do you fix it?**

What they're testing: pod spreading / anti-affinity

```bash
# Check pod distribution
kubectl get pods -o wide
# See NODE column — all showing same node

# Possible causes:
# 1. nodeSelector or nodeAffinity pointing to one node
kubectl describe pod my-pod | grep -A5 "Node-Selectors"

# 2. Resource requests too high for other nodes
kubectl describe nodes | grep -A5 Allocated

# 3. Other nodes are tainted
kubectl describe nodes | grep Taint
```

```yaml
# Fix 1: Pod Anti-affinity (preferred)
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - judicial-api
          topologyKey: kubernetes.io/hostname
# Prefers to spread pods across different hosts
```

```yaml
# Fix 2: Topology Spread Constraints (more precise)
spec:
  topologySpreadConstraints:
  - maxSkew: 1              # max difference between any two nodes
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule  # hard requirement
    labelSelector:
      matchLabels:
        app: judicial-api
# Ensures even spread across nodes
```

---

## SECTION 2 — INTERMEDIATE (Q21–Q45)
### For engineers with 2-4 years experience

---

**Q21. Your service is returning 503 errors intermittently. How do you debug this?**

What they're testing: service → pod connectivity debugging

```bash
# Step 1: Check if pods behind service are healthy
kubectl get pods -l app=my-app
# Look for: Running, Ready column = 1/1

# Step 2: Check service endpoints
kubectl get endpoints my-svc
# NAME     ENDPOINTS                       AGE
# my-svc   10.0.0.5:8080,10.0.0.6:8080   5m
# If ENDPOINTS is <none> → no pods match selector

# Step 3: Check if specific pods are failing
kubectl logs -l app=my-app --tail=50
# Multiple pods logs at once — look for errors

# Step 4: Check readiness probe
kubectl describe pod my-pod | grep -A10 Readiness
# Is readiness probe failing? → pod removed from endpoints

# Step 5: Test connectivity to specific pod
kubectl run test --rm -it --image=busybox \
  -- wget -qO- http://10.0.0.5:8080/health
# Test each pod IP directly

# Step 6: Check if service CIDR and pod CIDR overlap
kubectl get svc -o yaml | grep clusterIP

# Common causes:
# - Readiness probe failing → pod removed from rotation
# - Pod OOMKilled and restarting → briefly unavailable
# - App has memory leak → degraded performance → probe fails
# - Rolling update removing pods faster than new ones ready
```

---

**Q22. You need to expose an application on a custom domain (app.company.com) with HTTPS. Walk through the setup.**

What they're testing: Ingress + TLS + cert-manager

```bash
# Step 1: Install cert-manager (handles certificate issuance)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Step 2: Create ClusterIssuer (Let's Encrypt)
cat << 'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: aditya@judicialsolutions.in
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Step 3: Create Ingress with TLS
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.company.com
    secretName: app-tls  # cert-manager creates this secret
  rules:
  - host: app.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-svc
            port:
              number: 80
EOF

# Step 4: Point DNS to Ingress Controller IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Get EXTERNAL-IP → set DNS A record to this IP

# cert-manager automatically:
# - Requests certificate from Let's Encrypt
# - Stores in secret: app-tls
# - Renews 30 days before expiry
```

---

**Q23. You set up Nginx Ingress with path-based routing for 3 services but one path always returns 404. Debug it.**

What they're testing: Ingress debugging — your Minikube experience

```bash
# Step 1: Check Ingress resource
kubectl describe ingress my-ingress
# Look at Rules section — is your path listed?
# Look at Backends — is it pointing to right service?

# Step 2: Check if service and port are correct
kubectl get svc
kubectl get svc my-svc -o yaml | grep port

# Step 3: Check Ingress controller logs
kubectl logs -n ingress-nginx \
  $(kubectl get pods -n ingress-nginx -o name | head -1) \
  | grep 404

# Step 4: Check path type
# Exact: /products matches ONLY /products (not /products/123)
# Prefix: /products matches /products, /products/123, /products/all

# Step 5: Check annotation for path rewriting
# Without rewrite: /api/users → backend receives /api/users
# With rewrite:    /api/users → backend receives /users
# annotations:
#   nginx.ingress.kubernetes.io/rewrite-target: /$2
#   path: /api(/|$)(.*)

# Step 6: Test backend service directly
kubectl port-forward svc/missing-svc 8080:80
curl http://localhost:8080/  # test without Ingress

# Step 7: Check ingressClassName
kubectl get ingressclass  # verify nginx class exists
# Your ingress must specify: ingressClassName: nginx
```

---

**Q24. Your pods are being evicted and you see "The node was low on resource: memory". How do you fix this?**

What they're testing: resource management and QoS classes

```bash
# Check what's happening
kubectl get events --sort-by='.lastTimestamp' | grep Evict
kubectl describe node failing-node | grep -A20 "Allocated resources"

# Understanding QoS classes (who gets evicted first):

# BestEffort (evicted FIRST — no requests or limits):
containers:
- name: app
  image: myapp
  # no resources specified

# Burstable (evicted SECOND — requests < limits):
resources:
  requests:
    memory: "128Mi"
  limits:
    memory: "512Mi"

# Guaranteed (evicted LAST — requests = limits):
resources:
  requests:
    memory: "256Mi"    # same value
  limits:
    memory: "256Mi"    # same value

# Fix 1: Set resource requests on all pods
kubectl set resources deployment/my-app \
  --requests=memory=128Mi,cpu=100m \
  --limits=memory=512Mi,cpu=500m

# Fix 2: Add more nodes or larger nodes

# Fix 3: Enable VPA for automatic right-sizing
# VPA analyzes actual usage and recommends/sets appropriate values

# Fix 4: Find memory-hungry pods
kubectl top pods --sort-by=memory -A
kubectl describe pod memory-hungry-pod | grep -A3 Limits
```

---

**Q25. You need to run a database migration job once before your application starts. How do you implement this in Kubernetes?**

What they're testing: Jobs and init containers

```yaml
# Option 1: Kubernetes Job (run once)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  backoffLimit: 3      # retry up to 3 times on failure
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: migrate
        image: myapp:latest
        command: ["python", "manage.py", "migrate"]
        env:
        - name: DB_HOST
          value: postgres-svc
```

```yaml
# Option 2: Init Container (runs before main container)
spec:
  initContainers:
  - name: migrate
    image: myapp:latest
    command: ["python", "manage.py", "migrate"]
    # main container only starts after this exits 0
  
  containers:
  - name: app
    image: myapp:latest
    command: ["python", "manage.py", "runserver"]
```

```yaml
# Option 3: Helm hook (for Helm deployments)
annotations:
  "helm.sh/hook": pre-upgrade,pre-install
  "helm.sh/hook-weight": "-5"
  "helm.sh/hook-delete-policy": hook-succeeded
```

```bash
# Monitor job
kubectl get jobs
kubectl logs job/db-migration

# CronJob (scheduled recurring job)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
spec:
  schedule: "0 2 * * *"   # 2am daily (cron format)
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleanup
            image: myapp:latest
            command: ["python", "cleanup.py"]
```

---

**Q26. Two of your microservices are in different namespaces and need to communicate. How do you enable this?**

What they're testing: cross-namespace networking

```bash
# By default: pods in different namespaces CAN communicate
# K8s doesn't block cross-namespace traffic by default

# Access service in another namespace using FQDN:
# Format: <service>.<namespace>.svc.cluster.local

# From namespace 'frontend', reach service in namespace 'backend':
curl http://api-svc.backend.svc.cluster.local:8080

# Short names only work within same namespace:
curl http://api-svc:8080  # only works if in same namespace

# If you want to BLOCK cross-namespace traffic:
# Use NetworkPolicy

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-namespace
  namespace: backend
spec:
  podSelector: {}          # applies to all pods in namespace
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: backend    # only allow traffic from same namespace
    - namespaceSelector:
        matchLabels:
          name: frontend   # AND allow from frontend namespace
```

---

**Q27. Your Kubernetes cluster keeps running out of resources. How do you identify what's consuming the most resources?**

What they're testing: resource analysis

```bash
# Node resource usage
kubectl top nodes
# NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# node-1   1200m        60%    3Gi             75%
# node-2   400m         20%    1Gi             25%

# Pod resource usage across all namespaces
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Find pods with no resource limits (dangerous)
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.containers[].resources.limits == null) |
  .metadata.name'

# Find pods with high requests
kubectl get pods -A -o custom-columns=\
  'NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU:.spec.containers[*].resources.requests.cpu,MEM:.spec.containers[*].resources.requests.memory'

# Analyze namespace resource quotas
kubectl describe resourcequota -A

# Check for resource fragmentation
kubectl describe nodes | grep -A5 "Allocated resources"

# Find idle/wasted resources
# Pods with high limits but low actual usage → VPA candidates
```

---

**Q28. You need to ensure a pod always runs on a specific node (e.g., a GPU node). How do you configure this?**

What they're testing: node selection and taints/tolerations

```bash
# Step 1: Label the GPU node
kubectl label node gpu-node-1 \
  hardware=gpu \
  accelerator=nvidia-tesla-v100

# Method 1: NodeSelector (simple, hard requirement)
spec:
  nodeSelector:
    hardware: gpu

# Method 2: NodeAffinity (flexible)
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: hardware
            operator: In
            values:
            - gpu
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: accelerator
            operator: In
            values:
            - nvidia-tesla-v100

# Method 3: Taints and Tolerations (reserve node for specific pods)
# Taint the GPU node (repels all pods without toleration)
kubectl taint nodes gpu-node-1 \
  hardware=gpu:NoSchedule

# Add toleration to GPU pod
spec:
  tolerations:
  - key: hardware
    operator: Equal
    value: gpu
    effect: NoSchedule
  
  nodeSelector:
    hardware: gpu  # still need this to actively select GPU node
```

---

**Q29. Your EKS pods can't pull images from ECR. What are all the things you need to check?**

What they're testing: EKS + ECR integration — your real experience

```bash
# Check 1: Node group IAM role has ECR permissions
aws iam list-attached-role-policies \
  --role-name eksctl-my-cluster-NodeInstanceRole

# Must have: AmazonEC2ContainerRegistryReadOnly
# Or custom policy with:
# - ecr:GetAuthorizationToken
# - ecr:BatchGetImage
# - ecr:GetDownloadUrlForLayer

# Check 2: Image URI is correct
# Format: <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>
# NOT: docker.io/myimage:latest

# Check 3: ECR repository exists
aws ecr describe-repositories \
  --repository-names judicial-api \
  --region ap-south-1

# Check 4: Image tag exists
aws ecr describe-images \
  --repository-name judicial-api \
  --image-ids imageTag=latest \
  --region ap-south-1

# Check 5: Node is in same region as ECR
# Cross-region pull needs explicit permission

# Check 6: VPC endpoint for ECR (if private cluster)
# Private EKS cluster needs VPC endpoints:
# - com.amazonaws.region.ecr.api
# - com.amazonaws.region.ecr.dkr
# - com.amazonaws.region.s3 (for image layers)

# Check 7: For pods using service accounts (IRSA)
kubectl describe serviceaccount my-sa -n production
# Verify annotation: eks.amazonaws.com/role-arn

# Debug pod pull failure
kubectl describe pod failing-pod
# Look for: Failed to pull image...
#           Error response from daemon: pull access denied
#           → authentication issue
```

---

**Q30. How do you perform a blue-green deployment in Kubernetes?**

What they're testing: advanced deployment strategy

```yaml
# Blue (current version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: blue
  template:
    metadata:
      labels:
        app: my-app
        version: blue
    spec:
      containers:
      - name: app
        image: my-app:v1.0

---
# Green (new version — deployed but not serving traffic yet)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: green
  template:
    metadata:
      labels:
        app: my-app
        version: green
    spec:
      containers:
      - name: app
        image: my-app:v2.0
```

```yaml
# Service initially pointing to blue
apiVersion: v1
kind: Service
metadata:
  name: my-app-svc
spec:
  selector:
    app: my-app
    version: blue    # ← change this to green to switch traffic
  ports:
  - port: 80
    targetPort: 8080
```

```bash
# Deploy green, test thoroughly (no traffic yet)
kubectl apply -f deployment-green.yaml
kubectl get pods -l version=green  # verify all running

# Test green directly via port-forward
kubectl port-forward deployment/my-app-green 8080:8080
curl http://localhost:8080/health

# Switch traffic to green (instant, zero downtime)
kubectl patch service my-app-svc \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Monitor for errors
kubectl logs -l version=green --tail=50 -f

# If issues: instantly switch back to blue
kubectl patch service my-app-svc \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# After confidence: scale down blue
kubectl scale deployment my-app-blue --replicas=0
```

---

**Q31. Your pods are being scheduled on nodes in only one availability zone. How do you spread them across zones?**

What they're testing: topology spread for HA

```yaml
spec:
  topologySpreadConstraints:
  
  # Spread across zones
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: judicial-api
  
  # Also spread across nodes within each zone
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway  # soft requirement
    labelSelector:
      matchLabels:
        app: judicial-api
```

```bash
# Check zone labels on nodes
kubectl get nodes --show-labels | grep zone
kubectl label nodes node-1 \
  topology.kubernetes.io/zone=ap-south-1a  # if not set

# Verify spread after applying
kubectl get pods -o wide
# Should see pods spread across different NOMINATED NODE / zones

# For EKS: nodes are automatically labeled with zone
# topology.kubernetes.io/zone=ap-south-1a/1b/1c
```

---

**Q32. How do you implement a canary deployment in Kubernetes?**

What they're testing: canary strategy

```bash
# Canary = run small % of new version alongside stable

# Stable: 9 replicas (90% traffic)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: my-app
      track: stable
  template:
    metadata:
      labels:
        app: my-app      # service routes to this label
        track: stable
    spec:
      containers:
      - image: my-app:v1.0
EOF

# Canary: 1 replica (10% traffic)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
      track: canary
  template:
    metadata:
      labels:
        app: my-app    # same service label → gets traffic
        track: canary
    spec:
      containers:
      - image: my-app:v2.0
EOF

# Service selects on app: my-app only → gets traffic from both
# 9 stable + 1 canary = 10% to canary

# Gradually increase canary:
# stable: 7, canary: 3  = 30%
# stable: 5, canary: 5  = 50%
# stable: 0, canary: 10 = 100% (full rollout)

# Monitor error rate during canary
kubectl logs -l track=canary --tail=50
```

---

**Q33. Your Kubernetes cluster has nodes that should only run specific workloads (e.g., spot instances only for batch jobs). How do you implement this?**

What they're testing: taints and tolerations + node affinity

```bash
# Taint spot instances (repel regular pods)
kubectl taint nodes spot-node-1 spot-node-2 \
  instance-type=spot:NoSchedule

# Regular deployments (no toleration) → won't schedule on spot nodes
# This is the desired behavior — protect spot from regular workloads

# Batch job (tolerates spot and prefers it)
spec:
  tolerations:
  - key: instance-type
    operator: Equal
    value: spot
    effect: NoSchedule
  
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: instance-type
            operator: In
            values:
            - spot

# Critical pods — prevent from running on spot
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: instance-type
            operator: NotIn
            values:
            - spot

# On EKS with Karpenter:
# Karpenter provisioner can automatically taint spot nodes
# and manage mixed instance fleets
```

---

**Q34. A pod needs to access another pod's filesystem. How do you implement this?**

What they're testing: shared volumes / sidecar pattern

```yaml
# Shared emptyDir volume between containers in same pod
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: shared-data
      mountPath: /app/output
    # App writes files to /app/output

  - name: log-shipper
    image: fluentd:latest
    volumeMounts:
    - name: shared-data
      mountPath: /data/input     # reads files app wrote
      readOnly: true             # sidecar reads, doesn't write
  
  volumes:
  - name: shared-data
    emptyDir: {}                 # temporary, lives until pod deleted
```

```yaml
# For cross-pod access (different pods, same node)
# Use hostPath (not recommended, node-specific)
volumes:
- name: shared
  hostPath:
    path: /tmp/shared
    type: DirectoryOrCreate

# Better: use shared PVC with ReadWriteMany (NFS/EFS)
volumes:
- name: shared
  persistentVolumeClaim:
    claimName: shared-pvc       # must be RWX access mode
# Multiple pods on different nodes can all mount this
```

---

**Q35. Your application needs to read a large configuration file (5MB). How do you pass it to pods?**

What they're testing: ConfigMap size limits and alternatives

```
ConfigMap limit: 1MB total
etcd value limit: 1.5MB

For large configs:
  Option 1: Store in S3, read at startup
  Option 2: Break into multiple ConfigMaps
  Option 3: Use a ConfigMap with just the S3 path
  Option 4: Bake config into Docker image (bad practice)

For configs under 1MB:
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: large-config
data:
  config.yaml: |
    # your large config file content
    server:
      port: 8080
    database:
      ... (many lines)
```

```yaml
# Mount as file (not env var — too large for env)
spec:
  containers:
  - name: app
    volumeMounts:
    - name: config
      mountPath: /app/config    # mounted as directory
  
  volumes:
  - name: config
    configMap:
      name: large-config
# Creates: /app/config/config.yaml

# OR mount specific file
    volumeMounts:
    - name: config
      mountPath: /app/config/config.yaml
      subPath: config.yaml      # mount specific key as file
```

---

## SECTION 3 — ADVANCED (Q36–Q65)

---

**Q36. Your pods are slow to start (90 seconds) and liveness probe keeps killing them. How do you fix this?**

What they're testing: startup probe pattern

```yaml
# Problem:
# liveness probe starts checking immediately after container start
# App takes 90 seconds to initialize (Java JVM, DB connection pool, etc.)
# Liveness probe fails during initialization → container killed → loop

# Wrong fix: increase initialDelaySeconds to 90s
# Problem: if app crashes after startup, liveness doesn't kick in for 90s

# Right fix: Startup Probe
spec:
  containers:
  - name: app
    
    startupProbe:
      httpGet:
        path: /health
        port: 8080
      failureThreshold: 30   # 30 attempts
      periodSeconds: 10      # every 10 seconds
      # = up to 300 seconds (5 min) for startup
      # Liveness disabled until startup succeeds
    
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 0   # starts immediately AFTER startup probe
      periodSeconds: 10
      failureThreshold: 3
    
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      periodSeconds: 5

# Flow:
# Startup probe runs until success (up to 5 min)
# After startup succeeds: liveness + readiness probes start
# If startup probe exceeds failureThreshold: pod killed (not CrashLoopBackOff)
```

---

**Q37. How do you implement network policies to isolate your production namespace?**

What they're testing: NetworkPolicy for security

```yaml
# Default deny all ingress in production
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}     # applies to ALL pods
  policyTypes:
  - Ingress
  # No ingress rules = deny all ingress

---
# Allow frontend to talk to backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend    # this policy applies to backend pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend   # only allow traffic from frontend pods
    ports:
    - protocol: TCP
      port: 8080

---
# Allow backend to talk to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - port: 5432

---
# Allow Prometheus to scrape metrics
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: production
spec:
  podSelector: {}    # all pods
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - port: 9090
```

---

**Q38. Your cluster is running fine but a deployment shows 0 available replicas even though pods are running. Why?**

What they're testing: readiness probe understanding

```bash
# Check deployment
kubectl get deployment my-app
# READY   UP-TO-DATE   AVAILABLE
# 0/3     3            0         ← all 3 pods exist but 0 available

# "Available" = pods passing readiness probe

# Check pods
kubectl get pods
# All Running — but Ready = 0/1

# Check why readiness probe is failing
kubectl describe pod my-app-xyz
# Look for:
# Readiness probe failed: HTTP probe failed with statuscode: 503
# OR
# Readiness probe failed: Get "http://10.0.0.5:8080/ready": dial tcp: connect: connection refused

# Common causes:
# 1. App not ready yet (still starting, loading cache, DB migrations)
#    Fix: increase initialDelaySeconds in readiness probe

# 2. DB connection failing (app can't reach database)
#    Check: kubectl exec pod -- nc -zv db-host 5432

# 3. Readiness endpoint path wrong
#    App exposes /healthz but probe checks /ready
#    Fix: correct path in probe

# 4. App listening on wrong port/interface
#    Listening on 127.0.0.1 (not reachable from probe)
#    Must listen on 0.0.0.0

# 5. ConfigMap/Secret not loaded yet
#    App fails readiness until config available

# Note: pods NOT available = pod removed from service endpoints
# Users get 503 from service even though pods are running
```

---

**Q39. How do you implement zero-downtime deployment for a stateful application with a database schema change?**

What they're testing: advanced deployment with dependencies

```
The challenge:
  New app version requires new DB schema
  Old app version breaks with new schema
  Need to deploy without downtime

Strategy: Expand/Contract (Blue-Green for DB changes)

Phase 1 - Expand DB schema (backward compatible):
  Add new columns/tables (don't remove old ones)
  Both old and new app versions work with expanded schema
  Deploy new schema migration

Phase 2 - Deploy new app version:
  New app uses new columns
  Old app ignores new columns (still works)
  Rolling update with zero downtime

Phase 3 - Contract DB schema (after full rollout):
  Remove old columns/tables no longer needed
  Only after ALL pods are on new version
  This migration can have brief maintenance window

In Kubernetes:
  Step 1: Run migration Job (expand)
  Step 2: Rolling update deployment
  Step 3: Verify all pods on new version
  Step 4: Run cleanup migration Job (contract)

For emergency rollback:
  Old app version can roll back — schema still has old columns
  Contract migration NOT run yet — safe to roll back
```

---

**Q40. Your cluster has 50 deployments and you need to update the same environment variable across all of them. How do you do this efficiently?**

What they're testing: at-scale operations

```bash
# Option 1: Update all deployments with a label
kubectl get deployments -l team=backend \
  -o name | \
  xargs -I {} kubectl set env {} \
  LOG_LEVEL=debug

# Option 2: Update ConfigMap and trigger rolling restart
# All deployments referencing this ConfigMap
kubectl create configmap shared-config \
  --from-literal=LOG_LEVEL=debug \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rolling restart for all affected deployments
kubectl rollout restart deployment -l config=shared

# Option 3: Kustomize overlay
# Update value in kustomize overlay
# Apply: kustomize build overlays/prod | kubectl apply -f -
# Updates all deployments in that overlay

# Option 4: Helm values
# Update value in values.yaml
# helm upgrade my-release my-chart -f values.yaml
# All templates with this value updated

# Option 5: Script for bulk update
for deployment in $(kubectl get deploy -o name); do
  kubectl patch $deployment \
    --patch '{"spec":{"template":{"spec":{"containers":[{"name":"app","env":[{"name":"LOG_LEVEL","value":"debug"}]}]}}}}'
done
```

---

**Q41. How do you debug a pod that is running but behaving incorrectly (not crashing, just wrong output)?**

What they're testing: advanced debugging

```bash
# Step 1: Check what the app sees
# Environment variables
kubectl exec my-pod -- env | sort

# Mounted files
kubectl exec my-pod -- find /app/config -type f
kubectl exec my-pod -- cat /app/config/settings.yaml

# Step 2: Check network connectivity
kubectl exec my-pod -- nslookup database-svc
kubectl exec my-pod -- nc -zv database-svc 5432
kubectl exec my-pod -- curl -v http://api-svc/health

# Step 3: Check resource pressure
kubectl top pod my-pod
# Is CPU throttled? Memory near limit?

# Step 4: Compare with a working pod
kubectl diff pod/working-pod pod/broken-pod  # won't work directly
kubectl get pod working-pod -o yaml > working.yaml
kubectl get pod broken-pod -o yaml > broken.yaml
diff working.yaml broken.yaml

# Step 5: Check for secret/config drift
kubectl exec my-pod -- cat /run/secrets/token | base64 -d
# Verify the secret values are what you expect

# Step 6: Ephemeral debug container
kubectl debug -it my-pod \
  --image=ubuntu:22.04 \
  --target=my-container
# Shares process namespace — can see app's files and processes

# Step 7: Check if app connects to correct endpoint
kubectl exec my-pod -- curl -v http://db-svc/  
# Is it hitting dev DB or prod DB?

# Step 8: Enable debug logging temporarily
kubectl set env deployment/my-app LOG_LEVEL=DEBUG
# Check logs for detailed output
kubectl logs -l app=my-app --tail=100 -f
```

---

**Q42. How do you handle secrets rotation without restarting your pods?**

What they're testing: dynamic secrets management

```
Problem:
  Secret rotated in Kubernetes
  Pod still uses old secret value (cached at startup)
  Requires pod restart to pick up new value — causes downtime

Solutions:

Option 1: Application reads secret file dynamically
  Mount secret as volume (file, not env var)
  K8s updates mounted secret files when secret changes (within ~1 min)
  App reads file on each request instead of caching at startup
  
  volumeMounts:
  - name: secrets
    mountPath: /run/secrets
    readOnly: true
  
  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
  
  # In app:
  def get_db_password():
      with open('/run/secrets/db_password') as f:
          return f.read().strip()
  # Reads fresh value every time — no restart needed

Option 2: Implement secret reload endpoint
  App exposes POST /reload-secrets
  CI/CD calls endpoint after rotating secret
  App re-reads all secrets from volume

Option 3: External Secrets Operator + CSI driver
  Secrets Manager rotates secret
  External Secrets updates K8s secret
  CSI driver updates mounted file (propagates to pod)
  No pod restart required

Option 4: Rolling restart (simple but causes brief disruption)
  kubectl rollout restart deployment/my-app
  Rolling restart = pods restarted one at a time
  Each new pod gets new secret value
  No downtime but does restart all pods
```

---

**Q43. Your cluster is receiving too many requests and pods are getting OOMKilled. How do you fix this holistically?**

What they're testing: system-level problem solving

```
Root cause analysis:

1. Memory leak in application
   Check: kubectl top pods --sort-by=memory -w
   Memory increasing over time → leak
   Fix: profile app, fix memory leak

2. Resource limits too low
   Check: kubectl describe pod | grep OOMKilled
   Fix: increase memory limits
   kubectl set resources deployment/api --limits=memory=1Gi

3. Traffic spike (legitimate)
   Check: ingress logs, pod metrics
   Fix: HPA scale-out + Cluster Autoscaler scale nodes

4. Memory hogging query/request
   Check: app logs during OOM, identify request that triggers it
   Fix: pagination, streaming, query optimization

Holistic fixes:

Step 1: Immediate relief
  Increase memory limits
  Scale deployment manually: kubectl scale deploy api --replicas=10

Step 2: Auto-scaling
  Configure HPA (scale pods on CPU/memory/custom metric)
  Configure Cluster Autoscaler (scale nodes)

Step 3: Traffic management
  Rate limiting at Ingress level
  Circuit breaker pattern
  Queue requests via SQS

Step 4: Application optimization
  Profile memory usage
  Fix memory leaks
  Reduce memory footprint (distroless, less caching)

Step 5: Right-size with VPA
  VPA analyzes actual usage
  Recommends and applies optimal resource values
```

---

**Q44. How do you implement GitOps for Kubernetes deployments?**

What they're testing: GitOps with ArgoCD/Flux

```
GitOps principle:
  Git = single source of truth for cluster state
  Any change to cluster must go through Git (PR, review, merge)
  ArgoCD/Flux continuously syncs cluster to match git

ArgoCD setup:

Step 1: Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Step 2: Create Application (what to deploy, from where)
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: judicial-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/adityagaurav13a/cloud_learning
    targetRevision: main
    path: k8s/judicial-api       # K8s manifests in this path
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true      # delete resources removed from git
      selfHeal: true   # revert manual kubectl changes
    syncOptions:
    - CreateNamespace=true
```

```bash
# Workflow:
# 1. Developer creates PR to update image version in deployment.yaml
# 2. PR reviewed and merged to main
# 3. ArgoCD detects change within 3 minutes
# 4. ArgoCD applies changes to cluster
# 5. Shows green/healthy in ArgoCD UI

# Benefits:
# Full audit trail (git history = deployment history)
# Rollback = git revert PR
# No kubectl access needed for developers (only ArgoCD has access)
# Drift detection (ArgoCD alerts if cluster differs from git)
```

---

**Q45. How do you monitor your Kubernetes cluster and set up alerts for common issues?**

What they're testing: observability setup

```bash
# Install kube-prometheus-stack (Prometheus + Grafana + AlertManager)
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Key metrics to monitor:

# Node level:
# node_cpu_usage_seconds_total → CPU usage per node
# node_memory_MemAvailable_bytes → available memory
# node_filesystem_avail_bytes → disk space

# Pod level:
# container_cpu_usage_seconds_total → CPU per container
# container_memory_working_set_bytes → memory per container
# kube_pod_container_status_restarts_total → restart count

# Deployment level:
# kube_deployment_status_replicas_available → available pods
# kube_deployment_status_replicas_unavailable → unavailable pods

# Essential alerts to configure:
alerts:
  - name: PodCrashLooping
    condition: increase(kube_pod_container_status_restarts_total[1h]) > 5
    
  - name: NodeHighCPU
    condition: node_cpu_utilization > 80% for 5 minutes
    
  - name: PodOOMKilled
    condition: kube_pod_container_status_last_terminated_reason == "OOMKilled"
    
  - name: DeploymentNotReady
    condition: kube_deployment_status_replicas_available < desired
    
  - name: PVCAlmostFull
    condition: (pvc_used / pvc_capacity) > 0.85
    
  - name: CertificateExpiringSoon
    condition: cert_expiry_days < 14
```

---

## SECTION 4 — ADVANCED TO EXPERT (Q46–Q65)

---

**Q46. Your pod can't connect to the Kubernetes API server. How do you debug and fix this?**

What they're testing: service account and API access

```bash
# From inside a pod trying to call K8s API:
# Typical error: "unable to get current user context"
#                "connection refused to kubernetes.default.svc"

# Step 1: Test API connectivity from pod
kubectl exec my-pod -- \
  curl -k https://kubernetes.default.svc/api/v1/namespaces

# Step 2: Check service account token
kubectl exec my-pod -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Step 3: Verify RBAC permissions
kubectl auth can-i list pods \
  --as system:serviceaccount:production:my-sa \
  --namespace production

# Step 4: Check service account exists
kubectl get serviceaccount my-sa -n production

# Step 5: Check if automountServiceAccountToken is disabled
kubectl get pod my-pod -o yaml | grep automount
# automountServiceAccountToken: false  ← this disables API access

# Fix RBAC:
kubectl create clusterrolebinding my-app-binding \
  --clusterrole=view \
  --serviceaccount=production:my-sa

# If NetworkPolicy blocks API server access:
# API server is at kubernetes.default.svc (port 443)
# Allow egress to this service in NetworkPolicy
```

---

**Q47. How do you set up multi-tenancy in Kubernetes for different teams with resource isolation?**

What they're testing: enterprise K8s architecture

```yaml
# Namespace per team with full isolation

# Namespace for team-a
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    team: team-a

---
# ResourceQuota for team-a
apiVersion: v1
kind: ResourceQuota
metadata:
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    services.loadbalancers: "3"

---
# LimitRange for team-a (default limits)
apiVersion: v1
kind: LimitRange
metadata:
  namespace: team-a
spec:
  limits:
  - type: Container
    default:
      memory: 256Mi
      cpu: 200m
    defaultRequest:
      memory: 128Mi
      cpu: 100m

---
# RBAC: team-a members can only access team-a namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-admin
  namespace: team-a
subjects:
- kind: Group
  name: team-a-members
roleRef:
  kind: ClusterRole
  name: admin          # built-in admin role for namespace
  apiGroup: rbac.authorization.k8s.io

---
# NetworkPolicy: team-a cannot talk to team-b
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  namespace: team-a
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          team: team-a   # only from same namespace
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          team: team-a
  - ports:               # allow DNS
    - port: 53
      protocol: UDP
```

---

**Q48. A node in your cluster went NotReady. Walk through your complete investigation.**

What they're testing: node failure diagnosis

```bash
# Step 1: Identify the issue
kubectl get nodes
# node-3   NotReady   worker   5m

kubectl describe node node-3
# Look for: Conditions section
# Conditions:
#   Type             Status
#   Ready            False
#   MemoryPressure   True   ← out of memory
#   DiskPressure     False
#   PIDPressure      False

# Step 2: Check recent events
kubectl get events --field-selector \
  involvedObject.kind=Node,involvedObject.name=node-3

# Step 3: SSH to node (if accessible)
ssh ec2-user@node-3-ip

# On the node:
systemctl status kubelet
journalctl -u kubelet -n 100

# Check resources
free -h      # memory
df -h        # disk
top          # processes

# Step 4: Common causes:
# A. kubelet crashed/stopped
systemctl restart kubelet

# B. Out of disk space
du -sh /var/lib/docker/*  # find large directories
docker system prune       # clean up

# C. Out of memory
dmesg | grep -i "killed process"
# Find and kill memory-hogging processes

# D. Network issue (can't reach API server)
curl -k https://kubernetes-api-endpoint/healthz

# E. Certificate expired
openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -noout -dates

# Step 5: Cordon node while investigating
kubectl cordon node-3  # stop new pods being scheduled

# Step 6: Drain if maintenance needed
kubectl drain node-3 --ignore-daemonsets --delete-emptydir-data

# Step 7: Uncordon when healthy
kubectl uncordon node-3
```

---

**Q49. How do you implement pod priority and preemption in Kubernetes?**

What they're testing: advanced scheduling

```yaml
# PriorityClass definition
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical
value: 1000000       # higher = more important
globalDefault: false
description: "Critical production services"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high
value: 100000

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low
value: 1000
```

```yaml
# Assign priority to pods
spec:
  priorityClassName: critical  # this pod preempts lower priority pods
  containers:
  - name: api
    image: judicial-api:latest
```

```
How preemption works:
  High priority pod is Pending (no resources)
  Scheduler finds low priority pods on a node
  Evicts low priority pods to make room
  High priority pod scheduled

Built-in priorities:
  system-cluster-critical: 2000001000 (K8s system components)
  system-node-critical:    2000000000 (node-critical components)

Use cases:
  Critical: payment service, auth service
  High: API services
  Low: batch jobs, report generation
  Best-effort: dev/test workloads
```

---

**Q50. How do you debug and fix DNS resolution issues inside Kubernetes pods?**

What they're testing: K8s DNS troubleshooting

```bash
# Step 1: Test DNS from inside a pod
kubectl run dns-test \
  --image=busybox:1.28 \
  --restart=Never \
  --rm -it \
  -- nslookup kubernetes.default

# Expected output:
# Server: 10.96.0.10  ← CoreDNS ClusterIP
# Address: 10.96.0.10:53
# Name: kubernetes.default.svc.cluster.local

# Step 2: Test specific service DNS
kubectl exec my-pod -- nslookup my-service
kubectl exec my-pod -- nslookup my-service.production
kubectl exec my-pod -- nslookup my-service.production.svc.cluster.local

# Step 3: Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Step 4: Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Common DNS issues and fixes:

# Issue 1: DNS timeout (high latency)
# Node-level iptables conntrack table full
# Fix: enable NodeLocal DNSCache
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml

# Issue 2: NXDOMAIN for valid service
# Service in different namespace — use FQDN
nslookup service-name.other-namespace.svc.cluster.local

# Issue 3: Custom DNS not resolving
# Check dnsConfig in pod spec
spec:
  dnsConfig:
    nameservers:
    - 8.8.8.8
    searches:
    - production.svc.cluster.local
    - svc.cluster.local
    options:
    - name: ndots
      value: "5"

# Issue 4: DNS works sometimes (intermittent)
# Increase DNS replicas
kubectl scale deployment coredns -n kube-system --replicas=3
```

---

**Q51. You need to migrate a workload from one namespace to another with zero downtime. How do you do it?**

What they're testing: namespace migration strategy

```bash
# Strategy: run in parallel → shift traffic → cleanup

# Step 1: Deploy to new namespace
kubectl apply -f deployment.yaml -n new-namespace
kubectl apply -f service.yaml -n new-namespace

# Step 2: Verify new namespace pods are healthy
kubectl get pods -n new-namespace
kubectl rollout status deployment/my-app -n new-namespace

# Step 3: Update Ingress to route to new namespace
# If using cross-namespace service reference in Ingress:
# (Only supported with some Ingress controllers)
spec:
  rules:
  - host: app.company.com
    http:
      paths:
      - backend:
          service:
            name: my-app-svc
            port:
              number: 80
          # Note: Ingress must be in same namespace as service
          # Solution: create service in ingress namespace pointing to new-namespace

# Step 4: ExternalName service bridge
# Create ExternalName service in old namespace
# Points to new namespace service
apiVersion: v1
kind: Service
metadata:
  name: my-app-svc        # same name as before
  namespace: old-namespace
spec:
  type: ExternalName
  externalName: my-app-svc.new-namespace.svc.cluster.local
# Old namespace clients now transparently reach new namespace

# Step 5: Gradually move clients
# Update each client to use new namespace directly
# Once all clients updated: delete old namespace resources
```

---

**Q52. How do you implement pod security in Kubernetes to prevent privilege escalation?**

What they're testing: Pod Security Standards

```yaml
# Pod Security Standards (K8s 1.25+ — replaced PodSecurityPolicy)
# Apply to namespace level

# Enforce restricted policy on production namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

# Restricted policy requires:
# - No privileged containers
# - No privilege escalation
# - Non-root user
# - Seccomp profile
# - Drop ALL capabilities

# Compliant pod spec:
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    seccompProfile:
      type: RuntimeDefault
  
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE  # only if needed
    
    volumeMounts:
    - name: tmp
      mountPath: /tmp   # writable tmpfs for read-only root
  
  volumes:
  - name: tmp
    emptyDir: {}
```

---

**Q53. Your EKS cluster costs are unexpectedly high. How do you optimize?**

What they're testing: cost optimization

```bash
# Step 1: Identify cost drivers
# kubectl-cost plugin or AWS Cost Explorer

# Check node utilization
kubectl top nodes
# Low CPU/memory utilization → nodes oversized

# Check for idle/unused resources
kubectl get pvc -A | grep -v Bound  # unbound PVCs costing money
kubectl get svc -A | grep LoadBalancer  # each LB = ~$20/month

# Step 2: Right-size pods with VPA
kubectl apply -f vpa.yaml  # in recommendation mode
kubectl describe vpa my-app-vpa
# Shows recommended CPU/memory values

# Step 3: Use Spot instances for non-critical workloads
# Create spot node group
eksctl create nodegroup \
  --cluster my-cluster \
  --name spot-workers \
  --instance-types m5.large,m5.xlarge,m4.large \
  --spot

# Taint spot nodes
kubectl taint nodes -l node.kubernetes.io/capacity-type=SPOT \
  spot=true:NoSchedule

# Add toleration to batch/dev workloads

# Step 4: Cluster Autoscaler scale-to-zero
# Allow node groups to scale to 0 when no pods needed
# --scale-down-enabled=true
# --scale-down-unneeded-time=10m

# Step 5: Delete unused resources
kubectl delete pvc unused-data
# Remove LB services not in use
# Remove stale namespaces

# Step 6: Use Graviton (ARM) nodes (20% cheaper)
eksctl create nodegroup \
  --cluster my-cluster \
  --name arm-workers \
  --instance-types m6g.large  # Graviton2

# Step 7: Fargate for bursty workloads
# Pay per pod, not per node
# Expensive at constant load, cheap for spiky workloads
```

---

**Q54. How do you implement automated certificate management in Kubernetes?**

What they're testing: cert-manager in depth

```yaml
# cert-manager handles: issuance, renewal, rotation automatically

# ClusterIssuer for Let's Encrypt
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@judicialsolutions.in
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
    # HTTP-01 challenge (simpler)
    - http01:
        ingress:
          class: nginx
    # DNS-01 challenge (for wildcard certs)
    - dns01:
        route53:
          region: ap-south-1
          hostedZoneID: Z1234567890

---
# Certificate resource (explicit)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: judicial-cert
  namespace: production
spec:
  secretName: judicial-tls
  duration: 2160h      # 90 days
  renewBefore: 720h    # renew 30 days before expiry
  dnsNames:
  - judicialsolutions.in
  - "*.judicialsolutions.in"  # wildcard requires DNS-01
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

```bash
# Monitor certificate status
kubectl get certificates -A
# NAME           READY   SECRET         AGE
# judicial-cert  True    judicial-tls   5d

kubectl describe certificate judicial-cert
# Look for: Renewal Time, Not After

# Certificate automatically renewed by cert-manager
# No manual intervention needed

# Alert before expiry (in Prometheus):
# cert_manager_certificate_expiration_timestamp_seconds
# Alert if less than 14 days remaining
```

---

**Q55. Walk me through setting up a complete production EKS cluster from scratch.**

What they're testing: end-to-end Kubernetes operations

```bash
# Step 1: Create cluster
eksctl create cluster \
  --name judicial-prod \
  --region ap-south-1 \
  --version 1.29 \
  --nodegroup-name workers \
  --node-type m5.large \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 10 \
  --managed \
  --asg-access \
  --with-oidc

# Step 2: Install essential add-ons
# Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Cluster Autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=judicial-prod

# AWS Load Balancer Controller
helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=judicial-prod

# EBS CSI Driver (for PVC)
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster judicial-prod

# Step 3: Install Nginx Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Step 4: Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Step 5: Install monitoring
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Step 6: Set up namespaces and RBAC
kubectl create namespace production
kubectl create namespace staging

# Step 7: Configure network policies, resource quotas, limit ranges

# Step 8: Deploy ArgoCD for GitOps
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 9: Deploy applications via ArgoCD
# Point ArgoCD to your git repo
# It syncs everything automatically
```

---

## SECTION 5 — EXPERT (Q66–Q80)

---

**Q56. How does Kubernetes handle pod scheduling with multiple conflicting constraints?**

```
Scheduler evaluation order (simplified):

1. Filtering (hard constraints — removes ineligible nodes):
   - NodeSelector match
   - NodeAffinity required rules
   - Taints/Tolerations
   - Pod fits (enough CPU/memory)
   - Volume topology constraints
   - PodAntiAffinity required rules

2. Scoring (soft constraints — ranks remaining nodes):
   - NodeAffinity preferred weights
   - PodAffinity preferred weights
   - LeastRequestedPriority (prefer underutilized nodes)
   - BalancedResourceAllocation
   - ImageLocalityPriority (prefer nodes with image cached)
   - TopologySpread preferred

3. Highest score wins → pod scheduled there

If no nodes pass filtering:
  Pod stays Pending
  Cluster Autoscaler may add new node

Debugging scheduler decisions:
  kubectl describe pod pending-pod
  # Events show which predicates failed
  
  Enable scheduler verbose logging:
  --v=10 on scheduler for full decision tree
```

---

**Q57. What is the difference between Deployment, StatefulSet, DaemonSet, and Job? When do you use each?**

```
Deployment:
  Pods: interchangeable (random names)
  Scaling: horizontal, any number
  Updates: rolling update, rollback
  Storage: shared or no persistent storage
  Use for: stateless apps — APIs, web servers, workers
  Example: judicial-api, nginx, redis (cache, not persistence)

StatefulSet:
  Pods: unique stable identity (name-0, name-1)
  Scaling: ordered (0 before 1)
  Updates: ordered rolling
  Storage: each pod gets own PVC
  DNS: stable DNS per pod
  Use for: databases, distributed systems needing stable identity
  Example: postgres, kafka, elasticsearch, zookeeper

DaemonSet:
  Pods: one per node (always)
  New node: automatically gets pod
  Can't scale manually
  Use for: node-level agents
  Example: fluentd, prometheus node-exporter, calico, kube-proxy

Job:
  Pods: run to completion (exit 0)
  One-time or fixed number of completions
  Parallel execution supported
  Use for: batch processing, migrations, reports
  Example: db-migration, data-export, cleanup

CronJob:
  Job on a schedule (cron syntax)
  Use for: scheduled backups, nightly reports, cleanup
  Example: daily-backup, weekly-report
```

---

**Q58. Your cluster is doing a lot of unnecessary pod restarts. How do you find the root cause systematically?**

```bash
# Step 1: Find most restarting pods
kubectl get pods -A \
  --sort-by='.status.containerStatuses[0].restartCount' | tail -20

# Step 2: For each high-restart pod
kubectl describe pod high-restart-pod
# Check: Last State → Exit Code + Reason

# Exit Code meanings:
# 0   → App exited normally (not a daemon!)
# 1   → App error
# 137 → SIGKILL (OOMKilled)
# 139 → Segfault
# 143 → SIGTERM not handled properly
# 255 → General error

# Step 3: Get previous container logs
kubectl logs high-restart-pod --previous

# Step 4: Check if OOMKilled
kubectl get pod high-restart-pod -o json | \
  jq '.status.containerStatuses[].lastState.terminated'

# Step 5: Check liveness probe
kubectl describe pod | grep -A10 Liveness
# Is probe too aggressive? Is initialDelay too short?

# Step 6: Check resource limits
kubectl top pod high-restart-pod
# Is memory usage near limit? → increase limit or fix leak

# Step 7: Timeline analysis
kubectl get events --field-selector \
  involvedObject.name=high-restart-pod \
  --sort-by='.lastTimestamp'

# Step 8: Node-level check
# Is the NODE experiencing issues?
kubectl describe node <node-name> | grep -A5 Conditions
```

---

**Q59. How do you implement a service mesh with Istio for your microservices?**

```bash
# Install Istio
istioctl install --set profile=production

# Enable Istio sidecar injection for namespace
kubectl label namespace production \
  istio-injection=enabled

# Now all pods in production namespace get Envoy proxy sidecar
# Sidecar handles: mTLS, observability, traffic management

# Traffic management — canary with Istio VirtualService
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: judicial-api
spec:
  hosts:
  - judicial-api-svc
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: judicial-api-svc
        subset: v2            # canary users get v2
  - route:
    - destination:
        host: judicial-api-svc
        subset: v1
      weight: 90              # 90% to v1
    - destination:
        host: judicial-api-svc
        subset: v2
      weight: 10              # 10% to v2

# Automatic mTLS between all services
# No code changes needed — Istio handles it

# Observability: Istio generates metrics, traces automatically
# Install Kiali for service mesh visualization
kubectl apply -f \
  https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
```

---

**Q60. A critical production deployment is failing and you need to debug without impacting users. What's your approach?**

```bash
# Principle: never debug in production on live traffic
# Use isolated debugging techniques

# Technique 1: Debug specific pod without traffic
# Label the pod to remove from service rotation
kubectl label pod production-pod-xyz \
  debug=true \
  app=my-app-debug  # different from service selector
# Pod no longer receives traffic but keeps running

# Technique 2: Ephemeral debug container (K8s 1.23+)
kubectl debug -it production-pod-xyz \
  --image=ubuntu:22.04 \
  --target=api-container \
  --copy-to=debug-copy  # creates copy of pod for debugging
# Debug copy = same spec, not in service rotation

# Technique 3: Copy pod to debug namespace
kubectl get pod production-pod -o yaml | \
  sed 's/namespace: production/namespace: debug/' | \
  kubectl apply -f -

# Technique 4: Port-forward to debug interactively
kubectl port-forward pod/production-pod 8080:8080
# Access: http://localhost:8080 — your traffic only, not public

# Technique 5: Temporary debug deployment
kubectl create deployment debug \
  --image=my-app:broken-version \
  --replicas=1
# Not exposed via service — debug freely

# After debugging:
# Fix the issue, test in staging
# Deploy fix via normal CI/CD pipeline
# Remove debug resources
kubectl delete pod production-pod-xyz-debug
kubectl delete deployment debug
```

---

**Q61. How do you handle cluster upgrades in Kubernetes with zero downtime?**

```bash
# EKS upgrade process (safe approach):

# Step 1: Upgrade control plane first
eksctl upgrade cluster \
  --name judicial-prod \
  --version 1.30 \
  --approve

# Control plane upgraded, nodes still on 1.29
# This is safe — K8s maintains N-1 version compatibility

# Step 2: Upgrade node groups (one at a time)
# Add new node group with new version
eksctl create nodegroup \
  --cluster judicial-prod \
  --name workers-v130 \
  --version 1.30 \
  --node-type m5.large \
  --nodes 3

# Step 3: Cordon old node group (no new pods)
kubectl cordon -l alpha.eksctl.io/nodegroup-name=workers-v129

# Step 4: Drain old nodes one at a time
for node in $(kubectl get nodes -l alpha.eksctl.io/nodegroup-name=workers-v129 -o name); do
  kubectl drain $node \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --grace-period=60
  sleep 60  # wait for pods to settle on new nodes
done

# Step 5: Verify all pods moved to new nodes
kubectl get pods -o wide -A | grep workers-v129
# Should be empty

# Step 6: Delete old node group
eksctl delete nodegroup \
  --cluster judicial-prod \
  --name workers-v129

# Step 7: Upgrade add-ons
eksctl update addon \
  --name aws-ebs-csi-driver \
  --cluster judicial-prod

# Zero downtime because:
# PodDisruptionBudgets prevent too many pods evicted at once
# New nodes ready before old ones drained
# Rolling drain one node at a time
```

---

**Q62. How does etcd backup and restore work, and why is it critical?**

```bash
# etcd contains EVERYTHING:
# All pods, services, deployments, secrets, configmaps
# Cluster = etcd + nodes (nodes are replaceable, etcd is not)

# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save \
  /backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status \
  /backup/etcd-snapshot.db

# Schedule automated backup
# /etc/cron.d/etcd-backup:
0 */6 * * * root etcdctl snapshot save /backup/etcd-$(date +\%Y\%m\%d-\%H\%M\%S).db

# Restore from backup
ETCDCTL_API=3 etcdctl snapshot restore \
  /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore

# Update etcd manifest to use restored data
# /etc/kubernetes/manifests/etcd.yaml:
#   --data-dir=/var/lib/etcd-restore

# Restart kubelet
systemctl restart kubelet

# Best practices:
# - Backup before every cluster upgrade
# - Backup daily in production
# - Test restore procedure quarterly
# - Store backups in S3 (off-cluster)
# - Encrypt backups (contain all secrets)
```

---

**Q63. How do you implement multi-cluster management for disaster recovery?**

```
Architecture:
  Primary cluster: ap-south-1 (Mumbai)
  DR cluster:     ap-southeast-1 (Singapore)
  
  Active-Passive: all traffic to primary, DR on standby
  Active-Active:  traffic to both (complex — data consistency issues)

Tools:
  Velero:    backup/restore K8s resources + PVCs between clusters
  ArgoCD:    deploy same apps to multiple clusters from one git repo
  Istio:     service mesh spanning multiple clusters
  Submariner: cross-cluster pod networking

Velero backup/restore:

# Install Velero with S3 backend
velero install \
  --provider aws \
  --bucket judicial-backup-bucket \
  --backup-location-config region=ap-south-1 \
  --snapshot-location-config region=ap-south-1

# Schedule regular backups
velero schedule create daily \
  --schedule="0 2 * * *" \
  --include-namespaces production

# In DR scenario:
# 1. Get latest backup
velero get backups

# 2. Restore to DR cluster
velero restore create \
  --from-backup daily-20240322020000 \
  --include-namespaces production

# ArgoCD multi-cluster:
# Register DR cluster in ArgoCD
argocd cluster add dr-cluster-context

# Create ArgoCD ApplicationSet
# Deploys to BOTH clusters from same git
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
spec:
  generators:
  - list:
      elements:
      - cluster: primary
      - cluster: dr
  template:
    spec:
      destination:
        server: "{{cluster.server}}"
```

---

**Q64. Your Kubernetes deployment pipeline keeps failing intermittently with "resource version conflict". What is this and how do you fix it?**

```
Root cause:
  Kubernetes uses optimistic concurrency
  Every resource has a resourceVersion (monotonically increasing)
  When you update a resource, you must provide current resourceVersion
  If another process updates between your GET and your PATCH → conflict

Error: "the object has been modified; please apply your changes
        to the latest version and try again"

This happens when:
  Two CI/CD pipelines run simultaneously
  Controller reconciling same resource your pipeline is updating
  kubectl apply on same resource from two terminals

Fixes:

1. Retry with exponential backoff (application-level)
   for i in 1 2 3 4 5; do
     kubectl apply -f deployment.yaml && break
     sleep $((2 ** i))
   done

2. Use server-side apply
   kubectl apply --server-side -f deployment.yaml
   Server merges changes, no conflict possible

3. Use strategic merge patch
   kubectl patch deployment my-app \
     --type=strategic-merge-patch \
     --patch='{"spec":{"replicas":5}}'

4. Prevent parallel pipeline runs
   GitHub Actions: concurrency group prevents parallel runs
   concurrency:
     group: deploy-production
     cancel-in-progress: false  # queue, don't cancel

5. Use kubectl rollout for image updates (atomic)
   kubectl set image deployment/my-app \
     container=newimage:tag
   # Handles resourceVersion automatically
```

---

**Q65. Design a complete Kubernetes platform for a fintech company with 50 microservices.**

```
Architecture decisions:

Cluster topology:
  Production:    EKS multi-AZ, 3 zones, dedicated node groups
  Staging:       Separate cluster (not namespace — true isolation)
  Development:   Shared cluster, namespace per team

Node groups:
  System:        m5.large (3 nodes) — K8s system components
  General:       m5.xlarge auto-scaling 5-20 nodes
  Memory-opt:    r5.large (for in-memory DBs)
  Spot:          Mixed instances, spot, for batch

Namespace strategy:
  payments-prod, payments-staging
  auth-prod, auth-staging
  kafka, monitoring, ingress-nginx, argocd
  team-a, team-b (developer sandbox)

Networking:
  VPC: 10.0.0.0/16
  Pod CIDR: 172.16.0.0/16
  Service CIDR: 172.20.0.0/16
  CNI: Calico (NetworkPolicy support)
  Service Mesh: Istio (mTLS, observability, traffic management)

Security:
  Pod Security Standards: restricted for prod
  OPA/Kyverno: admission control policies
  Falco: runtime security (detect anomalous behavior)
  Secrets: AWS Secrets Manager + External Secrets Operator
  Image scanning: Trivy in CI, ECR scanning
  RBAC: team-scoped roles, minimal permissions

GitOps:
  ArgoCD: all deployments via git
  Branch → namespace mapping (main → prod, staging → staging)
  Sealed Secrets for credentials in git

Observability:
  Metrics: Prometheus + Grafana
  Logs: Fluent Bit → OpenSearch
  Traces: OpenTelemetry → Jaeger/Tempo
  Alerts: AlertManager → PagerDuty

DR:
  RPO: 1 hour (Velero backup to S3 hourly)
  RTO: 30 minutes (pre-provisioned DR cluster)
  Multi-region active-passive
  Database: RDS with read replica in DR region

CI/CD:
  GitHub Actions → build + test → ECR push
  ArgoCD → detects new image → deploys
  Rollback: git revert → ArgoCD reverts cluster
```

---

## QUICK REFERENCE — DEBUGGING COMMANDS

```bash
# The 6 commands you need for 90% of debugging

# 1. What's running?
kubectl get pods -A

# 2. Why is it failing?
kubectl describe pod <name>

# 3. What did it output?
kubectl logs <pod> --previous

# 4. What's inside?
kubectl exec -it <pod> -- sh

# 5. What events happened?
kubectl get events --sort-by='.lastTimestamp'

# 6. What resources is it using?
kubectl top pods

# BONUS: What did I break?
kubectl diff -f deployment.yaml

# BONUS: Undo everything
kubectl rollout undo deployment/my-app
```

### Pod Status Cheat Sheet

```
Pending          → Not scheduled (resources? nodeSelector? PVC?)
Init:0/1         → Init container running
ContainerCreating→ Image pulling or volume mounting
Running 0/1      → Container starting or readiness failing
CrashLoopBackOff → Container keeps crashing (check logs --previous)
OOMKilled        → Memory limit exceeded (increase limit or fix leak)
Error            → Container exited with non-zero (check logs)
Completed        → Exited 0 (normal for Jobs)
Terminating      → Being deleted (force: --grace-period=0 --force)
Evicted          → Node resource pressure evicted this pod
ImagePullBackOff → Can't pull image (name? credentials? registry?)
```

### Interview Answer Framework

```
For every scenario question, structure your answer as:

1. IDENTIFY   → What symptoms tell you about the problem?
2. DIAGNOSE   → What commands do you run? What do you look for?
3. ROOT CAUSE → What is the actual underlying issue?
4. FIX        → What exactly do you change?
5. PREVENT    → How do you stop this happening again?

Example (CrashLoopBackOff):
IDENTIFY:   kubectl get pods shows CrashLoopBackOff, restart count 5
DIAGNOSE:   kubectl logs pod --previous, kubectl describe pod
ROOT CAUSE: Exit code 137 = OOMKilled, memory limit 128Mi too low
FIX:        kubectl set resources deploy/api --limits=memory=512Mi
PREVENT:    VPA in recommendation mode, set proper limits from start
            Memory alert when pod approaches 80% of limit
```
