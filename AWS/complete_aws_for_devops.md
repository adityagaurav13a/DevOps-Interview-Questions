# AWS Complete Deep Dive — Full Reference
## EC2 + S3 + Databases + RDS + CloudWatch + Route53 + SQS/SNS + Security + ECS + Cost + Networking + CloudFormation + Well-Architected
### Theory → Interview Questions → Hands-on Commands

---

## README

**Total sections:** 13 (EC2, S3, Database Comparison added)
**Target:** Mid-level to Senior DevOps/Cloud Engineer interviews
**Coverage:** Suitable for both Cloud Engineer and DevOps Engineer interviews

### Priority sections for your profile:
| Section | Relevance |
|---|---|
| Part 1 — EC2 | Core compute — asked in every AWS interview |
| Part 2 — S3 | Storage, lifecycle, versioning — very commonly asked |
| Part 3 — Database Comparison | "When to use what" — senior-level design question |
| Part 4 — RDS | You executed RDS migration (resume bullet) |
| Part 5 — CloudWatch | Observability stack you built |
| Part 8 — Security | WAF, GuardDuty — senior-level |
| Part 10 — Cost | JD specifically asked for cost-efficient environments |

### Quick answer framework for "when to use what":
```
Storage:   object → S3 | block → EBS | file → EFS | archive → Glacier
Database:  relational+ACID → RDS | key-value/scale → DynamoDB |
           cache → ElastiCache | search → OpenSearch | graph → Neptune
Compute:   long-running → EC2 | containerised → ECS/EKS |
           event-driven → Lambda | batch → AWS Batch
```

---

## 📌 TABLE OF CONTENTS
> Click any link to jump directly to that section

| # | Section | Key Topics |
|---|---|---|
| 1 | [EC2 Deep Dive](#part-1--ec2-deep-dive) | Instance types, EBS, ASG, Spot, Placement Groups |
| 2 | [S3 Deep Dive](#part-2--s3-deep-dive) | Storage classes, Versioning, Lifecycle, Security |
| 3 | [Database Comparison](#part-3--database-comparison-when-to-use-what) | RDS vs DynamoDB vs Redis vs OpenSearch decision guide |
| 4 | [RDS + Aurora](#part-4--rds--aurora) | Multi-AZ, Read Replicas, Aurora, DMS migration |
| 5 | [CloudWatch](#part-5--cloudwatch-deep-dive) | Metrics, Logs Insights, Alarms, Agent |
| 6 | [Route53](#part-6--route53) | DNS types, Routing policies, Health checks, Failover |
| 7 | [SQS + SNS + EventBridge](#part-7--sqs--sns--eventbridge) | Queues, Pub-sub, Event-driven patterns |
| 8 | [AWS Security](#part-8--aws-security) | WAF, Shield, GuardDuty, Security Hub, Macie |
| 9 | [ECS Deep Dive](#part-9--ecs-deep-dive) | Task definitions, Fargate, Service discovery, vs EKS |
| 10 | [Cost Optimisation](#part-10--cost-optimisation) | Reserved, Savings Plans, Spot, S3 tiers, tools |
| 11 | [AWS Networking Overview](#part-11--aws-networking-deep-dive) | VPC Peering, TGW, Direct Connect, VPN overview |
| 12 | [CloudFormation vs Terraform](#part-12--cloudformation-vs-terraform) | When to use which, SAM, CDK |
| 13 | [Well-Architected Framework](#part-13--aws-well-architected-framework) | All 6 pillars, WAT tool |
| 14 | [**VPC Complete Deep Dive**](#part-14--vpc-complete-deep-dive) | **Full VPC reference — all components** |

### ⚡ VPC Section Quick Jump:
> [VPC & Subnets](#vpc--subnets) · [IGW](#internet-gateway-igw) · [NAT Gateway](#nat-gateway-ngw) · [SG vs NACLs](#security-groups-vs-nacls) · [VPC Peering](#vpc-peering) · [Transit Gateway](#transit-gateway-tgw) · [Site-to-Site VPN](#site-to-site-vpn) · [Direct Connect](#direct-connect) · [VPN CloudHub](#vpn-cloudhub) · [PrivateLink & Endpoints](#aws-privatelink--vpc-endpoints) · [Flow Logs](#vpc-flow-logs) · [Traffic Mirroring](#traffic-mirroring) · [Egress-Only IGW](#egress-only-internet-gateway) · [Comparison Table](#networking-comparison-table) · [Interview Q&A](#vpc-interview-questions)


---

## PART 1 — EC2 DEEP DIVE

### EC2 Instance Types

```
General Purpose (T, M):
  T3/T4g: burstable — earns CPU credits when idle, spends on burst
           Use for: web servers, dev/test, small DBs, low traffic apps
           T3 Unlimited: can burst beyond credit balance (extra cost)
  M5/M6: balanced CPU+memory
           Use for: mid-size databases, data processing, backend servers

Compute Optimised (C):
  C5/C6: high CPU ratio
  Use for: batch processing, web servers, media transcoding, ML inference

Memory Optimised (R, X):
  R5/R6: high RAM
  Use for: in-memory databases (Redis, Memcached), real-time analytics
  X1e: largest RAM on EC2
  Use for: SAP HANA, large in-memory workloads

Storage Optimised (I, D, H):
  I3/I4: NVMe SSD, high IOPS
  Use for: NoSQL databases (Cassandra, MongoDB), data warehousing
  D2: dense HDD storage
  Use for: Hadoop, MapReduce

Accelerated Computing (P, G, Inf):
  P3/P4: NVIDIA GPUs for ML training
  G4: GPU for ML inference, video transcoding
  Inf1: AWS Inferentia chips — cheapest ML inference

Naming convention:
  m5.xlarge
  │ │  └── size: nano,micro,small,medium,large,xlarge,2xlarge...
  │ └──── generation: 5 (higher = newer, cheaper, faster)
  └────── family: m=general, c=compute, r=memory, i=storage
```

### EC2 Storage Options

```
EBS (Elastic Block Store):
  Block storage attached to EC2
  Persists independently of instance (survives stop/terminate)
  Only one instance at a time (except io2 Multi-Attach)
  
  Volume Types:
    gp3 (General Purpose SSD):
      3,000 IOPS baseline, up to 16,000 IOPS (independent of size)
      125 MB/s throughput baseline, up to 1,000 MB/s
      Use for: OS volumes, most workloads
      Cost: cheaper than gp2 with better baseline performance
    
    gp2 (older General Purpose):
      IOPS tied to size: 3 IOPS/GB, min 100, max 16,000
      Use gp3 instead (cheaper, more flexible)
    
    io2 Block Express (Provisioned IOPS SSD):
      Up to 256,000 IOPS, up to 4,000 MB/s
      Multi-Attach: attach to multiple EC2 in same AZ
      Use for: critical databases needing guaranteed IOPS (Oracle, SAP)
    
    st1 (Throughput Optimised HDD):
      Sequential read/write, up to 500 MB/s
      Cannot be boot volume
      Use for: big data, log processing, data warehouses
    
    sc1 (Cold HDD):
      Lowest cost
      Infrequently accessed data
      Cannot be boot volume

Instance Store:
  Physical disk on the EC2 host
  Temporary: lost when instance stopped/terminated
  Very high IOPS (NVMe)
  Use for: buffer, cache, scratch data, temp files
  NOT for: anything important (ephemeral!)
```

### EC2 Purchasing Options

```
On-Demand:
  Per second billing (Linux), per hour (Windows)
  No commitment
  Use for: unpredictable workloads, short-term

Reserved Instances (1 or 3 year):
  Up to 72% discount
  Payment options: No Upfront, Partial Upfront, All Upfront
  All Upfront gives maximum discount
  Convertible RI: can change instance type, less discount

Savings Plans:
  Commit to $/hour for 1 or 3 years
  Compute Savings Plan: any instance type, region, OS, tenancy
  EC2 Savings Plan: specific family + region, max discount
  Automatically applies to Lambda + Fargate too

Spot Instances:
  Bid on unused EC2 capacity
  Up to 90% cheaper
  2-minute warning before termination
  Use for: batch jobs, ML training, CI/CD, stateless workers
  NOT for: databases, stateful apps, anything needing guaranteed uptime

Dedicated Hosts:
  Physical server dedicated to you
  Software license compliance (per-socket, per-core)
  Most expensive option

Dedicated Instances:
  Your instances on dedicated hardware (but AWS may move between hosts)
  Less control than Dedicated Hosts
  Use for: compliance (no other customers' VMs on same hardware)
```

### EC2 Networking

```
Security Groups:
  Stateful — response traffic automatically allowed
  Rules: Allow only (no explicit Deny)
  Applied to: instance (ENI)
  Default: all outbound allowed, no inbound

NACLs (Network ACLs):
  Stateless — must allow both request AND response
  Rules: Allow AND Deny
  Applied to: subnet (affects all instances in subnet)
  Rules evaluated in number order (lowest first)
  Default: all traffic allowed

Elastic IP (EIP):
  Static public IPv4 address
  Stays yours until you release it
  Free when attached to running instance
  $0.005/hr when NOT attached (so release unused ones)

ENI (Elastic Network Interface):
  Virtual network card
  Each EC2 has at least one ENI (eth0)
  Can attach additional ENIs
  Use for: dual-homed instances, failover (move ENI between instances)

Placement Groups:
  Cluster:   same AZ, same rack — low latency, high bandwidth
             Use for: HPC, tightly coupled applications
             Risk: single point of failure (all on same hardware)
  
  Spread:    max 7 instances per AZ per group, different hardware
             Use for: small critical instances that must not fail together
  
  Partition: groups of instances on different partitions (racks)
             Up to 7 partitions per AZ, hundreds of instances
             Use for: Hadoop, Cassandra, Kafka (fault domain isolation)
```

### EC2 Hands-on

```bash
# Launch instance
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.micro \
  --key-name my-key \
  --security-group-ids sg-12345678 \
  --subnet-id subnet-12345678 \
  --iam-instance-profile Name=my-ec2-profile \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server}]'

# List running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Stop / Start / Terminate
aws ec2 stop-instances --instance-ids i-1234567890
aws ec2 start-instances --instance-ids i-1234567890
aws ec2 terminate-instances --instance-ids i-1234567890

# Create snapshot
aws ec2 create-snapshot \
  --volume-id vol-12345678 \
  --description "Pre-deployment snapshot $(date +%Y-%m-%d)"

# Resize EBS volume (online, no restart needed for extend)
aws ec2 modify-volume \
  --volume-id vol-12345678 \
  --size 100 \
  --volume-type gp3 \
  --iops 6000

# Then on EC2:
sudo growpart /dev/xvda 1
sudo resize2fs /dev/xvda1  # ext4
# or: sudo xfs_growfs /    # xfs

# Create AMI from running instance
aws ec2 create-image \
  --instance-id i-1234567890 \
  --name "judicial-api-$(date +%Y%m%d)" \
  --no-reboot
```

### EC2 User Data

```bash
#!/bin/bash
# User data runs as root on first boot

# Update packages
yum update -y

# Install and start nginx
yum install -y nginx
systemctl enable nginx
systemctl start nginx

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:/cloudwatch-config

# Pull and run Docker container
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com
docker pull ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:latest
docker run -d -p 8080:8080 judicial-api:latest
```

### EC2 Auto Scaling

```
Auto Scaling Group (ASG):
  Maintains desired number of EC2 instances
  Replaces unhealthy instances automatically
  Scales based on policies

Scaling policies:
  Target Tracking: maintain metric at target value
    "Keep average CPU at 60%"
    ASG automatically adds/removes instances
    Simplest, recommended for most cases
  
  Step Scaling: scale by specific amount based on metric
    CPU 60-70% → add 1 instance
    CPU 70-80% → add 2 instances
    CPU > 80%  → add 3 instances
  
  Scheduled: scale at specific times
    9am Mon-Fri: set desired=10
    6pm Mon-Fri: set desired=3
    Weekend: set desired=1

Launch Template (preferred over Launch Config):
  Defines: AMI, instance type, SG, key pair, user data
  Versioned (can roll back)
  Supports mixed instances and spot

Health checks:
  EC2 health check: instance status checks
  ELB health check: target group health (more accurate)
  Always use ELB health check for web apps

Lifecycle hooks:
  Pause instance at: launch or terminate
  Run custom scripts (install agents, backup data)
  Continue or abandon the action

Instance Refresh:
  Rolling update of instances in ASG
  Specify min healthy %
  Use for: AMI updates, user data changes
  aws autoscaling start-instance-refresh \
    --auto-scaling-group-name my-asg \
    --preferences MinHealthyPercentage=90
```

---

## PART 2 — S3 DEEP DIVE

### S3 Core Concepts

```
S3 = Simple Storage Service
  Object storage (not block, not file)
  Bucket: container for objects (globally unique name)
  Object: file + metadata
  Key: full path of object (e.g., images/2024/photo.jpg)
  No real folders — key prefix creates illusion of hierarchy

Durability vs Availability:
  Durability: 99.999999999% (11 nines) — data won't be lost
              Objects replicated across minimum 3 AZs
  Availability: 99.99% Standard — objects are accessible
  
  Key distinction:
    High durability = data safe (won't disappear)
    Availability = can I access it right now

Object size:
  Min: 0 bytes, Max: 5TB per object
  Multipart upload required for > 5GB
  Recommended for > 100MB (parallel, retry on failure)

Consistency model:
  Strong read-after-write consistency (since Dec 2020)
  GET immediately after PUT returns the new object
  LIST immediately reflects new objects
```

### S3 Storage Classes

```
Standard:
  Frequently accessed data
  Millisecond access
  3+ AZ replication
  Cost: $0.023/GB
  Use for: active data, websites, mobile apps

Standard-IA (Infrequent Access):
  Accessed less than once a month
  Millisecond access (same speed as Standard)
  3+ AZ replication
  Retrieval fee: $0.01/GB
  Minimum storage: 30 days
  Cost: $0.0125/GB
  Use for: disaster recovery, backups accessed occasionally

One Zone-IA:
  Same as Standard-IA but single AZ
  20% cheaper than Standard-IA
  Data lost if AZ fails
  Cost: $0.01/GB
  Use for: secondary backup copies, data you can recreate

Glacier Instant Retrieval:
  Archived data accessed quarterly
  Millisecond retrieval (same speed as Standard)
  Minimum storage: 90 days
  Cost: $0.004/GB
  Use for: medical images, news media, long-lived backups

Glacier Flexible Retrieval (formerly Glacier):
  Data rarely accessed (1-2 times/year)
  Retrieval: Expedited (1-5 min), Standard (3-5 hrs), Bulk (5-12 hrs)
  Minimum storage: 90 days
  Cost: $0.0036/GB
  Use for: compliance archives, long-term backups

Glacier Deep Archive:
  Lowest cost storage ($0.00099/GB)
  Retrieval: Standard (12 hrs), Bulk (48 hrs)
  Minimum storage: 180 days
  Use for: data retained for 7-10 years (regulatory), rarely accessed

Intelligent-Tiering:
  ML automatically moves objects between access tiers
  No retrieval fees, no minimum duration
  Monitoring fee: $0.0025 per 1,000 objects
  Tiers: Frequent → Infrequent (30 days) → Archive (90 days) → Deep Archive (180 days)
  Use for: unknown or changing access patterns

Quick reference:
  Active data           → Standard
  Backup (access rarely)→ Standard-IA or Glacier Instant
  Compliance archive    → Glacier Flexible or Deep Archive
  Unknown pattern       → Intelligent-Tiering
  Cheap + replaceable   → One Zone-IA
```

### S3 Versioning

```
Versioning:
  Stores all versions of every object
  Once enabled: can only suspend, not disable
  Deleted objects: adds a delete marker (not truly deleted)
  
  Benefits:
    Recover from accidental deletes (remove delete marker)
    Recover from application overwrites
    Audit history

States:
  Unversioned (default): no version ID
  Versioning-enabled: all new objects get version ID
  Versioning-suspended: new objects get null version ID,
                        existing versions preserved
```

```bash
# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-bucket \
  --versioning-configuration Status=Enabled

# List versions of an object
aws s3api list-object-versions \
  --bucket my-bucket \
  --prefix documents/case-001.pdf

# Restore specific version
aws s3api get-object \
  --bucket my-bucket \
  --key documents/case-001.pdf \
  --version-id abc123 \
  restored-case-001.pdf

# Delete specific version permanently
aws s3api delete-object \
  --bucket my-bucket \
  --key documents/case-001.pdf \
  --version-id abc123

# List delete markers
aws s3api list-object-versions \
  --bucket my-bucket \
  --query 'DeleteMarkers[*].[Key,VersionId]'

# Restore deleted object (remove delete marker)
aws s3api delete-object \
  --bucket my-bucket \
  --key documents/case-001.pdf \
  --version-id DELETE_MARKER_VERSION_ID
```

### S3 Lifecycle Policies

```
Lifecycle rules: automate moving objects between storage classes
                 and deleting old objects

Actions:
  Transition: move to cheaper storage class after N days
  Expiration: delete objects after N days
  Both: transition then delete

Example lifecycle policy (backup data):
  Day 0:   Object uploaded → Standard
  Day 30:  Transition → Standard-IA       (accessed less now)
  Day 90:  Transition → Glacier Instant   (rarely accessed)
  Day 365: Transition → Glacier Deep Archive (compliance hold)
  Day 2555 (7 years): Delete             (regulatory period over)
```

```json
{
  "Rules": [
    {
      "ID": "judicial-data-lifecycle",
      "Status": "Enabled",
      "Filter": {"Prefix": "case-documents/"},
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER_IR"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    },
    {
      "ID": "clean-old-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    },
    {
      "ID": "clean-failed-multipart",
      "Status": "Enabled",
      "Filter": {},
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
```

```bash
# Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket \
  --lifecycle-configuration file://lifecycle.json

# View current lifecycle config
aws s3api get-bucket-lifecycle-configuration --bucket my-bucket
```

### S3 Security

```
Bucket Policy (resource-based):
  JSON policy attached to bucket
  Controls who can access
  Can grant cross-account access
  Example: allow CloudFront to read, deny all other public access

ACLs (Access Control Lists):
  Legacy, coarse-grained (Bucket Owner, Everyone, etc.)
  AWS recommends disabling ACLs (use bucket policies instead)

Block Public Access:
  4 settings per bucket (or account-level):
    BlockPublicAcls:        ignore public ACL grants
    IgnorePublicAcls:       ignore existing public ACLs
    BlockPublicPolicy:      reject bucket policies granting public access
    RestrictPublicBuckets:  restrict public and cross-account access
  
  Best practice: enable all 4 at account level
  Only disable per-bucket for intentionally public buckets (static websites)

Presigned URLs:
  Temporary URL with your credentials embedded
  Valid for: seconds to 7 days
  Use for: private file download links, upload without exposing S3

Encryption:
  SSE-S3:  AWS manages keys (free)
  SSE-KMS: AWS KMS manages keys ($0.03/10K API calls, more control)
  SSE-C:   you provide key per request (AWS doesn't store key)
  Client-side: encrypt before sending to S3

Static Website Hosting:
  Enable on bucket
  Serve index.html and error.html
  No HTTPS (use CloudFront for SSL + CDN)
  Bucket must be public OR use CloudFront OAC (Origin Access Control)
```

### S3 Performance

```
Prefix and partitioning:
  S3 scales automatically per prefix
  3,500 PUT/COPY/POST/DELETE + 5,500 GET/HEAD per second per prefix
  
  Add random prefix to increase parallelism:
    Poor:  logs/2024-03-22/file001.log
    Good:  1a2b/logs/2024-03-22/file001.log
    Good:  a/logs/..., b/logs/..., c/logs/... (different prefixes)

Transfer Acceleration:
  Upload to nearby CloudFront edge → backbone → S3
  Up to 5x faster for long-distance uploads
  Extra cost: $0.04-$0.08/GB
  Enable per bucket: bucket.s3-accelerate.amazonaws.com

Multipart Upload:
  Split large file → upload parts in parallel → assemble
  Required > 5GB, recommended > 100MB
  Benefits: parallel upload, retry individual parts, resume

S3 Select:
  Query CSV/JSON/Parquet files with SQL
  Retrieve only matching data (not full object)
  Use for: log analysis, filtering large CSVs
  aws s3api select-object-content --expression "SELECT * FROM S3Object WHERE status='ERROR'"

S3 Replication:
  Same-Region Replication (SRR): compliance, log aggregation
  Cross-Region Replication (CRR): DR, low-latency global access
  Requires: versioning enabled on both buckets
  NOT retroactive: only replicates new objects after setup
```

---

## PART 3 — DATABASE COMPARISON: WHEN TO USE WHAT

### The Complete Decision Framework

```
Ask these questions to pick the right database:

1. Is data relational (tables + joins)? → RDS/Aurora
2. Do I need ACID transactions? → RDS/Aurora
3. Will I need massive scale (100M+ records, millions req/sec)? → DynamoDB
4. Is access pattern simple (get by key, get by user)? → DynamoDB
5. Do I need sub-millisecond read? → ElastiCache (Redis/Memcached)
6. Is data in-memory only (cache, session)? → ElastiCache
7. Do I need full-text search? → OpenSearch
8. Is data a graph (social network, fraud detection)? → Neptune
9. Is it time-series data (metrics, IoT)? → Timestream
10. Large analytical queries on terabytes? → Redshift / Athena
```

### AWS Database Services — Full Comparison

```
┌─────────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
│ Database        │ Type         │ Use Cases    │ Strengths    │ Limitations  │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ RDS             │ Relational   │ E-commerce,  │ ACID, SQL,   │ Scaling      │
│ (MySQL/Postgres)│ SQL          │ ERP, CRM     │ JOINs        │ complexity   │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ Aurora          │ Relational   │ High-traffic │ 5x MySQL     │ More         │
│                 │ SQL          │ SaaS apps    │ speed, HA    │ expensive    │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ DynamoDB        │ Key-Value /  │ Gaming, IoT, │ Unlimited    │ No JOINs,    │
│                 │ Document     │ User prefs   │ scale, fast  │ limited query│
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ ElastiCache     │ In-Memory    │ Session,     │ <1ms latency │ Volatile     │
│ Redis           │ Cache        │ leaderboard  │ data structs │ (memory)     │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ ElastiCache     │ In-Memory    │ Simple cache │ Faster than  │ No           │
│ Memcached       │ Cache        │ only         │ Redis for    │ persistence  │
│                 │              │              │ simple ops   │ no replication│
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ OpenSearch      │ Search +     │ Log analysis,│ Full-text    │ Not for      │
│                 │ Analytics    │ product search│ search, KQL  │ transactions │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ Neptune         │ Graph        │ Social nets, │ Relationship │ Complex ops, │
│                 │              │ fraud detect │ queries      │ less mature  │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ DocumentDB      │ Document     │ Content mgmt,│ MongoDB      │ Not real     │
│                 │ (MongoDB)    │ catalogues   │ compatible   │ MongoDB      │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ Redshift        │ Data         │ Analytics,   │ Petabyte     │ Not for      │
│                 │ Warehouse    │ BI reports   │ scale SQL    │ transactions │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ Athena          │ Serverless   │ S3 log       │ No infra,    │ Slower than  │
│                 │ SQL on S3    │ analysis     │ pay per query│ Redshift     │
├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ Timestream      │ Time-series  │ IoT, metrics,│ Optimised    │ Niche use    │
│                 │              │ monitoring   │ time queries  │ case only    │
└─────────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
```

### Detailed: When to Choose Each

```
RDS (MySQL / PostgreSQL / MariaDB):
  ✓ Need SQL and JOINs
  ✓ ACID transactions (financial, inventory, booking)
  ✓ Schema is stable and well-defined
  ✓ Team knows SQL well
  ✓ Data size < 10TB
  ✗ Avoid when: massive scale, flexible schema, key-value access

  Real example:
    E-commerce: orders + order_items + products + customers
    All related — JOINs essential → RDS PostgreSQL

Aurora:
  ✓ Same as RDS but:
  ✓ Need higher performance (5x MySQL)
  ✓ Need faster failover (< 30 sec vs 60 sec RDS)
  ✓ Need more read replicas (15 vs 5)
  ✓ Traffic is high enough to justify 20% premium
  ✗ Avoid when: cost is concern, moderate traffic (RDS is fine)

DynamoDB:
  ✓ Simple, predictable access patterns
  ✓ Get item by ID, get all items for user → perfect
  ✓ Massive scale (millions of users, billions of items)
  ✓ Variable schema (different attributes per item)
  ✓ Single-digit millisecond latency at any scale
  ✓ Serverless / event-driven (Lambda integration)
  ✗ Avoid when: complex queries, JOINs needed, reporting

  Real example:
    User sessions, game leaderboards, IoT device state
    Access pattern: get session by sessionId → DynamoDB perfect

ElastiCache Redis:
  ✓ Sub-millisecond latency required
  ✓ Caching database query results (reduce DB load)
  ✓ Session store (web app sessions)
  ✓ Rate limiting (INCR command)
  ✓ Pub/Sub (real-time notifications)
  ✓ Leaderboards (sorted sets)
  ✓ Geospatial data
  ✗ Avoid when: persistence critical (Redis can lose data), large datasets

ElastiCache Memcached:
  ✓ Simple string caching only
  ✓ Multi-threaded (faster for pure cache)
  ✓ Need to scale out (horizontal sharding)
  ✗ Avoid when: need persistence, replication, complex data types

Redis vs Memcached:
  Redis: data structures (lists, sets, sorted sets, hashes)
         persistence (RDB + AOF), replication, clustering
  Memcached: simple string cache, multi-threaded, no persistence
  Choose Redis unless you specifically need Memcached's multi-threading

OpenSearch (Elasticsearch):
  ✓ Full-text search (product search, log search)
  ✓ Fuzzy matching, relevance scoring
  ✓ Log analytics (ELK stack — the L in ELK)
  ✓ Aggregations (count by category, avg price by brand)
  ✓ Kibana dashboards
  ✗ Avoid when: primary data store, ACID needed

  Real example:
    E-commerce: search "nike running shoes" → OpenSearch
    Log analysis: find all 500 errors in last hour → OpenSearch

Neptune:
  ✓ Highly connected data (social graphs, knowledge graphs)
  ✓ Traversal queries ("friends of friends who bought X")
  ✓ Fraud detection (find suspicious patterns in transactions)
  ✓ Recommendation engines
  ✗ Avoid when: tabular data, simple relationships (SQL JOINs are fine)

Redshift:
  ✓ Analytical queries on large datasets (TBs to PBs)
  ✓ Business intelligence (BI tools connect directly)
  ✓ Historical reporting, data warehouse
  ✓ SQL at scale
  ✗ Avoid when: OLTP (transactional workloads), row-level operations

Athena:
  ✓ Query data already in S3 (CSV, JSON, Parquet, ORC)
  ✓ Serverless — no infrastructure to manage
  ✓ Pay per query ($5/TB scanned)
  ✓ Log analysis, one-off queries
  ✗ Avoid when: frequent queries (Redshift cheaper at scale), joins heavy
```

### Database Design Patterns

```
Single-Table Design (DynamoDB):
  All entities in one table — efficient, avoids JOINs
  
  PK              SK              Type
  USER#u001       #METADATA       User record
  USER#u001       ORDER#o100      User's order
  USER#u001       ORDER#o101      User's order
  ORDER#o100      #METADATA       Order details
  ORDER#o100      ITEM#i001       Order item
  PRODUCT#p001    #METADATA       Product
  
  Access patterns:
    Get user:            PK=USER#u001, SK=#METADATA
    Get user's orders:   PK=USER#u001, SK begins_with ORDER#
    Get order items:     PK=ORDER#o100, SK begins_with ITEM#

Read/Write Separation (CQRS):
  Write: RDS (strong consistency, ACID)
  Read:  DynamoDB or ElastiCache (fast, scalable reads)
  Sync: DynamoDB Streams or CDC → read store
  
  Use when: read:write ratio heavily skewed toward reads

Caching Pattern (Cache-Aside):
  Check Redis → hit: return | miss: query RDS, store in Redis
  
  def get_product(product_id):
      # 1. Check cache
      cached = redis.get(f"product:{product_id}")
      if cached:
          return json.loads(cached)
      
      # 2. Query database
      product = db.query("SELECT * FROM products WHERE id = ?", product_id)
      
      # 3. Store in cache (1 hour TTL)
      redis.setex(f"product:{product_id}", 3600, json.dumps(product))
      
      return product

Polyglot Persistence (use multiple databases):
  User data:       RDS PostgreSQL (relational, ACID)
  Product catalog: DynamoDB (scale, flexible schema)
  Search:          OpenSearch (full-text)
  Sessions:        ElastiCache Redis (sub-ms, TTL)
  Analytics:       Redshift (complex queries)
  
  Each database optimised for its workload
```

### Migration Strategies

```
Database Migration Service (DMS):
  Migrate databases to AWS with minimal downtime
  Supports: Oracle, SQL Server, MySQL, PostgreSQL, MongoDB
  Continuous replication (CDC): near-zero downtime cutover

  Homogeneous: MySQL → RDS MySQL (same engine)
  Heterogeneous: Oracle → Aurora PostgreSQL (different engine)
    First: Schema Conversion Tool (SCT) to convert schema
    Then: DMS for data migration

RDS Migration (your resume experience):
  Step 1: Create target RDS instance with right config
  Step 2: Set up security (SG, parameter groups, IAM)
  Step 3: Enable DMS replication (or pg_dump/restore)
  Step 4: Cutover (update connection strings)
  Step 5: Validate data integrity
  Step 6: Monitor for issues

Zero-downtime migration strategy:
  1. Create new RDS with DMS replication from old DB
  2. Keep in sync until cutover
  3. Put app in read-only mode briefly
  4. Let replication catch up
  5. Update connection string to new DB
  6. Take app out of read-only mode
  Total downtime: < 5 minutes
```

---

## PART 4 — RDS + AURORA

### RDS Overview

```
Amazon RDS = managed relational database service
Supported engines: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server
Aurora: AWS's own cloud-optimised engine (MySQL/PostgreSQL compatible)

What RDS manages for you:
  ✓ OS patching
  ✓ DB software updates
  ✓ Automated backups
  ✓ Point-in-time recovery
  ✓ Multi-AZ failover
  ✓ Read replicas
  ✓ Encryption at rest + in transit
  ✓ Performance Insights
  
What you still manage:
  Schema design
  Query optimisation
  Connection pooling
  Application-level logic
```

### Multi-AZ vs Read Replicas

```
Multi-AZ (High Availability):
  Purpose: fault tolerance, NOT performance
  How: synchronous replication to standby in another AZ
  Failover: automatic (~60 seconds) if primary fails
  Standby: NOT accessible for reads (just a warm spare)
  Extra cost: 2x (running two instances)
  
  When primary fails:
  1. RDS detects failure via health check
  2. DNS record updated to point to standby
  3. Standby promoted to primary (~60 sec)
  4. Old primary becomes new standby
  5. Your app reconnects (using RDS endpoint, not IP)

Read Replicas (Performance):
  Purpose: scale read traffic, NOT HA
  How: asynchronous replication from primary
  Lag: usually < 1 second, but no guarantee
  Access: YES — readable endpoints for each replica
  Promotion: manual (for disaster recovery)
  Can be in different region (cross-region replica)
  
  Use when: read-heavy app, reports/analytics queries
  Example: API reads from replica, writes to primary
```

### Aurora vs RDS

```
Aurora MySQL/PostgreSQL:
  Storage: distributed, fault-tolerant, auto-scales 10GB to 128TB
  Replication: 6 copies across 3 AZs (built-in, not optional)
  Failover: < 30 seconds (faster than standard RDS)
  Read replicas: up to 15 (vs 5 for RDS)
  Cost: ~20% more than standard RDS
  Performance: 5x faster than MySQL, 3x faster than PostgreSQL

Aurora Serverless:
  Auto-scales capacity up and down per demand
  Pauses when idle (dev/test: cost-saving)
  Cold start: 20-30 seconds on first query after pause
  Use for: unpredictable workloads, dev environments

Aurora Global Database:
  Primary in one region, read replicas in up to 5 regions
  Replication lag: < 1 second globally
  Disaster recovery: promote secondary region in < 1 minute
  Use for: global low-latency reads, DR
```

### RDS Security

```
Encryption at rest:
  KMS key encrypts: data, automated backups, snapshots, logs
  Enable at creation (can't enable on existing unencrypted DB)
  To encrypt existing: snapshot → copy with encryption → restore

Encryption in transit:
  SSL/TLS: force SSL with parameter group
  rds.force_ssl = 1  (PostgreSQL)

Network isolation:
  Always put RDS in private subnet
  No public accessibility (unless explicitly needed — don't)
  Security Group: only allow from app server SG (not 0.0.0.0/0)

IAM Database Authentication:
  Instead of password: use IAM token (15-min expiry)
  Token generated by AWS SDK via sts:generate-db-auth-token
  Rotating credentials automatically (no static passwords)

RDS Proxy:
  Connection pooler between Lambda/app and RDS
  Reduces connection overhead (Lambda creates many connections)
  Supports IAM auth and Secrets Manager rotation
  Increases DB availability (connections survive DB failover)
```

### RDS Hands-on

```bash
# Create RDS PostgreSQL instance via CLI
aws rds create-db-instance \
  --db-instance-identifier judicial-prod-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 16.1 \
  --master-username admin \
  --master-user-password $(aws secretsmanager get-secret-value \
    --secret-id judicial/db/password \
    --query SecretString --output text) \
  --allocated-storage 20 \
  --storage-type gp3 \
  --storage-encrypted \
  --multi-az \
  --db-subnet-group-name judicial-db-subnet-group \
  --vpc-security-group-ids sg-12345678 \
  --backup-retention-period 7 \
  --deletion-protection \
  --no-publicly-accessible

# Create read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier judicial-prod-db-replica \
  --source-db-instance-identifier judicial-prod-db \
  --db-instance-class db.t3.small

# Point-in-time restore
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier judicial-prod-db \
  --target-db-instance-identifier judicial-prod-db-restored \
  --restore-time 2024-03-22T10:00:00Z

# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier judicial-prod-db \
  --db-snapshot-identifier judicial-prod-manual-snapshot-20240322

# Monitor
aws rds describe-db-instances \
  --db-instance-identifier judicial-prod-db \
  --query 'DBInstances[0].[DBInstanceStatus,MultiAZ,ReadReplicaDBInstanceIdentifiers]'
```

### Interview Questions

**Q: You're designing a database for an e-commerce app with 10,000 orders/day and heavy read traffic for product catalog. What RDS setup do you recommend?**

```
Setup:
  Primary: RDS PostgreSQL Multi-AZ (db.m5.large)
    - All writes go here
    - Multi-AZ for fault tolerance
  
  Read Replica 1: same region
    - Product catalog reads (heavy, cacheable)
    - Can afford replication lag for catalog
  
  Read Replica 2: cross-region (us-east-1)
    - DR capability
    - Can promote if primary region fails
  
  RDS Proxy: between Lambda/app and primary
    - Manages connection pool
    - Supports IAM authentication
  
  ElastiCache Redis: in front of read replica
    - Cache product catalog (rarely changes)
    - 95% cache hit rate → replica only sees cache misses

  Why not Aurora?
    At 10K orders/day → standard RDS is sufficient
    Aurora at 20% more cost only worth it at higher scale
```

**Q: Your RDS instance is showing high CPU. What do you check?**

```
1. Performance Insights (RDS → Performance Insights)
   Identifies top SQL queries consuming CPU
   Shows waits: CPU, I/O, locks

2. Slow query log
   Enable: slow_query_log = 1, long_query_time = 1
   Check: SELECT * FROM mysql.slow_log ORDER BY query_time DESC

3. Missing indexes
   EXPLAIN ANALYZE SELECT ... → look for Seq Scan

4. N+1 query problem
   Application making many small queries in a loop

5. Autovacuum (PostgreSQL)
   Tables with high churn → bloat → slow queries
   Run: VACUUM ANALYZE table_name

6. Connections exhausted
   Too many connections → connection wait
   Fix: RDS Proxy or connection pooling (PgBouncer)
```

---

## PART 5 — CLOUDWATCH DEEP DIVE

### CloudWatch Components

```
Metrics:
  Numerical data points over time
  Default: AWS service metrics (CPU, network, disk)
  Custom: your app metrics (orders/min, error rate, response time)
  Retention: 1 min data = 15 days, 5 min = 63 days, 1 hr = 455 days

Logs:
  Log Groups: collection of log streams (e.g., /aws/lambda/my-func)
  Log Streams: sequence of events (e.g., one Lambda execution context)
  Log Insights: SQL-like query language for log analysis
  Metric Filters: extract metrics from log patterns

Alarms:
  Watch a metric, trigger action when threshold crossed
  States: OK, ALARM, INSUFFICIENT_DATA
  Actions: SNS notification, Auto Scaling, EC2 action

Dashboards:
  Visualise metrics across services
  Share with team
  Auto refresh

Events/EventBridge:
  React to AWS events (EC2 state change, S3 object created, etc.)
  Schedule tasks (cron expression)
  Route events to Lambda, SQS, SNS, Step Functions
```

### Custom Metrics

```python
import boto3
from datetime import datetime

def push_custom_metric(
    namespace: str,
    metric_name: str,
    value: float,
    unit: str = 'Count',
    dimensions: dict = None
):
    """Push custom metric to CloudWatch."""
    cw = boto3.client('cloudwatch', region_name='ap-south-1')
    
    metric_data = {
        'MetricName': metric_name,
        'Value': value,
        'Unit': unit,
        'Timestamp': datetime.utcnow()
    }
    
    if dimensions:
        metric_data['Dimensions'] = [
            {'Name': k, 'Value': v}
            for k, v in dimensions.items()
        ]
    
    cw.put_metric_data(
        Namespace=namespace,
        MetricData=[metric_data]
    )

# Track deployment metrics
push_custom_metric(
    namespace='JudicialSolutions/Deployments',
    metric_name='DeploymentDuration',
    value=423.5,
    unit='Seconds',
    dimensions={'Environment': 'prod', 'Service': 'api'}
)

push_custom_metric(
    namespace='JudicialSolutions/Business',
    metric_name='CasesCreated',
    value=47,
    dimensions={'Environment': 'prod'}
)
```

### CloudWatch Logs Insights

```sql
-- Find error rate in Lambda logs
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as error_count by bin(5m)
| sort @timestamp desc

-- Slow API responses
fields @timestamp, requestId, duration
| filter duration > 3000
| sort duration desc
| limit 20

-- Count unique users
fields @timestamp, userId
| stats count_distinct(userId) as unique_users by bin(1h)

-- Lambda cold starts
fields @timestamp, @initDuration, @duration
| filter @initDuration > 0
| stats avg(@initDuration) as avg_cold_start, count(*) as cold_starts by bin(1h)

-- Error breakdown by type
fields @timestamp, @message
| filter @message like /Exception/
| parse @message "* Exception: *" as exception_type, exception_msg
| stats count(*) as count by exception_type
| sort count desc
```

### Alarms and Composite Alarms

```bash
# Create alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "judicial-api-high-error-rate" \
  --alarm-description "API error rate > 5%" \
  --namespace "AWS/Lambda" \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=judicial-api \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:ap-south-1:ACCOUNT:devops-alerts \
  --ok-actions arn:aws:sns:ap-south-1:ACCOUNT:devops-alerts \
  --treat-missing-data notBreaching

# Composite alarm (alert only when BOTH conditions are true)
aws cloudwatch put-composite-alarm \
  --alarm-name "judicial-api-critical" \
  --alarm-rule "ALARM(judicial-api-high-error-rate) AND ALARM(judicial-api-high-latency)" \
  --alarm-actions arn:aws:sns:ap-south-1:ACCOUNT:pagerduty

# Anomaly detection alarm (no fixed threshold)
aws cloudwatch put-metric-alarm \
  --alarm-name "judicial-api-anomaly" \
  --comparison-operator GreaterThanUpperThreshold \
  --evaluation-periods 2 \
  --metrics '[
    {"Id":"m1","MetricStat":{"Metric":{"Namespace":"AWS/Lambda","MetricName":"Duration","Dimensions":[{"Name":"FunctionName","Value":"judicial-api"}]},"Period":300,"Stat":"Average"}},
    {"Id":"ad1","Expression":"ANOMALY_DETECTION_BAND(m1, 2)"}
  ]' \
  --threshold-metric-id ad1
```

### CloudWatch Agent (EC2 metrics)

```json
// /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "JudicialSolutions/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "disk": {
        "measurement": ["used_percent", "inodes_free"],
        "resources": ["/", "/tmp"]
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available"]
      },
      "netstat": {
        "measurement": ["tcp_established", "tcp_time_wait"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/judicial/nginx/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/app/app.log",
            "log_group_name": "/judicial/app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

---

## PART 6 — ROUTE53

### DNS Concepts

```
DNS Record Types:
  A:     domain → IPv4 address
  AAAA:  domain → IPv6 address
  CNAME: domain → another domain (can't use for apex/root domain)
  ALIAS: domain → AWS resource (like CNAME but works at apex)
         Use ALIAS for: ALB, CloudFront, S3 website, API Gateway
  MX:    mail server
  TXT:   text (domain verification, SPF, DKIM)
  NS:    name servers for zone
  SOA:   start of authority

TTL (Time To Live):
  How long DNS resolvers cache the record
  Low TTL (60s): faster propagation for changes
  High TTL (86400s): less DNS queries, better performance
  During failover: lower TTL first, then change, then raise TTL
```

### Routing Policies

```
Simple:
  One record, one or more values
  Random selection if multiple IPs
  No health checks
  Use for: single resource

Weighted:
  Multiple records, each with a weight (0-255)
  Traffic distributed proportionally
  Use for: A/B testing, gradual migration
  Example: v1=90, v2=10 → 90% to v1, 10% to v2

Latency:
  Routes to region with lowest latency for the user
  AWS measures latency from user to each region
  Use for: global apps, reduce response time

Failover:
  Primary record: serves traffic when healthy
  Secondary record: serves when primary is unhealthy
  Requires health check on primary
  Use for: active-passive DR

Geolocation:
  Route based on user's geographic location
  Continent, country, or US state
  Use for: serve regional content, compliance (data residency)

Geoproximity:
  Route based on location + bias
  Bias: expand or shrink the region that gets traffic
  Requires Traffic Flow
  Use for: shift traffic between regions gradually

Multi-Value Answer:
  Multiple records, returns up to 8 healthy values
  Client randomly selects
  Like simple with health checks
  NOT a replacement for load balancer
```

### Health Checks

```bash
# Create health check
aws route53 create-health-check \
  --caller-reference "judicial-api-check-$(date +%s)" \
  --health-check-config '{
    "Type": "HTTPS",
    "FullyQualifiedDomainName": "api.judicialsolutions.in",
    "Port": 443,
    "ResourcePath": "/health",
    "RequestInterval": 30,
    "FailureThreshold": 3,
    "MeasureLatency": true,
    "Regions": ["ap-south-1", "us-east-1", "eu-west-1"]
  }'

# Health check types:
# HTTP/HTTPS: checks endpoint response (2xx/3xx = healthy)
# TCP: checks if port is open
# Calculated: based on other health checks (AND/OR logic)
# CloudWatch: based on CloudWatch alarm state
```

### Failover Example

```bash
# Primary record (us-east-1 — primary region)
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.judicialsolutions.in",
        "Type": "A",
        "SetIdentifier": "primary",
        "Failover": "PRIMARY",
        "HealthCheckId": "PRIMARY_HEALTH_CHECK_ID",
        "AliasTarget": {
          "HostedZoneId": "ALB_HOSTED_ZONE_ID",
          "DNSName": "my-alb.us-east-1.elb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# Secondary record (ap-south-1 — DR region)
# Similar with "Failover": "SECONDARY"
# No health check needed on secondary (always serves if primary fails)
```

---

## PART 7 — SQS + SNS + EVENTBRIDGE

### SQS Deep Dive

```
SQS = Simple Queue Service
  Decouples producers and consumers
  Producer sends message → queue stores → consumer reads and processes

Key settings:
  Visibility Timeout: how long message hidden after received (default 30s)
  Message Retention:  how long stored if not consumed (1min-14days, default 4days)
  Delivery Delay:     delay before message is available (0-15min)
  Max Message Size:   256KB (use S3 pointer for larger payloads)
  Long Polling:       wait up to 20s for messages (--wait-time-seconds 20)
                      reduces empty receives → cheaper, fewer API calls

Standard vs FIFO:
  Standard: at-least-once, best-effort ordering, unlimited throughput
  FIFO: exactly-once, strict ordering per MessageGroupId, 300 TPS
```

```python
import boto3
import json
from typing import Optional

class SQSProducer:
    def __init__(self, queue_url: str, region='ap-south-1'):
        self.sqs = boto3.client('sqs', region_name=region)
        self.queue_url = queue_url
    
    def send(self, message: dict, delay_seconds: int = 0) -> str:
        """Send message to SQS queue."""
        response = self.sqs.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps(message),
            DelaySeconds=delay_seconds,
            MessageAttributes={
                'Source': {
                    'DataType': 'String',
                    'StringValue': 'judicial-api'
                }
            }
        )
        return response['MessageId']
    
    def send_batch(self, messages: list) -> dict:
        """Send up to 10 messages in one API call."""
        entries = [
            {
                'Id': str(i),
                'MessageBody': json.dumps(msg),
                'DelaySeconds': 0
            }
            for i, msg in enumerate(messages[:10])
        ]
        return self.sqs.send_message_batch(
            QueueUrl=self.queue_url,
            Entries=entries
        )


class SQSConsumer:
    def __init__(self, queue_url: str, region='ap-south-1'):
        self.sqs = boto3.client('sqs', region_name=region)
        self.queue_url = queue_url
    
    def receive(self, max_messages: int = 10) -> list:
        """Poll for messages with long polling."""
        response = self.sqs.receive_message(
            QueueUrl=self.queue_url,
            MaxNumberOfMessages=max_messages,
            WaitTimeSeconds=20,      # long polling
            AttributeNames=['All'],
            MessageAttributeNames=['All']
        )
        return response.get('Messages', [])
    
    def process_and_delete(self, message: dict, processor):
        """Process message and delete on success."""
        receipt_handle = message['ReceiptHandle']
        try:
            body = json.loads(message['Body'])
            processor(body)
            
            # Only delete after successful processing
            self.sqs.delete_message(
                QueueUrl=self.queue_url,
                ReceiptHandle=receipt_handle
            )
        except Exception as e:
            # Don't delete — message will reappear after visibility timeout
            # After maxReceiveCount → moves to DLQ
            raise
```

### SNS (Simple Notification Service)

```
SNS = pub/sub messaging service
  Publisher sends to Topic
  Topic fans out to all subscriptions simultaneously

Subscription types:
  SQS:    reliable async (messages queued, processed later)
  Lambda: serverless processing
  HTTP/S: webhook to your endpoint
  Email:  human notification
  SMS:    text message
  Mobile Push: iOS/Android push notification

Fan-out pattern:
  S3 event → SNS topic
             ├── SQS queue 1 → Lambda (resize image)
             ├── SQS queue 2 → Lambda (update database)
             └── SQS queue 3 → Lambda (send notification)
  
  Why SNS → SQS (not S3 → SQS directly):
    SNS can fan out to multiple SQS queues
    SQS provides buffering (Lambda not overwhelmed)
    Each subscriber processes independently

Message filtering:
  Subscriber gets only messages matching their filter
  Filter on message attributes:
    topic subscription filter policy:
    {"eventType": ["ORDER_CREATED", "ORDER_UPDATED"]}
```

### EventBridge

```
EventBridge = serverless event bus
  Receives events from:
    AWS services (EC2 state change, S3 object created, CodePipeline)
    Custom applications (put_events API)
    SaaS partners (Zendesk, Datadog, PagerDuty)
  
  Routes to targets:
    Lambda, SQS, SNS, Step Functions, API Gateway, ECS task, CodePipeline

Event pattern matching:
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["stopped", "terminated"]
  }
}

Schedule (cron):
  Fixed rate: rate(5 minutes)
  Cron:       cron(0 12 * * ? *)  → noon every day UTC

Real use cases:
  EC2 stopped → Lambda → post to Slack
  CodePipeline failed → EventBridge → Lambda → send PagerDuty alert
  RDS snapshot completed → EventBridge → Lambda → copy to DR region
  Daily at 2am → EventBridge → Lambda → cleanup old artifacts
```

```bash
# Create EventBridge rule
aws events put-rule \
  --name "ec2-stopped-alert" \
  --event-pattern '{
    "source": ["aws.ec2"],
    "detail-type": ["EC2 Instance State-change Notification"],
    "detail": {"state": ["stopped", "terminated"]}
  }' \
  --state ENABLED

# Add Lambda as target
aws events put-targets \
  --rule "ec2-stopped-alert" \
  --targets '[{
    "Id": "1",
    "Arn": "arn:aws:lambda:ap-south-1:ACCOUNT:function:slack-notifier"
  }]'

# Schedule rule
aws events put-rule \
  --name "daily-cleanup" \
  --schedule-expression "cron(0 2 * * ? *)" \
  --state ENABLED
```

---

## PART 8 — AWS SECURITY

### WAF (Web Application Firewall)

```
WAF protects against:
  SQL injection
  Cross-site scripting (XSS)
  OWASP Top 10
  Bad bots
  IP-based attacks
  Rate-based rules (DDoS at L7)

Attach to: ALB, CloudFront, API Gateway, AppSync

Web ACL (Access Control List):
  Collection of rules evaluated in order
  Default action: Allow or Block
  Each rule: condition + action (Allow/Block/Count/CAPTCHA)

Rule groups:
  AWS Managed Rules: pre-built by AWS (AWSManagedRulesCommonRuleSet)
  AWS Marketplace: third-party (Fortinet, F5)
  Custom: your own rules

Rate-based rule:
  Block IP if > N requests in 5 minutes
  Use for: API abuse, credential stuffing, DDoS mitigation
```

```bash
# Create WAF WebACL for CloudFront
aws wafv2 create-web-acl \
  --name judicial-waf \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --default-action Allow={} \
  --rules '[
    {
      "Name": "AWSManagedRulesCommonRuleSet",
      "Priority": 1,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "OverrideAction": {"None": {}},
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "CommonRules"
      }
    },
    {
      "Name": "RateLimit",
      "Priority": 2,
      "Statement": {
        "RateBasedStatement": {
          "Limit": 2000,
          "AggregateKeyType": "IP"
        }
      },
      "Action": {"Block": {}},
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimit"
      }
    }
  ]' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=judicial-waf
```

### Shield

```
Shield Standard (free, automatic):
  Protects against common L3/L4 DDoS attacks
  Applied to: all AWS resources automatically
  SYN floods, UDP reflection, volumetric attacks

Shield Advanced ($3,000/month):
  Enhanced L3/L4/L7 protection
  DDoS Response Team (DRT) 24/7 support
  Cost protection (credit for scaling costs during attack)
  Detailed attack diagnostics
  Apply to: ALB, CloudFront, Route53, EC2 EIPs, Global Accelerator

When to use Advanced:
  High-profile applications (banking, government)
  Already experienced DDoS
  Business-critical, can't afford downtime
```

### GuardDuty

```
GuardDuty = threat detection service
  Continuously monitors:
    CloudTrail: API calls (suspicious API activity)
    VPC Flow Logs: network traffic (port scanning, unusual connections)
    DNS logs: DNS queries (crypto mining, malware C2)
    EKS audit logs: Kubernetes API activity
  
  Findings categories:
    Backdoor: EC2 running as crypto miner, DDoS attack tool
    Recon: port scanning, unusual API calls
    Stealth: CloudTrail logging disabled
    Trojan: DNS requests to known malicious domains
    UnauthorizedAccess: SSH brute force, unusual login
    Credential access: unusual IAM user activity

Cost: based on data volume analysed
Enable with one click (or Terraform):
  aws guardduty create-detector --enable

Respond to findings:
  GuardDuty finding → EventBridge → Lambda → auto-remediate
  E.g.: finding "EC2 crypto mining" → Lambda → isolate EC2 (change SG)
```

### Security Hub

```
Security Hub = aggregated security view
  Collects findings from:
    GuardDuty, Inspector, Macie, Firewall Manager, IAM Access Analyzer
    Third-party tools (Crowdstrike, Palo Alto)
  
  Compliance standards:
    AWS Foundational Security Best Practices
    CIS AWS Foundations Benchmark
    PCI DSS
    NIST 800-53
  
  Shows: compliance score, failed controls, trend over time
  
  Action on findings:
    Security Hub → EventBridge → Lambda → Jira ticket
    Security Hub → EventBridge → Lambda → auto-remediate
    Security Hub → SNS → email security team

Macie:
  Discovers and protects sensitive data in S3
  Uses ML to identify: PII, credentials, financial data
  Alerts: "bucket contains credit card numbers"
  Compliance: GDPR, HIPAA data discovery

Inspector:
  Vulnerability management for EC2, Lambda, ECR images
  Continuously scans for CVEs in OS packages and language libraries
  Integrates with ECR: scans images on push
  Provides risk score and remediation guidance
```

---

## PART 9 — ECS DEEP DIVE

### ECS Components

```
Cluster:
  Logical grouping of tasks/services
  Can be: EC2-backed or Fargate

Task Definition:
  Blueprint for your containers (like Dockerfile but for ECS)
  Defines: image, CPU, memory, ports, env vars, volumes, IAM roles

Task:
  Running instance of a task definition (like a Pod in K8s)
  Ephemeral: runs and stops
  Use for: one-off jobs, batch processing

Service:
  Ensures N tasks always running
  Handles: task failure → replace, rolling updates, load balancing
  Use for: long-running applications (web servers, APIs)

Launch Types:
  EC2: you manage the EC2 instances in the cluster
  Fargate: serverless — AWS manages the infrastructure
           You only define CPU/memory per task
```

### Task Definition

```json
{
  "family": "judicial-api",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/judicial-task-role",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "judicial-api",
      "image": "ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/judicial-api:latest",
      "essential": true,
      "portMappings": [
        {"containerPort": 8080, "protocol": "tcp"}
      ],
      "environment": [
        {"name": "ENV", "value": "prod"},
        {"name": "LOG_LEVEL", "value": "info"}
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-south-1:ACCOUNT:secret:judicial/db:password::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/judicial-api",
          "awslogs-region": "ap-south-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### ECS vs EKS

```
ECS:
  AWS-native, simpler
  No control plane cost
  Less configuration
  Good for: AWS-only teams, simple containerised apps
  Fargate: truly serverless

EKS:
  Kubernetes-native, portable
  $0.10/hr control plane
  More complex, more powerful
  Good for: K8s expertise, multi-cloud, complex apps
  Ecosystem: Helm, ArgoCD, Istio, Prometheus

Choose ECS when:
  New to containers, simpler operations
  Pure AWS shop
  Cost-sensitive (no control plane fee)
  Fargate for variable workloads

Choose EKS when:
  Already know Kubernetes
  Need K8s ecosystem (Helm charts, operators)
  Plan for multi-cloud
  Complex networking (Istio, eBPF)
```

### Service Discovery

```
ECS Service Discovery (Cloud Map):
  Each task registers in Route53 private hosted zone
  DNS: my-service.local → task IPs
  Works across VPC
  
  ECS creates:
    Route53 private hosted zone: judicial.local
    SRV record: judicial-api.judicial.local → task IPs

ALB integration:
  Service registers with target group
  ALB routes traffic to healthy tasks
  Path routing: /api → judicial-api service

App Mesh (service mesh for ECS):
  Sidecar Envoy proxy on each task
  mTLS between services
  Circuit breaking, retries, observability
  Similar to Istio but AWS-native
```

---

## PART 10 — COST OPTIMISATION

### EC2 Pricing Models

```
On-Demand:
  Pay by the second/hour
  No commitment
  Most expensive
  Use for: unpredictable workloads, short-term

Reserved Instances (RI):
  1 or 3 year commitment
  Up to 72% discount vs On-Demand
  Types:
    Standard:     highest discount, specific instance type
    Convertible:  can change instance type, less discount
    Scheduled:    reserved capacity for specific time windows

Savings Plans:
  Commit to $ per hour for 1 or 3 years
  Types:
    Compute Savings Plans: any instance type, any region (most flexible)
    EC2 Savings Plans: specific instance family + region
  Similar discount to RIs but more flexible
  Automatically applies to Lambda and Fargate too

Spot Instances:
  Up to 90% discount
  Can be interrupted with 2-minute warning
  Use for: batch jobs, ML training, stateless workers, dev/test
  Not for: production critical apps, databases

Dedicated Hosts:
  Physical server dedicated to you
  Required for: license compliance (per-socket/per-core software)
  Most expensive

Savings calculation example:
  m5.large On-Demand: $0.096/hr = $840/yr
  1yr Reserved (partial upfront): $0.056/hr = $490/yr → 42% savings
  3yr Reserved (all upfront): $0.035/hr = $306/yr → 64% savings
  Spot: $0.015-0.030/hr → 70-85% savings (with interruption risk)
```

### Cost Optimisation Strategies

```
Right-sizing:
  Use CloudWatch metrics to identify underutilised resources
  Instance running at 5% CPU → downsize to smaller instance
  AWS Compute Optimizer: ML-based recommendations
  Trusted Advisor: highlights idle/underutilised resources

Auto Scaling:
  Scale down during nights/weekends
  Scheduled scaling: small at 10pm, large at 8am
  Step scaling: add capacity as load increases, reduce when it drops

S3 Cost Optimisation:
  Storage classes (move data to cheaper tiers):
    Standard:           frequently accessed  ($0.023/GB)
    Standard-IA:        infrequent access   ($0.0125/GB)
    One Zone-IA:        single AZ           ($0.01/GB)
    Glacier Instant:    archive, ms retrieval ($0.004/GB)
    Glacier Flexible:   archive, hours       ($0.0036/GB)
    Glacier Deep:       rare access, 12hrs   ($0.00099/GB)
  
  S3 Lifecycle policies:
    Move to IA after 30 days
    Move to Glacier after 90 days
    Delete after 365 days
  
  S3 Intelligent-Tiering:
    Automatically moves objects between tiers based on access patterns
    No retrieval fee, monitoring fee: $0.0025/1000 objects

Data Transfer:
  Inbound to AWS: free
  Within same AZ: free
  Between AZs: $0.01/GB each direction
  Out to internet: $0.09/GB (first 10TB/month)
  
  Reduce costs:
    Use VPC endpoints for S3/DynamoDB (avoid data transfer fees)
    CloudFront: reduces origin requests, lower transfer cost
    Same-AZ: put app and DB in same AZ (free transfer)

Serverless (Lambda/Fargate):
  Pay per use → zero cost when idle
  Better than EC2 for bursty/variable workloads
  Lambda: first 1M requests/month free + 400,000 GB-seconds free
```

### AWS Cost Tools

```
Cost Explorer:
  Visualise and analyse costs over time
  Forecast future costs
  Filter by: service, region, tag, linked account
  Identify cost anomalies

AWS Budgets:
  Set budget thresholds, get alerts
  Types: Cost budget, Usage budget, Reservation budget
  Alert when: actual spend > threshold, forecasted to exceed budget

Trusted Advisor:
  Cost optimisation checks:
    Idle EC2 instances (< 10% CPU for 14 days)
    Unused Elastic IPs ($0.005/hr when not attached)
    Underutilised RDS instances
    S3 bucket versioning (excessive versions)

Cost Allocation Tags:
  Tag all resources: Project, Environment, Team, CostCenter
  View cost breakdown by tag in Cost Explorer
  Enforce tagging with AWS Config rules or SCPs

Savings Plans and RI coverage:
  Coverage: % of compute hours covered by discounted pricing
  Utilisation: % of Reserved capacity actually being used
  Target: > 80% utilisation (unused RI = wasted spend)
```

---

## PART 11 — AWS NETWORKING DEEP DIVE

### VPC Advanced

```
CIDR Planning:
  Use RFC 1918 private ranges:
    10.0.0.0/8    → 16M addresses (large enterprise)
    172.16.0.0/12 → 1M addresses (medium)
    192.168.0.0/16 → 65K addresses (small)
  
  Plan for future:
    VPC too small → can't expand (must recreate)
    Multiple VPCs → use non-overlapping ranges
    Peering: CIDRs must not overlap

VPC Peering:
  Direct connection between 2 VPCs (same or different accounts/regions)
  No transitive peering (A→B, B→C ≠ A→C)
  Route tables must be updated in BOTH VPCs
  No bandwidth limits, low latency
  Use for: 2-3 VPCs, simple connectivity

Transit Gateway (TGW):
  Central hub connecting multiple VPCs, VPNs, Direct Connect
  Transitive routing: all attached can talk to each other
  One TGW attachment per VPC ($0.05/hr per attachment + data)
  Use for: hub-and-spoke, 4+ VPCs, mixed connectivity
  
  With TGW vs peering:
    5 VPCs peered = 10 peering connections (N*(N-1)/2)
    5 VPCs with TGW = 5 attachments (N)
```

### AWS Direct Connect

```
Direct Connect = dedicated physical connection to AWS
  Your data centre → Direct Connect location → AWS region
  Speeds: 1 Gbps, 10 Gbps, 100 Gbps
  Not encrypted by default (add VPN over Direct Connect for encryption)

Benefits:
  More consistent bandwidth (not shared internet)
  Lower latency
  Reduced data transfer costs vs internet
  Compliance (data doesn't traverse public internet)

Provisioning:
  Takes weeks (physical infrastructure)
  Work with AWS Direct Connect partner (Tata, Airtel, etc.)

Direct Connect Gateway:
  One Direct Connect → multiple AWS regions
  Without: one Direct Connect per region

High Availability:
  Single DC: single point of failure
  HA: two Direct Connect connections (different locations)
  Backup: Site-to-Site VPN as backup (cheaper but slower)
```

### Site-to-Site VPN

```
Encrypted tunnel between on-premises and AWS VPC
  Uses IPSec protocol
  Bandwidth: up to 1.25 Gbps per tunnel
  Two tunnels (redundancy): each terminates in different AZ
  Cost: ~$0.05/hr per VPN connection + data

Components:
  Virtual Private Gateway (VGW): AWS side of tunnel
  Customer Gateway (CGW): your on-premises router config
  VPN Connection: the actual tunnel (two tunnels = HA)

Setup:
  1. Create Customer Gateway (your router's public IP)
  2. Create Virtual Private Gateway, attach to VPC
  3. Create VPN Connection (CGW + VGW)
  4. Download VPN config (for your router brand)
  5. Configure your router with provided settings
  6. Add routes to VPC route table (your on-prem CIDR → VGW)

VPN CloudHub:
  Multiple offices → AWS via VPN
  Offices can communicate through AWS (hub)
  Only if BGP is configured
```

### PrivateLink

```
AWS PrivateLink = expose your service privately to other VPCs
  Without: share service publicly (internet) or peer all VPCs
  With: create endpoint, consumers connect privately (no peering)
  
  Components:
    NLB in your VPC (service provider)
    VPC Endpoint in consumer VPC
    PrivateLink connection between them
  
  Traffic stays within AWS network
  Works across accounts, no need to manage peering
  
  Use cases:
    SaaS provider: expose service to customers via PrivateLink
    Internal: expose shared services to other teams/VPCs
    AWS services: S3, DynamoDB, etc. via VPC Endpoints (Interface)

Comparison:
  VPC Peering: full VPC-to-VPC connectivity (broad)
  PrivateLink: specific service exposed (narrow, more secure)
```

---

## PART 12 — CLOUDFORMATION vs TERRAFORM

### CloudFormation

```
CloudFormation = AWS-native IaC
  JSON or YAML templates
  Managed by AWS (no state file to manage)
  Deep AWS integration (IAM, Cost Tags, Drift detection)

Template structure:
AWSTemplateFormatVersion: '2010-09-09'
Description: Judicial Solutions API Stack

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: dev

Mappings:
  InstanceTypes:
    dev:     {Api: t3.micro}
    staging: {Api: t3.small}
    prod:    {Api: m5.large}

Conditions:
  IsProduction: !Equals [!Ref Environment, prod]

Resources:
  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub judicial-api-${Environment}
      Runtime: python3.12
      Handler: app.lambda_handler
      Role: !GetAtt LambdaRole.Arn
      Environment:
        Variables:
          ENV: !Ref Environment

Outputs:
  ApiEndpoint:
    Value: !GetAtt ApiGateway.ApiEndpoint
    Export:
      Name: !Sub ${AWS::StackName}-ApiEndpoint

CloudFormation features:
  Stack: deployed unit (create/update/delete together)
  StackSets: deploy same stack to multiple accounts/regions
  Drift detection: find manual changes to stack resources
  Change sets: preview changes before applying (like terraform plan)
  Rollback: automatic on failure (unlike Terraform)
```

### Terraform vs CloudFormation

```
Terraform:
  Pros:
    Multi-cloud (AWS, GCP, Azure, K8s, GitHub, etc.)
    Rich ecosystem (1000+ providers)
    Better modularity and reuse
    Plan output clearer than Change Sets
    Larger community
    HCL is more readable than JSON/YAML
  
  Cons:
    State file management (must handle S3 + locking)
    No automatic rollback on failure
    Provider version management complexity
    Not AWS-native

CloudFormation:
  Pros:
    No state file (AWS manages it)
    Automatic rollback on failure
    Native AWS integration (Service Catalog, Config, etc.)
    StackSets for multi-account/region
    Free (Terraform Cloud costs money for team features)
    Drift detection built-in
  
  Cons:
    AWS only
    JSON/YAML less readable
    Slower (waits for resource creation)
    Limited multi-cloud support

When to use:
  Terraform: multi-cloud, existing K8s/GitHub infra, team prefers HCL
  CloudFormation: AWS-only, want AWS-managed state, need StackSets, compliance
  
  In practice: most AWS shops use Terraform
  Your resume: Terraform → stick with it, don't need CF expertise
  
  AWS CDK: write CF in Python/TypeScript (best of both worlds)
    Generates CloudFormation, uses CF's state management
    Good if you prefer programming languages over HCL/YAML
```

### SAM (Serverless Application Model)

```
SAM = CloudFormation extension for serverless
  Simplifies Lambda + API Gateway + DynamoDB definitions
  sam local: test Lambda locally
  sam deploy: deploy via CloudFormation
  
  Template:
  Transform: AWS::Serverless-2016-10-31
  
  Resources:
    JudicialAPI:
      Type: AWS::Serverless::Function
      Properties:
        Handler: app.lambda_handler
        Runtime: python3.12
        Events:
          Api:
            Type: HttpApi
            Properties:
              Path: /cases
              Method: GET

  vs raw CloudFormation: SAM generates all the boilerplate
  (Lambda permissions, API Gateway integration, etc.)
```

---

## PART 13 — AWS WELL-ARCHITECTED FRAMEWORK

### 6 Pillars (memorise all 6)

```
1. Operational Excellence
   Perform operations as code (IaC, runbooks as Lambda)
   Annotate documentation (keep up to date)
   Anticipate failure (GameDays, chaos engineering)
   Learn from failures (post-mortems, blameless culture)
   Make frequent, small, reversible changes (CI/CD, feature flags)

2. Security
   Implement strong identity foundation (least privilege, MFA)
   Enable traceability (CloudTrail, Config, logs)
   Apply security at all layers (VPC, WAF, SG, NACLs, encryption)
   Automate security best practices (Security Hub, GuardDuty)
   Protect data in transit and at rest
   Prepare for security events (incident response playbooks)

3. Reliability
   Automatically recover from failure (health checks, auto-scaling)
   Test recovery procedures (DR drills, chaos engineering)
   Scale horizontally (stateless > stateful)
   Stop guessing capacity (auto-scaling, serverless)
   Manage change through automation (IaC, not manual)

4. Performance Efficiency
   Democratize advanced technologies (use managed services)
   Go global in minutes (CloudFront, Route53, multi-region)
   Use serverless architectures (Lambda, Fargate)
   Experiment more often (easy to try new things on cloud)
   Mechanical sympathy (use service designed for your use case)

5. Cost Optimization
   Implement cloud financial management (FinOps team)
   Adopt a consumption model (pay for what you use)
   Measure overall efficiency ($/transaction not just $/hour)
   Stop spending money on undifferentiated heavy lifting
   Analyse and attribute expenditure (tagging, cost allocation)

6. Sustainability (added 2021)
   Understand your impact (carbon footprint)
   Establish sustainability goals
   Maximise utilization (right-size, auto-scale, serverless)
   Anticipate and adopt new hardware/software
   Use managed services (AWS more efficient than your DC)
   Reduce downstream impact (efficient code, less data transfer)
```

### Well-Architected Tool

```
AWS Well-Architected Tool (free):
  Online questionnaire based on 6 pillars
  Answers questions about your workload
  Identifies high-risk issues (HRIs)
  Provides improvement plan
  Track progress over time

Process:
  1. Define workload (what you're reviewing)
  2. Answer questions per pillar (~50 total)
  3. Review findings (HRIs highlighted)
  4. Create improvement plan
  5. Fix HRIs
  6. Milestone: mark progress, compare over time

Questions cover:
  Operational Excellence: how do you deploy? How do you detect failures?
  Security: how do you manage credentials? How do you detect incidents?
  Reliability: how do you handle component failure? How do you test?
  Performance: how do you select instance types? How do you monitor?
  Cost: how do you allocate costs? How do you identify savings?
  Sustainability: what sustainability KPIs do you track?
```

### DevOps + Well-Architected Alignment

```
Your judicialsolutions.in vs Well-Architected:

Operational Excellence ✓:
  IaC (Terraform) ✓
  CI/CD pipeline ✓
  Automated testing ✓
  Areas to improve: runbooks, GameDays

Security ✓:
  Least-privilege IAM ✓
  Encryption at rest/transit ✓
  Cognito for auth ✓
  Areas to improve: GuardDuty, WAF

Reliability ✓:
  Serverless auto-scaling ✓
  99.9% availability ✓
  Areas to improve: multi-region DR, chaos testing

Performance Efficiency ✓:
  Serverless (no capacity planning) ✓
  CloudFront edge caching ✓
  Areas to improve: Performance Insights for DB

Cost Optimization ✓:
  Serverless (pay per request) ✓
  DynamoDB on-demand ✓
  Areas to improve: S3 lifecycle policies, cost allocation tags

Sustainability:
  Serverless = AWS manages efficiency ✓
  No idle resources ✓
```

---

## INTERVIEW QUESTIONS RAPID FIRE

**Q: Your RDS primary failed. Walk me through what happens with Multi-AZ.**
```
1. RDS detects primary failure via health check (~30 seconds)
2. Automatic failover initiates
3. Standby promoted to primary (~60 seconds total)
4. DNS record (CNAME) updated to point to new primary
5. Application reconnects using the same endpoint
6. Old primary becomes new standby (when recovered)

Key points:
- Application must use the RDS endpoint (not IP) — DNS is how failover works
- Brief downtime ~60-120 seconds
- Standby was NOT used for reads before failover
- After failover: you now have no standby (briefly) — AWS creates new one
```

**Q: What is the difference between SNS and SQS?**
```
SNS (Push/Pub-Sub):
  Publisher sends once → all subscribers receive simultaneously
  Fan-out pattern
  "Fire and forget" from publisher's perspective

SQS (Pull/Queue):
  Producer sends → queue stores → one consumer pulls and processes
  Point-to-point
  Message consumed by one consumer only
  Guaranteed delivery with retry

They complement each other:
  SNS → multiple SQS queues → multiple independent consumers
  This is the fan-out pattern for parallel processing
```

**Q: How do you reduce AWS costs without reducing functionality?**
```
1. Right-size: CloudWatch shows 5% CPU → downsize instance
2. Auto Scaling: scale to zero at night, up during business hours
3. Spot instances: 70-90% cheaper for fault-tolerant batch jobs
4. Reserved/Savings Plans: 40-70% cheaper for steady-state workloads
5. Serverless: Lambda/Fargate — pay only when running
6. S3 Lifecycle: move old objects to Glacier
7. Delete unused: Elastic IPs, old snapshots, idle LBs
8. VPC endpoints: avoid NAT Gateway data charges for S3/DynamoDB
9. CloudFront: reduce origin requests and data transfer cost
10. Right storage tier: gp3 vs gp2 (20% cheaper, better performance)
```

**Q: What is the difference between Transit Gateway and VPC Peering?**
```
VPC Peering:
  Direct, 1-to-1 connection
  No transitive routing
  N VPCs = N*(N-1)/2 peering connections
  No cost per hour (only data transfer)

Transit Gateway:
  Central hub, star topology
  Transitive routing: all attachments can talk
  N VPCs = N attachments
  $0.05/hr per attachment + data
  Also connects: VPN, Direct Connect, on-premises

Use peering: 2-3 VPCs, simple connectivity
Use TGW: 4+ VPCs, mixed connectivity, on-premises
```

---

## PART 14 — VPC COMPLETE DEEP DIVE

> Back to [Table of Contents](#table-of-contents)

---

### VPC & Subnets

```
VPC (Virtual Private Cloud):
  Your own isolated network within AWS
  Region-scoped (spans all AZs in that region)
  CIDR block: defines IP address range (e.g. 10.0.0.0/16 = 65,536 IPs)
  Default VPC: created automatically in each region (172.31.0.0/16)
               Don't use default VPC for production

Key VPC limits:
  5 VPCs per region (soft limit, can increase)
  5 CIDRs per VPC (can add secondary CIDRs)
  Cannot modify primary CIDR after creation

CIDR planning best practices:
  Use RFC 1918 ranges:
    10.0.0.0/8     → large enterprise
    172.16.0.0/12  → medium
    192.168.0.0/16 → small / home
  Plan for future growth (use /16 for VPC — gives 65K IPs)
  Non-overlapping: VPCs that peer must have different CIDRs
  Reserve ranges per environment:
    10.0.0.0/16  → prod
    10.1.0.0/16  → staging
    10.2.0.0/16  → dev
```

```
Subnets:
  Subdivision of VPC in ONE specific AZ
  Public subnet:  has route to Internet Gateway → internet-accessible
  Private subnet: no route to IGW → no direct internet access
                  uses NAT Gateway for outbound internet
  Isolated subnet: no route anywhere outside VPC
                   use for: databases, internal services

Subnet sizing:
  AWS reserves 5 IPs per subnet (first 4 + last 1)
  /24 subnet = 256 IPs → 251 usable
  /28 subnet = 16 IPs  → 11 usable (minimum useful size)

Typical 3-tier architecture per AZ:
  Public  (10.0.1.0/24): Load balancers, NAT Gateway, Bastion host
  Private (10.0.2.0/24): Application servers, EKS nodes, Lambda
  Data    (10.0.3.0/24): RDS, ElastiCache, internal services
  × 3 AZs = 9 subnets total for HA
```

```bash
# Create VPC
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=judicial-prod-vpc}]'

# Enable DNS hostnames (required for many AWS services)
aws ec2 modify-vpc-attribute \
  --vpc-id vpc-12345678 \
  --enable-dns-hostnames

# Create subnets
aws ec2 create-subnet \
  --vpc-id vpc-12345678 \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1a}]'

aws ec2 create-subnet \
  --vpc-id vpc-12345678 \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-1a}]'
```

---

### Internet Gateway (IGW)

```
IGW = door between your VPC and the public internet
  Horizontally scaled, redundant, highly available (no management)
  One IGW per VPC
  Free — no data processing charge (pay for data transfer)
  Stateful: allows return traffic automatically
  Performs NAT for instances with public IPs

For a subnet to be "public":
  1. VPC has an IGW attached
  2. Subnet route table has: 0.0.0.0/0 → igw-xxxxxx
  3. Instance has a public IP or Elastic IP

Without IGW:
  No inbound from internet
  No outbound to internet
  Internal VPC communication still works
```

```bash
# Create and attach IGW
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=judicial-igw}]'

aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-12345678 \
  --vpc-id vpc-12345678

# Create public route table
aws ec2 create-route-table \
  --vpc-id vpc-12345678 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]'

# Add default route to IGW
aws ec2 create-route \
  --route-table-id rtb-12345678 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-12345678

# Associate route table with public subnet
aws ec2 associate-route-table \
  --route-table-id rtb-12345678 \
  --subnet-id subnet-12345678
```

---

### NAT Gateway (NGW)

```
NAT Gateway = allows private subnet resources to reach internet
              while blocking inbound connections from internet

Why:
  Private EC2/ECS/Lambda needs: yum update, pip install, API calls
  But you don't want inbound connections from internet (security)
  NAT Gateway translates private IP → its own public IP → internet

Key facts:
  Deployed in PUBLIC subnet (needs internet access itself)
  Has an Elastic IP attached
  Route: private subnet → NAT GW → IGW → internet
  Managed by AWS (no patching, auto-scales, HA within an AZ)
  NOT free: $0.045/hr + $0.045/GB data processed

NAT Gateway vs NAT Instance:
  NAT Gateway:  managed, auto-scales, HA, more expensive
  NAT Instance: EC2 you manage, single point of failure, cheaper
                Only use NAT Instance for cost saving in dev/test
                AWS recommends NAT Gateway for production

High Availability:
  NAT Gateway is AZ-specific (NOT cross-AZ)
  If NAT GW AZ fails → private subnets in that AZ lose internet
  HA setup: one NAT GW per AZ + private subnet routes to same-AZ NAT GW

            AZ-1a                    AZ-1b
  Private subnet ─→ NAT GW 1a      Private subnet ─→ NAT GW 1b
                        ↓                                  ↓
                       IGW ←────────────────────────────────
```

```bash
# Allocate Elastic IP for NAT Gateway
aws ec2 allocate-address --domain vpc

# Create NAT Gateway in public subnet
aws ec2 create-nat-gateway \
  --subnet-id subnet-public-1a \
  --allocation-id eipalloc-12345678 \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=nat-gw-1a}]'

# Create private route table
aws ec2 create-route-table \
  --vpc-id vpc-12345678 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-rt-1a}]'

# Route private subnet traffic through NAT GW
aws ec2 create-route \
  --route-table-id rtb-private-1a \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-12345678

# Associate private route table with private subnet
aws ec2 associate-route-table \
  --route-table-id rtb-private-1a \
  --subnet-id subnet-private-1a
```

---

### Security Groups vs NACLs

```
Security Groups (SG):                  NACLs (Network ACL):
─────────────────────                  ─────────────────────
Applied to: ENI/Instance               Applied to: Subnet
Stateful: return traffic auto-allowed  Stateless: must allow both directions
Rules: Allow only                      Rules: Allow AND Deny
Evaluation: all rules evaluated        Evaluation: rules in number order (lowest first)
Default: deny inbound, allow outbound  Default NACL: allow all
Chaining: reference other SGs          No SG reference

When to use what:
  Security Group: primary security mechanism (always use)
  NACL: additional layer, block specific IPs/ports at subnet level
        Great for: blocking known malicious IPs, port-level restrictions

Security Group best practices:
  Never use 0.0.0.0/0 as inbound source (except for public-facing LBs)
  Reference security groups instead of IPs where possible
    ALB SG → allows 443 from 0.0.0.0/0
    App SG → allows 8080 from ALB SG only (not from internet)
    DB SG  → allows 5432 from App SG only
  Separate SGs per tier (ALB, app, DB)

NACL rules example:
  Rule 100: Allow TCP 443 from 0.0.0.0/0  INBOUND
  Rule 200: Allow TCP 80 from 0.0.0.0/0   INBOUND
  Rule 300: Allow TCP 1024-65535 (ephemeral ports) INBOUND  ← REQUIRED (stateless)
  Rule *:   Deny all
  
  Rule 100: Allow all OUTBOUND to 0.0.0.0/0
  Rule *:   Deny all
```

---

### VPC Peering

```
VPC Peering = private connection between two VPCs
  Traffic stays on AWS backbone (not internet)
  Works: same account, different accounts, different regions (inter-region peering)
  
  Key limitation: NO TRANSITIVE ROUTING
    A peered with B, B peered with C ≠ A can reach C
    Must create direct peering A-C if needed
    With 10 VPCs: 10*(10-1)/2 = 45 peering connections needed!

Setup steps:
  1. Requester VPC initiates peering request
  2. Accepter VPC accepts the request
  3. Both VPCs update their route tables (manual step — common mistake)
  4. Security groups updated to allow traffic from peer CIDR

Requirements:
  CIDRs must NOT overlap
  One peering connection per VPC pair
  Cannot peer with VPCs that have matching CIDRs
```

```bash
# Step 1: Create peering connection (from VPC A)
aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-aaaa1111 \
  --peer-vpc-id vpc-bbbb2222 \
  --peer-region ap-south-1 \
  --peer-owner-id 222222222222

# Step 2: Accept peering (in VPC B account)
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id pcx-12345678

# Step 3: Update route table in VPC A — route VPC B traffic via peering
aws ec2 create-route \
  --route-table-id rtb-vpc-a \
  --destination-cidr-block 10.1.0.0/16 \
  --vpc-peering-connection-id pcx-12345678

# Step 4: Update route table in VPC B — route VPC A traffic via peering
aws ec2 create-route \
  --route-table-id rtb-vpc-b \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id pcx-12345678

# Verify peering is active
aws ec2 describe-vpc-peering-connections \
  --filters Name=status-code,Values=active
```

---

### Transit Gateway (TGW)

```
Transit Gateway = central network hub connecting VPCs, VPNs, Direct Connect
  Solves the "N*(N-1)/2" peering problem
  Transitive routing: any attachment can reach any other attachment
  Regional (one per region) — can peer TGWs across regions

Attachments:
  VPC: attach your VPCs (each costs $0.05/hr)
  VPN: connect on-premises via Site-to-Site VPN
  Direct Connect Gateway: connect on-premises via Direct Connect
  Peering: connect to TGW in another region
  
TGW Route Tables:
  TGW has its own route tables (separate from VPC route tables)
  Control which attachments can talk to which
  Isolation: prod VPCs in one route table, dev in another → no cross-talk
  
  Example: hub-spoke
    Spoke VPCs: each only routes to TGW (not to each other directly)
    TGW routes: propagated from VPC attachments
    Shared services VPC: accessible to all spokes via TGW

TGW vs VPC Peering:
  VPC Peering: free (pay only data transfer), no transitive routing, complex at scale
  TGW:         $0.05/hr per attachment + $0.02/GB, transitive, simpler at scale
  Use peering for ≤3 VPCs, TGW for 4+ or mixed connectivity
```

```bash
# Create Transit Gateway
aws ec2 create-transit-gateway \
  --description "judicial-prod-tgw" \
  --options '
    AmazonSideAsn=64512,
    AutoAcceptSharedAttachments=disable,
    DefaultRouteTableAssociation=enable,
    DefaultRouteTablePropagation=enable,
    VpnEcmpSupport=enable,
    DnsSupport=enable
  ' \
  --tag-specifications 'ResourceType=transit-gateway,Tags=[{Key=Name,Value=judicial-tgw}]'

# Attach VPC to TGW
aws ec2 create-transit-gateway-vpc-attachment \
  --transit-gateway-id tgw-12345678 \
  --vpc-id vpc-aaaa1111 \
  --subnet-ids subnet-1a subnet-1b \
  --tag-specifications 'ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=prod-vpc-attachment}]'

# Update VPC route table to use TGW for traffic to other VPCs
aws ec2 create-route \
  --route-table-id rtb-vpc-a-private \
  --destination-cidr-block 10.0.0.0/8 \
  --transit-gateway-id tgw-12345678

# List all TGW attachments
aws ec2 describe-transit-gateway-attachments \
  --filters Name=transit-gateway-id,Values=tgw-12345678
```

---

### Site-to-Site VPN

```
Site-to-Site VPN = encrypted IPsec tunnel between on-premises and AWS

Components:
  Virtual Private Gateway (VGW):
    AWS side of the VPN tunnel
    Attached to your VPC
    AWS-managed, highly available

  Customer Gateway (CGW):
    Represents your on-premises router in AWS
    Configuration object (stores router's public IP and BGP ASN)
    The actual device is your router/firewall

  VPN Connection:
    The tunnel between VGW and CGW
    Always creates TWO tunnels (different AZs for redundancy)
    Each tunnel: one public IP on AWS side, one on your side
    If one tunnel fails → traffic fails over to second

Routing options:
  Static routing: manually enter on-premises CIDRs in AWS
  Dynamic (BGP): routers exchange routes automatically
                 Better for complex networks, automatic failover
                 Requires BGP ASN on both sides

Key facts:
  Bandwidth: up to 1.25 Gbps per tunnel
  Latency: internet-dependent (varies)
  Cost: $0.05/hr per VPN connection + data transfer
  Encryption: AES-256, IKEv1/IKEv2
  Use case: secure connectivity to AWS, backup for Direct Connect

Monitoring:
  TunnelState metric in CloudWatch (0=down, 1=up)
  Alert when tunnel goes down
```

```bash
# Create Customer Gateway (your on-premises router)
aws ec2 create-customer-gateway \
  --type ipsec.1 \
  --public-ip 203.0.113.1 \
  --bgp-asn 65000 \
  --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value=office-router}]'

# Create Virtual Private Gateway
aws ec2 create-vpn-gateway \
  --type ipsec.1 \
  --amazon-side-asn 64512 \
  --tag-specifications 'ResourceType=vpn-gateway,Tags=[{Key=Name,Value=judicial-vgw}]'

# Attach VGW to VPC
aws ec2 attach-vpn-gateway \
  --vpn-gateway-id vgw-12345678 \
  --vpc-id vpc-12345678

# Create VPN connection
aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id cgw-12345678 \
  --vpn-gateway-id vgw-12345678 \
  --options '{"StaticRoutesOnly":false}' \
  --tag-specifications 'ResourceType=vpn-connection,Tags=[{Key=Name,Value=office-to-aws}]'

# Download VPN configuration (for your router brand)
aws ec2 describe-vpn-connections \
  --vpn-connection-ids vpn-12345678 \
  --query 'VpnConnections[0].CustomerGatewayConfiguration'

# Enable route propagation (VGW automatically adds on-prem routes)
aws ec2 enable-vgw-route-propagation \
  --route-table-id rtb-12345678 \
  --gateway-id vgw-12345678
```

---

### Direct Connect

```
Direct Connect = dedicated physical connection from on-premises to AWS
  NOT over public internet — dedicated leased line
  Consistent, reliable, lower latency than VPN
  Speeds: 50 Mbps to 100 Gbps

Types:
  Dedicated Connection:
    Physical port at Direct Connect location
    1, 10, or 100 Gbps
    Takes weeks to provision (physical work)
    
  Hosted Connection:
    Via AWS Direct Connect Partner (Tata, Airtel, BSNL, etc.)
    50 Mbps to 10 Gbps
    Faster provisioning than dedicated
    Shared physical connection

Key concepts:
  Virtual Interface (VIF): logical connection over Direct Connect
    Private VIF: connects to a single VPC via VGW
    Public VIF:  connects to AWS public services (S3, DynamoDB, public IPs)
    Transit VIF: connects to Transit Gateway (up to 3 TGW attachments)

  Direct Connect Gateway:
    Connect ONE Direct Connect to MULTIPLE VPCs (in same or different regions)
    Without DXGW: need one VIF per VPC
    With DXGW:    one VIF → DXGW → multiple VGW/TGW

  Link Aggregation Group (LAG):
    Bundle multiple Direct Connect ports for higher bandwidth
    2 × 10 Gbps LAG = 20 Gbps effective bandwidth
    Still single physical location — not fully redundant

Benefits vs VPN:
  More consistent bandwidth (dedicated, not shared internet)
  Lower latency (more predictable)
  Reduced data transfer costs (lower than internet egress)
  Compliance: data doesn't traverse public internet

Limitations:
  NOT encrypted by default
  Solution: run IPsec VPN over Direct Connect (encryption + dedicated bandwidth)
  NOT instant: weeks to provision dedicated port
  NOT redundant by itself: need two connections at two locations for true HA

HA architecture:
  Location A: Direct Connect connection 1
  Location B: Direct Connect connection 2 (different facility)
  Backup: Site-to-Site VPN (activate if both DX connections fail)
```

---

### VPN CloudHub

```
VPN CloudHub = hub-and-spoke connectivity between multiple sites via AWS

Use case:
  Multiple office/branch locations need to communicate
  All connect to same AWS Virtual Private Gateway via VPN
  Offices can communicate through AWS as hub
  Can also access resources in the attached VPC

Setup:
  Each site: Customer Gateway + VPN connection to same VGW
  VGW becomes the hub
  Dynamic routing (BGP) enables offices to discover each other's routes

Traffic flow:
  Mumbai office → VPN → VGW → VPN → Singapore office
                              ↓
                          VPC resources

Requirements:
  BGP must be configured on all Customer Gateways
  Each site must have a unique BGP ASN
  Each site must have non-overlapping IP ranges

Cost:
  Each VPN connection: $0.05/hr
  Data transfer between sites: standard data transfer rates
  No additional CloudHub fee

Not to confuse with:
  Transit Gateway: more powerful, supports more connection types, higher scale
  CloudHub is older pattern — for simpler multi-site VPN needs
  TGW preferred for new deployments
```

---

### AWS PrivateLink & VPC Endpoints

```
Problem without endpoints:
  EC2 in private subnet → wants to call S3 API
  Traffic goes: private subnet → NAT Gateway → Internet → S3
  Costs: NAT GW processing fee + data transfer
  Risk: data traverses public internet

Solution: VPC Endpoints
  Private connection between VPC and AWS services
  Traffic stays within AWS network (never touches internet)
  No NAT Gateway, no IGW needed for these services
  Free to use (except Interface endpoints which have hourly cost)

Two types:

1. Gateway Endpoint (FREE):
   Services: S3 and DynamoDB ONLY
   Added as entry in route table (not an ENI)
   Traffic automatically routed through endpoint
   
   aws ec2 create-vpc-endpoint \
     --vpc-id vpc-12345678 \
     --service-name com.amazonaws.ap-south-1.s3 \
     --route-table-ids rtb-private-1a rtb-private-1b

2. Interface Endpoint (costs $0.01/hr/AZ + data):
   Most other AWS services (SSM, Secrets Manager, ECR, CloudWatch, etc.)
   Creates an ENI with private IP in your subnet
   DNS: AWS automatically resolves service hostname to private IP
   
   Popular interface endpoints:
     com.amazonaws.region.ssm             (Systems Manager)
     com.amazonaws.region.secretsmanager  (Secrets Manager)
     com.amazonaws.region.ecr.api         (ECR API)
     com.amazonaws.region.ecr.dkr         (ECR Docker)
     com.amazonaws.region.logs            (CloudWatch Logs)
     com.amazonaws.region.monitoring      (CloudWatch Metrics)
     com.amazonaws.region.execute-api     (API Gateway)
     com.amazonaws.region.sts             (STS)

AWS PrivateLink:
  Expose YOUR service to other VPCs privately
  You: create NLB → create endpoint service
  Consumer: creates Interface VPC Endpoint → gets private IP in their VPC
  Traffic never leaves AWS network
  Works cross-account and cross-region
  
  Use cases:
    SaaS: expose your service to customers without public internet
    Internal platform teams: share services across accounts
    Eliminate VPC peering complexity for service-specific access
```

```bash
# Create S3 Gateway Endpoint (free)
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345678 \
  --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids rtb-private-1a rtb-private-1b \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=s3-endpoint}]'

# Create DynamoDB Gateway Endpoint (free)
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345678 \
  --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.ap-south-1.dynamodb \
  --route-table-ids rtb-private-1a rtb-private-1b

# Create Interface Endpoint for Secrets Manager
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345678 \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.ap-south-1.secretsmanager \
  --subnet-ids subnet-private-1a subnet-private-1b \
  --security-group-ids sg-endpoint \
  --private-dns-enabled  # so existing SDK calls work without code change

# Endpoint policy (restrict which resources can be accessed via endpoint)
aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id vpce-12345678 \
  --policy-document '{
    "Statement": [{
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::judicial-prod-bucket",
        "arn:aws:s3:::judicial-prod-bucket/*"
      ]
    }]
  }'

# List all endpoints in VPC
aws ec2 describe-vpc-endpoints \
  --filters Name=vpc-id,Values=vpc-12345678 \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table
```

---

### VPC Flow Logs

```
VPC Flow Logs = capture network traffic metadata for your VPC
  NOT packet capture (no payload) — only metadata
  Records: source IP, destination IP, port, protocol, bytes, action (ACCEPT/REJECT)
  
Capture levels:
  VPC level:    all traffic across all ENIs in VPC
  Subnet level: all traffic in specific subnet
  ENI level:    specific network interface

Destinations:
  CloudWatch Logs: queryable via Logs Insights
  S3:             queryable via Athena (cheaper for long-term)
  Kinesis Data Firehose: real-time streaming to OpenSearch/S3

Flow log format (default):
  version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status

  Example (REJECTED):
  2 123456789012 eni-abc123 10.0.1.5 10.0.2.100 54321 22 6 1 52 1679500000 1679500060 REJECT OK

Custom format (choose fields):
  ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${action} ${bytes}

Use cases:
  Security: detect port scanning, unauthorized access attempts
  Troubleshooting: "why can't EC2 reach RDS?" → check flow logs for REJECT
  Compliance: audit all network traffic
  Cost: identify unexpected data transfer

Troubleshooting with flow logs:
  ACCEPT: traffic was allowed by SG/NACL
  REJECT: traffic was blocked by SG/NACL
  No record: traffic never reached the ENI (routing issue)
```

```bash
# Enable flow logs → CloudWatch Logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-12345678 \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /judicial/vpc-flow-logs \
  --deliver-logs-permission-arn arn:aws:iam::ACCOUNT:role/flow-logs-role

# Enable flow logs → S3 (cheaper for large volumes)
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-12345678 \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination arn:aws:s3:::judicial-logs/vpc-flow-logs/ \
  --log-format '${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${action} ${bytes} ${start} ${end}'

# Query flow logs in CloudWatch Logs Insights
# Find rejected connections to RDS port 5432
fields srcAddr, dstAddr, dstPort, action
| filter dstPort = 5432 and action = "REJECT"
| stats count(*) by srcAddr, dstAddr
| sort count desc

# Query flow logs in Athena (S3 destination)
# Create table first, then:
SELECT srcaddr, dstaddr, dstport, action, bytes
FROM vpc_flow_logs
WHERE action = 'REJECT'
  AND dstport = 5432
  AND day = '2024-03-22'
ORDER BY bytes DESC
LIMIT 50;
```

---

### Traffic Mirroring

```
Traffic Mirroring = copy actual network packets from ENI to monitoring tools
  Unlike Flow Logs (metadata only) — captures FULL PACKET PAYLOAD
  Source: ENI to mirror (your EC2, EKS node, etc.)
  Target: another ENI or NLB (your monitoring/analysis tool)
  Filter: specify which traffic to mirror (all, or specific ports/IPs)

Use cases:
  Security: IDS/IPS (Intrusion Detection/Prevention) — catch attacks
  Compliance: deep packet inspection for regulatory requirements
  Troubleshooting: see exact traffic content between services
  Performance analysis: application-level latency analysis

Limitations:
  Additional bandwidth cost (mirrored traffic = extra data)
  Instance must support Enhanced Networking (nitro-based)
  Cannot mirror from some instance types
  Within same VPC or across VPC (via peering)

Setup:
  1. Mirror source: ENI you want to monitor
  2. Mirror target: ENI of your monitoring tool
  3. Mirror filter: what to capture (all TCP, specific ports, etc.)
  4. Mirror session: connects source + target + filter
```

```bash
# Create mirror target (your monitoring tool's ENI)
aws ec2 create-traffic-mirror-target \
  --network-interface-id eni-monitor-tool \
  --description "IDS monitoring tool"

# Create mirror filter (what to capture)
aws ec2 create-traffic-mirror-filter \
  --description "capture all traffic"

# Add filter rule: capture inbound TCP
aws ec2 create-traffic-mirror-filter-rule \
  --traffic-mirror-filter-id tmf-12345678 \
  --traffic-direction ingress \
  --rule-number 100 \
  --rule-action accept \
  --protocol 6 \
  --destination-cidr-block 0.0.0.0/0 \
  --source-cidr-block 0.0.0.0/0

# Create mirror session (source → target using filter)
aws ec2 create-traffic-mirror-session \
  --network-interface-id eni-source-ec2 \
  --traffic-mirror-target-id tmt-12345678 \
  --traffic-mirror-filter-id tmf-12345678 \
  --session-number 1 \
  --description "Mirror production API traffic to IDS"
```

---

### Egress-Only Internet Gateway

```
Egress-Only Internet Gateway = NAT Gateway for IPv6
  Allows IPv6 instances in VPC to initiate connections to internet
  BLOCKS all inbound connections from internet (egress-only)
  Required because IPv6 addresses are public by default (no NAT)

Why needed:
  IPv4: private instances use NAT GW (private IP → public IP)
        Works because IPv4 has public/private distinction
  
  IPv6: ALL IPv6 addresses are public (no private range like 10.x.x.x)
        Without egress-only GW: IPv6 instances are fully internet-accessible
        With egress-only GW: can call internet but internet can't initiate connection

Key facts:
  Free (like regular IGW)
  Only for IPv6 (not IPv4)
  One per VPC
  Stateful (like SG — return traffic allowed automatically)

Route table entry:
  Destination: ::/0 (all IPv6)
  Target:      eigw-12345678

Compared to regular IGW:
  IGW:             allows both inbound AND outbound IPv6
  Egress-only IGW: allows OUTBOUND ONLY (internet can't initiate connection)
```

```bash
# Create Egress-Only Internet Gateway
aws ec2 create-egress-only-internet-gateway \
  --vpc-id vpc-12345678 \
  --tag-specifications 'ResourceType=egress-only-internet-gateway,Tags=[{Key=Name,Value=judicial-eigw}]'

# Add to route table (for private subnets with IPv6)
aws ec2 create-route \
  --route-table-id rtb-private-1a \
  --destination-ipv6-cidr-block ::/0 \
  --egress-only-internet-gateway-id eigw-12345678

# Assign IPv6 CIDR to VPC (required first)
aws ec2 associate-vpc-cidr-block \
  --vpc-id vpc-12345678 \
  --amazon-provided-ipv6-cidr-block

# Assign IPv6 CIDR to subnet
aws ec2 associate-subnet-cidr-block \
  --subnet-id subnet-private-1a \
  --ipv6-cidr-block 2600:1f14:xxx::/64
```

---

### Networking Comparison Table

```
┌────────────────────────────┬────────────────┬─────────────┬────────────────────────────────┐
│ Component                  │ Direction      │ Cost        │ Use For                        │
├────────────────────────────┼────────────────┼─────────────┼────────────────────────────────┤
│ Internet Gateway (IGW)     │ Bi-directional │ Free        │ Public subnets ↔ Internet      │
│ NAT Gateway                │ Outbound only  │ $0.045/hr   │ Private subnets → Internet     │
│ Egress-Only IGW            │ Outbound only  │ Free        │ Private IPv6 → Internet        │
│ VPC Peering                │ Bi-directional │ Data only   │ 2-3 VPCs, no transitive needed │
│ Transit Gateway            │ Bi-directional │ $0.05/hr/att│ 4+ VPCs, mixed connectivity    │
│ Site-to-Site VPN           │ Bi-directional │ $0.05/hr    │ On-prem ↔ AWS (encrypted)      │
│ Direct Connect             │ Bi-directional │ Port hours  │ Dedicated on-prem ↔ AWS line   │
│ VPN CloudHub               │ Bi-directional │ VPN costs   │ Multiple offices via AWS hub   │
│ Gateway Endpoint (S3/DDB)  │ Outbound       │ Free        │ Private S3/DynamoDB access     │
│ Interface Endpoint         │ Bi-directional │ $0.01/hr/AZ │ Private access to AWS services │
│ PrivateLink                │ Consumer only  │ $0.01/hr/AZ │ Expose service to other VPCs   │
│ VPC Flow Logs              │ N/A (logging)  │ Storage cost│ Network audit and troubleshoot │
│ Traffic Mirroring          │ N/A (copy)     │ Bandwidth   │ Deep packet inspection / IDS   │
└────────────────────────────┴────────────────┴─────────────┴────────────────────────────────┘
```

### When to Use Which — Quick Decision

```
Need internet access for PUBLIC resources?
  → Internet Gateway (IGW)

Private resources need to call internet (yum update, pip, APIs)?
  → NAT Gateway (in same AZ as private subnet for HA)

Private IPv6 resources need outbound internet?
  → Egress-Only Internet Gateway

Connect to S3 or DynamoDB without internet?
  → Gateway VPC Endpoint (free, no code change needed)

Private access to other AWS services (SSM, Secrets Manager, ECR)?
  → Interface VPC Endpoint

Connect on-premises to AWS securely?
  → Site-to-Site VPN (quick, affordable) 
  → OR Direct Connect (dedicated, consistent, for heavy traffic)

Connect multiple offices to AWS AND to each other?
  → VPN CloudHub

Connect 2-3 VPCs?
  → VPC Peering (free, simple)

Connect 4+ VPCs or mixed VPC+VPN+Direct Connect?
  → Transit Gateway

Expose your service privately to other AWS accounts?
  → AWS PrivateLink

Need full network traffic capture for security/compliance?
  → Traffic Mirroring

Need network metadata for troubleshooting/audit?
  → VPC Flow Logs
```

---

### VPC Interview Questions

**Q: Walk me through the components needed for an EC2 in a private subnet to call an S3 API.**

```
Route: EC2 (private subnet) → NAT Gateway (public subnet) → IGW → Internet → S3

Required components:
  1. VPC with DNS hostnames enabled
  2. Public subnet with IGW attached via route table (0.0.0.0/0 → IGW)
  3. Elastic IP allocated + NAT Gateway deployed in public subnet
  4. Private subnet route table: 0.0.0.0/0 → NAT GW
  5. Security Group: allow outbound 443 from EC2
  6. IAM role attached to EC2 with S3 permissions

Better approach (cheaper + more secure):
  Replace NAT GW → S3 Gateway Endpoint
  Traffic stays within AWS (no internet)
  Free (no NAT GW charges)
  Add endpoint to private route table
  0.0.0.0/0 → NAT GW (still needed for other internet traffic)
  S3 CIDR → S3 Gateway Endpoint (automatically managed by AWS)
```

**Q: A security team asks you to capture all traffic between your web tier and app tier for analysis. How do you implement this?**

```
Two options:

Option 1: VPC Flow Logs (metadata only, free)
  Enable Flow Logs on private subnet at ENI level
  Capture: source/dest IPs, ports, protocol, bytes, ACCEPT/REJECT
  Cannot see: actual data payload
  Good for: threat detection, troubleshooting, compliance logging
  Store in: CloudWatch Logs (query with Logs Insights) or S3 (Athena)

Option 2: Traffic Mirroring (full packets, additional cost)
  Mirror source ENI (web tier instances)
  Mirror target: security monitoring tool ENI (e.g. Suricata IDS)
  Filter: only TCP 8080 (app tier port)
  Can see: actual HTTP request/response payloads
  Good for: IDS/IPS, deep security inspection, compliance requiring full capture

Choose:
  Flow Logs → general monitoring, troubleshooting, SIEM integration
  Traffic Mirroring → full packet capture, IDS requirements, DLP
```

**Q: Your application in VPC A needs to access a database in VPC B (different account). What are your options?**

```
Option 1: VPC Peering (simplest)
  Create peering connection between VPC A and VPC B
  Update BOTH route tables
  Update security group in VPC B to allow from VPC A CIDR
  Works if CIDRs don't overlap
  No transitive routing (if VPC B can reach VPC C, VPC A cannot)

Option 2: AWS PrivateLink (most secure)
  VPC B: put DB behind NLB, create endpoint service
  VPC A: create interface endpoint pointing to VPC B's service
  VPC A app calls endpoint IP → PrivateLink → VPC B NLB → DB
  No need to expose VPC B CIDR to VPC A
  Works even with overlapping CIDRs

Option 3: Transit Gateway
  Overkill for just 2 VPCs but useful if you have many VPCs
  Attach both VPCs to TGW, route tables allow communication

Choose:
  2 VPCs, simple → Peering (free, easy)
  Security-sensitive, overlapping CIDRs possible → PrivateLink
  Many VPCs already using TGW → add to TGW
```

**Q: What happens if a NAT Gateway AZ goes down?**

```
Single NAT Gateway (bad design):
  All private subnets across all AZs route through one NAT GW
  NAT GW AZ fails → private subnets in ALL AZs lose internet
  Single point of failure

HA NAT Gateway design:
  One NAT GW per AZ (e.g., nat-gw-1a, nat-gw-1b, nat-gw-1c)
  Each AZ's private subnet routes to its own NAT GW
  AZ-1a fails → only private subnet in AZ-1a loses internet
  Other AZs unaffected

Terraform for HA NAT:
  resource "aws_nat_gateway" "main" {
    for_each      = aws_subnet.public      # one per public subnet (per AZ)
    subnet_id     = each.value.id
    allocation_id = aws_eip.nat[each.key].id
  }
  
  resource "aws_route" "private_nat" {
    for_each               = aws_route_table.private  # one RT per AZ
    route_table_id         = each.value.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.main[each.key].id
  }
  # Result: private-rt-1a → nat-1a, private-rt-1b → nat-1b
```

**Q: How do VPC Flow Logs help you troubleshoot connectivity issues?**

```
Scenario: App server can't connect to RDS on port 5432

Step 1: Check flow logs for the RDS ENI
  Filter: dstPort = 5432, srcAddr = app-server-IP
  
  If REJECT: Security Group or NACL is blocking
    Check: RDS SG inbound rules (is app SG allowed?)
    Check: Subnet NACL (are ports 5432 and ephemeral 1024-65535 allowed?)
  
  If no record: routing issue (packet never reached RDS ENI)
    Check: route table in app subnet
    Check: VPC peering connection if in different VPC
    Check: correct subnet/AZ for RDS

  If ACCEPT: packet reached RDS but connection still fails
    → Application-level issue (auth, TLS, DB user permissions)
    → Not a network issue — look at DB logs

Common patterns in flow logs:
  Many REJECT from same IP → potential port scan / attack
  Unexpected traffic on unusual ports → investigate security
  High bytes to external IP → potential data exfiltration
  ACCEPT then no response → asymmetric routing issue
```
