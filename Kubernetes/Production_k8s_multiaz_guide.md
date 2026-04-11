# Production Kubernetes — From Minikube to EKS
## How Pods Actually Run in Production + Multi-AZ Design + Downtime Tolerance
### Local Dev → Real World → Interview Ready

---

## README

**This doc answers:** "We run pods in Minikube locally — but where and how do they run in production?"
**Target level:** Mid-level to Senior DevOps/Cloud Engineer
**Your context:** Minikube (local fake shop project) + EKS (Capgemini production work)

---

## 📌 TABLE OF CONTENTS

| # | Section |
|---|---|
| 1 | [Minikube vs Production — The Core Difference](#part-1--minikube-vs-production) |
| 2 | [Where Pods Actually Run in Production](#part-2--where-pods-actually-run-in-production) |
| 3 | [EKS Architecture — How AWS Manages It](#part-3--eks-architecture) |
| 4 | [Multi-AZ Design — Surviving Zone Failures](#part-4--multi-az-design) |
| 5 | [Node Groups — What EC2s Run Your Pods](#part-5--node-groups) |
| 6 | [Downtime Tolerance — The Full Picture](#part-6--downtime-tolerance) |
| 7 | [Complete Production Architecture Diagram](#part-7--complete-production-architecture) |
| 8 | [Real World: judicialsolutions.in on EKS](#part-8--real-world-design) |
| 9 | [Cost vs Availability Tradeoffs](#part-9--cost-vs-availability-tradeoffs) |
| 10 | [Interview Questions](#part-10--interview-questions) |

---

## PART 1 — MINIKUBE vs PRODUCTION

### What Minikube Actually Is

```
Minikube = a fake single-node Kubernetes cluster on your laptop
           Control plane + worker node = SAME machine
           
Your laptop (Minikube):
┌─────────────────────────────────────────────────────────┐
│                  YOUR LAPTOP (1 machine)                │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │           MINIKUBE VM / CONTAINER                │  │
│  │                                                  │  │
│  │  Control Plane:     Worker Node:                 │  │
│  │  ┌─────────────┐    ┌───────────────────────┐   │  │
│  │  │ API Server   │    │ kubelet               │   │  │
│  │  │ etcd         │    │ kube-proxy            │   │  │
│  │  │ Scheduler    │    │ container runtime     │   │  │
│  │  │ Ctrl Manager │    │                       │   │  │
│  │  └─────────────┘    │  [Pod] [Pod] [Pod]    │   │  │
│  │                     └───────────────────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘

Everything on ONE machine (your laptop)
Restart laptop → everything gone
No real LoadBalancer (uses NodePort + minikube tunnel)
No real PersistentVolumes (uses local disk)
No multi-AZ (one machine = one AZ)
Fine for: learning, local development, testing YAML syntax
NOT for: real traffic, real users, data that matters
```

### What Production Kubernetes Looks Like

```
Production = multiple real servers spread across multiple data centers

AWS EKS Production (example with 3 AZs):
                                                        
  ┌────────────────────────────────────────────────────────────┐
  │                    AWS CLOUD (ap-south-1)                  │
  │                                                            │
  │   ┌──────────────────────────────────────────────────┐    │
  │   │           CONTROL PLANE (AWS managed)            │    │
  │   │   API Server + etcd + Scheduler + Ctrl Manager   │    │
  │   │   3 replicas across 3 AZs (AWS runs this for you)│    │
  │   └────────────────────┬─────────────────────────────┘    │
  │                        │                                   │
  │        ┌───────────────┼───────────────┐                  │
  │        │               │               │                   │
  │   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐             │
  │   │  AZ-1a  │     │  AZ-1b  │     │  AZ-1c  │             │
  │   │         │     │         │     │         │             │
  │   │ EC2     │     │ EC2     │     │ EC2     │             │
  │   │ node-1  │     │ node-2  │     │ node-3  │             │
  │   │(m5.lg)  │     │(m5.lg)  │     │(m5.lg)  │             │
  │   │         │     │         │     │         │             │
  │   │[Pod][Pod│     │[Pod][Pod│     │[Pod][Pod│             │
  │   └─────────┘     └─────────┘     └─────────┘             │
  │                                                            │
  └────────────────────────────────────────────────────────────┘

Each "node" = a real EC2 instance (a server in AWS data center)
Each AZ = different physical building with own power + cooling
Pods run INSIDE the EC2 instances
```

### Side-by-Side Comparison

```
Feature              Minikube (local)          EKS (production)
───────────────────────────────────────────────────────────────
Where it runs        Your laptop               Real EC2 servers in AWS
Control plane        Same machine as nodes     Separate, AWS-managed
Node count           1 (your laptop)           3-100+ real EC2 instances
Availability zones   1 (your laptop)           3 AZs (separate buildings)
LoadBalancer         Fake (minikube tunnel)    Real AWS ALB/NLB
Storage              Local disk                AWS EBS (block), EFS (file)
If machine dies      Everything lost           K8s reschedules pods to other nodes
Auto-scaling nodes   No                        Yes (Cluster Autoscaler)
Network              Docker/host network       AWS VPC with real routing
Cost                 Free                      ~$0.10/hr control plane + EC2 cost
Multi-AZ             No                        Yes (standard practice)
```

---

## PART 2 — WHERE PODS ACTUALLY RUN IN PRODUCTION

### Pods Run INSIDE EC2 Instances

```
Fundamental truth: Kubernetes doesn't create new machines
Kubernetes SCHEDULES containers onto existing machines (nodes)

A "node" in production = an EC2 instance (a Linux server)
The pod runs as a set of containers INSIDE that EC2 instance

Breakdown of ONE production node (EC2 instance):

EC2 Instance: m5.large (2 vCPU, 8 GB RAM)
└── Operating System: Amazon Linux 2 / Ubuntu
    └── Container Runtime: containerd
        ├── kubelet (talks to EKS control plane)
        ├── kube-proxy (manages network rules)
        └── Your Pods:
            ├── Pod: judicial-api-7d9f8-abc12
            │   └── Container: judicial-api (500m CPU, 512Mi RAM)
            ├── Pod: judicial-api-7d9f8-def34
            │   └── Container: judicial-api (500m CPU, 512Mi RAM)
            └── Pod: aws-node-xxxxx (system - CNI plugin)
```

### How a Pod Gets Onto a Specific Node

```
Step 1: You run: kubectl apply -f deployment.yaml
        Deployment says: "I want 6 pods of judicial-api"

Step 2: Deployment Controller creates 6 Pod objects in etcd
        Status: Pending (not scheduled yet)

Step 3: Scheduler looks at each pending pod:
        "Which node can run this pod?"
        Checks:
          - Does node have enough CPU/memory? (requests)
          - Does pod tolerate node's taints?
          - Does node match pod's nodeAffinity?
          - Does topology constraint allow it?
          - Is node in correct zone for PVC?
        
        Assigns: pod-1 → node-1 (AZ-1a)
                 pod-2 → node-2 (AZ-1b)
                 pod-3 → node-3 (AZ-1c)
                 pod-4 → node-1 (AZ-1a)
                 pod-5 → node-2 (AZ-1b)
                 pod-6 → node-3 (AZ-1c)

Step 4: kubelet on each node sees the assigned pod
        Pulls Docker image from ECR
        Starts the container
        Reports: pod is Running

Step 5: Pod gets IP from AWS VPC CNI
        Pod IP is a REAL VPC IP (e.g., 10.0.2.47)
        Any other resource in your VPC can reach it directly
```

### The VPC Network — How Pods Talk to Each Other

```
In Minikube: all pods on same fake network
In Production (EKS + AWS VPC CNI): 

Each pod gets a real VPC IP address
Same VPC → pods can talk to each other directly
Cross-AZ pod communication: works, but has small latency + cost

10.0.0.0/16 (your VPC)
├── 10.0.1.0/24 (public subnet AZ-1a) — ALB, NAT GW
├── 10.0.2.0/24 (private subnet AZ-1a) — EC2 nodes, pods
│   ├── 10.0.2.10  ← EC2 node-1 IP
│   ├── 10.0.2.47  ← Pod IP (judicial-api pod on node-1)
│   └── 10.0.2.48  ← Pod IP (another pod on node-1)
├── 10.0.11.0/24 (private subnet AZ-1b)
│   ├── 10.0.11.10 ← EC2 node-2 IP
│   └── 10.0.11.92 ← Pod IP (judicial-api pod on node-2)
└── 10.0.21.0/24 (private subnet AZ-1c)
    ├── 10.0.21.10 ← EC2 node-3 IP
    └── 10.0.21.55 ← Pod IP (judicial-api pod on node-3)

Pod on 10.0.2.47 can directly reach pod on 10.0.11.92
(cross-AZ — works but adds ~1ms latency and costs $0.01/GB)

Service (ClusterIP: 172.20.50.100) routes to all 3 pods
kube-proxy on each node manages the routing rules (iptables/IPVS)
```

---

## PART 3 — EKS ARCHITECTURE

### Control Plane vs Data Plane

```
EKS = Elastic Kubernetes Service

TWO separate planes:

CONTROL PLANE (AWS manages):
  What: API Server, etcd, Scheduler, Controller Manager
  Where: AWS-owned servers, NOT in your account
  HA: AWS runs 3 replicas across 3 AZs automatically
  Cost: $0.10/hour (fixed, regardless of cluster size)
  You: cannot SSH to it, don't patch it, don't worry about it
  
  AWS guarantees: 99.95% SLA on the control plane
  If control plane goes down: existing pods keep running!
                              You just can't deploy/scale/delete

DATA PLANE (you manage):
  What: EC2 nodes where pods actually run
  Where: YOUR AWS account, YOUR VPC
  HA: YOU configure multi-AZ node groups
  Cost: EC2 instance cost (your bill)
  You: must patch OS, choose instance types, manage node groups
  
  Managed Node Groups: AWS helps patch OS, you choose when
  Self-managed nodes: you do everything yourself
  Fargate: AWS manages nodes entirely (serverless pods)
```

### EKS Data Plane Options

```
Option 1: Managed Node Groups (most common)
  EC2 instances in an Auto Scaling Group
  AWS handles: node provisioning, OS patching, node updates
  You handle: instance type, size, min/max count, IAM role
  Your control: moderate
  Cost: EC2 pricing
  Good for: most production workloads

Option 2: Self-Managed Node Groups  
  EC2 instances you fully control
  You handle: everything (AMI, OS patches, K8s version updates)
  Your control: maximum
  Cost: EC2 pricing
  Good for: custom OS needs, specific AMI requirements
  Avoid for: most teams (too much overhead)

Option 3: AWS Fargate
  No EC2 instances — pods run on AWS-managed infrastructure
  Each pod gets dedicated micro-VM
  You handle: nothing at the node level
  Your control: minimal (no SSH, no node inspection)
  Cost: per vCPU/hour + per GB RAM/hour (more expensive)
  Good for: batch jobs, variable workloads, teams that hate node management
  Bad for: stateful workloads, daemonsets, large persistent volumes

Option 4: Karpenter (modern, replacing Cluster Autoscaler)
  Intelligent node provisioner
  Creates nodes of EXACTLY the right size for pending pods
  Mixed instance types: spot + on-demand, multiple sizes
  Faster than Cluster Autoscaler (seconds vs minutes)
  Cost optimization: right-sizes nodes automatically
```

### EKS Node Group Setup

```bash
# Create EKS cluster with eksctl (most common tool)
eksctl create cluster \
  --name judicial-prod \
  --region ap-south-1 \
  --version 1.29 \
  --with-oidc \                          # IRSA support
  --without-nodegroup                    # no default node group

# Create MULTI-AZ node group
eksctl create nodegroup \
  --cluster judicial-prod \
  --name workers-prod \
  --instance-types m5.large,m5.xlarge \ # multiple types for spot
  --nodes 3 \                           # 3 nodes initially
  --nodes-min 3 \                       # minimum
  --nodes-max 15 \                      # maximum (Cluster Autoscaler limit)
  --node-zones ap-south-1a,ap-south-1b,ap-south-1c \  # ALL 3 AZs
  --managed \                           # AWS manages OS patching
  --asg-access \                        # allow Cluster Autoscaler
  --external-dns-access \
  --full-ecr-access \                   # pull from ECR
  --alb-ingress-access                  # use AWS Load Balancer Controller
```

---

## PART 4 — MULTI-AZ DESIGN

### Why Multi-AZ? (The Real Reason)

```
AZ = Availability Zone = one physical data center building

One building has:
  Power systems
  Cooling systems
  Network connections
  Physical servers

What can go wrong with ONE building?
  Power outage (happens — even AWS has had AZ failures)
  Cooling failure (servers overheat → shutdown)
  Network equipment failure
  Physical disaster (flood, fire — rare but real)
  Planned maintenance

AWS SLA per AZ: NOT 100% — individual AZs DO go down
AWS SLA for multi-AZ: 99.99%+ (because multiple buildings must fail)

Rule: NEVER put all your production workloads in one AZ
      Design to survive ONE AZ going completely dark
```

### How to Design for Multi-AZ

```
Design principle: 
  Spread EVERYTHING across minimum 2 AZs (3 is standard)
  Any single AZ loss = cluster still runs (degraded but alive)

What to spread:
  EKS Nodes:           3 nodes in 3 AZs (1 per AZ)
  Application Pods:    2+ pods, spread across AZs
  NAT Gateways:        1 per AZ (not shared!)
  Load Balancer:       ALB spans all AZs automatically
  RDS:                 Multi-AZ (standby in different AZ)
  ElastiCache:         Multi-AZ replication
  EBS Volumes:         AZ-specific (pods move = volume can't follow!)
  EFS:                 Multi-AZ (better for K8s storage)
```

### Topology Spread — The Key Config

```yaml
# This is HOW you tell Kubernetes to spread pods across AZs
# Without this, scheduler might put all 6 pods in AZ-1a!

apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
spec:
  replicas: 6              # 6 pods total
  template:
    spec:
      # SPREAD ACROSS AVAILABILITY ZONES (primary HA requirement)
      topologySpreadConstraints:
      
      - maxSkew: 1                                   # max imbalance = 1 pod
        topologyKey: topology.kubernetes.io/zone     # spread by AZ
        whenUnsatisfiable: DoNotSchedule             # HARD — must spread
        labelSelector:
          matchLabels:
            app: judicial-api
        # Result: AZ-1a=2, AZ-1b=2, AZ-1c=2  (never 6-0-0)

      # ALSO SPREAD ACROSS INDIVIDUAL NODES (secondary)
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname           # spread by node
        whenUnsatisfiable: ScheduleAnyway             # SOFT — try to spread
        labelSelector:
          matchLabels:
            app: judicial-api
        # Result: each node gets ~2 pods

      # ANTI-AFFINITY (older approach, still used)
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: judicial-api
              topologyKey: topology.kubernetes.io/zone
```

### What Happens When AZ Goes Down

```
Before failure: 6 pods across 3 AZs
  AZ-1a: [api-pod-1] [api-pod-2]     ← 2 pods
  AZ-1b: [api-pod-3] [api-pod-4]     ← 2 pods
  AZ-1c: [api-pod-5] [api-pod-6]     ← 2 pods
  All 6 serving traffic via ALB

AZ-1a GOES DOWN (power outage in that building):
  
  Immediate (0-30 seconds):
    ALB health checks fail for pods in AZ-1a
    ALB STOPS routing traffic to AZ-1a targets
    Traffic automatically flows to AZ-1b and AZ-1c only
    Users may see brief errors (ALB detection time)

  Short term (30 seconds - 5 minutes):
    Node controller detects AZ-1a nodes are unreachable
    Pods in AZ-1a marked as Unknown/Terminating
    After 5 minutes: pods evicted

  Recovery (5-10 minutes):
    Scheduler creates new pods: 2 more in AZ-1b, 2 more in AZ-1c
    Cluster Autoscaler: AZ-1b and 1c nodes are now full?
    → CA provisions new nodes in AZ-1b and AZ-1c
    New pods scheduled on new nodes

  During all this:
    AZ-1b: 4 pods running         ← handles all traffic
    AZ-1c: 4 pods running
    Service still up at 67% capacity initially, then full capacity restored
    Users: brief slowness during failover, no complete outage

Key insight:
  ALB automatically removes unhealthy targets → traffic reroutes
  K8s eventually reschedules pods → full capacity restored
  The downtime is the ALB detection period (seconds) + pod startup (30-60s)
  Not the ENTIRE time AZ is down — just the detection window
```

### Multi-AZ for Different Components

```
STATELESS (your API pods) — easy:
  Replicas across AZs
  Any pod can handle any request
  AZ fails → other AZs handle traffic
  New pods created in healthy AZs

STATEFUL (databases) — harder:
  
  PostgreSQL (RDS Multi-AZ):
    Primary: AZ-1a
    Standby: AZ-1b (synchronous replication — no data loss)
    AZ-1a fails → automatic failover to AZ-1b in ~60 seconds
    You: update nothing — RDS DNS points to new primary automatically
    App: reconnects using same endpoint (brief connection drops)
  
  PostgreSQL (in Kubernetes StatefulSet):
    MUCH harder — you manage replication
    Primary pod in AZ-1a crashes → you need to promote a replica
    EBS volume is AZ-specific — can't move to another AZ automatically
    Recommendation: DON'T run production databases in K8s unless you know exactly what you're doing
                    Use RDS instead
  
  ElastiCache Redis (cluster mode):
    Primary in AZ-1a, replicas in AZ-1b and AZ-1c
    AZ-1a fails → replica promoted to primary automatically
    Brief cache miss window during failover (seconds)
  
  EBS Volumes:
    PROBLEM: EBS volumes are AZ-specific
    Pod with EBS volume in AZ-1a → pod MUST run in AZ-1a
    AZ-1a fails → pod can't move to AZ-1b (volume stuck in 1a)
    
    Solutions:
    a) Use EFS instead (multi-AZ by default, any pod can mount)
    b) Use ReadWriteOnce + accept you're AZ-locked
    c) Use cloud-native storage (databases) instead of raw EBS in K8s
```

---

## PART 5 — NODE GROUPS

### How Nodes Are Organized

```
A node group = a group of similar EC2 instances managed together
              backed by an AWS Auto Scaling Group (ASG)

Production typically has MULTIPLE node groups:

Node Group 1: "system" — for K8s system components
  Instance: m5.large (2 vCPU, 8 GB)
  Count: 3 (1 per AZ) — never scales to 0
  Purpose: CoreDNS, Cluster Autoscaler, monitoring
  Taint: dedicated=system:NoSchedule (only system pods go here)

Node Group 2: "general" — for most application pods
  Instance: m5.xlarge / m5.2xlarge (4-8 vCPU, 16-32 GB)
  Count: 3-20 (auto-scales with Cluster Autoscaler)
  Purpose: your application pods, APIs, workers
  No taint: any pod can go here

Node Group 3: "memory-optimized" — for memory-intensive apps
  Instance: r5.xlarge (4 vCPU, 32 GB) — more RAM than CPU
  Count: 0-10 (auto-scales)
  Purpose: Redis, ML inference, large caches
  Taint: workload=memory-optimized:NoSchedule

Node Group 4: "spot" — for fault-tolerant batch jobs
  Instance: mixed (m5.large, m4.large, m5a.large — multiple types)
  Capacity type: SPOT (70-90% cheaper, can be terminated)
  Count: 0-30 (scales for batch)
  Purpose: data processing, ML training, CI/CD jobs
  Taint: lifecycle=spot:NoSchedule
```

### Nodes and Pods — Resource Relationship

```
EC2 m5.large: 2 vCPU = 2000m CPU, 8 GB RAM = 8192 Mi

BUT not all is available for your pods:
  Reserved for system: ~100m CPU, ~512Mi RAM (kubelet, kube-proxy, OS)
  Allocatable:         ~1900m CPU, ~7680Mi RAM

Your pods on this node:
  Pod 1: requests 500m CPU, 512Mi RAM
  Pod 2: requests 500m CPU, 512Mi RAM
  Pod 3: requests 500m CPU, 512Mi RAM
  Pod 4: requests 300m CPU, 256Mi RAM

  Total used: 1800m CPU, 1792Mi RAM
  Remaining:   100m CPU, 5888Mi RAM

  5th pod requests 300m CPU, 512Mi RAM → fits (100m short on CPU though)
  
  If 5th pod requests 500m CPU → doesn't fit on this node
  → Scheduler looks at other nodes
  → If no node fits → pod stays Pending
  → Cluster Autoscaler sees Pending pod → provisions new node

kubectl describe node my-node | grep -A5 "Allocated resources"
# Shows exactly what's used vs available on each node
```

### Cluster Autoscaler in Action

```
Cluster Autoscaler (CA) = automatically adds/removes EC2 nodes

Scale UP trigger:
  Pod is Pending (can't fit on any existing node)
  CA sees: "pod needs 2 vCPU, 4 GB — no node has this free"
  CA calls AWS: "add 1 more m5.xlarge to the ASG in AZ-1b"
  AWS: provisions new EC2 (~2-3 minutes to boot and join cluster)
  Scheduler: places pending pod on new node
  
Scale DOWN trigger:
  Node utilization < 50% for 10 minutes
  Pods on it can be moved to other nodes
  CA: drains the node (moves pods with kubectl drain)
  CA calls AWS: "terminate this EC2 instance"
  Result: cost savings, no user impact

Why 10 minutes for scale-down:
  Traffic might return — don't terminate too aggressively
  Pod eviction takes time, need healthy destination nodes
  Configurable: --scale-down-unneeded-time=10m

CA respects:
  PodDisruptionBudgets: won't evict if it would violate PDB
  Pod priority: evicts lower priority pods first
  Node taints: only drains if pods can go elsewhere
```

---

## PART 6 — DOWNTIME TOLERANCE

### Types of "Downtime" in Kubernetes

```
1. Node failure (EC2 instance crashes or is terminated):
   Detection: ~40 seconds (kubelet heartbeat timeout)
   Pod eviction: after 5 minutes (default)
   Pod restart: ~30-60 seconds after eviction (image pull + startup)
   
   With multi-AZ + topology spread:
   ALB removes failing pods in seconds
   Remaining pods in other AZs serve all traffic
   New pods scheduled automatically
   User experience: brief slowness, not outage

2. Pod crash (your app crashes):
   Detection: immediate (process exit)
   Pod restart: in seconds (CrashLoopBackOff if keeps crashing)
   
   With multiple replicas:
   Other pods keep serving traffic while crashed pod restarts
   User experience: single request might fail (the one in-flight)

3. AZ failure (entire availability zone goes dark):
   Detection: ALB health checks fail (seconds)
   Traffic reroute: ALB automatically routes to other AZs (seconds)
   Pod eviction: 5 minutes
   New pod creation: 5-10 minutes (after eviction + scheduling)
   
   With multi-AZ design:
   Traffic continues on surviving AZs at reduced capacity
   Full capacity restored after pods reschedule
   User experience: brief latency spike during failover

4. Planned deployment (rolling update):
   maxUnavailable: 0 means NO pods removed until new ones are ready
   minReadySeconds: 30 means new pod stable 30s before old one leaves
   User experience: zero downtime (correctly configured)

5. Node drain (maintenance, CA scale-down):
   PodDisruptionBudget prevents too many pods evicted at once
   Pods gracefully moved to other nodes
   User experience: zero if PDB configured correctly
```

### PodDisruptionBudget — Protecting Your Service

```yaml
# PDB = "I don't care how many pods you evict, but never let it drop below N"

apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: judicial-api-pdb
  namespace: production
spec:
  # Option A: minimum available
  minAvailable: 2              # always keep AT LEAST 2 pods running
  
  # Option B: maximum unavailable (choose one)
  # maxUnavailable: 1          # allow at most 1 pod down at a time
  
  selector:
    matchLabels:
      app: judicial-api

# What this prevents:
#   kubectl drain node → pauses if evicting pod would violate PDB
#   Cluster Autoscaler scale-down → waits for safe eviction
#   Rolling update → respects PDB (even if deployment strategy allows more)

# Real example:
#   6 pods running, PDB minAvailable=4
#   Node drain starts: evicts pod-1 → 5 pods (OK, ≥ 4)
#   Evicts pod-2 → 4 pods (OK, exactly 4)
#   Evicts pod-3 → would be 3 pods (BLOCKED by PDB!)
#   Node drain waits... until rescheduled pods are running
#   Then continues: pod-3 evicted, new pod running → always ≥ 4

# Sizing rule:
#   replicas=6, PDB minAvailable=4 → allows 2 simultaneous disruptions
#   replicas=3, PDB minAvailable=2 → allows 1 simultaneous disruption
#   replicas=2, PDB minAvailable=2 → NOTHING can be evicted (avoid this)
```

### Resource Requests — Why They're Critical for Availability

```
Without resource requests:
  Scheduler places pods randomly (no capacity check)
  Multiple pods on one node → node runs out of memory
  OOMKiller kills pods to free memory → downtime

With resource requests:
  Scheduler only places pod if node has enough capacity
  Node never overloaded beyond what it promised
  Predictable, stable behavior

Without resource limits:
  One buggy pod consumes all memory → all pods on node suffer
  "Noisy neighbor" problem → your downtime caused by other team's bug

With resource limits:
  CPU: throttled if exceeds limit (slows down, doesn't die)
  Memory: OOMKilled if exceeds limit (your pod dies, others safe)
  Isolation: each pod's "blast radius" contained

Production minimum:
  ALWAYS set requests (for scheduling)
  ALWAYS set limits (for isolation)
  requests ≤ limits
  
  resource starvation → bad → requests
  noisy neighbor → bad → limits
```

### Full Reliability Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: production
spec:
  replicas: 6                 # enough to survive 1 AZ failure (6/3 * 2 = 4 pods)
  
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0       # never reduce below 6 during update
      maxSurge: 2             # add up to 2 extra pods during update
  
  minReadySeconds: 30         # new pod must be stable 30s before considered ready
  revisionHistoryLimit: 5     # keep 5 old ReplicaSets for rollback
  progressDeadlineSeconds: 600 # fail deployment if not done in 10 min
  
  selector:
    matchLabels:
      app: judicial-api
  
  template:
    metadata:
      labels:
        app: judicial-api
    spec:
      # Spread across AZs
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: judicial-api
      
      # Don't co-locate pods on same node
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: judicial-api
      
      # Graceful shutdown
      terminationGracePeriodSeconds: 60
      
      containers:
      - name: judicial-api
        image: judicial-api:1.2.3
        
        ports:
        - containerPort: 8080
        
        # Resource guarantees (CRITICAL for availability)
        resources:
          requests:
            cpu: "300m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        
        # Readiness: pod only gets traffic when truly ready
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 5
          successThreshold: 2   # must pass twice
          failureThreshold: 3   # fail 3 times → remove from LB
        
        # Liveness: restart if pod hangs
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        
        # Graceful shutdown hook
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
              # 15s for ALB to stop sending traffic
              # Then pod handles remaining in-flight requests
              # Then exits

---
# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: judicial-api-pdb
  namespace: production
spec:
  minAvailable: 4             # with 6 replicas: tolerate loss of 2 AZ worth
  selector:
    matchLabels:
      app: judicial-api

---
# HPA — auto-scale pods
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
  minReplicas: 6             # never go below 6 (2 per AZ)
  maxReplicas: 30            # scale up to 30 (10 per AZ)
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60   # scale before hitting limit
```

---

## PART 7 — COMPLETE PRODUCTION ARCHITECTURE

### Full Stack Architecture

```
Internet Users
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ROUTE53 (DNS)                                │
│    judicialsolutions.in → CloudFront distribution               │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                 CLOUDFRONT (CDN)                                │
│  /static/* → S3 (cached, global edge)                          │
│  /api/*    → ALB origin (not cached)                           │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│            APPLICATION LOAD BALANCER (ALB)                      │
│            Multi-AZ by default                                  │
│            Health checks every 10s per target                   │
│            AZ-1a ←→ AZ-1b ←→ AZ-1c (all zones)               │
└──────────┬─────────────────────┬────────────────────┬──────────┘
           │                     │                    │
    ┌──────▼──────┐       ┌──────▼──────┐     ┌──────▼──────┐
    │    AZ-1a    │       │    AZ-1b    │     │    AZ-1c    │
    │             │       │             │     │             │
    │ EC2 Node-1  │       │ EC2 Node-2  │     │ EC2 Node-3  │
    │ m5.xlarge   │       │ m5.xlarge   │     │ m5.xlarge   │
    │             │       │             │     │             │
    │ [api-pod-1] │       │ [api-pod-3] │     │ [api-pod-5] │
    │ [api-pod-2] │       │ [api-pod-4] │     │ [api-pod-6] │
    │ [sys-pods]  │       │ [sys-pods]  │     │ [sys-pods]  │
    └──────┬──────┘       └──────┬──────┘     └──────┬──────┘
           │ (private subnet)    │                   │
           └──────────────┬──────┘───────────────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
    ┌─────────▼──────────┐  ┌────────▼──────────┐
    │  RDS PostgreSQL     │  │  ElastiCache Redis │
    │  Multi-AZ           │  │  Multi-AZ          │
    │  Primary: AZ-1a     │  │  Primary: AZ-1b    │
    │  Standby: AZ-1b     │  │  Replica: AZ-1c   │
    └────────────────────┘  └───────────────────┘

EKS Control Plane: AWS-managed, 3 replicas, 99.95% SLA
NAT Gateways: 1 per AZ (nat-gw-1a, nat-gw-1b, nat-gw-1c)
VPC Endpoints: S3, DynamoDB (no NAT GW needed for these)
```

### Traffic Flow — Request by Request

```
User requests GET https://api.judicialsolutions.in/cases

1. DNS: Route53 → CloudFront IP (nearest edge)
2. CloudFront: /api/* → not cached → forward to ALB
3. ALB: receives request, checks health of targets
        routes to healthy pod: judicial-api-pod-3 (AZ-1b, IP: 10.0.11.92)
4. Pod: processes request, needs data
        queries: PostgreSQL on 10.0.20.5 (RDS in AZ-1a, private subnet)
        queries: Redis cache on 10.0.21.100 (ElastiCache)
5. Pod: returns JSON response to ALB
6. ALB: returns to CloudFront
7. CloudFront: returns to user (with appropriate headers)

If pod-3 is being updated (rolling update):
  ALB sees pod-3 readiness probe failing
  ALB routes to pod-1, pod-2, pod-4, pod-5, pod-6 instead
  User: doesn't notice (request goes to different pod)

If AZ-1b is down:
  ALB: pod-3, pod-4 health checks fail → removed from targets
  ALB: all traffic to pod-1, pod-2 (AZ-1a) + pod-5, pod-6 (AZ-1c)
  K8s: reschedules 2 new pods in AZ-1a and AZ-1c after 5 min
  User: brief slowness during failover, then normal
```

---

## PART 8 — REAL WORLD DESIGN

### judicialsolutions.in — How to Design This on EKS

```
Requirements:
  Legal case management platform
  Real users: lawyers, judges, clerks
  Availability target: 99.9% (43 min downtime/month allowed)
  No sensitive data loss
  India users (ap-south-1)

Infrastructure Design:

EKS Cluster:
  Region: ap-south-1 (Mumbai)
  AZs: ap-south-1a, ap-south-1b, ap-south-1c

Node Groups:
  system-ng:  t3.medium × 3 (1 per AZ) — system pods
  app-ng:     m5.large × 3-10 (auto-scales) — your API pods
  
Pods:
  judicial-api: 3 replicas minimum (1 per AZ)
  HPA: scales to 9 on traffic spikes (court deadline days)
  
Ingress:
  AWS Load Balancer Controller → creates real ALB
  SSL terminated at ALB (ACM certificate, auto-renews)
  
Database:
  RDS PostgreSQL t3.medium, Multi-AZ
  NOT in Kubernetes (use managed RDS)
  
Cache:
  ElastiCache Redis (for sessions, case list cache)
  
Storage:
  S3: document storage (PDFs, court orders)
  EFS: if pods need shared file storage

Cost estimate (ap-south-1):
  EKS control plane: $0.10/hr = $72/month
  3 × m5.large:      $0.096/hr each = $207/month
  RDS t3.medium Multi-AZ: ~$80/month
  ElastiCache cache.t3.micro: ~$25/month
  ALB:               ~$20/month
  NAT GW (3 AZs):    ~$100/month
  ─────────────────────────────
  Total:             ~$500/month
  
  Vs: running equivalent on EC2 directly → similar cost
  But: K8s gives you self-healing, rolling updates, auto-scaling
```

### Actual Deployment Config for judicialsolutions.in

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: judicial-prod
  labels:
    environment: production
    pod-security.kubernetes.io/enforce: restricted

---
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: judicial-prod
spec:
  replicas: 3                 # 1 per AZ to start
  selector:
    matchLabels:
      app: judicial-api
  template:
    spec:
      serviceAccountName: judicial-api-sa   # IRSA → AWS permissions
      
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: judicial-api
      
      terminationGracePeriodSeconds: 60
      
      containers:
      - name: judicial-api
        image: ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc12345
        
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        
        env:
        - name: DB_HOST
          value: "judicial-prod.cluster-xxxxxxxxx.ap-south-1.rds.amazonaws.com"
        - name: ENVIRONMENT
          value: "production"
        
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 5
        
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

---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: judicial-api-hpa
  namespace: judicial-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: judicial-api
  minReplicas: 3
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 65

---
# pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: judicial-api-pdb
  namespace: judicial-prod
spec:
  minAvailable: 2             # always keep at least 2 pods
  selector:
    matchLabels:
      app: judicial-api

---
# ingress.yaml (using AWS Load Balancer Controller)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: judicial-ingress
  namespace: judicial-prod
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip    # route directly to pod IPs
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:...
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
spec:
  rules:
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
```

---

## PART 9 — COST vs AVAILABILITY TRADEOFFS

### Minimum vs Recommended vs High Availability

```
Setup 1: Minimum (not for real production)
  Nodes: 1 node in 1 AZ
  Pods: 1 replica
  Cost: ~$80/month (1x m5.large)
  Availability: ~95% (node dies = complete outage)
  Downtime tolerance: NONE

Setup 2: Basic Production
  Nodes: 2 nodes in 2 AZs
  Pods: 2 replicas (1 per AZ)
  PDB: minAvailable=1
  Cost: ~$160/month (2x m5.large)
  Availability: ~99.5% (one node can fail)
  Downtime tolerance: 1 node, not 1 AZ

Setup 3: Recommended Production
  Nodes: 3 nodes in 3 AZs (auto-scales 3-10)
  Pods: 3+ replicas with topology spread
  PDB: minAvailable=2
  HPA: scale on traffic
  Cost: ~$240-800/month (3-10x m5.large)
  Availability: ~99.9%+ (one full AZ can fail)
  Downtime tolerance: 1 complete AZ failure

Setup 4: High Availability
  Nodes: 6+ nodes (2 per AZ, auto-scales 6-30)
  Pods: 6+ replicas (2 per AZ minimum)
  PDB: minAvailable=4
  Multi-region: active-active or active-passive
  Cost: $1000+/month
  Availability: 99.99%+
  Downtime tolerance: 1 AZ + partial 2nd AZ failure

Rule of thumb:
  99.9% SLA → 3 nodes, 3 AZs, 3 replicas minimum
  99.99% SLA → 6+ nodes, 3 AZs, 6 replicas, consider multi-region
```

### Smart Cost Saving Without Losing Availability

```
1. Spot instances for non-critical pods
   Spot: 70-90% cheaper, can be interrupted with 2-min warning
   
   Use spot for: batch jobs, non-prod environments, stateless workers
   Don't use spot for: databases, stateful apps, critical API pods
   
   Mix: 2 on-demand (baseline) + N spot (scale-out)
   If spot interrupted: on-demand handles traffic while spot restarts
   
   eksctl: --capacity-type SPOT

2. Right-size your nodes
   Monitor: kubectl top nodes → see actual utilization
   If 2 vCPU node using only 0.3 vCPU → downsize to t3.small
   VPA: automatically recommends right-size
   Compute Optimizer (AWS): gives EC2 right-sizing recommendations

3. Scale to zero for non-prod
   Dev/staging: scale node group to 0 at night and weekends
   KEDA: scale pods to 0 when no traffic
   Savings: 40-50% on dev environments

4. Graviton nodes (ARM-based EC2)
   20% cheaper than x86 for same performance
   m6g.large vs m5.large: same vCPU/RAM, 20% cheaper
   Requires: multi-platform Docker images (linux/amd64 + linux/arm64)

5. Reserved Instances for baseline nodes
   3 baseline nodes always running → 1-year RI → 40% discount
   Scale-out nodes on on-demand/spot
```

---

## PART 10 — INTERVIEW QUESTIONS

**Q: "We run pods in Minikube locally. In production, where exactly do the pods run?"**

```
"In production on AWS, pods run inside EC2 instances.

Minikube is a single-machine simulation — your laptop runs both
the control plane and the worker node.

In production with EKS:
  Control plane: AWS-managed (you don't see or manage these servers)
                 API Server, etcd, Scheduler — run by AWS, 99.95% SLA
  
  Data plane: YOUR EC2 instances in YOUR VPC
              Each EC2 = a 'node' in Kubernetes
              Pods run inside these EC2s as containers
  
For judicialsolutions.in, I'd use:
  3 EC2 nodes (m5.large), one in each AZ (ap-south-1a/b/c)
  3 replicas of judicial-api, one pod per AZ
  
Each pod gets a real VPC IP from AWS VPC CNI plugin
  (not a fake overlay network like Minikube)
  
Load balancer: real AWS ALB created by AWS Load Balancer Controller
  Not minikube tunnel — a real internet-facing load balancer"
```

**Q: "How do you design Kubernetes for high availability across AZs?"**

```
"Three layers of multi-AZ design:

Layer 1: Nodes across AZs
  Node group spans all 3 AZs (ap-south-1a/b/c)
  eksctl: --node-zones ap-south-1a,ap-south-1b,ap-south-1c
  Minimum 1 node per AZ, so pods always have somewhere to go

Layer 2: Pods spread across AZs
  topologySpreadConstraints with topologyKey: topology.kubernetes.io/zone
  maxSkew: 1 → pods balanced across AZs (max 1 imbalance)
  whenUnsatisfiable: DoNotSchedule → hard requirement
  Result: 6 pods → 2 per AZ, not 6 in one AZ

Layer 3: Traffic routing
  AWS ALB spans all AZs automatically
  Health checks per pod: ALB removes unhealthy pods
  AZ fails → ALB instantly routes to other AZs
  No manual failover needed

Plus:
  PodDisruptionBudget: minAvailable=4 → never fewer than 4 pods running
  HPA: scales out before hitting capacity limits
  Cluster Autoscaler: adds nodes when pods can't be scheduled

Result:
  AZ-1a goes dark → 4 pods still running in 1b and 1c
  ALB already routing to them (detected in seconds)
  New pods scheduled in 1b/1c after 5 minutes
  Users: brief slowness during detection window, not a full outage"
```

**Q: "What is the difference between Minikube and production EKS in terms of network?"**

```
Minikube:
  Fake overlay network (bridge/flannel)
  Pod IPs: 192.168.x.x or 172.17.x.x (not real VPC IPs)
  LoadBalancer: fake (minikube tunnel or NodePort)
  No real VPC, subnets, or security groups
  Ingress: works but needs minikube addons enable ingress
  External DNS: doesn't work (no real hosted zone)

EKS with AWS VPC CNI:
  Pod IPs = REAL VPC IPs (e.g., 10.0.2.47)
  Each pod is a real VPC network interface (ENI or VETH)
  Pod can be reached directly from any VPC resource (EC2, Lambda, RDS)
  LoadBalancer: real ALB/NLB created by AWS (internet-facing)
  Security Groups: can be applied per-pod (not just per-node)
  VPC Flow Logs: captures all pod network traffic for audit
  
  Implication: if RDS allows port 5432 from pod's security group,
               pod can reach RDS directly — no extra config
               In Minikube: you'd need port-forwarding or NodePort"
```

**Q: "What is PodDisruptionBudget and when does it matter?"**

```
PDB = contract that says 'I don't care what you do, but keep at least N pods running'

When it fires:
  kubectl drain node (for maintenance)
  Cluster Autoscaler scaling down nodes
  Rolling updates that would remove too many pods

Without PDB:
  CA drains a node → evicts ALL pods on it simultaneously
  If 3 replicas on same node: all 3 evicted at once = outage

With PDB (minAvailable=2, replicas=3):
  CA evicts pod-1 → 2 remaining (OK, ≥ 2)
  CA tries to evict pod-2 → would be 1 remaining (BLOCKED)
  CA waits for pod-1 to be rescheduled and running
  Then evicts pod-2 → 2 remaining (OK again)
  Always 2 pods serving traffic during maintenance

My setup for judicial-api:
  replicas=6, PDB minAvailable=4
  Can lose 2 pods simultaneously
  Enough for one AZ failure (2 pods in that AZ)"
```
