# End-to-End Production Architecture
## How AWS + Docker + Kubernetes + GitHub Actions Connect
### From Developer Laptop → Production Application

---

## README

**This answers:** "How do AWS, Docker, Kubernetes, and GitHub Actions all connect
                  to run a real production application?"
**Approach:** Follow one feature from laptop → internet users
**Real example:** judicialsolutions.in (your live project)
**Target:** Mid-level to Senior DevOps/Cloud Engineer interviews

---

## 📌 TABLE OF CONTENTS

| # | Section |
|---|---|
| 1 | [The Big Picture — All Tools Connected](#part-1--the-big-picture) |
| 2 | [Layer 1 — Developer Writes Code](#part-2--layer-1-developer-writes-code) |
| 3 | [Layer 2 — GitHub Actions Kicks In](#part-3--layer-2-github-actions) |
| 4 | [Layer 3 — Docker Builds the Image](#part-4--layer-3-docker) |
| 5 | [Layer 4 — ECR Stores the Image](#part-5--layer-4-ecr) |
| 6 | [Layer 5 — Kubernetes Runs the App](#part-6--layer-5-kubernetes) |
| 7 | [Layer 6 — AWS Infrastructure Underneath](#part-7--layer-6-aws-infrastructure) |
| 8 | [Layer 7 — User Makes a Request](#part-8--layer-7-user-request-flow) |
| 9 | [What Happens When Things Break](#part-9--what-happens-when-things-break) |
| 10 | [Full Workflow — One Feature End to End](#part-10--full-workflow-one-feature) |
| 11 | [Interview Questions](#part-11--interview-questions) |

---

## PART 1 — THE BIG PICTURE

### Every Tool Has ONE Job

```
GITHUB          = where your code lives + triggers automation
GITHUB ACTIONS  = the automation engine (CI/CD pipeline)
DOCKER          = packages your app into a portable container image
ECR             = AWS's private storage for your Docker images
KUBERNETES      = runs and manages your containers at scale
AWS             = the physical infrastructure everything runs on

None of these tools can do the other's job.
They connect in a chain — output of one is input of next.
```

### The Connection Chain

```
YOU WRITE CODE
      │
      │  git push
      ▼
  GITHUB (stores code, triggers pipeline on push)
      │
      │  webhook → starts workflow
      ▼
  GITHUB ACTIONS (runs your pipeline steps)
      │
      │  docker build
      ▼
  DOCKER (builds image from your code + Dockerfile)
      │
      │  docker push
      ▼
  ECR (stores the built image in AWS)
      │
      │  kubectl set image
      ▼
  KUBERNETES (pulls image from ECR, runs it as pods)
      │
      │  schedules pods on...
      ▼
  AWS EC2 (physical servers where pods actually run)
      │
      │  exposes via...
      ▼
  AWS ALB (load balancer, routes internet traffic to pods)
      │
      │  responds to...
      ▼
  INTERNET USER (sees your running application)
```

### Visual — Everything Connected

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORLD                              │
│                                                                     │
│   Developer Laptop                                                  │
│   ┌─────────────────┐                                               │
│   │  VS Code        │  git push origin main                        │
│   │  Python/Node/Go │ ──────────────────────────────────►          │
│   │  Dockerfile     │                                    │          │
│   └─────────────────┘                                    │          │
│                                                          │          │
└──────────────────────────────────────────────────────────┼──────────┘
                                                           │
                                                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         GITHUB                                      │
│                                                                     │
│   Repository: adityagaurav13a/judicial-api                          │
│   Branch: main                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  src/          ← your Python/Go/Node code                   │  │
│   │  Dockerfile    ← how to package your app                    │  │
│   │  k8s/          ← Kubernetes YAML manifests                  │  │
│   │  .github/      ← GitHub Actions workflow files              │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                  │                                                  │
│   Push detected → GitHub Actions Workflow TRIGGERED                 │
└──────────────────┼──────────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS (CI/CD Engine)                    │
│                                                                     │
│   Runs on: ubuntu-latest runner (free VM spun up by GitHub)         │
│                                                                     │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐    │
│   │  BUILD   │→ │  TEST    │→ │  PUSH    │→ │ DEPLOY to EKS  │    │
│   │docker    │  │pytest    │  │ to ECR   │  │kubectl set img │    │
│   │build     │  │lint      │  │          │  │rollout status  │    │
│   └──────────┘  │trivy     │  └──────────┘  └────────────────┘    │
│                 └──────────┘                                        │
│                                                                     │
│   Secrets used:                                                     │
│   AWS_ROLE_ARN → OIDC → AWS (no stored keys)                       │
└────────────────────────────────────────────────────────┬────────────┘
                                                         │
                        ┌────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AWS CLOUD (ap-south-1)                         │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │   ECR (Elastic Container Registry)                          │   │
│  │   judicial-api:abc1234f   ← Docker image stored here        │   │
│  └─────────────────────────────────┬───────────────────────────┘   │
│                                    │ image pulled by EKS nodes      │
│  ┌─────────────────────────────────▼───────────────────────────┐   │
│  │   EKS (Elastic Kubernetes Service)                          │   │
│  │                                                             │   │
│  │   Control Plane (AWS managed):                              │   │
│  │   API Server ← kubectl commands land here                   │   │
│  │                                                             │   │
│  │   Data Plane (your EC2 nodes):                              │   │
│  │   AZ-1a: EC2 m5.large → [pod-1] [pod-2]                   │   │
│  │   AZ-1b: EC2 m5.large → [pod-3] [pod-4]                   │   │
│  │   AZ-1c: EC2 m5.large → [pod-5] [pod-6]                   │   │
│  └─────────────────────────────────┬───────────────────────────┘   │
│                                    │ pods registered as targets      │
│  ┌─────────────────────────────────▼───────────────────────────┐   │
│  │   ALB (Application Load Balancer)                           │   │
│  │   internet-facing, spans all 3 AZs                          │   │
│  │   SSL terminated here (ACM cert)                            │   │
│  └─────────────────────────────────┬───────────────────────────┘   │
│                                    │                                │
│  ┌─────────────────────────────────▼───────────────────────────┐   │
│  │   Supporting Services                                       │   │
│  │   RDS PostgreSQL ← pods query this (private subnet)         │   │
│  │   ElastiCache Redis ← pods cache here (private subnet)      │   │
│  │   S3 ← static files, uploads                                │   │
│  │   CloudWatch ← logs and metrics from pods                   │   │
│  │   Secrets Manager ← DB passwords                            │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                        │
                        ▼
                 INTERNET USER
            https://judicialsolutions.in
```

---

## PART 2 — LAYER 1: DEVELOPER WRITES CODE

### What the Developer Does

```
Developer writes a new feature: "Add priority field to cases"

Files changed:
  src/cases/models.py     ← added priority field
  src/cases/routes.py     ← added GET /cases?priority=high
  tests/test_cases.py     ← added tests for new endpoint
  migrations/V5.sql       ← ALTER TABLE cases ADD COLUMN priority INT

Developer runs locally:
  python -m pytest        ← all tests pass
  docker build -t api .   ← image builds locally
  docker run api          ← app starts, test manually

Then:
  git add .
  git commit -m "feat: add priority field to cases"
  git push origin main    ← THIS triggers everything
```

### The Dockerfile — Bridge Between Code and Container

```dockerfile
# Dockerfile — tells Docker HOW to package your app

# Stage 1: Build (has all build tools, large)
FROM python:3.12-slim AS builder
WORKDIR /build

# Install dependencies first (cached if requirements.txt unchanged)
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Copy source code (changes most often → last layer)
COPY src/ ./src/

# Stage 2: Runtime (minimal, only what's needed to RUN)
FROM python:3.12-slim AS runtime
WORKDIR /app

# Security: run as non-root user
RUN useradd --create-home --shell /bin/bash appuser

# Copy only what we need from builder
COPY --from=builder /root/.local /home/appuser/.local
COPY --from=builder /build/src ./src/

USER appuser

# What port the app listens on (documentation)
EXPOSE 8080

# Health check (Docker-level, before K8s probes)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# How to start the app
CMD ["python", "-m", "uvicorn", "src.main:app",
     "--host", "0.0.0.0", "--port", "8080"]
```

### How Docker Builds the Image

```
docker build -t judicial-api:abc1234f .

Docker reads Dockerfile top to bottom:
  Layer 1: FROM python:3.12-slim    → downloads base image (cached)
  Layer 2: WORKDIR /build           → creates directory
  Layer 3: COPY requirements.txt    → copies file
  Layer 4: RUN pip install          → installs packages (cached if no change)
  Layer 5: COPY src/                → copies your code (changes every build)
  Layer 6: FROM python:3.12-slim    → multi-stage: fresh base
  Layer 7: COPY --from=builder      → copies only what's needed
  Layer 8: USER appuser             → security: not root
  Layer 9: CMD [...]                → default start command

Result: judicial-api:abc1234f
  A portable package containing:
    Your code (src/)
    Python runtime
    All dependencies
    Start command
  
  Run it anywhere that has Docker:
    Your laptop: docker run judicial-api:abc1234f
    CI runner:   docker run judicial-api:abc1234f pytest
    Production:  Docker runs inside each K8s pod
```

---

## PART 3 — LAYER 2: GITHUB ACTIONS

### What Triggers GitHub Actions

```
You push code → GitHub receives the push → webhook fires

GitHub checks: .github/workflows/deploy.yml
Finds trigger:
  on:
    push:
      branches: [main]  ← this matches!

GitHub spins up a fresh Ubuntu VM (runner)
Runner has: git, docker, python, node, aws cli, kubectl
Runner clones your repo
Runner executes jobs defined in workflow
```

### How GitHub Actions Gets AWS Access (OIDC)

```
Old way (BAD):
  Store AWS_ACCESS_KEY_ID in GitHub Secrets
  Long-lived credentials → rotate every 90 days
  If GitHub is hacked → permanent AWS access

New way (OIDC — what you should use):
  GitHub is trusted as an Identity Provider by AWS
  
  Flow:
  1. GitHub Actions job starts
  2. Job requests JWT (JSON Web Token) from GitHub's OIDC endpoint
  3. JWT contains: repo name, branch, actor, expiry (15 min)
  4. Job sends JWT to AWS STS:
     "I'm GitHub Actions, here's my JWT, please give me credentials"
  5. AWS STS validates JWT signature with GitHub's public key
  6. AWS checks: does jwt.sub match the IAM role's trust policy?
     "repo:adityagaurav13a/judicial-api:ref:refs/heads/main" ✓
  7. AWS returns temporary credentials (valid 1 hour)
  8. Job uses these to: push to ECR, deploy to EKS
  
  No stored credentials anywhere.
  Every job gets fresh credentials that expire automatically.

GitHub Actions YAML:
  permissions:
    id-token: write        # allow requesting OIDC token

  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789:role/github-actions-role
        aws-region: ap-south-1
        # No access-key-id! OIDC handles it.

AWS IAM Role Trust Policy (one-time setup):
  {
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringLike": {
        "token.actions.githubusercontent.com:sub":
          "repo:adityagaurav13a/judicial-api:*"
      }
    }
  }
```

### What Each GitHub Actions Job Does

```
Job 1: build
  Checks out your code
  Sets image tag = first 8 chars of git commit SHA (e.g., abc1234f)
  Runs: docker build -t judicial-api:abc1234f .
  Saves tag as job output (passed to other jobs)

Job 2: test (3 parallel jobs)
  test-unit:     runs pytest, checks coverage >= 80%
  test-lint:     runs flake8, black, isort
  test-security: runs Trivy (scans Docker image for CVEs)

Job 3: push (only runs if all tests pass)
  Logs in to ECR: aws ecr get-login-password | docker login
  Pushes: docker push judicial-api:abc1234f
  Pushes: docker push judicial-api:latest
  Image now safely in ECR

Job 4: deploy-staging (only on main branch)
  Configures kubectl: aws eks update-kubeconfig --name judicial-staging
  Updates deployment: kubectl set image deployment/judicial-api judicial-api=...
  Waits: kubectl rollout status --timeout=5m
  Smoke test: curl https://staging.judicialsolutions.in/health

Job 5: deploy-production (requires manual approval)
  Same as staging but targets prod cluster
  Auto-rollback: kubectl rollout undo if smoke test fails
```

---

## PART 4 — LAYER 3: DOCKER

### What Docker Actually Does in This Chain

```
Docker's role: PACKAGING

Your app exists as:
  Python files (src/*.py)
  Dependencies (requirements.txt)
  Config files
  
Problem: "Works on my machine"
  Your laptop: Python 3.12, specific packages, RHEL-like OS
  CI runner:   Python 3.11, different packages, Ubuntu
  Production:  Amazon Linux, different packages
  → Different behaviour in different environments

Docker's solution: package EVERYTHING into one image
  Your code +
  Python 3.12 (exact version) +
  All packages (exact versions) +
  OS libraries +
  Start command
  = One image that runs identically EVERYWHERE

Docker image = shipping container for software
  Shipping container: wine from France, meat from Australia, electronics from China
    → All fit in same standard container
    → Ship loads any container without knowing contents
  
  Docker image: Python app, Java app, Go binary
    → All wrapped in standard image format
    → Kubernetes runs any image without knowing language

Image layers = efficiency
  Each RUN/COPY creates a layer
  Layers are cached (if unchanged, reuse cached layer)
  Multiple images share base layers (python:3.12-slim cached once)
  
  Build 1: all layers built (~5 min)
  Build 2: code changed → only last COPY layer rebuilds (~30 sec)
  This is why Dockerfile order matters:
    dependencies first (rarely change) → cached
    code last (changes every commit) → rebuilt
```

### Docker Image vs Docker Container

```
Image:     blueprint, static, stored in ECR
           like a class in programming

Container: running instance of an image
           like an object (instance of class)

One image → multiple containers
  judicial-api:abc1234f (image in ECR)
    → pod-1 running on node-1 (container)
    → pod-2 running on node-2 (container)
    → pod-3 running on node-3 (container)
  
  All 3 containers from same image
  Each container has its own:
    Memory space
    File system (but read-only from image, writable layer on top)
    Network interface
    Process space

In Kubernetes:
  Pod = one or more containers running together
  Container inside pod = Docker container running the image
  
  kubectl get pods → shows running containers
  kubectl exec -it pod-1 -- bash → you're inside the container
```

---

## PART 5 — LAYER 4: ECR

### What ECR Does

```
ECR = Elastic Container Registry
    = private Docker Hub, but inside your AWS account

Why not Docker Hub?
  Docker Hub: public (anyone can see your code)
  Docker Hub: rate limited (100 pulls/6hr for free)
  Docker Hub: outside AWS (data transfer costs, latency)
  
  ECR: private (only your AWS account + IAM permissions)
  ECR: no rate limits
  ECR: inside AWS (EKS pulls images over VPC network = fast, free)
  ECR: integrated with IAM (node role grants pull access)

How ECR fits in the chain:
  GitHub Actions (builder) → PUSHES image to ECR
  EKS nodes (runners) → PULLS image from ECR when pod starts

ECR repository:
  123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api
  ↑                              ↑             ↑
  your AWS account               region        repo name

Each image tagged:
  judicial-api:abc1234f  ← specific commit (immutable)
  judicial-api:main      ← latest from main branch (moves)
  judicial-api:latest    ← most recent build (moves)

Always deploy with the SHA tag (abc1234f) not latest
  SHA tag = deterministic, never changes, perfect for rollback
  latest = could point to different image tomorrow = dangerous
```

### ECR Lifecycle — Managing Image Storage

```
Without lifecycle policy: images pile up forever → costs money
  1 year of daily builds × 100MB each = hundreds of GB in ECR

ECR Lifecycle Policy (auto-delete old images):

{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 20 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Delete untagged images after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    }
  ]
}

Result: always have last 20 deployable images
        older images auto-deleted
        always keep last version for rollback
```

---

## PART 6 — LAYER 5: KUBERNETES

### What Kubernetes Does

```
Kubernetes' role: RUNNING + MANAGING containers at scale

Without Kubernetes (raw Docker on EC2):
  Problem 1: Docker runs ONE container per command
             You have 50 microservices → 50 manual docker run commands
             Node crashes → all containers on that node dead
             No automatic restart
  
  Problem 2: How do services find each other?
             Container IPs change on restart
             No built-in service discovery
  
  Problem 3: Load balancing
             Which server handles traffic?
             What if a container is unhealthy?
  
  Problem 4: Scaling
             Traffic spikes → manually ssh to 10 servers, docker run
  
Kubernetes solves all of this:
  Self-healing: pod crashes → K8s restarts it automatically
  Service discovery: stable DNS names (api-service.production.svc)
  Load balancing: Service routes to healthy pods automatically
  Scaling: HPA adds pods when CPU > 70%
  Rolling updates: replace pods one at a time (no downtime)
  Resource management: ensures no node is overloaded
  Multi-node: spreads pods across multiple EC2 instances
```

### How Kubernetes Connects to Docker and ECR

```
When you run:
  kubectl set image deployment/judicial-api judicial-api=ECR_URL/judicial-api:abc1234f

What happens step by step:

1. kubectl sends request to EKS API Server (control plane)
   API Server updates Deployment object in etcd:
   "desired image is now judicial-api:abc1234f"

2. Deployment Controller detects the change
   Creates new ReplicaSet with new image spec
   Old ReplicaSet still running (rolling update)

3. Scheduler assigns new pods to nodes
   Considers: available CPU/memory, topology spread, taints

4. kubelet on the target EC2 node receives pod spec
   kubelet talks to containerd (container runtime):
   "start this pod with image judicial-api:abc1234f"

5. containerd pulls the image from ECR
   Uses the EC2 node's IAM role to authenticate:
   Node role has: AmazonEC2ContainerRegistryReadOnly policy
   → allowed to pull any image from your ECR repositories
   Image pulled over AWS internal network (fast, free)

6. containerd starts the container
   Your Python/Go/Node app starts inside the container
   Container gets: VPC IP, mounted ConfigMaps/Secrets, env vars

7. kubelet runs readiness probe
   curl http://localhost:8080/health → must return 200
   
8. Once ready: pod IP added to Service endpoints
   Traffic now flows to new pod
   Old pod gracefully terminated

9. Repeat for each pod in rolling update
   Always maxUnavailable=0 → no downtime
```

### Kubernetes Objects and What They Do

```
Deployment:
  What: "I want N copies of this container, keep them running"
  Manages: ReplicaSet → manages pods
  Handles: rolling updates, rollback
  Your file: k8s/deployment.yaml

Service (ClusterIP):
  What: stable virtual IP + DNS name for a group of pods
  Handles: load balancing across pods, pod discovery
  Your file: k8s/service.yaml
  
  judicial-api-svc.production.svc.cluster.local → virtual IP
  Virtual IP → kube-proxy → one of the healthy pods

Ingress:
  What: routes external HTTP/HTTPS to internal Services
  On AWS: creates real ALB via AWS Load Balancer Controller
  Your file: k8s/ingress.yaml
  
  judicialsolutions.in/* → judicial-frontend-svc
  api.judicialsolutions.in/* → judicial-api-svc

ConfigMap:
  What: inject config into pods (non-sensitive)
  Contains: DB_HOST, REDIS_HOST, LOG_LEVEL, ENVIRONMENT
  Your file: k8s/configmap.yaml

Secret:
  What: inject sensitive data into pods
  Contains: DB_PASSWORD, REDIS_PASSWORD, JWT_SECRET
  Source: AWS Secrets Manager via External Secrets Operator
  Your file: k8s/external-secret.yaml

HPA:
  What: auto-scale pods based on CPU/memory/custom metrics
  Your file: k8s/hpa.yaml
  
  CPU > 65% → add pods
  CPU < 30% → remove pods (after 5 min cool-down)

PodDisruptionBudget:
  What: "never let fewer than N pods run during maintenance"
  Your file: k8s/pdb.yaml
  Protects: during node drain, rolling updates, CA scale-down
```

---

## PART 7 — LAYER 6: AWS INFRASTRUCTURE

### AWS is the Foundation Everything Runs On

```
Everything you've read so far runs ON AWS infrastructure.
AWS provides the actual physical servers, network, storage.

The layers:

AWS Data Center
  → Physical servers (CPU, RAM, disk, network)
     → EC2 instances (virtual machines on those servers)
        → EKS nodes (EC2 instances configured as K8s nodes)
           → Pods (containers on those nodes)
              → Your application (Python/Go/Node inside containers)

You don't manage: physical servers, hypervisor, hardware
You manage: EC2 instances (via EKS node groups)
EKS manages: what runs ON the EC2 instances (pod scheduling)
```

### AWS Services in the Chain and Their Role

```
SERVICE          ROLE IN THE CHAIN
─────────────────────────────────────────────────────────────
VPC              Your private network — everything runs inside
                 Subnets: public (ALB), private (pods), data (DB)

EC2              Physical nodes where pods run
                 Part of EKS managed node groups

EKS              Kubernetes control plane as a service
                 API Server, etcd, scheduler (AWS manages these)
                 You just pay $0.10/hr and use kubectl

ECR              Docker image registry inside AWS
                 Pods pull images from here (same network, fast)

ALB              Internet-facing load balancer
                 Created automatically by K8s Ingress + AWS LB Controller
                 Routes HTTPS → pods

RDS              Managed PostgreSQL
                 Your pods connect to this via private VPC routing
                 Multi-AZ, automatic backups, AWS handles operations

ElastiCache      Managed Redis
                 Pods connect for caching, sessions
                 AWS handles HA, backups

S3               Object storage
                 Stores: uploaded files, static assets, Terraform state,
                         ECR lifecycle, CloudWatch logs archive

Secrets Manager  Secure password/key storage
                 External Secrets Operator pulls from here → K8s Secrets
                 Rotation: AWS auto-rotates, pods get new secret automatically

CloudWatch       Logs and metrics
                 Pods send logs → CloudWatch Log Groups
                 Metrics: CPU, memory, request count, error rate
                 Alarms: notify Slack if error rate > 5%

Route53          DNS
                 judicialsolutions.in → ALIAS → ALB DNS name
                 TTL: 300 seconds (cache 5 min)

ACM              SSL certificates
                 Free, auto-renews, attached to ALB
                 ALB terminates HTTPS (decrypts), forwards HTTP to pods

IAM              Permissions for everything
                 IRSA: pod has AWS IAM role → can access S3, Secrets Manager
                 Node role: EC2 can pull from ECR
                 GitHub Actions role: OIDC → deploy to EKS
```

### How IAM Connects Everything (Permissions Chain)

```
Who needs permission to do what?

1. GitHub Actions → needs to push to ECR and deploy to EKS
   Solution: OIDC → GitHub Actions assumes github-actions-role
   Role permissions:
     ecr:GetAuthorizationToken
     ecr:BatchCheckLayerAvailability
     ecr:PutImage
     eks:DescribeCluster       ← to run aws eks update-kubeconfig
   K8s RBAC: github-actions user → ClusterRole with deploy permissions

2. EKS Nodes → need to pull images from ECR
   Solution: EC2 Node IAM Role has:
     AmazonEC2ContainerRegistryReadOnly
     AmazonEKSWorkerNodePolicy
     AmazonEKS_CNI_Policy

3. Pods → need to access Secrets Manager, S3, etc.
   Solution: IRSA (IAM Roles for Service Accounts)
   Each pod type has its own IAM role:
     judicial-api-role:
       secretsmanager:GetSecretValue  (for DB password)
       s3:GetObject, s3:PutObject     (for file uploads)
   
   kubernetes/serviceaccount + IAM role annotation:
     kubectl annotate sa judicial-api-sa \
       eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT:role/judicial-api-role
   
   Pod uses this SA → automatically gets these AWS permissions
   No access keys anywhere → OIDC between K8s and AWS

4. ALB → needs to describe EKS targets
   Solution: AWS Load Balancer Controller role
   ALB controller reads K8s Ingress → creates/updates real AWS ALB
```

---

## PART 8 — LAYER 7: USER REQUEST FLOW

### From Click to Response — Every Hop

```
User opens browser: https://judicialsolutions.in/cases

─── STEP 1: DNS (Route53) ────────────────────────────────────
Browser: "What IP is judicialsolutions.in?"
OS DNS cache: miss
Recursive resolver (8.8.8.8): miss
Route53 authoritative: "ALIAS → judicial-xxx.ap-south-1.elb.amazonaws.com"
Resolver: resolves ALB DNS → ALB IPs: [13.235.xx.xx, 65.0.xx.xx, 52.66.xx.xx]
Browser gets: 13.235.xx.xx (closest ALB IP)
Time: ~50ms (first time), ~0ms (cached, TTL=300s)

─── STEP 2: TCP Connection ───────────────────────────────────
Browser → 13.235.xx.xx:443 (ALB IP)
TCP 3-way handshake: SYN → SYN-ACK → ACK
Connection established
Time: ~10-30ms (Mumbai → Mumbai AWS = same city)

─── STEP 3: TLS Handshake ────────────────────────────────────
Browser: "I speak TLS 1.3, here are cipher suites"
ALB: "Using AES-256-GCM, here's my certificate"
Browser: validates cert (issued by ACM, signed by Amazon CA)
Both: derive session keys
All further communication: encrypted
Time: ~10ms (TLS 1.3 is 1 round trip)

─── STEP 4: HTTP Request reaches ALB ────────────────────────
GET /cases HTTP/2
Host: judicialsolutions.in
Authorization: Bearer eyJhbGc...
Cookie: session=abc123

ALB receives request (decrypted)
WAF checks: not in blocklist, not SQL injection, rate OK
ALB route rule: judicialsolutions.in/* → target group: judicial-frontend-svc
Target group: healthy pods [10.0.11.47, 10.0.12.89, 10.0.13.23]
ALB picks: 10.0.11.47 (least connections algorithm)

─── STEP 5: ALB → Pod (private subnet) ──────────────────────
ALB forwards request to pod IP: 10.0.11.47:3000
Traffic: stays within VPC (private network, no internet)
Pod: React frontend Nginx serving static files

─── STEP 6: React App → API Call ────────────────────────────
React loads in browser
React calls: GET https://api.judicialsolutions.in/api/cases
(New DNS lookup + TCP + TLS + HTTP for api.judicialsolutions.in)
ALB: routes api.judicialsolutions.in → judicial-api-svc
Picks pod: 10.0.12.89:8080

─── STEP 7: API Pod Business Logic ──────────────────────────
FastAPI receives: GET /api/cases
Middleware: validates JWT token (checks signature)
Handler:
  1. Check Redis cache (ElastiCache: 10.0.22.10:6379)
     Cache hit? Return cached JSON (1ms)
     Cache miss? Query database

  2. Query PostgreSQL (RDS: 10.0.21.5:5432)
     SELECT * FROM cases WHERE user_id = ? ORDER BY created_at DESC
     Result: list of 47 cases
     
  3. Store in Redis cache (TTL: 300 seconds)
  
  4. Return JSON response

─── STEP 8: Response flows back ─────────────────────────────
API pod → ALB → browser
ALB re-encrypts (HTTPS)
Browser receives: 200 OK + JSON data
React renders: list of 47 cases displayed to user

Total time: 200-400ms (first load, no cache)
            50-100ms  (with Redis cache hit)
```

---

## PART 9 — WHAT HAPPENS WHEN THINGS BREAK

### Scenario 1: Pod Crashes

```
What happens:
  judicial-api pod-3 crashes (OOMKilled — memory limit exceeded)
  
Timeline:
  T+0s:  Container exits with code 137
  T+0s:  kubelet on node-2 detects exit immediately
  T+1s:  kubelet marks pod as Failed
  T+1s:  Endpoint controller removes pod-3 from Service endpoints
  T+2s:  ALB health check: pod-3 not responding → removed from targets
  T+5s:  Pod-3 restarted by kubelet (CrashLoopBackOff if keeps failing)
  T+30s: If readiness probe passes → pod-3 re-added to targets

User impact: 0 (other pods handled traffic, pod-3 removed instantly)

Fix: increase memory limit in deployment
  kubectl set resources deployment/judicial-api \
    --limits=memory=1Gi
```

### Scenario 2: Node (EC2) Crashes

```
What happens:
  EC2 node-2 (ap-south-1b) crashes (hardware failure)

Timeline:
  T+0s:   Node stops responding
  T+0s:   ALB health checks: pods on node-2 start failing
  T+10s:  ALB removes pod-3, pod-4 from targets (health check fails)
  T+40s:  K8s node controller marks node as NotReady
  T+5min: K8s evicts pods from node-2 (NodeNotReady timeout)
  T+5min: Scheduler: creates replacement pods on node-1 and node-3
  T+6min: New pods start, pass readiness probes
  T+6min: New pods added to Service endpoints

User impact: ~10-30 seconds (ALB detection time) of slow responses
             Traffic rerouted to pods on node-1 and node-3

Cluster Autoscaler:
  CA sees: only 2 nodes, capacity reduced
  CA: provisions new EC2 in AZ-1b (~2-3 min)
  New node joins: scheduler places new pods
  Full capacity restored

Your design protected you:
  topologySpreadConstraints → pods were NOT all on node-2
  ALB health checks → automatic failover in seconds
  K8s → automatic pod rescheduling
```

### Scenario 3: Bad Deployment (App Bug)

```
What happens:
  You deploy v1.4.0 — has a bug that returns 500 on all requests

Timeline (GitHub Actions):
  T+0:   Pipeline deploys new image
  T+2m:  Rollout completes (rolling update — all pods now v1.4.0)
  T+2m:  Smoke test: curl /health → 200 (health endpoint works)
          Smoke test passes ← THIS IS THE WEAKNESS
  T+3m:  Real users hit /cases → 500 errors
  T+3m:  CloudWatch alarm fires (error rate > 5%)
  T+3m:  Slack alert: "Error rate 87% in production"

Response:
  Option A: Manual rollback (fastest)
    kubectl rollout undo deployment/judicial-api -n production
    Rollback time: 30-60 seconds
  
  Option B: CI/CD re-deploy previous tag
    git revert HEAD → push → pipeline runs → deploys v1.3.9
    Time: 8 minutes (your pipeline time)

Lesson: smoke test was too shallow
  Better: test actual business endpoints
    curl /api/cases → must return 200
    curl /api/cases/123 → must return 200
    Run a quick integration test suite in smoke test stage
```

### Scenario 4: Database Failure (RDS)

```
What happens:
  RDS primary in AZ-1a fails

Timeline:
  T+0s:   RDS primary becomes unreachable
  T+0s:   App pods: DB connections start failing
  T+5s:   Readiness probe: pods query DB as part of health check
           Pods start failing readiness → removed from ALB targets
           (if health check includes DB check)
  T+30s:  AWS detects RDS failure
  T+60s:  RDS standby (AZ-1b) promoted to primary
  T+60s:  RDS DNS endpoint updated (same endpoint, new IP)
  T+65s:  App pods reconnect to same DB endpoint (DNS resolves to new primary)
  T+70s:  Readiness probes pass again → pods re-added to ALB targets

User impact: 60-90 seconds of errors
             CloudWatch alarm fires, Slack alert sent

Better design (RDS Proxy):
  App → RDS Proxy (connection pooler) → RDS
  During failover: RDS Proxy handles reconnection transparently
  User impact: ~5 seconds (near-zero)
```

---

## PART 10 — FULL WORKFLOW: ONE FEATURE END TO END

### Following "Add Case Priority" Feature

```
Day 1: 09:00 — Developer starts feature

  git checkout -b feature/case-priority
  # writes code, tests, migration SQL

Day 1: 17:00 — Developer opens Pull Request

  git push origin feature/case-priority
  # GitHub PR created

  GitHub Actions triggers (on: pull_request):
    ✓ Unit tests (new priority field has tests)
    ✓ Lint checks pass
    ✓ Trivy scan: no new CVEs
    
  Team reviews PR, approves
  PR merged to main at 17:45

Day 1: 17:45 — Merge triggers full pipeline

  GitHub Actions triggers (on: push to main):

  17:45 — Job: BUILD starts
    Runner clones repo
    docker build -t judicial-api:f3a21b8c .
    Image layers: 4 cached, 2 rebuilt (requirements unchanged, code changed)
    Build time: 45 seconds (cached deps)

  17:46 — Jobs: TEST (parallel)
    test-unit:     pytest → 147 tests pass, 83% coverage ✓
    test-lint:     flake8, black → ✓
    test-security: Trivy → 0 CRITICAL, 2 HIGH (acceptable) ✓

  17:49 — Job: PUSH
    aws ecr get-login-password | docker login
    docker push judicial-api:f3a21b8c → uploaded to ECR
    docker push judicial-api:latest → also updated
    ECR: image confirmed ✓

  17:50 — Job: DEPLOY STAGING
    aws eks update-kubeconfig --name judicial-staging
    kubectl set image deployment/judicial-api \
      judicial-api=ECR/judicial-api:f3a21b8c -n production
    
    Rolling update begins:
      pod-4 (new) starts → readiness probe passes → added to endpoints
      pod-1 (old) gracefully terminated
      pod-5 (new) starts → ready → added
      pod-2 (old) terminated
      pod-6 (new) starts → ready → added
      pod-3 (old) terminated
    
    kubectl rollout status: "successfully rolled out" ✓
    Smoke test: curl https://staging.judicialsolutions.in/health → 200 ✓

  17:55 — Staging deployed ✓

  Slack notification:
    "✅ judicial-api:f3a21b8c deployed to staging"
    "🔗 https://staging.judicialsolutions.in"

Day 1: 18:00 — QA manually tests staging
  Tests: create case with priority → works ✓
  Tests: filter cases by priority → works ✓
  Tests: priority persists on refresh → works ✓
  QA approves

  Team lead goes to GitHub Actions
  Clicks "Review pending deployments" for production
  Clicks "Approve" ✓

  18:05 — Job: DEPLOY PRODUCTION
    aws eks update-kubeconfig --name judicial-prod
    
    DB migration runs first (Kubernetes Job):
      kubectl apply -f k8s/jobs/migrate-v5.yaml
      ALTER TABLE cases ADD COLUMN priority INT DEFAULT 0
      Job completes successfully ✓
    
    Rolling update (production):
      6 pods replaced one at a time
      maxUnavailable=0: always 6 pods serving traffic
      Each new pod: readiness probe passes before old one removed
      Zero downtime achieved ✓
    
    kubectl rollout status: "successfully rolled out" ✓
    
    Smoke tests:
      curl https://api.judicialsolutions.in/health → 200 ✓
      curl https://api.judicialsolutions.in/api/cases → 200 ✓
    
    Git tag created: release-f3a21b8c-20240322
    
    Slack notification:
      "✅ judicial-api:f3a21b8c PRODUCTION deployed"
      "🏷️ Tag: release-f3a21b8c-20240322"
      "⏱️ Deployed by: aditya at 18:12"

  Total time: code merged 17:45 → production 18:12 = 27 minutes
  Downtime: 0 seconds
```

### What Each Tool Did in This Feature

```
TOOL              WHAT IT DID FOR THIS FEATURE
─────────────────────────────────────────────────────────────────────
Git/GitHub        Stored code, managed PR review, triggered pipeline on merge
GitHub Actions    Ran build→test→push→deploy automatically in 27 minutes
Docker            Packaged new code with all dependencies into one image
ECR               Stored the image (judicial-api:f3a21b8c) safely in AWS
Kubernetes        Replaced old pods with new ones one-at-a-time (no downtime)
AWS EKS           Provided the K8s infrastructure (managed control plane)
AWS EC2           Physical servers where new pods actually ran
AWS ALB           Automatically routed traffic to healthy pods during update
AWS RDS           Stored the new priority column (zero-downtime migration)
AWS IAM/OIDC      Allowed GitHub to deploy to AWS without stored credentials
CloudWatch        Monitored error rates, no spike = deployment successful
Route53/ACM       Kept users on HTTPS throughout (transparent to feature)
```

---

## PART 11 — INTERVIEW QUESTIONS

**Q: Explain how all these tools — GitHub, Docker, Kubernetes, AWS — connect in a production deployment.**

```
"They form a chain where output of each tool is input of the next:

1. Developer pushes code to GitHub
   GitHub detects push → triggers GitHub Actions workflow

2. GitHub Actions is the orchestrator:
   Runs on a fresh Ubuntu VM (runner)
   Uses OIDC to get temporary AWS credentials (no stored keys)

3. Docker builds the image:
   Actions runner runs: docker build -t judicial-api:abc1234f .
   Image = code + runtime + dependencies packaged together
   This runs on the GitHub Actions runner (not your prod servers)

4. Image pushed to ECR (AWS image registry):
   docker push → stored in your private AWS registry
   EKS nodes can pull this over the internal AWS network (fast, free)

5. Kubernetes receives deploy command:
   kubectl set image deployment/judicial-api judicial-api=ECR_URL:abc1234f
   K8s schedules new pods on EC2 nodes
   EC2 nodes pull image from ECR
   New pods start, pass health checks
   Old pods gracefully terminated (rolling update = zero downtime)

6. AWS infrastructure underneath:
   EC2: physical servers running the pods
   ALB: routes internet traffic to healthy pods
   RDS: database the pods connect to
   VPC: private network keeping everything secure

7. User sends request:
   Route53 → ALB → Pod → RDS → response
   All within AWS private network except the first hop (internet → ALB)

The key insight: none of these tools overlap.
  GitHub = code storage + pipeline trigger
  GitHub Actions = automation runner
  Docker = packaging
  ECR = image storage
  Kubernetes = container orchestration
  AWS = physical infrastructure"
```

**Q: Why do you use OIDC instead of storing AWS credentials in GitHub?**

```
"Stored credentials (old way) have problems:
  Long-lived: if GitHub is compromised, attacker has permanent AWS access
  Rotation: must manually rotate every 90 days (often forgotten)
  Scope: one secret often shared across many jobs (too much access)

OIDC (modern approach):
  GitHub is trusted as Identity Provider by AWS
  Flow: GitHub generates short-lived JWT (15 min) →
        AWS STS validates JWT signature →
        AWS returns temporary credentials (1 hour) →
        Credentials used for the job →
        Credentials expire automatically

  Benefits:
    No stored credentials anywhere
    Credentials expire in 1 hour (even if leaked, useless quickly)
    Scoped per repository and branch
    Full audit trail in CloudTrail

This is what I use for judicialsolutions.in — zero stored AWS credentials in GitHub."
```

**Q: How does a pod get access to the database password securely?**

```
"Three layers working together:

Layer 1: AWS Secrets Manager
  DB password stored in Secrets Manager (encrypted, access logged)
  NOT in git, NOT in K8s YAML

Layer 2: External Secrets Operator
  K8s operator that syncs Secrets Manager → K8s Secret
  Runs in cluster, has IAM role to read from Secrets Manager
  Creates K8s Secret: 'app-secrets' in production namespace
  Refreshes every hour (picks up rotations)

Layer 3: Pod consumes K8s Secret as env var
  env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db_password
  
  K8s injects this as env var inside the container
  App reads: os.environ['DB_PASSWORD']

Layer 4: IRSA (IAM Roles for Service Accounts)
  External Secrets Operator pod has K8s ServiceAccount
  ServiceAccount annotated with IAM role ARN
  Role has: secretsmanager:GetSecretValue permission
  
  This is how the operator is allowed to read Secrets Manager
  No static AWS keys — OIDC between K8s and AWS (same as GitHub)

Chain: IAM Role → External Secrets → K8s Secret → Pod env var
       At no point is the password in git or CI/CD logs"
```

**Q: How do you achieve zero-downtime deployment end-to-end?**

```
"Zero downtime requires coordination across all layers:

GitHub Actions:
  Smoke test after staging before promoting to prod
  rollout status --timeout to detect failures
  Auto-rollback: if smoke test fails → kubectl rollout undo

Kubernetes:
  RollingUpdate: maxUnavailable=0 (never drop below desired count)
  maxSurge=1: temporarily run one extra pod
  minReadySeconds=30: new pod stable for 30s before old one leaves
  
Readiness probe:
  New pod only receives traffic after /health returns 200
  If app starts but isn't ready: pod not in LB rotation

preStop hook:
  sleep 15: gives ALB time to stop sending new requests to pod
  Pod finishes in-flight requests, THEN exits

ALB health checks:
  Check every 15 seconds
  Remove pod after 2 consecutive failures
  Re-add after 2 consecutive successes

Result:
  New pod created → health check passes → ALB adds it → gets traffic
  Old pod: preStop hook (15s) → drains connections → exits
  User: zero dropped requests throughout

This is what I implemented for judicialsolutions.in
  6 pods across 3 AZs
  Deployments happen daily with zero user impact"
```

---

## CHEAT SHEET — How Everything Connects

```
CODE → IMAGE → REGISTRY → CLUSTER → NODES → PODS → USERS

Tool mapping:
  CODE     = Git + GitHub (version control, collaboration)
  PIPELINE = GitHub Actions (automation, CI/CD)
  IMAGE    = Docker (packaging, build)
  REGISTRY = ECR (image storage in AWS)
  CLUSTER  = EKS (K8s control plane, managed by AWS)
  NODES    = EC2 (servers where pods run)
  PODS     = Your app containers (Docker running on K8s on EC2)
  NETWORK  = VPC + ALB + Route53 (routing traffic to pods)
  DATA     = RDS + ElastiCache (databases pods connect to)
  SECURITY = IAM + OIDC + Secrets Manager (permissions + secrets)
  OBS      = CloudWatch + Prometheus (monitoring everything)

Permission chain:
  GitHub → OIDC → AWS (to push images, deploy to EKS)
  EKS nodes → IAM Role → ECR (to pull images)
  Pods → IRSA → Secrets Manager/S3 (to get secrets, upload files)

Traffic chain:
  User → Route53 → ALB → Pod → RDS → User

Deployment chain:
  git push → Actions → docker build → ECR push → kubectl set image
  → K8s rolling update → new pods → readiness probe → ALB registers
  → old pods drain → zero downtime
```
