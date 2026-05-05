# Azure Complete Notes — DevOps & Cloud Engineer
## Fundamentals + Networking + Compute + AKS + DevOps + Security + Monitoring
### Theory → Commands → AWS Comparison → Interview Questions

---

## README

**Who this is for:** DevOps/Cloud Engineers coming from AWS background
**Approach:** AWS equivalent shown for every concept (fastest way to learn)
**Target:** Mid-level to Senior DevOps/Cloud Engineer interviews

### Power phrases:
- *"Azure uses Resource Groups to organize everything — like AWS tags but mandatory and structural"*
- *"Managed Identity replaces IAM roles for Azure resources — no stored credentials"*
- *"AKS is Azure's managed Kubernetes — same K8s, different cloud integrations"*
- *"Azure DevOps Pipelines = GitHub Actions equivalent, built into Microsoft ecosystem"*
- *"VNet + NSG = VPC + Security Groups in AWS"*

---

## 📌 TABLE OF CONTENTS

| # | Section | Key Topics |
|---|---|---|
| 1 | [Azure Fundamentals](#part-1--azure-fundamentals) | Regions, AZs, Resource Groups, Subscriptions |
| 2 | [Azure Networking](#part-2--azure-networking) | VNet, Subnets, NSG, Load Balancer, App Gateway |
| 3 | [Azure Compute](#part-3--azure-compute) | VMs, VMSS, App Service, Azure Functions |
| 4 | [Azure Storage](#part-4--azure-storage) | Blob, Files, Disks, tiers, lifecycle |
| 5 | [Azure Databases](#part-5--azure-databases) | SQL, Cosmos DB, PostgreSQL, Redis Cache |
| 6 | [Azure Container Registry (ACR)](#part-6--azure-container-registry) | Push, pull, geo-replication, scanning |
| 7 | [AKS — Azure Kubernetes Service](#part-7--aks--azure-kubernetes-service) | Deep dive, node pools, AGIC, Workload Identity |
| 8 | [Azure Identity & Security](#part-8--azure-identity--security) | Azure AD, RBAC, Managed Identity, Key Vault |
| 9 | [Azure DevOps Pipelines](#part-9--azure-devops-pipelines) | Pipelines, Repos, Artifacts, full YAML |
| 10 | [Azure Monitor & Observability](#part-10--azure-monitor--observability) | Monitor, Log Analytics, App Insights, Alerts |
| 11 | [Azure IaC](#part-11--azure-iac) | ARM, Bicep, Terraform with Azure |
| 12 | [Azure vs AWS Comparison](#part-12--azure-vs-aws-comparison) | Side-by-side every service |
| 13 | [Interview Questions](#part-13--interview-questions) | 20 Q&As — basic to senior |

---

## PART 1 — AZURE FUNDAMENTALS

### Global Infrastructure

```
Region:
  Physical location with multiple data centers
  Examples: East US, West Europe, South India, Central India
  Azure has 60+ regions globally (more than any cloud provider)
  Choose region based on: latency to users, compliance, service availability

Availability Zone (AZ):
  Physically separate data centers within a region
  Each zone: own power, cooling, networking
  Connected by high-speed private fiber
  Minimum 3 zones per region (where supported)
  Same concept as AWS AZs

Region Pair:
  Every Azure region paired with another (300+ miles apart)
  Examples: East US ↔ West US, North Europe ↔ West Europe
  Azure updates paired regions sequentially (not simultaneously)
  Disaster recovery: replicate to region pair
  No AWS equivalent (AWS uses separate regions independently)
```

### Azure Account Hierarchy

```
Management Group (optional top level)
    │
    ├── Subscription 1 (Production)
    │     ├── Resource Group: judicial-prod-rg
    │     │     ├── AKS Cluster
    │     │     ├── Azure SQL
    │     │     └── Key Vault
    │     └── Resource Group: judicial-network-rg
    │           ├── VNet
    │           └── NSG
    │
    └── Subscription 2 (Development)
          └── Resource Group: judicial-dev-rg
                └── (dev resources)

Management Group: apply policies across multiple subscriptions
Subscription:     billing unit + resource container (like AWS account)
Resource Group:   logical container for related resources (MANDATORY)
Resource:         actual service (VM, AKS, SQL DB, etc.)

Key difference from AWS:
  AWS: resources exist in an account, optionally tagged
  Azure: resources MUST be in a Resource Group
         Resource Group has a region (but can contain resources from other regions)
         Delete Resource Group → deletes ALL resources inside it
```

### Resource Groups — Critical Concept

```
Resource Group = mandatory logical container for Azure resources

Rules:
  Every resource must belong to exactly one Resource Group
  Resource Group has a location (metadata stored there)
  Resources inside can be in different regions
  Delete RG → delete all resources inside (powerful + dangerous)
  
Best practices:
  Group by: lifecycle (things deployed/deleted together)
  NOT by: type (don't put all VMs in one RG, all DBs in another)
  
  judicial-prod-rg:    AKS + ACR + Key Vault + SQL (all prod together)
  judicial-network-rg: VNet, NSGs, Route Tables (network layer separate)
  judicial-dev-rg:     all dev resources (delete entire dev env easily)

Naming convention:
  {project}-{environment}-{type}-rg
  judicial-prod-compute-rg
  judicial-prod-network-rg
  judicial-dev-rg
```

### Azure CLI — Essential Commands

```bash
# Login
az login
az login --service-principal \
  --username APP_ID \
  --password PASSWORD \
  --tenant TENANT_ID

# Set subscription
az account set --subscription "Production"
az account show                          # current subscription
az account list --output table           # all subscriptions

# Resource Groups
az group create \
  --name judicial-prod-rg \
  --location centralindia \
  --tags Environment=prod Project=judicial

az group list --output table
az group delete --name judicial-dev-rg --yes --no-wait

# List resources in RG
az resource list \
  --resource-group judicial-prod-rg \
  --output table

# Get locations
az account list-locations --output table | grep india
```

---

## PART 2 — AZURE NETWORKING

### VNet — Virtual Network (= AWS VPC)

```
VNet = your private network in Azure
  CIDR block: 10.0.0.0/16 (same as AWS VPC)
  Subnets: subdivisions of the VNet
  No internet by default (must add Internet Gateway equivalent)

Key difference from AWS VPC:
  AWS VPC: one per region, subnets per AZ
  Azure VNet: can span all AZs in a region
              Subnet is NOT AZ-specific (subnet spans all AZs)
              VMs get placed in AZ at creation time

VNet Peering:
  Connect two VNets (same region or cross-region)
  Same as AWS VPC Peering
  Traffic stays on Microsoft backbone
  Must configure both directions (like AWS — update both route tables)
  No transitive peering

VNet Gateway:
  Connect on-premises to Azure via VPN
  Like AWS Virtual Private Gateway
  SKU-based: Basic, VpnGw1-5 (higher = more bandwidth)

ExpressRoute:
  Dedicated private connection to Azure
  Like AWS Direct Connect
  Through telecom partners (Tata, Airtel)
  Speeds: 50 Mbps to 100 Gbps
  NOT encrypted by default (add IPSec for encryption)
```

```bash
# Create VNet
az network vnet create \
  --resource-group judicial-prod-rg \
  --name judicial-vnet \
  --address-prefix 10.0.0.0/16 \
  --location centralindia

# Create subnets
az network vnet subnet create \
  --resource-group judicial-prod-rg \
  --vnet-name judicial-vnet \
  --name aks-subnet \
  --address-prefix 10.0.1.0/24

az network vnet subnet create \
  --resource-group judicial-prod-rg \
  --vnet-name judicial-vnet \
  --name db-subnet \
  --address-prefix 10.0.2.0/24

# List subnets
az network vnet subnet list \
  --resource-group judicial-prod-rg \
  --vnet-name judicial-vnet \
  --output table
```

### NSG — Network Security Group (= AWS Security Group + NACL)

```
NSG = stateful packet filter for Azure
  Applied to: subnet OR network interface (NIC)
  Rules: allow/deny based on source, destination, port, protocol
  Priority: lower number = evaluated first (100 = first, 4096 = last)
  Default rules: allow VNet traffic, allow Azure LB, deny internet inbound

Key difference from AWS:
  AWS SG: stateful, allow only, applied to ENI
  AWS NACL: stateless, allow+deny, applied to subnet
  Azure NSG: stateful (like SG), allow+deny (like NACL), applied to subnet OR NIC

NSG rule components:
  Priority:             100-4096 (lower = higher priority)
  Source:               IP, CIDR, Service Tag, Application Security Group
  Source port:          * (any) usually
  Destination:          IP, CIDR, Service Tag, ASG
  Destination port:     80, 443, 5432, etc.
  Protocol:             TCP, UDP, ICMP, *
  Action:               Allow or Deny

Service Tags (built-in Azure IP ranges — like AWS managed prefix lists):
  Internet:             all public internet IPs
  VirtualNetwork:       all IPs in your VNet + peered VNets
  AzureLoadBalancer:    Azure load balancer probe IPs
  AzureCloud:           all Azure datacenter IPs
  Storage:              Azure Storage service IPs
  Sql:                  Azure SQL service IPs
```

```bash
# Create NSG
az network nsg create \
  --resource-group judicial-prod-rg \
  --name judicial-aks-nsg \
  --location centralindia

# Add rule: allow HTTPS from internet
az network nsg rule create \
  --resource-group judicial-prod-rg \
  --nsg-name judicial-aks-nsg \
  --name Allow-HTTPS \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefix Internet \
  --source-port-range "*" \
  --destination-address-prefix "*" \
  --destination-port-range 443

# Deny all other inbound
az network nsg rule create \
  --resource-group judicial-prod-rg \
  --nsg-name judicial-aks-nsg \
  --name Deny-All-Inbound \
  --priority 4000 \
  --direction Inbound \
  --access Deny \
  --protocol "*" \
  --source-address-prefix "*" \
  --source-port-range "*" \
  --destination-address-prefix "*" \
  --destination-port-range "*"

# Associate NSG to subnet
az network vnet subnet update \
  --resource-group judicial-prod-rg \
  --vnet-name judicial-vnet \
  --name aks-subnet \
  --network-security-group judicial-aks-nsg

# View effective security rules on a NIC
az network nic list-effective-nsg \
  --resource-group judicial-prod-rg \
  --name myNIC
```

### Azure Load Balancers

```
Load Balancer (L4) — = AWS NLB:
  TCP/UDP load balancing
  Public LB: internet-facing (gets public IP)
  Internal LB: private (inside VNet)
  SKU: Basic (free, limited) vs Standard (production, HA)
  Health probes: TCP or HTTP
  No SSL termination (L4 only)

Application Gateway (L7) — = AWS ALB:
  HTTP/HTTPS load balancing
  Path-based routing: /api → backend-1, /web → backend-2
  Host-based routing: api.example.com vs web.example.com
  SSL termination + re-encryption
  WAF integration (Web Application Firewall)
  Sticky sessions (cookie-based)
  Auto-scaling
  Use for: web apps, APIs (most common for AKS)

Azure Front Door — = AWS CloudFront + Global Accelerator:
  Global HTTP load balancing across regions
  CDN capabilities
  WAF at edge
  Path-based routing
  Health checks + automatic failover
  SSL offloading
  Use for: global apps needing edge presence

Traffic Manager — = AWS Route53 health-check routing:
  DNS-based load balancing (not data plane)
  Routes users to closest/healthiest endpoint
  Routing methods: Performance, Priority, Weighted, Geographic
  Works across regions and on-premises
```

### Azure DNS

```
Azure DNS:
  Host your DNS zones in Azure
  Integrated with Azure services (no IP needed for App Service, etc.)
  Alias records: point to Azure resources (like AWS ALIAS records)
  
  az network dns zone create \
    --resource-group judicial-prod-rg \
    --name judicialsolutions.in
  
  az network dns record-set a add-record \
    --resource-group judicial-prod-rg \
    --zone-name judicialsolutions.in \
    --record-set-name api \
    --ipv4-address 1.2.3.4

Private DNS Zones:
  DNS resolution within VNet (no public DNS)
  Like AWS Route53 Private Hosted Zones
  AKS uses private DNS zones for cluster API endpoint
  
  az network private-dns zone create \
    --resource-group judicial-prod-rg \
    --name judicial.private
```

---

## PART 3 — AZURE COMPUTE

### Virtual Machines

```
VM Sizes (naming convention):
  D4s_v5:
  │ │ │ │ └── version 5
  │ │ │ └──── s = premium SSD supported
  │ │ └────── 4 = number of vCPUs
  │ └──────── D = general purpose (like AWS m5)
  
  Series types:
  B:   burstable (like AWS T3)       dev/test
  D:   general purpose               web, app servers
  E:   memory optimised              databases, in-memory
  F:   compute optimised             batch, gaming
  L:   storage optimised             NoSQL, data warehousing
  M:   very large memory             SAP HANA
  NC/ND: GPU                         ML training
  NV:  GPU visualisation             rendering

Availability Sets:
  Group VMs so they don't all fail at same time
  Fault Domains: VMs on different physical racks (power/network)
  Update Domains: VMs patched in sequence (not all at once)
  Use for: old-style HA (2+ VMs in availability set)

Availability Zones:
  Place individual VMs in specific AZs
  Better than Availability Sets for modern workloads
  --zone 1, --zone 2, --zone 3 in az vm create
```

```bash
# Create VM
az vm create \
  --resource-group judicial-prod-rg \
  --name judicial-api-vm \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --vnet-name judicial-vnet \
  --subnet aks-subnet \
  --nsg judicial-aks-nsg \
  --zone 1 \
  --no-wait

# List VMs
az vm list --resource-group judicial-prod-rg --output table

# Start/Stop/Restart
az vm start --resource-group judicial-prod-rg --name judicial-api-vm
az vm stop --resource-group judicial-prod-rg --name judicial-api-vm
az vm restart --resource-group judicial-prod-rg --name judicial-api-vm

# SSH via Azure Bastion (no public IP needed)
az network bastion ssh \
  --name judicial-bastion \
  --resource-group judicial-prod-rg \
  --target-resource-id /subscriptions/.../judicial-api-vm \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

### VM Scale Sets (VMSS) — = AWS Auto Scaling Group

```
VMSS = group of identical VMs that auto-scale

Features:
  Auto-scaling: scale out/in based on metrics
  Manual or automatic scaling
  Rolling updates: update VMs without downtime
  Spot instances: use Azure Spot VMs (cheaper, interruptible)
  Integration: used by AKS for node pools

az vmss create \
  --resource-group judicial-prod-rg \
  --name judicial-vmss \
  --image Ubuntu2204 \
  --instance-count 3 \
  --vm-sku Standard_D2s_v3 \
  --zones 1 2 3 \
  --upgrade-policy-mode automatic

# Autoscale settings
az monitor autoscale create \
  --resource-group judicial-prod-rg \
  --resource judicial-vmss \
  --resource-type Microsoft.Compute/virtualMachineScaleSets \
  --name autoscale-settings \
  --min-count 3 \
  --max-count 15 \
  --count 3

az monitor autoscale rule create \
  --resource-group judicial-prod-rg \
  --autoscale-name autoscale-settings \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 2
```

### Azure App Service — = AWS Elastic Beanstalk

```
Fully managed platform for web apps
  No server management
  Auto-scaling built-in
  Deployment slots (blue-green built-in)
  Custom domains + SSL
  
Languages: .NET, Java, Python, Node.js, PHP, Ruby

App Service Plan:
  Defines: compute resources (CPU, RAM), pricing tier
  Free/Shared: dev/test (no SLA)
  Basic: simple apps (B1, B2, B3)
  Standard: production + auto-scale (S1, S2, S3)
  Premium: advanced features (P1v3, P2v3, P3v3)
  Isolated: dedicated network (for compliance)

Deployment Slots (killer feature):
  Production slot + staging slot
  Deploy to staging → test → swap slots (zero downtime)
  Swap: routes 100% traffic instantly
  Rollback: swap back (old version still in staging)
  Like Blue-Green but built-in!

az webapp create \
  --resource-group judicial-prod-rg \
  --plan judicial-app-plan \
  --name judicial-api-app \
  --runtime "PYTHON:3.12"

# Create staging slot
az webapp deployment slot create \
  --resource-group judicial-prod-rg \
  --name judicial-api-app \
  --slot staging

# Swap staging to production
az webapp deployment slot swap \
  --resource-group judicial-prod-rg \
  --name judicial-api-app \
  --slot staging \
  --target-slot production
```

### Azure Functions — = AWS Lambda

```
Serverless compute — event-driven, pay per execution

Triggers:
  HTTP trigger:        REST API endpoint
  Timer trigger:       cron schedule
  Blob trigger:        when file added to storage
  Queue trigger:       when message added to queue
  Event Hub trigger:   stream processing
  Cosmos DB trigger:   change feed
  Service Bus trigger: message queue

Hosting Plans:
  Consumption (serverless):
    Pay per execution
    Scale to zero
    Cold starts possible
    Execution limit: 5-10 minutes
    
  Premium:
    Pre-warmed instances (no cold start)
    VNet integration
    Unlimited execution duration
    
  Dedicated (App Service):
    Always-on
    Predictable cost
    Full App Service features

az functionapp create \
  --resource-group judicial-prod-rg \
  --storage-account judicialstorage \
  --consumption-plan-location centralindia \
  --runtime python \
  --runtime-version 3.12 \
  --functions-version 4 \
  --name judicial-functions
```

---

## PART 4 — AZURE STORAGE

### Storage Account — Foundation

```
Storage Account = container for all Azure storage services
  One account → multiple services (Blob, File, Queue, Table)
  Globally unique name (DNS: accountname.blob.core.windows.net)

Redundancy options:
  LRS  (Locally Redundant):     3 copies in ONE data center
  ZRS  (Zone Redundant):        3 copies across 3 AZs (same region)
  GRS  (Geo-Redundant):         LRS + async copy to paired region
  GZRS (Geo-Zone Redundant):    ZRS + async copy to paired region
  RA-GRS:                       GRS + read access to secondary (anytime)

Performance tiers:
  Standard: HDD-based, cheaper, for blobs, queues, tables
  Premium:  SSD-based, low latency, for page blobs, file shares

az storage account create \
  --resource-group judicial-prod-rg \
  --name judicialstorage \
  --location centralindia \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --https-only true \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2
```

### Blob Storage — = AWS S3

```
Blob = Binary Large Object = any file (images, videos, documents, logs)

Blob types:
  Block Blob: general files (upload, download) — most common
  Append Blob: log files (can only append, not modify)
  Page Blob: VM disks, random read/write

Access tiers (per blob or account level):
  Hot:     frequently accessed ($0.018/GB) — like S3 Standard
  Cool:    infrequently accessed ($0.01/GB, $0.01/GB retrieval) — like S3-IA
  Cold:    rarely accessed, 90-day minimum
  Archive: long-term, hours to retrieve ($0.002/GB) — like S3 Glacier Deep

Lifecycle management:
  Move to Cool after 30 days
  Move to Archive after 90 days
  Delete after 365 days
  Same concept as AWS S3 Lifecycle policies

az storage container create \
  --name judicial-documents \
  --account-name judicialstorage \
  --auth-mode login

az storage blob upload \
  --account-name judicialstorage \
  --container-name judicial-documents \
  --name case-001.pdf \
  --file /local/path/case-001.pdf

# Generate SAS URL (like AWS presigned URL)
az storage blob generate-sas \
  --account-name judicialstorage \
  --container-name judicial-documents \
  --name case-001.pdf \
  --permissions r \
  --expiry 2024-12-31T23:59:59Z \
  --auth-mode login \
  --as-user
```

### Azure Files — = AWS EFS

```
Azure Files = managed file shares (SMB or NFS protocol)
  Mount on Windows, Linux, macOS
  Mount in Azure VMs or AKS pods
  Fully managed, HA, redundant

Use for:
  Lift-and-shift apps that need shared file storage
  AKS persistent volumes (ReadWriteMany — multiple pods)
  Shared config files across VMs

# Create file share
az storage share create \
  --name judicial-share \
  --account-name judicialstorage \
  --quota 100  # GB

# Mount on Linux
sudo mount -t cifs \
  //judicialstorage.file.core.windows.net/judicial-share \
  /mnt/judicial \
  -o username=judicialstorage,password=STORAGE_KEY,serverino

# In AKS: use Azure File CSI driver
# StorageClass: kubernetes.io/azure-file
# Access mode: ReadWriteMany (unlike Azure Disk which is RWO)
```

### Azure Managed Disks — = AWS EBS

```
Managed Disks = block storage for VMs and AKS
  Azure manages the storage account behind the scenes
  Attached to a single VM (except Ultra for shared)

Disk types:
  Ultra Disk:   highest performance, 160,000 IOPS  (DB intensive)
  Premium SSD:  high performance,    20,000 IOPS  (production DBs)
  Standard SSD: moderate,            6,000 IOPS   (web servers)
  Standard HDD: cheapest,            500 IOPS     (backup, dev)

Premium SSD v2: newer, customize IOPS/throughput independently (like AWS gp3)

In AKS:
  StorageClass: managed-csi (Premium SSD default)
  Access mode: ReadWriteOnce (like AWS EBS — one pod at a time)
  WaitForFirstConsumer: creates disk in same AZ as pod

# AKS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-ssd
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

## PART 5 — AZURE DATABASES

### Azure SQL Database — = AWS RDS SQL Server

```
Fully managed SQL Server in Azure
  No OS management, auto-backup, HA built-in
  
Deployment models:
  Single Database:   one database with dedicated resources
  Elastic Pool:      share resources across multiple databases (cost saving)
  Managed Instance:  near 100% SQL Server compatibility (lift-and-shift)

Service tiers:
  General Purpose:   balanced (5000 IOPS, 8 vCores) — like RDS db.m5
  Business Critical: in-memory, 3 replicas, readable secondaries
  Hyperscale:        auto-scale up to 100TB, read scale-out

HA built-in:
  General Purpose: 99.99% SLA, remote storage
  Business Critical: 99.995% SLA, Always On, 3 replicas
  No need for Multi-AZ option like AWS (it's built-in)

az sql server create \
  --resource-group judicial-prod-rg \
  --name judicial-sql-server \
  --location centralindia \
  --admin-user sqladmin \
  --admin-password SecurePass123!

az sql db create \
  --resource-group judicial-prod-rg \
  --server judicial-sql-server \
  --name judicial-db \
  --service-objective GP_Gen5_2 \
  --zone-redundant true \
  --backup-storage-redundancy Zone
```

### Azure Cosmos DB — = AWS DynamoDB

```
Globally distributed, multi-model NoSQL database

APIs (all backed by same engine):
  Core SQL:     document DB with SQL-like queries
  MongoDB:      MongoDB wire protocol compatible
  Cassandra:    Cassandra CQL compatible
  Gremlin:      graph database
  Table:        key-value (Azure Table Storage compatible)

Key features:
  Single-digit millisecond latency globally
  99.999% availability
  Multi-region writes (all regions can write simultaneously)
  5 consistency levels (Strong → Eventual)
  Serverless or provisioned throughput

Consistency levels (from strong to weak):
  Strong:         read always sees latest write (like SQL)
  Bounded Staleness: reads lag by X versions or time
  Session:        consistent within a client session (default)
  Consistent Prefix: reads never see out-of-order writes
  Eventual:       fastest, cheapest, some stale reads

az cosmosdb create \
  --resource-group judicial-prod-rg \
  --name judicial-cosmos \
  --kind GlobalDocumentDB \
  --locations regionName=centralindia failoverPriority=0 \
  --locations regionName=southindia failoverPriority=1 \
  --enable-automatic-failover true \
  --consistency-policy session
```

### Azure Database for PostgreSQL — = AWS RDS PostgreSQL

```
Managed PostgreSQL — two options:

Flexible Server (recommended):
  Full PG compatibility (11-16)
  Zone redundant HA (standby in different AZ)
  Burstable, General Purpose, Memory Optimized
  Stop/start (save money in dev)
  Private access via VNet

az postgres flexible-server create \
  --resource-group judicial-prod-rg \
  --name judicial-postgres \
  --location centralindia \
  --admin-user pgadmin \
  --admin-password SecurePass123! \
  --sku-name Standard_D4s_v3 \
  --tier GeneralPurpose \
  --version 16 \
  --high-availability ZoneRedundant \
  --storage-size 128 \
  --vnet judicial-vnet \
  --subnet db-subnet
```

### Azure Cache for Redis — = AWS ElastiCache Redis

```
Managed Redis — open-source or Enterprise tiers

az redis create \
  --resource-group judicial-prod-rg \
  --name judicial-redis \
  --location centralindia \
  --sku Standard \
  --vm-size c1 \
  --redis-version 7.0 \
  --enable-non-ssl-port false
```

---

## PART 6 — AZURE CONTAINER REGISTRY

### ACR — = AWS ECR

```
ACR = private Docker registry in Azure
  Stores Docker images, Helm charts, OCI artifacts
  Integrated with AKS (pull without credentials via Managed Identity)
  Geo-replication: replicate images to multiple regions
  Image scanning: Microsoft Defender for Containers

SKUs:
  Basic:    dev/test, no geo-replication
  Standard: production, 100GB storage
  Premium:  geo-replication, private endpoints, 500GB

az acr create \
  --resource-group judicial-prod-rg \
  --name judicialacr \
  --sku Premium \
  --location centralindia \
  --admin-enabled false \     # use Managed Identity instead
  --zone-redundancy Enabled

# Push image
az acr login --name judicialacr

docker tag judicial-api:latest judicialacr.azurecr.io/judicial-api:latest
docker push judicialacr.azurecr.io/judicial-api:latest

# List images
az acr repository list --name judicialacr --output table

# Show tags
az acr repository show-tags \
  --name judicialacr \
  --repository judicial-api \
  --output table

# Geo-replication
az acr replication create \
  --resource-group judicial-prod-rg \
  --registry judicialacr \
  --location westindia

# Enable vulnerability scanning
az acr update \
  --resource-group judicial-prod-rg \
  --name judicialacr \
  --ms-enabledefenderplan true

# Attach ACR to AKS (Managed Identity — no passwords)
az aks update \
  --resource-group judicial-prod-rg \
  --name judicial-aks \
  --attach-acr judicialacr
```

---

## PART 7 — AKS — AZURE KUBERNETES SERVICE

### AKS vs EKS Comparison

```
Feature              AKS                           EKS
──────────────────────────────────────────────────────────────────
Control plane cost   FREE (Microsoft pays)          $0.10/hr
Node OS              Ubuntu, Windows, Azure Linux   Amazon Linux 2
Authentication       Azure AD + Workload Identity   IAM + IRSA
Image registry       ACR (Managed Identity)         ECR (Node IAM role)
Storage (block)      Azure Disk CSI                 EBS CSI
Storage (file)       Azure File CSI                 EFS CSI
Load balancer        AGIC (App Gateway)             AWS LB Controller
Networking           Azure CNI / Azure Overlay      VPC CNI
Node pools           same concept                   same concept
Cluster Autoscaler   built-in option                separate addon
Cost saving          Spot node pools                Spot node groups
```

### Create AKS Cluster

```bash
# Create AKS cluster
az aks create \
  --resource-group judicial-prod-rg \
  --name judicial-aks \
  --location centralindia \
  --kubernetes-version 1.29 \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --zones 1 2 3 \                           # spread across AZs
  --network-plugin azure \                  # Azure CNI
  --network-policy azure \                  # network policy support
  --vnet-subnet-id /subscriptions/.../aks-subnet \
  --enable-managed-identity \               # Managed Identity (not service principal)
  --enable-workload-identity \              # Workload Identity (= IRSA)
  --enable-oidc-issuer \                    # OIDC for Workload Identity
  --enable-cluster-autoscaler \             # Cluster Autoscaler
  --min-count 3 \
  --max-count 15 \
  --attach-acr judicialacr \               # pull from ACR without creds
  --enable-azure-monitor-metrics \          # Prometheus integration
  --tier standard \                         # uptime SLA on control plane
  --no-wait

# Get credentials (configure kubectl)
az aks get-credentials \
  --resource-group judicial-prod-rg \
  --name judicial-aks

# Verify
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

### Node Pools — = EKS Node Groups

```bash
# AKS cluster has one system node pool (created with cluster)
# System pool: runs kube-system pods (CoreDNS, kube-proxy, etc.)
# User pools: run your application pods

# Add user node pool (general purpose)
az aks nodepool add \
  --resource-group judicial-prod-rg \
  --cluster-name judicial-aks \
  --name userpool \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --zones 1 2 3 \
  --mode User \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 20 \
  --labels app=judicial env=prod \
  --node-taints CriticalAddonsOnly=true:NoSchedule

# Add spot node pool (cheaper, interruptible)
az aks nodepool add \
  --resource-group judicial-prod-rg \
  --cluster-name judicial-aks \
  --name spotpool \
  --node-count 0 \
  --node-vm-size Standard_D4s_v3 \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \                     # pay up to on-demand price
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 30 \
  --node-taints kubernetes.azure.com/scalesetpriority=spot:NoSchedule

# Tolerate spot taint in pod spec:
# tolerations:
# - key: "kubernetes.azure.com/scalesetpriority"
#   value: "spot"
#   effect: NoSchedule

# Scale node pool manually
az aks nodepool scale \
  --resource-group judicial-prod-rg \
  --cluster-name judicial-aks \
  --name userpool \
  --node-count 5

# List node pools
az aks nodepool list \
  --resource-group judicial-prod-rg \
  --cluster-name judicial-aks \
  --output table

# Upgrade node pool OS
az aks nodepool upgrade \
  --resource-group judicial-prod-rg \
  --cluster-name judicial-aks \
  --name userpool \
  --kubernetes-version 1.30
```

### Workload Identity — = AWS IRSA

```
Problem: pods need to call Azure services (Key Vault, Storage, SQL)
         Don't want to store credentials in pod

Workload Identity (= IRSA in AWS):
  Pod has a Kubernetes ServiceAccount
  ServiceAccount annotated with Azure Managed Identity
  Pod gets a projected token → exchanges with Azure AD → gets temp Azure credentials
  No secrets stored anywhere

Setup:

Step 1: Create Managed Identity
az identity create \
  --resource-group judicial-prod-rg \
  --name judicial-api-identity

Step 2: Get identity details
CLIENT_ID=$(az identity show \
  --name judicial-api-identity \
  --resource-group judicial-prod-rg \
  --query clientId -o tsv)

Step 3: Grant identity permissions
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $CLIENT_ID \
  --scope /subscriptions/.../vaults/judicial-keyvault

Step 4: Create federated credential (trust K8s SA)
AKS_OIDC_ISSUER=$(az aks show \
  --resource-group judicial-prod-rg \
  --name judicial-aks \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --name judicial-api-fedcred \
  --identity-name judicial-api-identity \
  --resource-group judicial-prod-rg \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:production:judicial-api-sa \
  --audience api://AzureADTokenExchange

Step 5: Create K8s ServiceAccount with annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judicial-api-sa
  namespace: production
  annotations:
    azure.workload.identity/client-id: "CLIENT_ID_HERE"

Step 6: Use in pod
spec:
  serviceAccountName: judicial-api-sa
  labels:
    azure.workload.identity/use: "true"    # REQUIRED label

Now pod can call Azure SDK — no stored credentials!
Azure SDK auto-discovers credentials from projected token.
```

### AGIC — Application Gateway Ingress Controller

```
AGIC = Application Gateway Ingress Controller
     = Azure's equivalent of AWS Load Balancer Controller

Creates real Azure Application Gateway from K8s Ingress definitions

# Enable AGIC addon
az aks enable-addons \
  --resource-group judicial-prod-rg \
  --name judicial-aks \
  --addons ingress-appgw \
  --appgw-name judicial-appgw \
  --appgw-subnet-cidr 10.225.0.0/16

# Ingress YAML (uses App Gateway)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: judicial-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
    appgw.ingress.kubernetes.io/waf-policy-for-path: /subscriptions/.../wafpolicy
spec:
  tls:
  - hosts:
    - api.judicialsolutions.in
    secretName: judicial-tls
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

### AKS Networking — Azure CNI vs Kubenet

```
Azure CNI (recommended for production):
  Pods get real VNet IPs (like EKS VPC CNI)
  Each pod = real VNet IP
  Pods directly reachable from VNet (VMs, on-premises)
  Requires: pre-plan enough IPs in subnet
  
  IP planning:
    Node count * pods-per-node = IPs needed
    30 nodes * 30 pods = 900 IPs minimum
    Use /22 or larger subnet

Azure Overlay (newer, recommended):
  Pods get private overlay IPs (not VNet IPs)
  Much less IP consumption from VNet
  Pods NOT directly reachable from outside cluster
  Use when: many pods, limited VNet IP space

Kubenet (legacy, avoid):
  Simple overlay networking
  No NetworkPolicy support
  Limited features

Network Policy support:
  Azure Network Policy: built into Azure CNI
  Calico: open-source, works with Azure CNI and Kubenet
  Cilium: eBPF-based, newest, most powerful
```

---

## PART 8 — AZURE IDENTITY & SECURITY

### Azure Active Directory (Azure AD / Entra ID)

```
Azure AD = Microsoft's cloud identity service
           Renamed to Microsoft Entra ID in 2023

Unlike AWS IAM:
  AWS IAM: users, roles, policies (cloud-native)
  Azure AD: enterprise identity (users, groups, apps, devices)
            ALSO used for Azure resource access
            Used by Office 365, Teams, Azure, all Microsoft services

Key concepts:
  Tenant:       your organization's Azure AD instance
  User:         person with identity (aditya@company.com)
  Group:        collection of users
  App Registration: your app's identity (like AWS IAM role for apps)
  Service Principal: identity for an app/service to access Azure
  Managed Identity: automatic identity for Azure resources (no credentials)
```

### Managed Identity — = AWS IAM Role for EC2/Lambda

```
Managed Identity = automatic identity for Azure resources
  No credentials to manage, rotate, or store
  Azure automatically manages the credential lifecycle

Types:
  System-assigned: tied to one resource, deleted with resource
  User-assigned:   independent, can be shared across resources

Common use:
  AKS pod → Workload Identity → Azure AD → Key Vault
  VM → Managed Identity → Storage Account (no keys in VM)
  Azure Function → Managed Identity → SQL Database

# Create user-assigned managed identity
az identity create \
  --name judicial-api-identity \
  --resource-group judicial-prod-rg

# Assign to VM
az vm identity assign \
  --resource-group judicial-prod-rg \
  --name judicial-vm \
  --identities judicial-api-identity

# Grant permissions
az role assignment create \
  --assignee $(az identity show -n judicial-api-identity \
    -g judicial-prod-rg --query clientId -o tsv) \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/.../storageAccounts/judicialstorage

# SDK automatically uses Managed Identity (no code change):
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

credential = DefaultAzureCredential()  # auto-detects Managed Identity
client = BlobServiceClient(
  "https://judicialstorage.blob.core.windows.net",
  credential=credential
)
```

### Azure RBAC — Role-Based Access Control

```
Azure RBAC = who can do what on which resources

Components:
  Security principal: who (user, group, managed identity, service principal)
  Role definition:    what permissions (built-in or custom)
  Scope:              which resources (subscription, RG, resource)
  Role assignment:    principal + role + scope

Built-in roles:
  Owner:          full access + can assign roles
  Contributor:    full access, cannot assign roles
  Reader:         read-only
  User Access Admin: only manage role assignments

Service-specific roles:
  Storage Blob Data Contributor: read+write blobs
  Storage Blob Data Reader:      read blobs
  Key Vault Secrets User:        read secrets
  AcrPull:                       pull images from ACR
  AKS Cluster Admin:             full AKS access
  AKS RBAC Cluster Admin:        K8s RBAC admin

# Assign role
az role assignment create \
  --assignee developer@company.com \
  --role "Reader" \
  --scope /subscriptions/SUBSCRIPTION_ID/resourceGroups/judicial-prod-rg

# List assignments
az role assignment list \
  --resource-group judicial-prod-rg \
  --output table

# Check what current user can do
az role assignment list \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --output table
```

### Azure Key Vault — = AWS Secrets Manager + KMS

```
Key Vault = centralized secrets, keys, certificates management

Three types of objects:
  Secrets:      passwords, connection strings, API keys
  Keys:         cryptographic keys (RSA, EC) for encryption/signing
  Certificates: X.509 certificates with auto-renewal

Access models:
  Vault access policy: old model (per-object permissions)
  Azure RBAC: new model (recommended, role-based)

# Create Key Vault
az keyvault create \
  --resource-group judicial-prod-rg \
  --name judicial-keyvault \
  --location centralindia \
  --enable-rbac-authorization true \    # use Azure RBAC model
  --sku standard \
  --retention-days 90 \
  --enable-soft-delete true \           # 90-day recovery window
  --enable-purge-protection true        # prevent permanent deletion

# Add secret
az keyvault secret set \
  --vault-name judicial-keyvault \
  --name "db-password" \
  --value "MyStr0ngP@ss"

# Read secret
az keyvault secret show \
  --vault-name judicial-keyvault \
  --name "db-password" \
  --query value -o tsv

# Grant access (Managed Identity)
az role assignment create \
  --assignee CLIENT_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/.../vaults/judicial-keyvault

# In AKS: use Secrets Store CSI Driver
# Mounts Key Vault secrets as files in pods

# Install CSI driver
az aks enable-addons \
  --addons azure-keyvault-secrets-provider \
  --name judicial-aks \
  --resource-group judicial-prod-rg

# SecretProviderClass
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: judicial-secrets
  namespace: production
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    clientID: "MANAGED_IDENTITY_CLIENT_ID"
    keyvaultName: judicial-keyvault
    tenantId: "TENANT_ID"
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret

# Pod mounts Key Vault secret as file
volumeMounts:
- name: secrets
  mountPath: "/run/secrets"
  readOnly: true

volumes:
- name: secrets
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: judicial-secrets
```

### Microsoft Defender for Containers

```
Defender for Containers = security for AKS + ACR
  Image scanning: scan ACR images on push
  Runtime protection: detect threats in running containers
  K8s audit: monitor K8s API for suspicious activity
  Recommendations: security posture improvements

Enable:
  az security pricing create \
    --name Containers \
    --tier Standard

What it detects:
  Privileged container spawned
  New container exposed on node network
  Shell command execution in running container
  Outbound connection to known malicious IP
  Crypto mining activity
```

---

## PART 9 — AZURE DEVOPS PIPELINES

### Azure DevOps Overview

```
Azure DevOps = Microsoft's DevOps platform (like GitHub + GitHub Actions)
Components:
  Boards:     project management (like Jira)
  Repos:      git repositories (like GitHub)
  Pipelines:  CI/CD (like GitHub Actions)
  Artifacts:  package management (npm, pip, Maven, NuGet)
  Test Plans: testing management

URL: dev.azure.com/organization/project

Azure Pipelines vs GitHub Actions:
  Azure Pipelines:   Microsoft ecosystem, enterprise features
  GitHub Actions:    community marketplace, simpler, YAML
  Both: YAML-defined, agents/runners, same concepts

Pipeline Agent = GitHub Actions Runner
Self-hosted agents: your own VMs (like GitHub self-hosted runners)
Microsoft-hosted agents: pre-configured VMs (like GitHub-hosted runners)
  ubuntu-latest, windows-latest, macos-latest
```

### Azure Pipeline YAML — Complete Example

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main
  paths:
    exclude:
    - '**.md'

pr:
  branches:
    include:
    - main

variables:
  imageRepository: 'judicial-api'
  containerRegistry: 'judicialacr.azurecr.io'
  dockerfilePath: '$(Build.SourcesDirectory)/Dockerfile'
  tag: '$(Build.SourceVersion)'   # full git SHA
  shortTag: $[ left(variables['Build.SourceVersion'], 8) ]
  aksResourceGroup: 'judicial-prod-rg'
  aksClusterName: 'judicial-aks'
  k8sNamespace: 'production'

stages:

# ─── STAGE 1: BUILD AND TEST ─────────────────────────────────
- stage: BuildTest
  displayName: 'Build and Test'
  jobs:

  - job: UnitTests
    displayName: 'Unit Tests'
    pool:
      vmImage: ubuntu-latest
    steps:
    - task: UsePythonVersion@0
      inputs:
        versionSpec: '3.12'
    - script: |
        pip install -r requirements.txt
        pip install pytest pytest-cov
        pytest tests/ \
          --cov=src \
          --cov-fail-under=80 \
          --junitxml=junit.xml
      displayName: 'Run tests'
    - task: PublishTestResults@2
      inputs:
        testResultsFiles: 'junit.xml'
      condition: always()

  - job: Build
    displayName: 'Build Docker Image'
    pool:
      vmImage: ubuntu-latest
    steps:
    - task: Docker@2
      displayName: 'Build image'
      inputs:
        command: build
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        tags: |
          $(shortTag)
          latest

    - task: trivy@1                    # Trivy security scan
      displayName: 'Security scan'
      inputs:
        version: latest
        docker: false
        image: $(imageRepository):$(shortTag)
        severity: CRITICAL,HIGH
        exitCode: 1                    # fail on critical

# ─── STAGE 2: PUSH ───────────────────────────────────────────
- stage: Push
  displayName: 'Push to ACR'
  dependsOn: BuildTest
  condition: succeeded()
  jobs:

  - job: PushImage
    displayName: 'Push to Azure Container Registry'
    pool:
      vmImage: ubuntu-latest
    steps:
    - task: Docker@2
      displayName: 'Login and push to ACR'
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: 'judicial-acr-connection'  # service connection
        tags: |
          $(shortTag)
          latest

# ─── STAGE 3: DEPLOY STAGING ─────────────────────────────────
- stage: DeployStaging
  displayName: 'Deploy to Staging'
  dependsOn: Push
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:

  - deployment: DeployStaging
    displayName: 'Deploy to staging AKS'
    pool:
      vmImage: ubuntu-latest
    environment: 'staging'             # environment protection rules
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@1
              displayName: 'Set image in staging'
              inputs:
                action: patch
                resourceToPatch: deployment/judicial-api
                namespace: $(k8sNamespace)
                kubernetesServiceConnection: 'judicial-aks-staging'
                patch: |
                  spec:
                    template:
                      spec:
                        containers:
                        - name: judicial-api
                          image: $(containerRegistry)/$(imageRepository):$(shortTag)

          - script: |
              sleep 30
              curl -sf https://staging.judicialsolutions.in/health \
                || exit 1
              echo "Staging healthy"
            displayName: 'Smoke test'

# ─── STAGE 4: DEPLOY PRODUCTION ──────────────────────────────
- stage: DeployProduction
  displayName: 'Deploy to Production'
  dependsOn: DeployStaging
  jobs:

  - deployment: DeployProduction
    displayName: 'Deploy to production AKS'
    pool:
      vmImage: ubuntu-latest
    environment: 'production'          # requires manual approval
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@1
            displayName: 'Deploy to production'
            inputs:
              action: deploy
              namespace: $(k8sNamespace)
              kubernetesServiceConnection: 'judicial-aks-prod'
              manifests: |
                k8s/deployment.yaml
                k8s/service.yaml
              containers: |
                $(containerRegistry)/$(imageRepository):$(shortTag)

          - script: |
              sleep 30
              curl -sf https://api.judicialsolutions.in/health || exit 1
            displayName: 'Production smoke test'
```

### Service Connections — = GitHub OIDC

```
Service Connection = how Azure DevOps authenticates to external services
  ACR connection: pipeline can push/pull images
  AKS connection: pipeline can run kubectl
  Azure connection: pipeline can manage Azure resources

Types:
  Azure Resource Manager: connect to Azure subscription
  Docker Registry:        connect to ACR or Docker Hub
  Kubernetes:            connect to AKS cluster

# Create via Azure DevOps UI:
Project Settings → Service Connections → New Service Connection

Best practice: use Workload Identity Federation
  (like OIDC — no stored secrets, automatic token exchange)
  
  Azure Resource Manager connection:
    Authentication method: Workload Identity federation
    → Creates app registration + federated credential automatically
    → Pipeline gets temp tokens, no secrets stored
```

---

## PART 10 — AZURE MONITOR & OBSERVABILITY

### Azure Monitor — Central Observability Hub

```
Azure Monitor = umbrella for all Azure observability
  Metrics:    numerical time-series data (CPU, memory, requests)
  Logs:       text events in Log Analytics workspace
  Alerts:     notify when condition met
  Dashboards: visualise metrics and logs

Data sources → Azure Monitor:
  Azure resources:    automatically (no agent)
  VMs:               Azure Monitor Agent (AMA)
  AKS:               Container Insights
  Applications:      Application Insights SDK
  Custom:            REST API, OpenTelemetry

AWS equivalent:
  Azure Monitor = CloudWatch (metrics + logs + alarms combined)
  Log Analytics = CloudWatch Logs Insights
  App Insights = AWS X-Ray + custom metrics
```

### Log Analytics Workspace

```
Log Analytics Workspace = central log storage and query engine

Like AWS CloudWatch Logs but with more powerful query language (KQL)

KQL (Kusto Query Language):
  // Last hour of errors
  ContainerLog
  | where TimeGenerated > ago(1h)
  | where LogEntry contains "ERROR"
  | summarize count() by ContainerName, bin(TimeGenerated, 5m)
  | order by TimeGenerated desc

  // AKS pod crashes
  KubePodInventory
  | where TimeGenerated > ago(1h)
  | where ContainerStatusReason == "OOMKilled"
  | project TimeGenerated, Name, Namespace, ContainerStatusReason

  // API response times
  AppRequests
  | where TimeGenerated > ago(1h)
  | where Url contains "/api/cases"
  | summarize
      avg(DurationMs),
      percentile(DurationMs, 95),
      percentile(DurationMs, 99)
    by bin(TimeGenerated, 5m)

  // Failed login attempts
  SigninLogs
  | where ResultType != 0              // non-zero = failure
  | summarize count() by UserPrincipalName
  | top 10 by count_
```

### Container Insights — AKS Monitoring

```
Container Insights = built-in AKS monitoring addon

Enable:
  az aks enable-addons \
    --addons monitoring \
    --name judicial-aks \
    --resource-group judicial-prod-rg \
    --workspace-resource-id /subscriptions/.../workspaces/judicial-laws

What you get:
  Node metrics: CPU, memory, disk per node
  Pod metrics:  CPU, memory per pod/container
  Container logs: stdout/stderr → Log Analytics
  Live logs: stream logs in real-time from Azure portal
  Pre-built dashboards: node inventory, pod health, deployments

Key KQL queries for AKS:
  // High CPU pods
  KubePodInventory
  | where TimeGenerated > ago(5m)
  | join kind=inner (
      Perf
      | where ObjectName == "K8SContainer"
      | where CounterName == "cpuUsageNanoCores"
  ) on InstanceName
  | summarize AvgCPU = avg(CounterValue) by Name, Namespace

  // OOMKilled events
  KubeEvents
  | where TimeGenerated > ago(1h)
  | where Reason == "OOMKilling"
  | project TimeGenerated, Name, Namespace, Message
```

### Application Insights — = AWS X-Ray + Custom Metrics

```
Application Insights = APM (Application Performance Management)
  Distributed tracing
  Request/dependency tracking
  Custom metrics
  Availability tests (synthetic monitoring)
  Smart detection (anomaly detection)

SDK integration (Python):
  pip install opencensus-ext-azure

  from opencensus.ext.azure import metrics_exporter
  from opencensus.ext.azure.trace_exporter import AzureExporter
  from opencensus.trace.samplers import ProbabilitySampler
  from opencensus.trace.tracer import Tracer

  tracer = Tracer(
    exporter=AzureExporter(connection_string=CONNECTION_STRING),
    sampler=ProbabilitySampler(1.0)
  )

  with tracer.span(name='get_cases'):
    cases = db.query("SELECT * FROM cases")

Or: OpenTelemetry (vendor-neutral, recommended)
  pip install azure-monitor-opentelemetry
  
  from azure.monitor.opentelemetry import configure_azure_monitor
  configure_azure_monitor(connection_string=CONNECTION_STRING)
  # Auto-instruments: requests, SQLAlchemy, Redis, etc.
```

### Alerts

```bash
# Create metric alert
az monitor metrics alert create \
  --name "High CPU Alert" \
  --resource-group judicial-prod-rg \
  --scopes /subscriptions/.../resourceGroups/judicial-prod-rg/providers/Microsoft.ContainerService/managedClusters/judicial-aks \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/.../actionGroups/devops-alerts

# Create action group (where to send alerts)
az monitor action-group create \
  --resource-group judicial-prod-rg \
  --name devops-alerts \
  --short-name devops \
  --email devops@company.com \
  --webhooks name=slack url=https://hooks.slack.com/...

# Log alert (KQL-based)
az monitor scheduled-query create \
  --resource-group judicial-prod-rg \
  --name "Pod OOMKilled Alert" \
  --scopes /subscriptions/.../workspaces/judicial-laws \
  --condition "count > 0" \
  --condition-query "KubeEvents | where Reason == 'OOMKilling'" \
  --evaluation-frequency 5m \
  --window-size 5m \
  --severity 2 \
  --action-groups /subscriptions/.../actionGroups/devops-alerts
```

---

## PART 11 — AZURE IAC

### ARM Templates — = AWS CloudFormation

```
ARM (Azure Resource Manager) = native Azure IaC format
  JSON format (verbose, hard to read)
  Declarative
  Idempotent
  Azure-native (deep integration)

{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "aksClusterName": {
      "type": "string",
      "defaultValue": "judicial-aks"
    }
  },
  "resources": [
    {
      "type": "Microsoft.ContainerService/managedClusters",
      "apiVersion": "2024-02-01",
      "name": "[parameters('aksClusterName')]",
      "location": "[resourceGroup().location]",
      "properties": { ... }
    }
  ]
}

# Deploy ARM template
az deployment group create \
  --resource-group judicial-prod-rg \
  --template-file aks.json \
  --parameters aksClusterName=judicial-aks
```

### Bicep — = Easier ARM (like Terraform HCL for Azure)

```
Bicep = Microsoft's own HCL-like language for Azure
  Compiles to ARM templates
  Much cleaner syntax than raw ARM JSON
  Azure-native (better IDE support, type checking)

// main.bicep
param location string = resourceGroup().location
param clusterName string = 'judicial-aks'
param nodeCount int = 3

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodeCount
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        availabilityZones: ['1', '2', '3']
        enableAutoScaling: true
        minCount: 3
        maxCount: 15
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
    }
  }
}

output clusterName string = aksCluster.name

# Deploy Bicep
az deployment group create \
  --resource-group judicial-prod-rg \
  --template-file main.bicep \
  --parameters nodeCount=5
```

### Terraform with Azure

```
Terraform = multi-cloud IaC — works with Azure
  Same HCL syntax you know from AWS
  Azure provider: hashicorp/azurerm

# providers.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
  backend "azurerm" {               # remote state in Azure Blob
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "judicialterraformstate"
    container_name       = "tfstate"
    key                  = "production/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# main.tf
resource "azurerm_resource_group" "main" {
  name     = "judicial-prod-rg"
  location = "Central India"
  tags = {
    Environment = "production"
    Project     = "judicial"
    ManagedBy   = "terraform"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "judicial-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "judicial-aks"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "judicial-aks"
  kubernetes_version  = "1.29"

  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D4s_v3"
    zones               = ["1", "2", "3"]
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 15
    vnet_subnet_id      = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true
}

# Authentication for Terraform → Azure
az login
az account set --subscription "Production"
# Terraform uses your logged-in credentials
# OR use Service Principal:
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_TENANT_ID="..."
export ARM_SUBSCRIPTION_ID="..."
```

---

## PART 12 — AZURE VS AWS COMPARISON

### Service Comparison Table

```
Category           AWS                    Azure
──────────────────────────────────────────────────────────────────
Compute:
  VMs              EC2                    Virtual Machines
  Auto Scaling     Auto Scaling Group     VM Scale Sets (VMSS)
  Serverless       Lambda                 Azure Functions
  PaaS web         Elastic Beanstalk      App Service
  Containers       ECS                    Azure Container Instances

Kubernetes:
  Managed K8s      EKS ($0.10/hr)         AKS (FREE control plane)
  Image registry   ECR                    ACR
  Ingress          AWS LB Controller      AGIC (App Gateway)
  Pod IAM          IRSA                   Workload Identity
  Node groups      Managed Node Groups    Node Pools

Networking:
  Private network  VPC                    VNet
  Subnet           Subnet (per AZ)        Subnet (spans all AZs)
  Firewall         Security Group + NACL  NSG
  L4 load balancer NLB                    Azure Load Balancer
  L7 load balancer ALB                    Application Gateway
  CDN + global LB  CloudFront             Azure Front Door
  DNS routing      Route53                Azure Traffic Manager
  DNS hosting      Route53 Hosted Zones   Azure DNS
  Private DNS      Route53 Private HZ     Azure Private DNS
  VPC peering      VPC Peering            VNet Peering
  Dedicated line   Direct Connect         ExpressRoute
  VPN              Site-to-Site VPN       VPN Gateway

Storage:
  Object storage   S3                     Azure Blob Storage
  File storage     EFS                    Azure Files
  Block storage    EBS                    Azure Managed Disks
  Archive          S3 Glacier             Archive tier (Blob)

Databases:
  Managed SQL      RDS                    Azure SQL / Flexible Server
  NoSQL            DynamoDB               Cosmos DB
  PostgreSQL       RDS PostgreSQL         Azure DB for PostgreSQL
  MySQL            RDS MySQL              Azure DB for MySQL
  Redis cache      ElastiCache            Azure Cache for Redis

Identity:
  Identity service IAM                    Azure AD (Entra ID)
  User management  IAM Users              Azure AD Users
  Roles            IAM Roles              Azure RBAC Roles
  Service identity IAM Role (EC2)         Managed Identity
  Pod identity     IRSA                   Workload Identity
  SSO              AWS SSO                Azure AD SSO
  MFA              IAM MFA                Azure AD MFA + Conditional Access

Secrets & Keys:
  Secrets          Secrets Manager        Key Vault (Secrets)
  Keys             KMS                    Key Vault (Keys)
  Certificates     ACM                    Key Vault (Certs)

DevOps:
  CI/CD pipelines  CodePipeline           Azure Pipelines
  Source control   CodeCommit             Azure Repos
  Package registry CodeArtifact           Azure Artifacts
  Project mgmt     —                      Azure Boards (like Jira)

Security:
  Threat detection GuardDuty              Microsoft Defender for Cloud
  WAF              AWS WAF                Azure WAF (in App Gateway)
  Compliance       Security Hub           Microsoft Defender for Cloud
  IaC scanning     —                      Defender for DevOps
  CSPM             Security Hub           Defender CSPM
  Log aggregation  CloudTrail             Azure Activity Log + Monitor

Monitoring:
  Metrics          CloudWatch Metrics     Azure Monitor Metrics
  Logs             CloudWatch Logs        Log Analytics (KQL)
  APM/Tracing      X-Ray                  Application Insights
  Dashboards       CloudWatch Dashboards  Azure Dashboards + Workbooks

IaC:
  Native           CloudFormation         ARM Templates / Bicep
  State backend    S3 + DynamoDB          Azure Blob Storage + table
  Multi-cloud      Terraform              Terraform

Cost:
  Cost view        Cost Explorer          Azure Cost Management
  Budgets          AWS Budgets            Azure Budgets
  Savings plans    Savings Plans          Azure Savings Plans
  Spot             Spot Instances         Spot VMs
```

### Key Conceptual Differences

```
1. Resource Groups (Azure) vs Tags (AWS)
   AWS: resources exist in account, organization via tags
   Azure: resources MUST be in Resource Group — structural, not optional

2. AKS is Free; EKS is Not
   EKS: $0.10/hr per cluster = $72/month just for control plane
   AKS: control plane is FREE — pay only for nodes

3. Subscription vs Account
   Both = billing + permission boundary
   Azure: Subscriptions organized under Management Groups
   AWS: Accounts organized under Organizations

4. Azure AD is Central to Everything
   AWS: IAM is cloud-only identity
   Azure: Azure AD integrates enterprise identity + cloud
          Office 365 users = Azure AD users = Azure access

5. Networking Subnets
   AWS: subnet is per-AZ (tight coupling)
   Azure: subnet spans all AZs in region
          VM/AKS nodes placed in AZ at creation time

6. Managed Identity > Managed Identity
   Both avoid storing credentials
   Azure: MI directly to resource (simpler for non-K8s)
   AWS: IAM role needs instance profile (slightly more setup)
```

---

## PART 13 — INTERVIEW QUESTIONS

**Q1: How is AKS different from EKS?**
```
Core Kubernetes is identical — same YAML, same kubectl.
Differences are cloud-specific integrations:

Cost:    AKS control plane is FREE; EKS costs $0.10/hr (~$72/month)
Auth:    AKS uses Workload Identity + Azure AD; EKS uses IRSA + IAM
Images:  AKS uses ACR with Managed Identity; EKS uses ECR with node IAM role
Ingress: AKS uses AGIC (Application Gateway); EKS uses AWS LB Controller
Storage: AKS → Azure Disk/Files CSI; EKS → EBS/EFS CSI
Network: AKS → Azure CNI or Overlay; EKS → VPC CNI

My EKS experience transfers directly to AKS.
The K8s concepts are identical — the cloud integrations differ.
```

**Q2: What is Workload Identity in AKS? How is it different from IRSA?**
```
Both solve the same problem: pods need cloud service access without stored credentials.

IRSA (AWS):
  Pod → K8s projected token → AWS STS → IAM role credentials
  ServiceAccount annotated with IAM role ARN

Workload Identity (Azure):
  Pod → K8s projected token → Azure AD → Azure credentials
  ServiceAccount annotated with Managed Identity client ID
  Federated credential established between AKS OIDC issuer and Managed Identity

Both:
  No static credentials stored anywhere
  Pod-level permissions (not node-level sharing)
  Auto-expire and refresh
  OIDC-based token exchange

Implementation in AKS:
  Enable --enable-workload-identity and --enable-oidc-issuer on cluster
  Create Managed Identity
  Create federated credential linking K8s SA to Managed Identity
  Annotate ServiceAccount: azure.workload.identity/client-id
  Label pod: azure.workload.identity/use: "true"
```

**Q3: How do you manage secrets in AKS?**
```
Production approach: Key Vault + Secrets Store CSI Driver

1. Store secrets in Azure Key Vault (encrypted, audited, access-controlled)
2. Enable Secrets Store CSI Driver addon in AKS
3. Create SecretProviderClass (defines which KV secrets to sync)
4. Pod uses Workload Identity to access Key Vault (no stored creds)
5. Secrets mounted as files in /run/secrets/

Benefits over K8s native Secrets:
  Key Vault: encrypted at rest, full audit log, RBAC-controlled
  K8s Secrets: base64 only (not encrypted), anyone with broad RBAC can read
  Auto-rotation: KV secret rotates → pod gets new value on next mount

Alternative: External Secrets Operator + Key Vault
  Works same way but syncs to K8s Secrets (useful for apps that need env vars)
```

**Q4: VNet vs VPC — what are the key differences?**
```
Similar purpose: private network for cloud resources

Key differences:
  Subnets:  AWS subnet is per-AZ; Azure subnet spans all AZs in region
  NSG:      Azure NSG = SG + NACL combined (stateful, allow+deny)
  AWS SG:   only allow rules; NACL for deny rules
  Peering:  both non-transitive, must configure both sides
  VPN:      AWS Site-to-Site VPN; Azure VPN Gateway
  Dedicated: AWS Direct Connect; Azure ExpressRoute

For AKS:
  Bring Your Own VNet (BYOVNET) — deploy AKS into existing VNet
  Subnet must be large enough for pods (Azure CNI: nodes × max-pods IPs)
  Service endpoints or Private Endpoints for PaaS services
```

**Q5: Explain Azure DevOps Pipeline vs GitHub Actions**
```
Same concept: YAML-defined CI/CD triggered by git events

GitHub Actions:
  Community marketplace (1000s of actions)
  Simpler syntax
  Free for public repos
  OIDC for cloud auth
  Better for open-source

Azure DevOps Pipelines:
  Enterprise features (audit, compliance, approvals)
  Deeper Azure integration (service connections, environments)
  Better reporting (test results, code coverage history)
  Self-hosted agents on VMs or AKS
  Works with any git (GitHub, GitLab, Bitbucket, Azure Repos)

For Azure workloads I'd choose:
  Azure DevOps Pipelines — native environment protection,
  service connections with Workload Identity Federation,
  and the deployment gates for enterprise compliance.
  But the YAML concepts are near-identical to what I know
  from GitHub Actions.
```

**Q6: How do you achieve high availability in Azure?**
```
Multiple layers:

1. Availability Zones: deploy VMs, AKS nodes across 3 AZs
   --zones 1 2 3 in az aks create

2. AKS topology spread: pods spread across AZs
   topologySpreadConstraints (identical to AWS)

3. Application Gateway: spans all AZs, health checks per pod
   Remove unhealthy targets automatically

4. Azure SQL: Business Critical tier has 3 replicas across AZs
   Automatic failover < 30 seconds

5. Redis: Zone-redundant Standard tier

6. Storage: ZRS (Zone Redundant Storage) → 3 copies across 3 AZs

7. Multi-region (DR): Azure Front Door routes globally
   Region pair replication for databases
   Traffic Manager for DNS-based failover

Result: single AZ failure → system continues running
```

**Q7: How does ACR differ from ECR?**
```
Both: private container registries

ACR advantages:
  Geo-replication: replicate to multiple regions automatically
  Integrated with AKS via Managed Identity (no credentials needed)
  Content trust (image signing)
  Tasks: build images in cloud (like CodeBuild integrated)
  Helm chart storage

ECR advantages:
  Lifecycle policies similar (both support tag retention)
  Public ECR: public image hosting (ACR has no public option)

Integration:
  AKS → ACR: az aks update --attach-acr (one command, Managed Identity)
  EKS → ECR: node IAM role with AmazonEC2ContainerRegistryReadOnly

Both:
  Vulnerability scanning built-in
  IAM/RBAC controlled access
  Geo-distributed image serving within region
```

---

## QUICK REFERENCE

### Azure CLI Cheatsheet

```bash
# Login and subscription
az login
az account set --subscription "Production"
az account show

# Resource Groups
az group create --name rg --location centralindia
az group list --output table
az group delete --name rg --yes

# AKS
az aks create --resource-group rg --name aks --generate-ssh-keys
az aks get-credentials --resource-group rg --name aks
az aks nodepool add --resource-group rg --cluster-name aks --name pool2
az aks show --resource-group rg --name aks

# ACR
az acr create --resource-group rg --name acr --sku Standard
az acr login --name acr
az acr repository list --name acr
az aks update --resource-group rg --name aks --attach-acr acr

# Key Vault
az keyvault create --resource-group rg --name kv --location centralindia
az keyvault secret set --vault-name kv --name secret --value value
az keyvault secret show --vault-name kv --name secret --query value

# VNet
az network vnet create --resource-group rg --name vnet --address-prefix 10.0.0.0/16
az network vnet subnet create --resource-group rg --vnet-name vnet --name subnet --address-prefix 10.0.1.0/24
az network nsg create --resource-group rg --name nsg

# Monitoring
az monitor metrics alert create --name alert --resource-group rg ...
az monitor log-analytics workspace create --resource-group rg --name laws
```

### AWS → Azure Cheatsheet (Quick Reference)

```
AWS term          →  Azure term
─────────────────────────────────────────────────────
VPC               →  VNet
Security Group    →  NSG (Network Security Group)
NACL              →  NSG (combined with SG)
EC2               →  Virtual Machine
Auto Scaling Group→  VM Scale Set
Lambda            →  Azure Functions
ECS               →  Azure Container Instances
EKS               →  AKS
ECR               →  ACR
S3                →  Azure Blob Storage
EBS               →  Azure Managed Disk
EFS               →  Azure Files
RDS               →  Azure SQL / Flexible Server
DynamoDB          →  Cosmos DB
ElastiCache       →  Azure Cache for Redis
Route53           →  Azure DNS + Traffic Manager
CloudFront        →  Azure Front Door
ALB               →  Application Gateway
NLB               →  Azure Load Balancer
IAM               →  Azure AD + Azure RBAC
IAM Role          →  Managed Identity
IRSA              →  Workload Identity
Secrets Manager   →  Key Vault (Secrets)
KMS               →  Key Vault (Keys)
CloudWatch        →  Azure Monitor
CloudTrail        →  Azure Activity Log
GuardDuty         →  Microsoft Defender for Cloud
CloudFormation    →  ARM Templates / Bicep
CodePipeline      →  Azure Pipelines
Direct Connect    →  ExpressRoute
VPC Peering       →  VNet Peering
AWS Organizations →  Azure Management Groups
AWS Account       →  Azure Subscription
Resource tags     →  Resource Groups + Tags
```
