# DevOps Security Complete Guide
## Pod + Node + Container + Image + Infrastructure + Network Security
### Theory → Config → Commands → Interview Answers

---

## 📌 TABLE OF CONTENTS

| # | Section |
|---|---|
| 1 | [Container Security (Docker)](#1--container-security-docker) |
| 2 | [Image Security](#2--image-security) |
| 3 | [Pod Security (Kubernetes)](#3--pod-security-kubernetes) |
| 4 | [Node Security (EC2/EKS)](#4--node-security) |
| 5 | [Network Security (K8s)](#5--network-security-kubernetes) |
| 6 | [Secrets Management](#6--secrets-management) |
| 7 | [RBAC Deep Dive](#7--rbac-deep-dive) |
| 8 | [Infrastructure Security (AWS)](#8--infrastructure-security-aws) |
| 9 | [CI/CD Pipeline Security](#9--cicd-pipeline-security) |
| 10 | [Security Scanning Tools](#10--security-scanning-tools) |
| 11 | [Interview Q&A — 25 Questions](#11--interview-qa) |

---

## 1 — CONTAINER SECURITY (DOCKER)

### The Core Problem

```
Default Docker container:
  Runs as ROOT inside container
  Root in container = root on host (if container escapes)
  Full access to host filesystem via mounts
  Can make kernel calls that affect the host
  No resource limits → one container can starve others

Goal: containers should be as isolated and limited as possible
```

### Non-Root User — Most Important Rule

```dockerfile
# BAD — runs as root (default)
FROM python:3.12-slim
COPY app/ /app/
CMD ["python", "app.py"]

# GOOD — runs as non-root
FROM python:3.12-slim

# Create user with no shell, no home (system user)
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup \
            --no-create-home --shell /bin/false appuser

WORKDIR /app
COPY --chown=appuser:appgroup app/ /app/

# Switch to non-root before CMD
USER appuser

CMD ["python", "app.py"]
```

```bash
# Verify container is not running as root
docker run myimage whoami      # should NOT say "root"
docker run myimage id          # should show uid=1001

# Force non-root in docker run (even if image has root)
docker run --user 1001:1001 myimage
```

### Read-Only Filesystem

```bash
# Run container with read-only root filesystem
docker run --read-only myimage

# Problem: app needs to write somewhere (logs, tmp, cache)
# Solution: allow specific writable paths via tmpfs
docker run \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --tmpfs /app/logs:rw \
  myimage

# Why this matters:
# Attacker compromises app → tries to write malicious files
# Read-only filesystem → write fails → attack contained
```

### Linux Capabilities — Drop Everything

```
Linux capabilities: fine-grained privileges (not just root/non-root)
  CAP_NET_ADMIN:   configure network interfaces
  CAP_SYS_ADMIN:   many admin operations (very broad — avoid)
  CAP_CHOWN:       change file ownership
  CAP_SETUID:      change user ID
  CAP_SYS_PTRACE:  trace processes (debug injection)
  CAP_NET_RAW:     raw network packets (ping, packet sniffing)
  ...31 total capabilities

Default Docker: gives containers ~14 capabilities
Secure Docker: drop ALL, add back only what's needed
```

```bash
# Drop ALL capabilities (most secure)
docker run \
  --cap-drop ALL \
  myimage

# Drop all, add back only what's needed
docker run \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \   # only if binding port < 1024
  myimage

# Check what capabilities a running container has
docker inspect CONTAINER_ID | grep -i cap
```

### Seccomp — System Call Filtering

```
Seccomp = secure computing mode
Filters which Linux system calls a container can make
Blocks dangerous syscalls (even if attacker has root inside container)

Default Docker seccomp profile: blocks ~300 dangerous syscalls
Custom profile: even more restrictive

# Run with default seccomp (already applied by Docker)
docker run myimage

# Run with custom restrictive seccomp profile
docker run --security-opt seccomp=/path/to/profile.json myimage

# Disable seccomp (NEVER in production)
docker run --security-opt seccomp=unconfined myimage  ← BAD

# Common dangerous syscalls blocked:
# ptrace     → process tracing (debugger injection)
# kexec_load → load new kernel
# mount      → mount filesystems
# reboot     → reboot host
```

### No Privilege Escalation

```bash
# Prevent container process from gaining more privileges than parent
docker run \
  --security-opt no-new-privileges:true \
  myimage

# What this prevents:
# SUID binaries: binary that runs as file owner (not process owner)
# Example: su, sudo inside container
# With no-new-privileges: SUID binaries don't work → can't escalate

# In Dockerfile: don't install SUID binaries
RUN find / -perm /4000 -type f 2>/dev/null  # find SUID files
RUN chmod a-s /usr/bin/su                    # remove SUID bit
```

### Resource Limits

```bash
# Limit CPU and Memory (prevents DoS from one container)
docker run \
  --memory="512m" \           # hard memory limit
  --memory-swap="512m" \      # swap = same as memory = no swap
  --cpus="0.5" \              # max 0.5 CPU cores
  --pids-limit=100 \          # max 100 processes (prevent fork bomb)
  myimage

# Without limits:
# One buggy container → consumes all host memory → all containers crash
# One process → forks infinitely → PID table full → system unusable
```

### Minimal Base Image

```dockerfile
# Size comparison (and attack surface):
# ubuntu:latest    → 77MB, many packages, many CVEs
# debian:slim      → 75MB, fewer packages
# python:3.12      → 900MB (includes compiler, tools)
# python:3.12-slim → 130MB (fewer tools)
# python:3.12-alpine → 50MB (musl libc, minimal)
# distroless       → 20MB (no shell, no package manager)
# scratch          → 0MB (empty — only for static binaries)

# Less code = fewer CVEs = smaller attack surface

# Best practice for Python:
FROM python:3.12-slim AS builder
# ... install deps ...

FROM gcr.io/distroless/python3:nonroot AS runtime
# distroless: no shell, no package manager, no tools
# If attacker gets in → nothing to use → attack very limited
COPY --from=builder /app /app
```

---

## 2 — IMAGE SECURITY

### Image Scanning

```bash
# Trivy — most popular image scanner (free, open source)
trivy image myimage:latest

# Scan with severity filter (fail on CRITICAL)
trivy image --severity CRITICAL,HIGH --exit-code 1 myimage:latest

# Scan and output as JSON
trivy image --format json --output results.json myimage:latest

# Scan a tarball (air-gapped environments)
docker save myimage:latest | trivy image --input /dev/stdin

# Trivy output shows:
# Library:     requests
# Version:     2.25.0
# Severity:    HIGH
# CVE:         CVE-2023-32681
# Fixed in:    2.31.0
# Description: Unintended leak of Proxy-Authorization header

# Grype — alternative scanner
grype myimage:latest
grype myimage:latest --fail-on high

# ECR built-in scanning
aws ecr start-image-scan \
  --repository-name judicial-api \
  --image-id imageTag=latest

aws ecr describe-image-scan-findings \
  --repository-name judicial-api \
  --image-id imageTag=latest
```

### Image Signing (Supply Chain Security)

```bash
# Cosign — sign images to verify they haven't been tampered with
# Install cosign
brew install cosign

# Generate key pair
cosign generate-key-pair

# Sign image after push to ECR
cosign sign --key cosign.key \
  123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f

# Verify image before deployment
cosign verify --key cosign.pub \
  123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f

# In Kubernetes: use Kyverno or OPA Gatekeeper to enforce:
# "Only deploy images that have valid cosign signature"
# Any unsigned image → admission controller rejects pod

# SBOM (Software Bill of Materials)
# List of all components in your image
trivy image --format cyclonedx \
  --output sbom.json myimage:latest
# Submit to security team, compliance, vulnerability tracking
```

### Image Tag Strategy

```
NEVER use :latest in production

Reason: latest is mutable — points to different image tomorrow
        You don't know what you're deploying
        No rollback (latest is overwritten)

Use git SHA tag:
  myimage:abc1234f  ← deterministic, immutable, traceable
  
  git push → CI builds → tags with git SHA → pushes to ECR
  Kubernetes: image: judicial-api:abc1234f  ← always this exact code

ECR Image Lifecycle:
  Keep: last 20 tagged versions (for rollback)
  Delete: untagged images after 7 days (layer cache cleanup)
  Never delete: release tags (v1.0.0, v1.1.0)
```

### Dockerfile Security Best Practices

```dockerfile
# Complete secure Dockerfile
FROM python:3.12-slim AS builder

# Don't run pip as root (use --user)
WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# ─── runtime stage ───────────────────────────────────────────
FROM python:3.12-slim

# 1. Create non-root user
RUN groupadd --gid 1001 app && \
    useradd --uid 1001 --gid app \
            --no-create-home --shell /bin/false app

# 2. Copy only runtime deps (not build tools)
COPY --from=builder /root/.local /home/app/.local
COPY --chown=app:app src/ /app/src/

WORKDIR /app

# 3. Remove SUID/SGID bits from all binaries
RUN find / -xdev \( -perm /4000 -o -perm /2000 \) -type f -exec chmod a-s {} \; 2>/dev/null

# 4. Switch to non-root
USER app

# 5. Expose non-privileged port (> 1024)
EXPOSE 8080

# 6. No shell in CMD (use exec form — not shell form)
# Shell form: CMD python app.py   ← runs via /bin/sh -c (extra process)
# Exec form:  CMD ["python","app.py"] ← runs directly (SIGTERM works)
CMD ["python", "-m", "uvicorn", "src.main:app", \
     "--host", "0.0.0.0", "--port", "8080"]
```

---

## 3 — POD SECURITY (KUBERNETES)

### securityContext — The Most Asked Topic

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      # ── POD-LEVEL securityContext ──────────────────────────
      securityContext:
        runAsNonRoot: true          # reject if any container runs as root
        runAsUser: 1001             # run all containers as UID 1001
        runAsGroup: 1001            # run as GID 1001
        fsGroup: 1001               # volume files owned by this GID
        seccompProfile:
          type: RuntimeDefault      # apply default seccomp filter
        sysctls:                    # kernel parameters (careful)
        - name: net.core.somaxconn
          value: "1024"

      containers:
      - name: api
        image: judicial-api:abc1234f

        # ── CONTAINER-LEVEL securityContext ───────────────────
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          readOnlyRootFilesystem: true    # no writes to container fs
          allowPrivilegeEscalation: false # can't sudo/SUID inside
          capabilities:
            drop:
            - ALL                         # drop ALL Linux capabilities
            add:
            - NET_BIND_SERVICE            # ONLY add if binding port <1024

        # If readOnlyRootFilesystem=true, need writable dirs
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.cache

      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

### Pod Security Standards (PSS) — Replacing PSP

```
Kubernetes 1.25+: PodSecurityPolicy removed → Pod Security Standards

3 policy levels applied at NAMESPACE level:

privileged:  no restrictions (use for kube-system, monitoring)
baseline:    prevents known privilege escalations (minimum security)
restricted:  heavily restricted (production workloads)

3 enforcement modes:
enforce:  reject pods that violate
audit:    allow but log violations (warning)
warn:     allow but warn user in kubectl output

Apply to namespace:
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

What "restricted" requires:
  ✓ runAsNonRoot: true
  ✓ allowPrivilegeEscalation: false
  ✓ drop ALL capabilities
  ✓ seccompProfile set (RuntimeDefault or Localhost)
  ✓ No hostNetwork, hostPID, hostIPC
  ✓ No privileged containers
  ✓ volumes: only configMap, emptyDir, ephemeral, projected, secret, csi, persistentVolumeClaim
```

### OPA Gatekeeper / Kyverno — Policy as Code

```yaml
# Kyverno policy: deny privileged containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce    # Enforce = block, Audit = warn
  rules:
  - name: check-privileged
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          containers:
          - =(securityContext):
              =(privileged): false

---
# Kyverno: require non-root user
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: Enforce
  rules:
  - name: check-runasnonroot
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "Containers must not run as root"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true

---
# Kyverno: only allow images from your ECR
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registry
spec:
  validationFailureAction: Enforce
  rules:
  - name: check-registry
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "Only images from approved ECR registry allowed"
      pattern:
        spec:
          containers:
          - image: "123456789.dkr.ecr.ap-south-1.amazonaws.com/*"
```

### Admission Controllers — Security Gates

```
Admission controllers: intercept K8s API requests before storing in etcd
  MutatingAdmissionWebhook:   modify the request (add defaults)
  ValidatingAdmissionWebhook: accept or reject the request

Built-in important admission controllers:
  PodSecurity:        enforces Pod Security Standards
  NodeRestriction:    limits what kubelets can do
  LimitRanger:        enforces LimitRange policies
  ResourceQuota:      enforces ResourceQuota

Custom admission controllers (via webhooks):
  OPA Gatekeeper:     rego policies evaluated at admission time
  Kyverno:            YAML-based policies easier to write
  
Flow:
  kubectl apply → API Server → Admission Controllers → etcd → Scheduler

If admission controller rejects:
  kubectl apply returns error
  Pod never created
  Security policy enforced at entry point
```

---

## 4 — NODE SECURITY

### EKS Node Security

```
EC2 Node Security Checklist:

1. Minimal IAM role (node instance profile)
   Only what nodes need:
   AmazonEKSWorkerNodePolicy
   AmazonEKS_CNI_Policy
   AmazonEC2ContainerRegistryReadOnly
   NOT: AdministratorAccess, PowerUserAccess

2. No public IP on worker nodes
   Nodes in private subnets only
   ALB in public subnet
   Nodes never directly reachable from internet

3. Security Group for nodes (App-SG):
   Inbound: only from ALB-SG + control plane
   Inbound: node-to-node (for pod communication)
   NO: 0.0.0.0/0 on any port

4. SSM Session Manager instead of SSH
   No port 22 open
   All sessions logged to CloudWatch
   IAM controls who can access

5. Regular OS patching
   EKS Managed Node Groups: AWS handles patching
   Custom AMI: use SSM Patch Manager

6. IMDSv2 (Instance Metadata Service v2)
   Prevents SSRF attacks stealing instance credentials
   v1: curl http://169.254.169.254/... → works
   v2: requires token → SSRF attacks fail
```

```bash
# Enable IMDSv2 only (disable IMDSv1) on launch template
aws ec2 modify-instance-metadata-options \
  --instance-id i-1234567890 \
  --http-tokens required \          # REQUIRED = IMDSv2 only
  --http-put-response-hop-limit 1   # limit hops (containers can't reach IMDS)

# Hop limit 1: only EC2 itself can reach IMDS
# Pods (additional network hop) cannot reach IMDS
# Prevents pod from stealing node's IAM credentials
# Enforces IRSA usage for pods

# Verify IMDSv2 is set
aws ec2 describe-instances \
  --instance-ids i-1234567890 \
  --query 'Reservations[0].Instances[0].MetadataOptions'

# In EKS launch template (Terraform):
resource "aws_launch_template" "nodes" {
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}
```

### Falco — Runtime Security

```
Falco: open-source runtime security for containers and nodes
Monitors: system calls in real-time
Detects: unexpected/malicious behaviour AT RUNTIME

What Trivy can't catch (static) → Falco catches (runtime):
  Container trying to read /etc/shadow (password file)
  Unexpected shell spawned inside container
  kubectl exec into production pod
  Process writing to /tmp and executing it
  Outbound connection to unknown IP

Falco rules example:
  - rule: Shell in container
    desc: Shell spawned inside container
    condition: >
      spawned_process and
      container and
      proc.name in (shell_binaries)
    output: >
      Shell spawned in container
      (user=%user.name container=%container.name
       shell=%proc.name parent=%proc.pname)
    priority: WARNING

  - rule: Read sensitive file
    desc: Attempt to read sensitive file
    condition: >
      open_read and
      sensitive_files and
      container
    output: "Sensitive file opened for reading (file=%fd.name container=%container.name)"
    priority: ERROR

Deploy as DaemonSet (runs on every node):
  helm install falco falcosecurity/falco \
    --namespace falco \
    --create-namespace \
    --set falco.grpc.enabled=true \
    --set falco.grpc_output.enabled=true

Alerts sent to: Slack, PagerDuty, Elasticsearch
```

---

## 5 — NETWORK SECURITY (KUBERNETES)

### NetworkPolicy — Microsegmentation

```
Default K8s: all pods can reach all pods (no isolation)
NetworkPolicy: whitelist-based firewall between pods

Key concept: deny-all first, then explicitly allow

Without NetworkPolicy:
  Compromised frontend pod → can directly reach DB pod
  Attacker has unrestricted access to all services
  
With NetworkPolicy:
  Frontend → can ONLY reach API (explicitly allowed)
  API → can ONLY reach DB (explicitly allowed)
  DB → cannot initiate any connections
```

```yaml
# Step 1: Deny ALL traffic in namespace (default deny)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}        # applies to ALL pods in namespace
  policyTypes:
  - Ingress
  - Egress

---
# Step 2: Allow frontend → API only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: judicial-api           # applies to API pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: judicial-frontend  # only from frontend pods
    ports:
    - protocol: TCP
      port: 8080

---
# Step 3: Allow API → DB only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres               # applies to DB pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: judicial-api       # only from API pods
    ports:
    - protocol: TCP
      port: 5432

---
# Step 4: Allow egress to DNS (CoreDNS) — needed for all pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53

---
# Cross-namespace: allow monitoring namespace to scrape metrics
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

```bash
# Test NetworkPolicy is working
# From frontend pod: should reach API
kubectl exec -it frontend-pod -- nc -zv judicial-api 8080
# From frontend pod: should NOT reach DB
kubectl exec -it frontend-pod -- nc -zv postgres 5432
# Expected: connection refused or timeout

# Verify NetworkPolicies applied
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-all -n production

# Important: NetworkPolicy requires CNI that supports it
# AWS VPC CNI + Calico: supports NetworkPolicy
# Flannel alone: does NOT support NetworkPolicy
# Cilium: full support + eBPF-based (more powerful)
```

### mTLS — Service Mesh (Advanced)

```
mTLS (mutual TLS):
  Normal TLS: client verifies server identity
  mTLS: BOTH client and server verify each other
  
  Without mTLS: pod-to-pod traffic inside cluster is plaintext
  With mTLS: encrypted + authenticated between every service pair

Service mesh options:
  Istio:   most feature-rich, complex, Envoy sidecar per pod
  Linkerd: simpler, lighter, easier to operate
  Cilium:  eBPF-based, no sidecar, more efficient

What you get with service mesh:
  Automatic mTLS between all services
  Traffic observability (who calls who, latency per connection)
  Circuit breaking (stop calling failing service)
  Retries and timeouts (without code changes)
  Traffic splitting (canary at service mesh level)

Istio mTLS config:
  apiVersion: security.istio.io/v1beta1
  kind: PeerAuthentication
  metadata:
    name: default
    namespace: production
  spec:
    mtls:
      mode: STRICT    # reject all non-mTLS traffic
```

---

## 6 — SECRETS MANAGEMENT

### The Problem with Default K8s Secrets

```
kubectl create secret generic db-pass \
  --from-literal=password=MyPassword

Default K8s Secret:
  base64 encoded (NOT encrypted)
  echo "TXlQYXNzd29yZA==" | base64 -d  → MyPassword
  Anyone with etcd access → reads all secrets
  Anyone with kubectl get secret → reads with one command

More secure options:
  1. Encryption at rest (etcd encryption)
  2. External Secrets Operator + AWS Secrets Manager
  3. HashiCorp Vault
  4. Sealed Secrets (encrypted YAML committed to git)
```

### External Secrets Operator (Production Standard)

```yaml
# Setup: ESO syncs AWS Secrets Manager → K8s Secrets

# 1. Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# 2. Create ClusterSecretStore (connects to AWS)
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        jwt:                           # uses IRSA
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets

---
# 3. Create ExternalSecret (declares what to sync)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  refreshInterval: 1h                  # sync every hour (picks up rotations)
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials               # K8s Secret name created
    creationPolicy: Owner
  data:
  - secretKey: password                # key in K8s Secret
    remoteRef:
      key: judicial/prod/database      # path in Secrets Manager
      property: password               # JSON property in the secret
  - secretKey: username
    remoteRef:
      key: judicial/prod/database
      property: username

# 4. Pod uses the K8s Secret normally
# ESO handles: fetching, syncing, rotation pickup
# AWS Secrets Manager: actual encrypted storage + audit trail
```

### Vault Integration (Enterprise)

```
HashiCorp Vault:
  Dynamic secrets: generate short-lived DB credentials per request
  "Vault creates a DB user, gives it to pod, destroys after 1 hour"
  No static passwords anywhere
  Full audit: who requested which secret when

Vault Agent Sidecar:
  Sidecar container injects secrets as files into pod
  Secret never goes through K8s API (bypasses etcd)
  Auto-renews before expiry

  spec:
    containers:
    - name: api
      volumeMounts:
      - name: secrets
        mountPath: /run/secrets
        readOnly: true

    - name: vault-agent            # sidecar
      image: hashicorp/vault
      # Writes secrets to /run/secrets/db-password
      # App reads from file (not env var — more secure)

  volumes:
  - name: secrets
    emptyDir:
      medium: Memory               # in-memory only — never hits disk
```

### Secrets Best Practices

```
✅ DO:
  Use Secrets Manager or Vault for all credentials
  Reference secrets as files (not env vars — less leak risk)
  Set RBAC: only pods that need a secret can read it
  Enable rotation: Secrets Manager auto-rotates DB passwords
  Audit: CloudTrail logs every Secrets Manager access
  Use namespaced secrets (secret in prod namespace, not accessible from dev)

❌ DON'T:
  Commit secrets to git (use git-secrets or truffleHog to scan)
  Put secrets in environment variables in Dockerfile
  Use base64 encoding and call it encryption
  Give broad RBAC like: secrets, get, * (all secrets)
  Log secrets (add no_log: true in Ansible, use redaction in apps)

# Scan git history for accidentally committed secrets
truffleHog --regex --entropy=False https://github.com/myorg/repo
gitleaks detect --source . --report-format json
```

---

## 7 — RBAC DEEP DIVE

### Least Privilege Principle

```
Every principal (user, SA, role) should have:
  Only the permissions they need
  Nothing more
  Scoped to only the namespaces they need

Common mistake: giving broad access for convenience
  kubectl create clusterrolebinding dev-admin \
    --clusterrole=cluster-admin \
    --user=developer@company.com
  → Developer now has full control of entire cluster → very bad

Correct: give specific narrow permissions
```

```yaml
# Correct: developer can only read pods/logs in their namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]    # read-only
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]    # can see but not change
# No: secrets, configmaps with passwords, create/delete/patch

---
# CI/CD ServiceAccount: only what pipeline needs
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deploy-role
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch", "update"]  # only update images
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]             # check rollout status
# No: create/delete deployments, access secrets, cross-namespace
```

### Audit RBAC Regularly

```bash
# Who can do what in the cluster?
kubectl auth can-i --list --as developer@company.com
kubectl auth can-i --list \
  --as system:serviceaccount:production:judicial-api-sa \
  -n production

# Who has admin access? (dangerous to leave unreviewed)
kubectl get clusterrolebindings \
  -o json | jq '.items[] | 
  select(.roleRef.name=="cluster-admin") | 
  {name:.metadata.name, subjects:.subjects}'

# Find overly broad permissions
kubectl get roles,clusterroles -A \
  -o json | jq '.items[] | 
  select(.rules[].verbs[] == "*")' 

# Find SAs with no workloads (should be cleaned up)
kubectl get serviceaccounts -A \
  -o json | jq '.items[] | 
  select(.metadata.name != "default") | 
  .metadata.name'
```

### ServiceAccount Security

```yaml
# By default: every pod gets "default" SA with no permissions
# But "default" SA can be given permissions accidentally

# Best practice: create dedicated SA per application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judicial-api-sa
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/judicial-api-role
automountServiceAccountToken: false   # don't auto-mount SA token

# In pod: only opt-in to SA token when needed
spec:
  serviceAccountName: judicial-api-sa
  automountServiceAccountToken: true   # explicitly opt in
  
# Also: disable automount on default SA in every namespace
kubectl patch serviceaccount default -n production \
  -p '{"automountServiceAccountToken": false}'
```

---

## 8 — INFRASTRUCTURE SECURITY (AWS)

### VPC Security Architecture

```
Security layers in order (defence in depth):

Layer 1: AWS Organizations SCP
  "No account can disable CloudTrail"
  "No account can create public S3 buckets"
  Cannot be bypassed even by account admin

Layer 2: IAM
  Who can do what in AWS
  Least privilege per service
  OIDC for CI/CD (no stored keys)
  IRSA for pods (no node-level access sharing)

Layer 3: Network (VPC)
  Public subnet: ALB only
  Private subnet: EKS nodes only
  Data subnet: RDS/ElastiCache only
  No direct internet access to nodes or databases

Layer 4: Security Groups
  ALB-SG: allow 443 from internet
  App-SG: allow 8080 from ALB-SG only
  Data-SG: allow 5432 from App-SG only
  Principle: reference SGs not IP ranges (dynamic)

Layer 5: NACLs (optional extra layer)
  Block known malicious IP ranges
  Port-level restrictions at subnet level
  Stateless (must allow both directions)

Layer 6: WAF (Web Application Firewall)
  Attached to ALB or CloudFront
  Blocks: SQL injection, XSS, OWASP Top 10
  Rate limiting: block IP if > 2000 req/5min
  Geo-blocking: allow only Indian IPs (if required)

Layer 7: Application
  Auth: Cognito/JWT validation
  Input validation
  Parameterised queries (prevent SQL injection)
```

### GuardDuty — Threat Detection

```
GuardDuty: ML-based threat detection across your AWS account
Analyses: CloudTrail, VPC Flow Logs, DNS logs, EKS audit logs

What it finds:
  EC2:  instance communicating with known C2 (command & control) servers
        Instance conducting port scanning
        Cryptocurrency mining detected
        
  IAM:  credentials used from unusual location (India creds → Russia)
        Root account used (should never happen)
        API calls from TOR exit nodes
        
  EKS:  kubectl exec into containers unusual time
        Anonymous API access to K8s
        Pod launched with privileged container
        
  S3:   bucket publicly exposed
        Unusual data access pattern (mass download)

Enable GuardDuty:
  aws guardduty create-detector --enable --region ap-south-1

Respond to findings:
  GuardDuty finding → EventBridge → Lambda → auto-remediate
  
  Example auto-remediation:
  Finding: "EC2 instance communicating with C2 server"
  Lambda: isolate instance (replace SG with deny-all SG)
          snapshot the instance (for forensics)
          alert security team
          open incident ticket
```

### AWS Security Hub — Unified View

```
Security Hub: aggregates findings from all security services
  GuardDuty findings
  Inspector (EC2/ECR vulnerability scans)
  Macie (S3 sensitive data)
  IAM Access Analyzer
  Config Rules compliance

Compliance standards built-in:
  AWS Foundational Security Best Practices
  CIS AWS Foundations Benchmark
  PCI DSS
  NIST 800-53

Score: 0-100% across each standard
Failed controls: listed with severity and remediation guidance

Security Hub → EventBridge → Jira/Slack/PagerDuty
  Every new HIGH/CRITICAL finding → automatic ticket created
  SLA: HIGH = fix in 7 days, CRITICAL = fix in 24 hours
```

### IAM Security Hardening

```bash
# 1. Root account: lock it down
aws iam create-virtual-mfa-device --virtual-mfa-device-name root-mfa
# Enable MFA on root
# NEVER create access keys for root
# Only use root for: billing, account recovery, initial setup

# 2. Check for root access keys (should be none)
aws iam get-account-summary \
  --query 'SummaryMap.AccountAccessKeysPresent'
# Should return: 0

# 3. Find users with no MFA
aws iam list-users --query 'Users[*].UserName' --output text | \
  xargs -I{} aws iam list-mfa-devices --user-name {} \
  --query 'length(MFADevices)' 
# Any 0 = user with no MFA

# 4. Find unused credentials (rotate or delete)
aws iam generate-credential-report
aws iam get-credential-report --query 'Content' --output text | \
  base64 -d | grep "false\|N/A" 

# 5. Check for admin policies attached to users directly
# Better: use groups, not direct attachment
aws iam list-attached-user-policies --user-name developer

# 6. IAM Access Analyzer: find external access
aws accessanalyzer create-analyzer \
  --analyzer-name judicial-analyzer \
  --type ACCOUNT

aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:ap-south-1:ACCOUNT:analyzer/judicial-analyzer
# Shows: which resources are accessible from outside account
```

---

## 9 — CI/CD PIPELINE SECURITY

### Secure Pipeline Design

```
Security checks in pipeline — in order:

Pre-commit (developer machine):
  git-secrets: blocks commit if secrets detected
  pre-commit hooks: lint, format, basic checks

PR/Merge Request:
  SAST (Static Application Security Testing):
    Bandit (Python), Semgrep, SonarQube
    Scans source code for security issues
    SQL injection patterns, hardcoded secrets, weak crypto
  
  Dependency scanning:
    Safety (Python), npm audit, Snyk
    Scans requirements.txt/package.json for known CVEs
  
  IaC scanning:
    Checkov, tfsec, terrascan
    Scans Terraform for security misconfigurations
    "S3 bucket has public access", "SG allows 0.0.0.0/0"

Build:
  Docker build with non-root, minimal base image

Post-build image scan:
  Trivy: CVE scan of built image
  Fail pipeline on CRITICAL CVEs
  Block deployment if vulnerabilities found

Push:
  Only push to ECR if all scans pass
  Sign image with Cosign

Deploy:
  OIDC: no stored AWS credentials
  Environment protection: prod requires approval
  Verify image signature before deploy (Kyverno policy)
```

```yaml
# GitHub Actions secure pipeline
name: Secure CI/CD

on:
  push:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # full history for secret scanning

      # Scan git history for secrets
      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # SAST - static code analysis
      - name: SAST with Bandit (Python)
        run: |
          pip install bandit
          bandit -r src/ -f json -o bandit-report.json || true
          # Fail on HIGH severity
          bandit -r src/ --severity-level high

      # Dependency vulnerability scan
      - name: Dependency scan
        run: |
          pip install safety
          safety check -r requirements.txt

      # IaC security scan
      - name: Terraform security scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform
          soft_fail: false

  build-and-scan:
    needs: [security-scan]
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      security-events: write

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-south-1

      - uses: aws-actions/amazon-ecr-login@v2

      - name: Build image
        run: docker build -t ${{ env.IMAGE }} .

      # CVE scan BEFORE pushing
      - name: Image CVE scan (Trivy)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE }}
          format: sarif
          output: trivy.sarif
          severity: CRITICAL,HIGH
          exit-code: 1    # FAIL pipeline on critical CVEs

      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy.sarif

      # Only push if scan passed
      - name: Push to ECR
        run: docker push ${{ env.IMAGE }}

      # Sign the image
      - name: Sign image with Cosign
        uses: sigstore/cosign-installer@v3
        run: |
          cosign sign --key env://COSIGN_KEY ${{ env.IMAGE }}
        env:
          COSIGN_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
```

### Secrets in CI/CD — OIDC Pattern

```yaml
# NEVER do this:
env:
  AWS_ACCESS_KEY_ID: AKIA1234567890     ← stored credential, rotation needed
  AWS_SECRET_ACCESS_KEY: ${{ secrets.SECRET_KEY }}

# ALWAYS do this (OIDC):
permissions:
  id-token: write     # request OIDC token from GitHub

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-role
      aws-region: ap-south-1
      # No keys! GitHub exchanges OIDC token for temp credentials

# GitHub → AWS trust:
# IAM Role Trust Policy allows:
# token.actions.githubusercontent.com → for specific repo/branch
# Credentials last 1 hour → expire automatically
# Nothing to rotate, nothing to leak
```

---

## 10 — SECURITY SCANNING TOOLS

### Tool Reference

```
CATEGORY          TOOL              USE CASE
─────────────────────────────────────────────────────────────
Secret detection  gitleaks          Scan git repos for committed secrets
                  truffleHog        Deep git history secret scan
                  git-secrets       Pre-commit secret blocker

SAST (code)       Bandit            Python security linting
                  Semgrep           Multi-language SAST
                  SonarQube         Code quality + security
                  CodeQL            GitHub's SAST (free for OSS)

Dependencies      Safety            Python package CVE check
                  npm audit         Node.js package audit
                  Snyk              Multi-language SCA
                  Dependabot        GitHub auto-PR for vulnerable deps

Container image   Trivy             Image + filesystem + IaC scan
                  Grype             Anchore image scanner
                  Clair             CoreOS image scanner

IaC security      Checkov           Terraform/CloudFormation/K8s
                  tfsec             Terraform-specific
                  terrascan         Multi-IaC framework
                  kube-score        K8s manifest best practice check

Runtime           Falco             K8s/container runtime security
                  Sysdig            Commercial Falco + more
                  Tetragon          Cilium eBPF-based runtime

Compliance        kube-bench        CIS K8s Benchmark check
                  kube-hunter       K8s penetration testing
                  Polaris           K8s config best practices
```

```bash
# kube-bench — CIS Kubernetes Benchmark
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs -l app=kube-bench
# Checks: API server flags, etcd security, kubelet config, RBAC
# Reports: PASS/FAIL per CIS control

# Polaris — Kubernetes best practices
kubectl apply -f https://github.com/FairwindsOps/polaris/releases/latest/download/dashboard.yaml
# Dashboard shows: issues per namespace, severity, fix guidance

# kube-score — score your YAML files
kube-score score deployment.yaml
# Reports: missing resource limits, no readiness probe, runs as root, etc.

# Check your cluster for common misconfigurations
kubectl get pods --all-namespaces -o json | \
  jq '.items[] | 
  select(.spec.containers[].securityContext.runAsRoot == true) |
  {name: .metadata.name, ns: .metadata.namespace}'
```

---

## 11 — INTERVIEW Q&A

**Q1: How do you secure a Docker container?**
```
5 layers:

1. Non-root user:
   USER 1001 in Dockerfile
   runAsNonRoot: true in K8s securityContext

2. Read-only filesystem:
   --read-only in Docker
   readOnlyRootFilesystem: true in K8s
   Writable paths via emptyDir volumes

3. Drop ALL capabilities:
   --cap-drop ALL in Docker
   capabilities.drop: [ALL] in K8s
   Add back only what's needed (NET_BIND_SERVICE if port < 1024)

4. No privilege escalation:
   --security-opt no-new-privileges:true
   allowPrivilegeEscalation: false in K8s

5. Minimal base image:
   distroless or slim variant
   Reduces CVEs — less code = smaller attack surface

In production I also:
  Scan every image with Trivy before push
  Sign images with Cosign
  Enforce Pod Security Standards (restricted) at namespace level
```

**Q2: What is the difference between securityContext at pod vs container level?**
```
Pod-level securityContext:
  Applies to ALL containers in the pod
  Settings: runAsUser, runAsGroup, fsGroup, seccompProfile, sysctls

Container-level securityContext:
  Applies to ONE specific container
  Overrides pod-level settings for that container
  Settings: runAsUser, readOnlyRootFilesystem,
            allowPrivilegeEscalation, capabilities

Common pattern:
  Pod level: runAsNonRoot: true (enforce for all)
  Container level: readOnlyRootFilesystem: true (per container)
                   capabilities.drop: [ALL] (per container)
```

**Q3: How do you prevent pods from talking to each other in Kubernetes?**
```
NetworkPolicy — whitelist-based pod firewall

Step 1: Apply default-deny to namespace
  podSelector: {}  (all pods)
  policyTypes: [Ingress, Egress]
  (no rules = nothing allowed)

Step 2: Explicitly allow only what's needed
  frontend → API: allowed port 8080
  API → DB: allowed port 5432
  All pods → CoreDNS: allowed UDP 53

Without this: compromised frontend pod → can directly attack DB
With this: frontend can ONLY reach API, nothing else

Requires: CNI that supports NetworkPolicy (Calico, Cilium, not plain Flannel)
```

**Q4: What is IRSA and why is it better than node IAM role?**
```
Problem with node IAM role:
  All pods on same node share node's IAM permissions
  If node role has S3 access → ALL pods can access S3
  Compromised pod → steals node credentials → broad AWS access

IRSA (IAM Roles for Service Accounts):
  Each pod has its own IAM role via Kubernetes ServiceAccount
  judicial-api pod → judicial-api-role (S3 read, Secrets Manager)
  monitoring pod → monitoring-role (CloudWatch write only)
  
  How:
  1. EKS OIDC provider established
  2. IAM role trust policy: allows specific K8s SA
  3. SA annotated with role ARN
  4. K8s injects projected token into pod
  5. Pod → AWS STS: exchange K8s token for AWS creds
  6. Creds scoped to that role only

  Compromise one pod → only that pod's role → minimal blast radius
```

**Q5: How do you secure secrets in Kubernetes?**
```
Problem: default K8s secrets are base64 only (not encrypted)
Anyone with etcd access or broad RBAC can read all secrets

Solution (production):
  External Secrets Operator + AWS Secrets Manager
  
  1. Secrets stored in AWS Secrets Manager (properly encrypted, audited)
  2. ESO pod (has IRSA with SecretsManager:GetSecretValue) 
     syncs Secrets Manager → K8s Secret every hour
  3. Pod consumes K8s Secret as env var or mounted file
  4. Auto-rotation: Secrets Manager rotates DB password,
     ESO picks it up, K8s Secret updated, pod reads new value
  
  Also:
  - RBAC: only specific SAs can read specific secrets
  - resourceNames restriction: SA can only read "app-secrets" not all secrets
  - CloudTrail: every Secrets Manager access logged
  - No secrets in git (gitleaks prevents accidental commit)
```

**Q6: What is Pod Security Standards (PSS) and what does restricted mode enforce?**
```
PSS replaced PodSecurityPolicy in K8s 1.25
Applied at namespace level via labels

restricted mode requires:
  runAsNonRoot: true          → no root containers
  allowPrivilegeEscalation: false
  capabilities.drop: [ALL]   → no Linux capabilities
  seccompProfile: RuntimeDefault or Localhost
  No: hostNetwork, hostPID, hostIPC, hostPath volumes
  No: privileged: true

Apply:
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted

Violating pod → rejected at admission time
Works with Kyverno or OPA Gatekeeper for more custom policies
```

**Q7: How do you secure your CI/CD pipeline?**
```
4 key areas:

1. No stored credentials:
   OIDC for GitHub Actions → AWS (no access keys stored)
   Credentials auto-expire in 1 hour

2. Security gates in pipeline:
   Pre-commit: gitleaks (secret detection)
   PR: Bandit/Semgrep (SAST), Safety (dependency CVEs), Checkov (IaC)
   Build: Trivy (image CVE scan) — fail on CRITICAL
   Push: only if all scans pass + Cosign image signing

3. Least privilege for pipeline:
   CI/CD role: only deploy permissions (kubectl patch deployment)
   NOT: cluster-admin, IAM admin, delete permissions

4. Environment protection:
   Production: requires manual approval
   Separate AWS role for prod (different trust policy)
   No auto-deploy to prod from PR — only from main branch
```

**Q8: What is Falco and what does it detect?**
```
Falco: runtime security for containers and nodes
Monitors system calls at runtime using eBPF/kernel module

What static scanning (Trivy) misses → Falco catches:
  Shell spawned inside running container
    (someone ran kubectl exec and opened bash)
  Process reading /etc/shadow or /etc/passwd
  Outbound connection to unexpected external IP
  Sensitive file access (private keys, credentials)
  Privilege escalation attempt inside container
  New process spawned with elevated privileges

Runs as DaemonSet (on every node)
Outputs alerts to: Slack, PagerDuty, Elasticsearch, stdout

Interview answer structure:
"Trivy is static — scans before deployment
 Falco is dynamic — watches during runtime
 They complement each other:
 Trivy prevents known vulnerable images from deploying
 Falco catches unexpected behaviour of running containers"
```

**Q9: How do you implement defence in depth for a K8s cluster?**
```
Multiple independent layers — attacker must breach all:

Layer 1: Image security
  Non-root, minimal base, Trivy-scanned, Cosign-signed
  Only signed images from your ECR allowed (Kyverno policy)

Layer 2: Pod security
  Pod Security Standards: restricted namespace label
  securityContext: runAsNonRoot, readOnly, drop ALL caps
  No privileged containers, no hostPath

Layer 3: Network
  NetworkPolicy: deny-all + explicit allow
  mTLS between services (Istio/Linkerd)
  VPC: nodes in private subnet, DB in data subnet

Layer 4: RBAC
  Least privilege per ServiceAccount
  No cluster-admin for regular workloads
  IRSA: per-pod AWS permissions

Layer 5: Secrets
  External Secrets + Secrets Manager
  Rotation enabled
  RBAC restricts which pods can read which secrets

Layer 6: Runtime
  Falco: detect unexpected behaviour
  CloudTrail: log every AWS API call
  GuardDuty: detect threats in AWS environment

Layer 7: Supply chain
  Cosign image signing
  SBOM generation
  Only deploy from known-good registry
```

**Q10: Node was compromised — what do you do?**
```
Immediate response:

1. Isolate the node (stop new traffic)
   kubectl cordon node-1
   # Marks node unschedulable (no new pods land here)

2. Drain existing pods
   kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data
   # Moves pods to other nodes gracefully

3. Isolate at network level
   Change node security group to deny-all (quarantine)
   aws ec2 replace-iam-instance-profile → revoke all AWS permissions
   # Node can't call AWS APIs → can't exfiltrate data via cloud

4. Preserve evidence (before termination)
   Create EBS snapshot of node's volumes (for forensics)
   Capture: /var/log, running processes, network connections
   aws ec2 create-snapshot --volume-id vol-xxx --description "incident-NODEIP"

5. Terminate and replace
   aws ec2 terminate-instances --instance-ids i-xxx
   ASG creates replacement automatically

6. Investigate
   Review Falco alerts (what did attacker do?)
   Review CloudTrail (did node's role make unusual API calls?)
   Review VPC Flow Logs (what connections were made?)

7. Post-mortem
   How did attacker get in?
   What did they access?
   What policy/config prevents recurrence?
```

---

## QUICK REFERENCE — Security Checklist

### Docker Checklist
```
□ Non-root user (USER 1001)
□ Read-only filesystem (--read-only)
□ Drop ALL capabilities (--cap-drop ALL)
□ No privilege escalation (--no-new-privileges)
□ Resource limits (--memory, --cpus, --pids-limit)
□ Minimal base image (slim/distroless)
□ No secrets in image (use env vars or mounted secrets)
□ Trivy scan passes (no CRITICAL)
□ Image signed with Cosign
```

### Pod Security Checklist
```
□ runAsNonRoot: true
□ runAsUser: non-zero UID
□ readOnlyRootFilesystem: true
□ allowPrivilegeEscalation: false
□ capabilities.drop: [ALL]
□ seccompProfile: RuntimeDefault
□ No hostNetwork, hostPID, hostIPC
□ No privileged: true
□ Resource requests and limits set
□ Namespace has Pod Security Standard label (restricted)
```

### Network Security Checklist
```
□ Default-deny NetworkPolicy in every namespace
□ Explicit allow rules (whitelist only)
□ CoreDNS egress allowed (UDP 53)
□ Cross-namespace traffic explicitly allowed where needed
□ Monitoring namespace can scrape metrics
□ No 0.0.0.0/0 in NetworkPolicy (too broad)
```

### AWS Security Checklist
```
□ Root account: MFA enabled, no access keys
□ All human users: MFA enabled
□ No IAM users (use SSO/federated identity)
□ OIDC for CI/CD (no stored access keys)
□ IRSA for K8s pods (no node-level sharing)
□ IMDSv2 only (hop limit 1 for pods)
□ GuardDuty enabled in all regions
□ CloudTrail enabled in all regions
□ Security Hub enabled
□ VPC: nodes in private subnet, DB in data subnet
□ Security groups: reference SGs not IP ranges
□ WAF on ALB/CloudFront
□ S3: block public access (account level)
□ RDS: no public accessibility
□ Secrets Manager for all credentials
□ KMS encryption for RDS, S3, EBS
```
