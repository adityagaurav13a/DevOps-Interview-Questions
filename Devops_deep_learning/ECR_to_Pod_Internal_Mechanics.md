# From ECR Image → Running Pod — The Complete Internal Story
## How Kubernetes Actually Uses Your Image, Creates Pods, and Uses VPC
### Every Step Explained — No Gaps

---

## YOUR QUESTION ANSWERED FIRST

```
YES — you are correct.

In deployment.yaml you set the ECR image path:
  image: 123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f
  
Kubernetes does NOT create EC2 instances.
EC2 instances already exist (your node group).
Kubernetes SCHEDULES your pod onto an existing EC2.
The EC2 node then PULLS the image from ECR and runs it.

That's the core mechanic. Now let's go deep.
```

---

## 📌 TABLE OF CONTENTS

| # | Section |
|---|---|
| 1 | [The deployment.yaml — What's Inside It](#part-1--the-deploymentyaml) |
| 2 | [Step by Step — kubectl apply to Running Pod](#part-2--step-by-step-kubectl-apply-to-running-pod) |
| 3 | [How EC2 Nodes Already Exist (Node Groups)](#part-3--how-ec2-nodes-already-exist) |
| 4 | [How the EC2 Pulls Image from ECR](#part-4--how-ec2-pulls-image-from-ecr) |
| 5 | [How VPC is Used by Pods](#part-5--how-vpc-is-used-by-pods) |
| 6 | [How Pods Talk to Each Other and to RDS](#part-6--how-pods-talk-to-each-other-and-rds) |
| 7 | [What Actually Runs Inside the EC2](#part-7--what-actually-runs-inside-the-ec2) |
| 8 | [Full Visual — Everything Connected](#part-8--full-visual) |
| 9 | [Common Questions](#part-9--common-questions) |

---

## PART 1 — THE deployment.yaml

### What's Inside It

```yaml
# deployment.yaml — this is what YOU write and apply

apiVersion: apps/v1
kind: Deployment
metadata:
  name: judicial-api
  namespace: production

spec:
  replicas: 3           # I want 3 copies of my app running

  selector:
    matchLabels:
      app: judicial-api  # manage pods with this label

  template:             # THIS is the pod blueprint
    metadata:
      labels:
        app: judicial-api

    spec:
      containers:
      - name: judicial-api

        # ↓ YES — this is the ECR image path you set
        image: 123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f
        #       ─────────────────────────────────────────────────────────────────
        #       AWS Account   Region            Repo Name       Tag (git SHA)

        ports:
        - containerPort: 8080

        resources:
          requests:
            cpu: "200m"      # I need at least 200 milli-CPU
            memory: "256Mi"  # I need at least 256 MB RAM

        env:
        - name: DB_HOST
          value: "judicial-db.xxx.ap-south-1.rds.amazonaws.com"
```

### What This File is NOT Doing

```
This file does NOT:
  ✗ Create an EC2 instance
  ✗ Pull the image
  ✗ Run docker run
  ✗ Configure the network
  ✗ Set up VPC

This file ONLY says:
  ✓ "I want 3 pods"
  ✓ "Each pod should run THIS image"
  ✓ "Each pod needs this much CPU and memory"
  ✓ "Expose port 8080"

Kubernetes figures out the REST — where to run it,
how to pull it, how to network it.
That is the entire point of Kubernetes.
```

---

## PART 2 — STEP BY STEP: kubectl apply TO RUNNING POD

### The Complete Flow

```
You run:
  kubectl apply -f deployment.yaml

What happens next — every step:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 1 — kubectl sends request to API Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

kubectl reads your YAML file
kubectl sends HTTP POST to EKS API Server:
  POST https://CLUSTER_ENDPOINT/apis/apps/v1/namespaces/production/deployments
  Body: your deployment YAML (converted to JSON)

API Server:
  Authenticates: is this kubectl allowed to create deployments?
    (checks IAM + K8s RBAC)
  Validates: is the YAML schema correct?
  Stores: saves the Deployment object in etcd
    etcd is K8s's database — stores ALL cluster state

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 2 — Deployment Controller wakes up
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The Deployment Controller is always watching etcd for changes.
It sees: "New Deployment created! Desired replicas = 3, current = 0"

Deployment Controller creates a ReplicaSet:
  ReplicaSet = "ensure exactly 3 pods with this spec always exist"

ReplicaSet Controller sees: "Need 3 pods, have 0"
Creates 3 Pod objects in etcd:
  Pod-1: status=Pending, image=ECR_URL/judicial-api:abc1234f
  Pod-2: status=Pending, image=ECR_URL/judicial-api:abc1234f
  Pod-3: status=Pending, image=ECR_URL/judicial-api:abc1234f

At this point: pods exist as RECORDS in etcd
They are NOT running anywhere yet.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 3 — Scheduler wakes up
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Scheduler watches etcd for Pending pods (not yet assigned to a node).
Scheduler sees: 3 Pending pods

For each pod, Scheduler asks:
  "Which EC2 node should this pod run on?"

Scheduler checks every available node:
  node-1 (ap-south-1a, m5.large): 1900m CPU free, 7.5GB RAM free
  node-2 (ap-south-1b, m5.large): 1700m CPU free, 7.0GB RAM free
  node-3 (ap-south-1c, m5.large): 1800m CPU free, 7.2GB RAM free

For each node, Scheduler checks:
  ✓ Does node have enough CPU? (pod needs 200m)
  ✓ Does node have enough memory? (pod needs 256Mi)
  ✓ Does pod tolerate node's taints?
  ✓ Does node match pod's nodeAffinity?
  ✓ Does topologySpreadConstraint allow this? (spread across AZs)

Decision:
  Pod-1 → node-1 (AZ-1a) ← avoids putting all in same AZ
  Pod-2 → node-2 (AZ-1b)
  Pod-3 → node-3 (AZ-1c)

Scheduler writes this decision to etcd:
  Pod-1: status=Pending, nodeName=node-1
  Pod-2: status=Pending, nodeName=node-2
  Pod-3: status=Pending, nodeName=node-3

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 4 — kubelet on each node wakes up
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

kubelet is an agent running on EVERY EC2 node.
It constantly asks API Server: "Any pods assigned to me?"

node-1's kubelet sees: Pod-1 assigned to me!
  image: 123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f

kubelet instructs containerd (container runtime):
  "Pull this image and start a container"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 5 — containerd pulls image from ECR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

containerd needs to pull:
  123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f

To pull from ECR (private registry), need to authenticate.

Authentication flow:
  containerd uses EC2 Instance Metadata Service (IMDS)
  IMDS is available at: 169.254.169.254 (special link-local IP)
  
  containerd → IMDS: "What IAM role does this EC2 have?"
  IMDS → containerd: "This EC2 has role: eks-node-role"
  
  containerd → AWS STS: "Give me credentials for eks-node-role"
  STS → containerd: temporary AWS credentials (Access Key, Secret, Token)
  
  containerd → ECR: "Login with these credentials"
  ECR verifies: does eks-node-role have ecr:GetAuthorizationToken?
  YES → ECR returns a Docker login token (valid 12 hours)
  
  containerd → ECR: "Pull layers of judicial-api:abc1234f"
  ECR streams the image layers to the EC2 node
  Image cached on EC2's local disk (EBS volume)

Image pulled. Now start the container.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 6 — containerd starts the container
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

containerd creates a container from the image:
  Sets up isolated filesystem (from image layers)
  Sets up process namespace (container can't see host processes)
  Sets up network namespace (container gets its own network stack)
  
CNI plugin (aws-node) assigns a VPC IP to the pod:
  Requests IP from VPC subnet: "Give me an IP from 10.0.11.0/24"
  Gets: 10.0.11.47
  This is a REAL VPC IP — not a fake overlay network
  
Injects environment variables from ConfigMap and Secrets:
  DB_HOST=judicial-db.xxx.rds.amazonaws.com
  DB_PASSWORD=<from secret>
  
Mounts volumes (if any):
  ConfigMap mounted as files
  
Starts the process defined in CMD:
  python -m uvicorn src.main:app --host 0.0.0.0 --port 8080
  
Your app is now running inside the container!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 7 — kubelet runs readiness probe
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

kubelet starts checking your app's health:
  HTTP GET http://10.0.11.47:8080/health
  
  Response: 200 OK  ← healthy!
  
kubelet reports to API Server:
  "Pod-1 is Running and Ready on node-1"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 8 — Endpoints Controller adds pod to Service
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You have a Service defined:
  kind: Service
  name: judicial-api-svc
  selector: app=judicial-api

Endpoints Controller watches for Ready pods matching the selector.
Pod-1 is Ready with label app=judicial-api
Endpoints Controller adds 10.0.11.47:8080 to the Service's endpoints

kube-proxy on EVERY node updates iptables rules:
  "Traffic to ServiceIP:80 → route to one of: 10.0.11.47, 10.0.12.89, 10.0.13.23"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 9 — ALB registers the pod as a target
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AWS Load Balancer Controller watches K8s Ingress and Services.
It sees new endpoints added (pod IPs).
It calls AWS ALB API:
  "Register 10.0.11.47:8080 as a target in target group"
  
ALB runs health check against pod IP directly:
  HTTP GET http://10.0.11.47:8080/health → 200 OK ✓
  
Pod is now LIVE — receiving real user traffic!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total time from kubectl apply to pod receiving traffic:
  Small image (cached): ~30-45 seconds
  First time (image pull): ~90-120 seconds
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## PART 3 — HOW EC2 NODES ALREADY EXIST

### Kubernetes Does NOT Create EC2 — You Do (Before Deploying)

```
Common misconception:
  "When I apply deployment.yaml, does K8s create EC2 instances?"

Answer: NO.

EC2 instances (nodes) must ALREADY EXIST in your cluster
BEFORE you can deploy pods.

Think of it this way:
  EC2 nodes = the WAREHOUSE (physical space)
  Pods       = the PACKAGES you store in the warehouse
  Kubernetes = the WAREHOUSE MANAGER (decides where to put packages)

You must build the warehouse FIRST.
Then the manager places packages in it.
```

### How EC2 Nodes Are Created — Node Groups

```
When you create an EKS cluster, you create a NODE GROUP:
  A node group = an Auto Scaling Group (ASG) of EC2 instances
  Pre-configured to join your K8s cluster automatically

eksctl create nodegroup \
  --cluster judicial-prod \
  --name workers \
  --instance-types m5.large \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 15 \
  --node-zones ap-south-1a,ap-south-1b,ap-south-1c \
  --managed

This creates:
  3 EC2 instances (m5.large)
  1 in each AZ
  All automatically joined to your K8s cluster

When these EC2s boot up:
  1. EC2 launches with EKS-optimised AMI (Amazon Machine Image)
  2. AMI has pre-installed: kubelet, containerd, aws-node (CNI)
  3. Startup script runs:
     /etc/eks/bootstrap.sh judicial-prod
     This command registers the EC2 as a node in your K8s cluster
  4. kubelet starts → connects to EKS API Server → node is "Ready"

Now Kubernetes knows about these 3 nodes and can schedule pods on them.

Check registered nodes:
  kubectl get nodes
  NAME                                          STATUS   ROLES    AGE
  ip-10-0-11-10.ap-south-1.compute.internal    Ready    <none>   5d
  ip-10-0-12-10.ap-south-1.compute.internal    Ready    <none>   5d
  ip-10-0-13-10.ap-south-1.compute.internal    Ready    <none>   5d
```

### What's Pre-Installed on Each EC2 Node

```
EC2 Node = Amazon Linux 2 / Bottlerocket OS
           with these components installed:

containerd:
  Container runtime — actually runs containers
  Replaces the older Docker daemon
  Receives instructions from kubelet

kubelet:
  The K8s agent on every node
  Watches API Server for pods assigned to this node
  Instructs containerd to pull images and run containers
  Reports pod status back to API Server
  Runs health probes (readiness, liveness)

kube-proxy:
  Maintains network rules (iptables/IPVS)
  Enables Service routing (ClusterIP → pod IP)
  Runs on every node

aws-node (VPC CNI plugin):
  Assigns real VPC IPs to pods
  Manages Elastic Network Interfaces (ENIs) on the EC2
  Each EC2 can have multiple ENIs
  Each ENI can have multiple IPs
  Each IP = one pod

These 4 components make an EC2 into a K8s node.
```

### Cluster Autoscaler — When K8s DOES Create EC2

```
There is ONE case where K8s causes EC2 creation:
  Cluster Autoscaler (CA)

CA watches for pods stuck in Pending state.
Pending = Scheduler can't find a node with enough resources.

When CA sees pending pods:
  CA calculates: how many nodes needed to fit pending pods?
  CA calls AWS Auto Scaling API:
    "Increase desired count of ASG 'workers' from 3 to 4"
  AWS launches new EC2 instance (same type, same AZ as needed pod)
  EC2 boots (~2-3 minutes)
  EC2 registers with K8s cluster
  Scheduler now sees new node → schedules pending pod onto it
  Pod runs!

So CA is the bridge:
  K8s (pod can't fit) → CA → AWS ASG → new EC2 → K8s node → pod scheduled

But YOU set up the CA and the ASG.
CA doesn't create random EC2s — it scales the ASG you defined.
```

---

## PART 4 — HOW EC2 PULLS IMAGE FROM ECR

### The Authentication Chain

```
EC2 node needs to pull from ECR (private registry).
How does it authenticate? No passwords stored anywhere.

The chain:

EC2 Instance
    │
    │ 1. EC2 has an IAM Instance Profile attached
    │    (set when node group was created)
    │    Instance Profile = "this EC2 is allowed to be eks-node-role"
    │
    ▼
IAM Role: eks-node-role
    │
    │ Policies attached to this role:
    │   AmazonEC2ContainerRegistryReadOnly
    │     → ecr:GetAuthorizationToken
    │     → ecr:BatchGetImage
    │     → ecr:GetDownloadUrlForLayer
    │
    ▼
IMDS (Instance Metadata Service) at 169.254.169.254
    │
    │ containerd asks IMDS: "What credentials do I have?"
    │ IMDS responds with temporary credentials for eks-node-role
    │ (auto-refreshed every hour, no rotation needed)
    │
    ▼
ECR (Elastic Container Registry)
    │
    │ containerd calls:
    │   aws ecr get-login-password --region ap-south-1
    │ ECR verifies: does this caller have ecr:GetAuthorizationToken?
    │ YES (via eks-node-role) → returns Docker auth token
    │
    ▼
Image Pull
    containerd pulls layers from ECR over HTTPS
    Traffic: EC2 → VPC → ECR endpoint (within AWS network)
    No internet needed (ECR is in same AWS region)
    Layers cached on EC2's local EBS volume
    Next time: if image tag already cached → no pull needed
```

### Image Pull in Detail

```
Image: 123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f

This URL breaks down as:
  123456789                = your AWS account ID
  .dkr.ecr                 = ECR Docker registry endpoint
  .ap-south-1              = region (Mumbai)
  .amazonaws.com           = AWS domain
  /judicial-api            = repository name
  :abc1234f                = image tag (your git SHA)

Docker images are made of LAYERS:
  Layer 1: python:3.12-slim base (200MB) ← shared with other images
  Layer 2: pip packages (150MB)          ← changes when requirements.txt changes
  Layer 3: your source code (5MB)        ← changes every commit

Each layer has a SHA256 hash.

Pull is smart (only downloads what's missing):
  EC2 checks: do I have layer1 hash abc...? YES → skip download
  EC2 checks: do I have layer2 hash def...? YES → skip download
  EC2 checks: do I have layer3 hash ghi...? NO  → download (5MB)
  
  Result: only 5MB downloaded for every code-only change.
  Base layers (350MB) downloaded once, cached forever.

Image cached at: /var/lib/containerd/... on EC2's EBS root volume

kubectl describe pod pod-1 | grep -A5 Events:
  Normal  Pulling    "Pulling image judicial-api:abc1234f"
  Normal  Pulled     "Successfully pulled image (2.3s)"  ← from cache
  Normal  Created    "Created container judicial-api"
  Normal  Started    "Started container judicial-api"
```

---

## PART 5 — HOW VPC IS USED BY PODS

### Pods Get Real VPC IPs — Not Fake IPs

```
This is what makes EKS different from Minikube.

Minikube: pods get fake IPs (172.17.x.x) on a virtual bridge network
          not real network — can't be reached by other VPC resources

EKS with AWS VPC CNI:
  Pods get REAL IPs from your VPC subnets
  Pod IP = just another IP in your subnet (like an EC2's IP)
  Any VPC resource (EC2, Lambda, RDS) can reach pod IP directly

How:
  EC2 node has one primary network interface (eth0) with one IP
  EC2 also gets additional ENIs (Elastic Network Interfaces)
  Each ENI can have multiple secondary IPs
  Each secondary IP = one pod IP

  m5.large limits:
    Max ENIs: 3
    Max IPs per ENI: 10
    Max pods: 3 × 10 - 2 (reserved) = 29 pods per m5.large

Your VPC subnet: 10.0.11.0/24 (private, AZ-1a)
  EC2 node IP:     10.0.11.10  ← the node's primary IP
  Pod-1 IP:        10.0.11.47  ← real VPC IP assigned to pod
  Pod-2 IP:        10.0.11.48  ← real VPC IP assigned to pod
  Pod-3 IP:        10.0.11.49  ← real VPC IP assigned to pod

These IPs appear in your AWS VPC console as secondary IPs on the EC2's ENI.
```

### How aws-node (CNI) Assigns IPs

```
aws-node = DaemonSet that runs on every EC2 node
         = manages VPC IP assignment for pods

Process:
  1. aws-node runs on new EC2 node
  2. Requests a "warm pool" of IPs from VPC:
     "Attach a new ENI to this EC2 with 10 secondary IPs"
     IPs allocated from private subnet (10.0.11.0/24)
  
  3. Pod scheduled on this node needs an IP:
     aws-node picks IP from warm pool: 10.0.11.47
     Configures this IP on a virtual ethernet interface (veth)
     Creates a veth pair:
       veth1 inside container (pod sees it as eth0)
       veth0 on host (EC2 sees it)
     Routes pod traffic through this interface

  4. Pod's eth0: IP 10.0.11.47, default gateway points to host
  5. Traffic from pod: goes through veth0 → EC2 → VPC routing

kubectl get pod pod-1 -o wide
  NAME    READY   STATUS    IP            NODE
  pod-1   1/1     Running   10.0.11.47    ip-10-0-11-10.internal
  
  10.0.11.47 = real VPC IP in your private subnet
```

### VPC Security Groups Apply to Pods

```
Because pods have real VPC IPs, security groups work at pod level.

Without Pod-level SG (default):
  Security group applied at EC2/ENI level
  ALL pods on a node share the same security group
  Can't give different permissions to different pod types

With Pod-level Security Groups (EKS feature):
  Each pod gets its own security group assignment
  judicial-api pod: App-SG (allows 8080 from ALB-SG)
  postgres pod: Data-SG (allows 5432 from App-SG)
  
  This is possible ONLY because pods have real VPC IPs.
  
Enable in deployment:
  eks.amazonaws.com/pod-sg: sg-app-xxxxxxxx

Traffic rules still apply:
  ALB → 10.0.11.47:8080 — allowed (ALB-SG → App-SG rule)
  0.0.0.0:any → 10.0.11.47 — blocked (no rule allows it)
```

---

## PART 6 — HOW PODS TALK TO EACH OTHER AND TO RDS

### Pod to Pod (Same Cluster)

```
Scenario: frontend pod needs to call backend API pod

frontend-pod IP: 10.0.11.47
backend-pod-1 IP: 10.0.12.89
backend-pod-2 IP: 10.0.13.23
backend-pod-3 IP: 10.0.11.52

Frontend does NOT hardcode pod IPs (they change on restart!)
Frontend calls: http://judicial-api-svc:8080/api/cases
                ─────────────────────────────
                K8s Service DNS name

DNS Resolution:
  CoreDNS (runs in kube-system namespace) handles DNS for the cluster
  frontend-pod asks CoreDNS:
    "What IP is judicial-api-svc.production.svc.cluster.local?"
  CoreDNS responds:
    "172.20.50.100" ← this is the Service's ClusterIP (virtual IP)

Traffic flow:
  frontend-pod → 172.20.50.100:8080 (ClusterIP)
  
  kube-proxy has set up iptables rules on the node:
  "Traffic to 172.20.50.100:8080 → pick one of:
     10.0.12.89:8080
     10.0.13.23:8080
     10.0.11.52:8080
   (round robin)"
  
  iptables rewrites destination: 172.20.50.100 → 10.0.12.89
  Packet goes: frontend-pod → EC2 network stack → VPC routing → backend-pod
  
  If pods are on different nodes: traffic goes via VPC routing between EC2s
  VPC knows all these IPs (they're real VPC IPs) → routes correctly

kubectl get service judicial-api-svc
  NAME               TYPE        CLUSTER-IP      PORT(S)
  judicial-api-svc   ClusterIP   172.20.50.100   80/TCP
  
kubectl get endpoints judicial-api-svc
  NAME               ENDPOINTS
  judicial-api-svc   10.0.12.89:8080,10.0.13.23:8080,10.0.11.52:8080
```

### Pod to RDS (Database)

```
Scenario: backend API pod queries PostgreSQL on RDS

RDS endpoint: judicial-prod.cluster-xxx.ap-south-1.rds.amazonaws.com
RDS IP: 10.0.21.5 (in data subnet)

Backend pod connects:
  psycopg2.connect(
    host="judicial-prod.cluster-xxx.ap-south-1.rds.amazonaws.com",
    port=5432,
    database="judicial",
    user="admin",
    password=os.environ['DB_PASSWORD']
  )

DNS Resolution:
  "judicial-prod.cluster-xxx..." → Route53 private hosted zone
  Route53 responds: 10.0.21.5 (RDS primary IP)

Traffic flow:
  backend-pod (10.0.11.47) → RDS (10.0.21.5:5432)
  
  Both are in your VPC (different subnets):
    10.0.11.47 → private subnet AZ-1a
    10.0.21.5  → data subnet AZ-1a
  
  VPC routing: traffic between subnets in same VPC = automatic
  (local route: 10.0.0.0/16 → local, no gateway needed)
  
  Security Group check:
    Source: 10.0.11.47 (pod, has App-SG)
    Destination: 10.0.21.5:5432 (RDS, has Data-SG)
    Data-SG inbound rule: allow 5432 from App-SG → ALLOWED ✓

No internet used. No NAT Gateway needed.
VPC private routing handles it entirely.

kubectl exec -it backend-pod -- nc -zv \
  judicial-prod.cluster-xxx.ap-south-1.rds.amazonaws.com 5432
# Connection to ... 5432 port [tcp] succeeded!
```

---

## PART 7 — WHAT ACTUALLY RUNS INSIDE THE EC2

### One EC2, Multiple Pods — How It Looks

```
SSH into EC2 node (for debugging):
  ssh -i judicial-key.pem ec2-user@10.0.11.10

What you see on the EC2:

# OS processes:
ps aux | grep -E "kubelet|containerd|aws-node"
  root  kubelet --config /etc/kubernetes/kubelet/kubelet-config.json ...
  root  containerd --config /etc/containerd/config.toml
  root  aws-node  (CNI plugin)

# Running containers:
sudo crictl ps
  CONTAINER     IMAGE                    NAME           POD
  a1b2c3d4e5f6  judicial-api:abc1234f    judicial-api   judicial-api-pod-1
  g7h8i9j0k1l2  judicial-api:abc1234f    judicial-api   judicial-api-pod-2
  m3n4o5p6q7r8  prometheus-node-exp...   node-exporter  node-exporter-xxx
  s9t0u1v2w3x4  aws-node:v1.15...        aws-node       aws-node-xxx

# Pod network interfaces:
ip addr show
  eth0: 10.0.11.10/24        ← EC2's primary IP
  eth1: <no IP>              ← ENI for pod IPs
  veth1a2b3c: (no IP)        ← host side of pod-1's veth pair
  veth4d5e6f: (no IP)        ← host side of pod-2's veth pair

# Inside a pod:
kubectl exec -it judicial-api-pod-1 -- ip addr
  eth0: 10.0.11.47/32        ← pod's own VPC IP
  
kubectl exec -it judicial-api-pod-1 -- cat /etc/resolv.conf
  nameserver 172.20.0.10     ← CoreDNS IP
  search production.svc.cluster.local svc.cluster.local cluster.local

# Pod can see its env vars injected by K8s:
kubectl exec -it judicial-api-pod-1 -- env | grep DB
  DB_HOST=judicial-prod.cluster-xxx.ap-south-1.rds.amazonaws.com
  DB_PASSWORD=<secret value injected from K8s Secret>
```

### Resource Isolation Between Pods

```
Pod-1 and Pod-2 run on the same EC2.
They cannot interfere with each other because Linux namespaces:

Network namespace:
  Pod-1 sees: eth0 = 10.0.11.47 (its own IP only)
  Pod-2 sees: eth0 = 10.0.11.48 (its own IP only)
  They cannot see each other's network traffic directly

Process namespace:
  Pod-1: ps aux → only sees its own Python process
  Pod-2: ps aux → only sees its own Python process
  Pod-1 cannot kill Pod-2's processes

Filesystem namespace:
  Pod-1: sees its own container filesystem (from image)
  Pod-2: sees its own container filesystem (from image)
  Pod-1 cannot read Pod-2's files

CPU/Memory limits:
  Pod-1 has limit: 1000m CPU, 1Gi RAM
  Pod-2 has limit: 1000m CPU, 1Gi RAM
  cgroups enforce: Pod-1 cannot steal Pod-2's CPU

So even on the same physical EC2:
  Complete isolation between pods
  One buggy pod cannot crash another pod
```

---

## PART 8 — FULL VISUAL

### Complete Picture — One Deployment, Everything Connected

```
YOUR DEPLOYMENT.YAML
  image: 123456789.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:abc1234f
  replicas: 3
  resources.requests: cpu=200m, memory=256Mi
        │
        │ kubectl apply -f deployment.yaml
        ▼
┌─────────────────────────────────────────────────────────────┐
│   EKS CONTROL PLANE  (AWS managed, you pay $0.10/hr)        │
│                                                             │
│   API Server ← receives your kubectl apply                  │
│   etcd       ← stores deployment + 3 pod records           │
│   Scheduler  ← assigns pods to nodes                       │
│   Controllers← creates ReplicaSet, watches pod count       │
└───────────────────────┬─────────────────────────────────────┘
                        │ "Pod-1 → node-1, Pod-2 → node-2..."
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌────────────┐   ┌────────────┐   ┌────────────┐
│  EC2 node-1│   │  EC2 node-2│   │  EC2 node-3│
│  AZ-1a     │   │  AZ-1b     │   │  AZ-1c     │
│  10.0.11.10│   │  10.0.12.10│   │  10.0.13.10│
│            │   │            │   │            │
│ kubelet ↓  │   │ kubelet ↓  │   │ kubelet ↓  │
│            │   │            │   │            │
│ containerd │   │ containerd │   │ containerd │
│ ↓ pulls from ECR (via EC2 IAM role → no password)          │
│            │   │            │   │            │
│ [Pod-1]    │   │ [Pod-2]    │   │ [Pod-3]    │
│ IP:        │   │ IP:        │   │ IP:        │
│ 10.0.11.47 │   │ 10.0.12.89 │   │ 10.0.13.23 │
│ (real VPC) │   │ (real VPC) │   │ (real VPC) │
│            │   │            │   │            │
└─────┬──────┘   └─────┬──────┘   └─────┬──────┘
      │                │                │
      └────────────────┼────────────────┘
                       │
    All pod IPs registered in Service endpoints
    kube-proxy sets iptables rules for Service ClusterIP
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  K8s Service (judicial-api-svc)                              │
│  ClusterIP: 172.20.50.100                                    │
│  Endpoints: 10.0.11.47, 10.0.12.89, 10.0.13.23             │
└──────────────────────┬───────────────────────────────────────┘
                       │ AWS LB Controller registers pod IPs as ALB targets
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  AWS ALB (internet-facing, created by K8s Ingress)          │
│  DNS: judicial-xxx.ap-south-1.elb.amazonaws.com             │
│  Targets: 10.0.11.47:8080, 10.0.12.89:8080, 10.0.13.23:8080│
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
              INTERNET USERS
         https://judicialsolutions.in
```

### What Happens When You Update the Image

```
You push new image: judicial-api:d4e5f6g7

Run (or GitHub Actions runs):
  kubectl set image deployment/judicial-api \
    judicial-api=ECR_URL/judicial-api:d4e5f6g7

K8s rolling update:

Before: [Pod-1 old] [Pod-2 old] [Pod-3 old]

Step 1: Create Pod-4 (new image)
  [Pod-1 old] [Pod-2 old] [Pod-3 old] [Pod-4 NEW starting]
  
  Pod-4: node pulls d4e5f6g7 from ECR (only changed layers)
         container starts
         readiness probe: curl /health → 200 ✓
         added to Service endpoints

  [Pod-1 old] [Pod-2 old] [Pod-3 old] [Pod-4 NEW ready]
  All 4 in rotation, serving traffic

Step 2: Terminate Pod-1 (old image)
  preStop hook: sleep 15 (ALB stops sending traffic to Pod-1)
  Pod-1 finishes in-flight requests
  Pod-1 container stopped, removed from endpoints

  [Pod-2 old] [Pod-3 old] [Pod-4 NEW]

Step 3: Create Pod-5 (new image), terminate Pod-2
  [Pod-3 old] [Pod-4 NEW] [Pod-5 NEW]

Step 4: Create Pod-6 (new image), terminate Pod-3
  [Pod-4 NEW] [Pod-5 NEW] [Pod-6 NEW]

Done. Zero downtime. Users never saw an error.
The new image is now running on all pods.
```

---

## PART 9 — COMMON QUESTIONS

**Q: Does Kubernetes need Docker installed on EC2 nodes?**

```
No. Modern Kubernetes (1.24+) uses containerd directly.
Docker was removed as the default runtime.

What changed:
  Old: kubelet → dockershim → Docker daemon → containerd → container
  New: kubelet → containerd → container  (one less layer)

Your Dockerfile still works — containerd reads the same OCI image format
that Docker produces. The image in ECR is format-compatible with containerd.

Check on EC2:
  sudo crictl ps        ← containerd's CLI (not docker ps)
  sudo crictl images    ← images cached on node
```

**Q: If I update deployment.yaml replicas from 3 to 6, what exactly happens?**

```
kubectl apply -f deployment.yaml  (with replicas: 6)

1. API Server updates Deployment in etcd: desired=6
2. ReplicaSet Controller: current=3, desired=6, need 3 more pods
3. Creates 3 new Pod objects in etcd (Pending)
4. Scheduler assigns each to a node with enough resources
5. kubelet on each node pulls image (probably cached) and starts container
6. Readiness probes pass → pods added to Service endpoints
7. kube-proxy updates iptables: now load balances across 6 pods

No new EC2 created (if existing nodes have capacity).
No re-pull of unchanged image (cached on node's EBS).
New pods up in ~30-60 seconds.

If nodes are full (no CPU/RAM):
  Pods stay Pending
  Cluster Autoscaler sees Pending pods
  CA tells AWS ASG: increase from 3 to 4 nodes
  New EC2 boots (~2-3 min), joins cluster
  Scheduler places pods on new node
```

**Q: How does the pod know its own IP and the DB host?**

```
Pod IP:
  Assigned by aws-node CNI when pod starts
  Pod can see it: ip addr show eth0
  Or: hostname -I

DB host (from ConfigMap):
  ConfigMap has: DB_HOST=judicial-prod.xxx.rds.amazonaws.com
  Deployment has:
    env:
      - name: DB_HOST
        valueFrom:
          configMapKeyRef:
            name: app-config
            key: DB_HOST
  
  K8s injects this as env var BEFORE the container starts
  Your Python app reads: os.environ['DB_HOST']
  
  So your code never hardcodes the DB hostname —
  it reads from environment, which comes from ConfigMap,
  which you control separately from the code.

DB password (from Secret):
  Same mechanism but from a K8s Secret
  Secret value comes from AWS Secrets Manager
  via External Secrets Operator

kubectl exec pod-1 -- env
  DB_HOST=judicial-prod.xxx.ap-south-1.rds.amazonaws.com
  DB_PASSWORD=<actual password injected at runtime>
  KUBERNETES_SERVICE_HOST=172.20.0.1
  KUBERNETES_PORT=tcp://172.20.0.1:443
```

**Q: What happens if I have 3 pods and 1 pod's node has no internet — can it still pull from ECR?**

```
ECR pull doesn't need internet.

Traffic path: EC2 → VPC → ECR endpoint (within AWS)

ECR is an AWS service in the same region.
Within AWS, services communicate over the AWS backbone network.
Your EC2 in ap-south-1 reaching ECR ap-south-1:
  No internet required
  No NAT Gateway required (but it works through NAT GW too)
  Even better: create VPC Interface Endpoint for ECR:
    com.amazonaws.ap-south-1.ecr.api
    com.amazonaws.ap-south-1.ecr.dkr
  Then: EC2 → VPC Endpoint → ECR (never leaves VPC, cheaper, faster)

With ECR VPC endpoints:
  EC2 in private subnet (no NAT GW) → still pulls from ECR ✓
  Useful when: Fargate pods (no NAT GW, need ECR access)
               Cost optimization (avoid NAT GW data charges)
```

---

## SUMMARY — The 10-Line Version

```
1. You write deployment.yaml with image: ECR_URL/app:tag
2. kubectl apply sends this to EKS API Server
3. K8s creates 3 Pod records in etcd (Pending)
4. Scheduler assigns pods to EC2 nodes (already existing)
5. kubelet on each EC2 sees its assigned pod
6. kubelet tells containerd: pull ECR_URL/app:tag
7. containerd authenticates via EC2 IAM role (no passwords)
8. containerd pulls image from ECR over AWS network
9. containerd starts container, aws-node gives it a real VPC IP
10. Pod passes readiness probe → ALB registers it → users can reach it

K8s does NOT create EC2.  K8s uses EC2s that already exist.
Pods get real VPC IPs.  They talk to RDS via private VPC routing.
ECR authentication uses IAM roles.  No passwords stored anywhere.
```
