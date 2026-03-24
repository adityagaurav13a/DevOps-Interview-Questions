# Terraform Complete Deep Dive
## Architecture + Commands + Modules + State + Workspaces + Import + AWS + CI/CD
### Theory → Interview Questions → Hands-on Steps

---

## README — How to Use This Document

**Total sections:** 10
**Your strongest sections (real experience):** Modules, AWS resources, CI/CD
**Focus for interviews:** State management internals, import, workspace patterns

### Priority questions to memorise:
| Section | Topic | Why it matters |
|---|---|---|
| Part 1 | How state works | Asked in every Terraform interview |
| Part 3 | Module structure | You claim this on resume — own it |
| Part 4 | Remote state + locking | Production must-know |
| Part 6 | terraform import | Senior-level question |
| Part 8 | Terraform with EKS | Directly on your resume |

### Power phrases:
- *"Terraform state is the source of truth — it maps config to real resources"*
- *"I wrote reusable modules for VPC, IAM, RDS — one-command environment provisioning"*
- *"Remote state in S3 + DynamoDB locking prevents concurrent apply conflicts"*
- *"terraform import brings existing resources under Terraform management"*
- *"I use for_each over count — it handles deletions without index shifting"*

---

## PART 1 — TERRAFORM ARCHITECTURE

### How Terraform Works

```
You write HCL (HashiCorp Configuration Language)
    │
    ▼
terraform plan → compares desired state (config) vs actual state (state file)
    │            generates execution plan (what will change)
    ▼
terraform apply → calls provider APIs to create/update/delete resources
    │             updates state file with new real-world state
    ▼
State file (terraform.tfstate) → single source of truth
    records: what resources exist + their current attributes
```

### Core Components

```
Provider:
  Plugin that talks to a specific API (AWS, GCP, Azure, GitHub)
  Downloads during: terraform init
  Handles: authentication, API calls, resource mapping

  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
  }
  provider "aws" {
    region = "ap-south-1"
  }

Resource:
  Thing Terraform creates/manages
  resource "aws_instance" "web" { ... }
  Format: resource "<type>" "<local_name>"

Data Source:
  Read existing resources (don't create)
  data "aws_ami" "ubuntu" { ... }
  Reference: data.aws_ami.ubuntu.id

State:
  JSON file mapping config → real resources
  Contains: resource IDs, attributes, dependencies
  NEVER edit manually

Backend:
  Where state is stored (local, S3, Terraform Cloud)
  Local = terraform.tfstate (default, not for teams)
  Remote = S3 (for teams — shared, locked)
```

### Terraform Lifecycle

```
terraform init
  Downloads providers
  Initialises backend
  Downloads modules

terraform validate
  Checks HCL syntax
  Validates configuration
  Does NOT check against real infrastructure

terraform plan
  Reads current state
  Calls provider APIs to check real state
  Computes diff: what to create/update/destroy
  Shows execution plan
  Does NOT make any changes

terraform apply
  Runs the plan
  Creates/updates/destroys resources
  Updates state file
  Prompts for confirmation (unless -auto-approve)

terraform destroy
  Plans destruction of all resources
  Applies the destruction plan
  Removes from state file
```

### Dependency Graph

```
Terraform automatically builds a dependency graph:

resource "aws_vpc" "main" { }

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id  ← depends on VPC
}

resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id  ← depends on subnet
}

Execution order: VPC → Subnet → Instance (sequential)
Independent resources: created in parallel

Explicit dependency (when implicit not possible):
resource "aws_instance" "web" {
  depends_on = [aws_iam_role_policy.ec2_policy]
}
```

### Interview Question:
**"What is Terraform state and why is it important?"**

```
State is a JSON file that tracks the relationship between
your Terraform configuration and real-world infrastructure.

It stores:
  - Resource IDs (e.g., instance-id: i-1234567890)
  - Resource attributes (IP, ARN, etc.)
  - Dependency metadata
  - Metadata for performance (cached API responses)

Why it's critical:
  1. Mapping: Terraform knows "aws_instance.web" = i-1234567890
              Without state, it can't manage existing resources

  2. Diff calculation: Plan compares desired (config) vs actual (state)
                       Without state, every apply would recreate everything

  3. Dependencies: State tracks which resources depend on others
                   Ensures correct destroy order

  4. Performance: Terraform can skip API calls using cached state
                  --refresh=false skips even cached refresh

Danger: if state is lost or corrupted:
  Terraform thinks resources don't exist
  Next apply would try to recreate everything → conflicts
  Always backup state (S3 versioning + DynamoDB lock)
```

---

## PART 2 — CORE COMMANDS + VARIABLES + OUTPUTS

### Essential Commands

```bash
# Initialise working directory
terraform init
terraform init -upgrade           # upgrade providers to latest matching version
terraform init -reconfigure       # reinitialise backend (change backend config)

# Validate and format
terraform validate                # check syntax and config validity
terraform fmt                     # format HCL files (style consistency)
terraform fmt -recursive          # format all subdirectories
terraform fmt -check              # exit 1 if formatting needed (CI check)

# Plan
terraform plan                    # show what will change
terraform plan -out=tfplan        # save plan to file
terraform plan -var="env=prod"    # pass variable
terraform plan -target=aws_instance.web  # plan only specific resource
terraform plan -destroy           # show what will be destroyed

# Apply
terraform apply                   # apply with prompt
terraform apply -auto-approve     # no prompt (use in CI/CD)
terraform apply tfplan            # apply saved plan file
terraform apply -target=aws_instance.web  # apply only specific resource

# Destroy
terraform destroy                 # destroy all resources
terraform destroy -target=aws_instance.web  # destroy specific resource

# State inspection
terraform show                    # show current state
terraform show tfplan             # show plan file contents
terraform output                  # show output values
terraform output db_endpoint      # show specific output

# Graph
terraform graph | dot -Tsvg > graph.svg  # visualize dependency graph

# Workspace
terraform workspace list
terraform workspace new prod
terraform workspace select prod
terraform workspace show
```

### Variables

```hcl
# variable types
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Must be a valid t3 instance type."
  }
}

variable "replica_count" {
  type    = number
  default = 2
}

variable "enable_monitoring" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
  default = {
    Team        = "devops"
    Environment = "dev"
  }
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/8", "172.16.0.0/12"]
}

variable "db_config" {
  type = object({
    engine  = string
    version = string
    size    = number
  })
  default = {
    engine  = "postgres"
    version = "16"
    size    = 20
  }
  sensitive = true  # redacted from plan output
}
```

### Variable Precedence (highest to lowest)

```
1. -var flag:           terraform apply -var="env=prod"
2. -var-file flag:      terraform apply -var-file="prod.tfvars"
3. *.auto.tfvars files: automatically loaded
4. terraform.tfvars:    automatically loaded
5. Environment vars:    TF_VAR_env=prod
6. Default values:      in variable block
```

```bash
# terraform.tfvars (auto-loaded)
instance_type = "t3.medium"
replica_count = 3

# prod.tfvars (explicit)
instance_type = "m5.large"
replica_count = 5

# Environment variable
export TF_VAR_db_password="mysecret"
terraform apply  # picks up TF_VAR_db_password
```

### Outputs

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true  # not shown in console, still in state
}

output "instance_ips" {
  value = [for i in aws_instance.web : i.public_ip]
}

# Use output from another module
module "vpc" {
  source = "./modules/vpc"
}

resource "aws_instance" "web" {
  subnet_id = module.vpc.public_subnet_id  # module output
}
```

### Locals and Data Sources

```hcl
# Locals — computed values, avoid repetition
locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = local.common_tags  # reuse everywhere
}

# Data Sources — read existing resources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
# data.aws_caller_identity.current.account_id

data "aws_region" "current" {}
# data.aws_region.current.name

# Use existing VPC (not managed by this Terraform)
data "aws_vpc" "existing" {
  tags = {
    Name = "production-vpc"
  }
}
```

---

## PART 3 — MODULES

### Why Modules?

```
Without modules (copy-paste problem):
  vpc-dev/main.tf     → 200 lines of VPC config
  vpc-staging/main.tf → same 200 lines, slight differences
  vpc-prod/main.tf    → same 200 lines, slight differences

With modules (reusable, parameterised):
  modules/vpc/main.tf → 200 lines (written once)
  
  dev/main.tf         → 5 lines (call module with dev vars)
  staging/main.tf     → 5 lines (call module with staging vars)
  prod/main.tf        → 5 lines (call module with prod vars)
```

### Module Structure

```
modules/
└── vpc/
    ├── main.tf        ← resources
    ├── variables.tf   ← input variables
    ├── outputs.tf     ← output values
    ├── versions.tf    ← required providers/versions
    └── README.md      ← documentation

# Your actual module structure (from resume):
modules/
├── vpc/
├── iam/
├── rds/
└── lambda/
```

### Creating a VPC Module

```hcl
# modules/vpc/variables.tf
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Enable NAT Gateway for private subnets"
}
```

```hcl
# modules/vpc/main.tf
locals {
  az_count = length(data.aws_availability_zones.available.names)
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % local.az_count]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % local.az_count]

  tags = {
    Name = "${var.environment}-private-${count.index + 1}"
    Type = "private"
  }
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs"
}

output "nat_gateway_ip" {
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}
```

### Using a Module

```hcl
# environments/prod/main.tf
module "vpc" {
  source = "../../modules/vpc"    # local path

  # OR from Terraform Registry:
  # source  = "terraform-aws-modules/vpc/aws"
  # version = "~> 5.0"

  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway = true
}

module "rds" {
  source = "../../modules/rds"

  vpc_id     = module.vpc.vpc_id           # use vpc module output
  subnet_ids = module.vpc.private_subnet_ids
  environment = "prod"
}

# Access module outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

### count vs for_each

```hcl
# count — creates N identical resources
resource "aws_subnet" "public" {
  count      = 3
  cidr_block = "10.0.${count.index}.0/24"
}
# Creates: aws_subnet.public[0], [1], [2]
# Problem: deleting middle element shifts all indices → recreates resources

# for_each — creates resources from map/set (preferred)
resource "aws_subnet" "public" {
  for_each = {
    "ap-south-1a" = "10.0.1.0/24"
    "ap-south-1b" = "10.0.2.0/24"
    "ap-south-1c" = "10.0.3.0/24"
  }
  
  availability_zone = each.key
  cidr_block        = each.value
}
# Creates: aws_subnet.public["ap-south-1a"], ["ap-south-1b"], ["ap-south-1c"]
# Deleting "ap-south-1b" only affects that resource — others untouched

# for_each with set of strings
resource "aws_iam_user" "engineers" {
  for_each = toset(["alice", "bob", "charlie"])
  name     = each.key
}
```

---

## PART 4 — STATE MANAGEMENT

### Local vs Remote State

```
Local state (default):
  File: terraform.tfstate
  Works for: single developer, learning
  Problems:
    - Not shared (team can't collaborate)
    - No locking (two applies simultaneously = corruption)
    - No encryption (contains secrets in plaintext)
    - No versioning (hard to recover from mistakes)

Remote state (production):
  Stored in: S3, Terraform Cloud, Azure Blob, GCS
  Benefits:
    - Shared across team
    - Locking (DynamoDB for S3 backend)
    - Encryption (S3 SSE-KMS)
    - Versioning (S3 versioning for recovery)
```

### S3 Backend Setup

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "judicial-terraform-state"
    key            = "judicial/prod/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    
    # Optional: KMS key for additional encryption
    kms_key_id = "arn:aws:kms:ap-south-1:ACCOUNT:key/KEY-ID"
  }
}
```

```bash
# Bootstrap: create the S3 bucket and DynamoDB table first
# (can't use Terraform to create its own state backend)

aws s3 mb s3://judicial-terraform-state --region ap-south-1

aws s3api put-bucket-versioning \
  --bucket judicial-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket judicial-terraform-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Block public access
aws s3api put-public-access-block \
  --bucket judicial-terraform-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1

# Migrate local state to S3
terraform init  # detects backend config, asks to migrate
```

### State Locking

```
DynamoDB lock prevents concurrent applies:

Developer A runs terraform apply:
  DynamoDB: INSERT LockID="judicial/prod/terraform.tfstate"
  Apply runs...
  DynamoDB: DELETE lock

Developer B runs terraform apply at same time:
  DynamoDB: LockID already exists → Error: state locked
  "state blob is already locked, lock Info: ..."
  B must wait for A to finish

Force unlock (DANGEROUS — only if lock is stale):
terraform force-unlock LOCK-ID
# Only run if you're sure no other apply is running
# Incorrect force-unlock → state corruption
```

### State Commands

```bash
# List all resources in state
terraform state list

# Show details of specific resource
terraform state show aws_instance.web

# Move resource (rename in state)
terraform state mv aws_instance.web aws_instance.api
# Use when: renaming resource in config — prevents destroy+recreate

# Move resource to different module
terraform state mv aws_vpc.main module.vpc.aws_vpc.main

# Remove resource from state (WITHOUT destroying it)
terraform state rm aws_instance.web
# Use when: want to unmanage a resource (won't be destroyed)

# Pull state from remote (download to stdout)
terraform state pull > current-state.json

# Push state to remote (DANGEROUS)
terraform state push custom-state.json
# Use only for recovery — can overwrite valid state

# Refresh state from real infrastructure
terraform refresh
# Updates state to match real-world (deprecated in newer versions)
# Use: terraform apply -refresh-only
```

### State Manipulation Best Practices

```
When to use terraform state mv:
  Renaming a resource in config → mv prevents destroy/recreate
  Moving resource into a module → mv updates state path
  Splitting one state into multiple → mv between states

When to use terraform state rm:
  Resource managed outside Terraform temporarily
  Taking a resource out of Terraform management
  Resource was deleted manually — remove from state to sync

NEVER do:
  Delete tfstate file manually → Terraform thinks nothing exists
  Edit tfstate JSON directly → high risk of corruption
  Run two applies simultaneously without locking → state corruption

Recovery from bad state:
  S3 versioning → restore previous version
  aws s3 cp s3://bucket/key?versionId=OLD_VERSION terraform.tfstate
  terraform state push terraform.tfstate
```

---

## PART 5 — WORKSPACES

### What are Workspaces?

```
Workspaces = multiple state files in the same directory
Each workspace gets its own terraform.tfstate

Default workspace: "default" (always exists)

Use case:
  dev workspace → manages dev resources
  staging workspace → manages staging resources
  prod workspace → manages prod resources

Same code, different state = different resource sets
```

```bash
# Workspace commands
terraform workspace list     # list all workspaces
terraform workspace new dev  # create and switch to dev
terraform workspace select prod  # switch to prod
terraform workspace show     # current workspace
terraform workspace delete dev   # delete workspace (must be empty)

# State location with S3 backend:
# s3://bucket/env:/dev/terraform.tfstate
# s3://bucket/env:/prod/terraform.tfstate
# s3://bucket/terraform.tfstate  (default workspace)
```

### Using Workspace in Config

```hcl
# Reference current workspace in config
resource "aws_instance" "web" {
  instance_type = terraform.workspace == "prod" ? "m5.large" : "t3.micro"
  
  tags = {
    Environment = terraform.workspace
    Name        = "${terraform.workspace}-web-server"
  }
}

# Lookup table for workspace-specific values
locals {
  workspace_config = {
    dev = {
      instance_type = "t3.micro"
      replica_count = 1
      db_size       = 20
    }
    staging = {
      instance_type = "t3.medium"
      replica_count = 2
      db_size       = 50
    }
    prod = {
      instance_type = "m5.large"
      replica_count = 3
      db_size       = 100
    }
  }
  
  config = local.workspace_config[terraform.workspace]
}

resource "aws_instance" "web" {
  instance_type = local.config.instance_type
}
```

### Workspaces vs Separate Directories

```
Workspaces (same directory, different state):
  Pros: simple, DRY code
  Cons: same providers/config, can't have different backends
        prod and dev configs must be identical structure
  
  Risk: terraform destroy on wrong workspace → disaster

Separate directories (different directories per environment):
  pros/
  ├── dev/
  │   ├── main.tf
  │   └── terraform.tfvars
  ├── staging/
  │   ├── main.tf
  │   └── terraform.tfvars
  └── prod/
      ├── main.tf
      └── terraform.tfvars
  
  Pros: complete isolation, different configs per env
        can't accidentally apply prod when in dev
  Cons: more duplication (solved with modules)

Best practice for teams:
  Use separate directories for environments
  Use modules to avoid duplication
  Workspaces for simple cases or feature branches
```

---

## PART 6 — TERRAFORM IMPORT

### What is terraform import?

```
Problem: Resources exist in AWS (created manually or by other tools)
         Terraform doesn't know about them (not in state)
         
terraform import: bring existing resources under Terraform management
  - Updates state to track the resource
  - Does NOT generate configuration
  - You must write the config manually (or use -generate-config-out)
```

### Import Workflow

```bash
# Step 1: Find the resource ID in AWS
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=my-server" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text
# i-1234567890abcdef0

# Step 2: Write the config (Terraform needs this first)
# main.tf:
resource "aws_instance" "my_server" {
  # attributes will be populated from state after import
  # minimum required for plan to not fail:
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}

# Step 3: Import
terraform import aws_instance.my_server i-1234567890abcdef0
# State updated: aws_instance.my_server → i-1234567890abcdef0

# Step 4: Run plan to see drift
terraform plan
# Shows differences between your config and real resource
# Update your config to match reality

# Step 5: Verify no drift
terraform plan
# No changes → config matches real resource perfectly
```

### Terraform 1.5+ Import Block (new way)

```hcl
# import.tf — declarative import
import {
  id = "i-1234567890abcdef0"
  to = aws_instance.my_server
}

import {
  id = "vpc-12345678"
  to = aws_vpc.main
}

# Generate config automatically (Terraform 1.5+)
terraform plan -generate-config-out=generated.tf
# Creates generated.tf with all resource attributes
# Review and clean up generated.tf
# Then: terraform apply
```

### Common Import IDs

```bash
# EC2 Instance
terraform import aws_instance.web i-1234567890abcdef0

# S3 Bucket
terraform import aws_s3_bucket.data my-bucket-name

# VPC
terraform import aws_vpc.main vpc-12345678

# Subnet
terraform import aws_subnet.public subnet-12345678

# Security Group
terraform import aws_security_group.web sg-12345678

# RDS Instance
terraform import aws_db_instance.main mydb

# Lambda Function
terraform import aws_lambda_function.api my-function-name

# IAM Role
terraform import aws_iam_role.lambda_role my-role-name

# IAM Policy
terraform import aws_iam_policy.custom arn:aws:iam::ACCOUNT:policy/MyPolicy

# IAM Role Policy Attachment
terraform import aws_iam_role_policy_attachment.lambda \
  my-role/arn:aws:iam::ACCOUNT:policy/MyPolicy

# DynamoDB Table
terraform import aws_dynamodb_table.users users-prod

# CloudFront Distribution
terraform import aws_cloudfront_distribution.cdn E1234ABCDEF

# Route53 Zone
terraform import aws_route53_zone.main ZONE_ID

# EKS Cluster
terraform import aws_eks_cluster.main cluster-name
```

---

## PART 7 — FUNCTIONS + EXPRESSIONS + CONDITIONALS

### String Functions

```hcl
# String manipulation
upper("hello")          → "HELLO"
lower("HELLO")          → "hello"
title("hello world")    → "Hello World"
trimspace("  hello  ")  → "hello"
replace("hello", "l", "L")  → "heLLo"
format("%-10s", "hello")    → "hello     "

# String interpolation
"${var.project}-${var.environment}"

# Multiline string
<<-EOF
  This is a
  multiline string
  EOF

# Heredoc with indentation stripping
locals {
  user_data = <<-SCRIPT
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    SCRIPT
}
```

### Collection Functions

```hcl
# List operations
length(["a", "b", "c"])       → 3
element(["a", "b", "c"], 1)   → "b"
flatten([[1,2], [3,4]])        → [1,2,3,4]
distinct(["a", "b", "a"])     → ["a", "b"]
sort(["c", "a", "b"])         → ["a", "b", "c"]
concat(["a"], ["b", "c"])     → ["a", "b", "c"]
slice(["a","b","c","d"], 1, 3) → ["b", "c"]

# Map operations
keys({a=1, b=2})              → ["a", "b"]
values({a=1, b=2})            → [1, 2]
merge({a=1}, {b=2})           → {a=1, b=2}
lookup({a=1, b=2}, "a", 0)    → 1  (default 0 if not found)

# Type conversion
tostring(42)                  → "42"
tonumber("42")                → 42
tolist(toset(["a","b","a"]))  → ["a", "b"]
toset(["a", "b", "a"])        → {"a", "b"}  (deduplicates)
```

### Expressions

```hcl
# Conditional expression
instance_type = var.environment == "prod" ? "m5.large" : "t3.micro"

# For expression (list)
output "public_ips" {
  value = [for instance in aws_instance.web : instance.public_ip]
}

# For expression (map)
output "instance_map" {
  value = {for instance in aws_instance.web : instance.id => instance.public_ip}
}

# For expression with filter
output "running_ids" {
  value = [
    for instance in aws_instance.web : instance.id
    if instance.instance_state == "running"
  ]
}

# Splat expression (shorthand for for)
output "all_ips" {
  value = aws_instance.web[*].public_ip
  # equivalent to [for i in aws_instance.web : i.public_ip]
}

# Dynamic block (create nested blocks programmatically)
resource "aws_security_group" "web" {
  name = "web-sg"
  
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}

variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {from_port=80, to_port=80, protocol="tcp", cidr_blocks=["0.0.0.0/0"]},
    {from_port=443, to_port=443, protocol="tcp", cidr_blocks=["0.0.0.0/0"]}
  ]
}
```

### Lifecycle Rules

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  lifecycle {
    # Prevent accidental destruction
    prevent_destroy = true

    # Create new resource before destroying old one
    create_before_destroy = true

    # Ignore changes to specific attributes
    ignore_changes = [
      ami,            # don't update if AMI changes
      user_data,      # don't recreate if user_data changes
      tags["LastUpdated"]  # ignore auto-updated tag
    ]

    # Custom validation before resource creation
    precondition {
      condition     = data.aws_ami.ubuntu.architecture == "x86_64"
      error_message = "Only x86_64 AMIs are supported."
    }

    # Custom validation after resource creation
    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance must have a public IP."
    }
  }
}
```

---

## PART 8 — TERRAFORM WITH AWS

### Complete VPC + EC2 Setup

```hcl
# providers.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "judicial-terraform-state"
    key            = "judicial/prod/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

```hcl
# Lambda + API Gateway setup
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-api"
  role             = aws_iam_role.lambda.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.users.name
      ENV        = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}-api"
  retention_in_days = 14
}

# IAM for Lambda
resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query"
      ]
      Resource = [
        aws_dynamodb_table.users.arn,
        "${aws_dynamodb_table.users.arn}/index/*"
      ]
    }]
  })
}

# API Gateway
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["https://judicialsolutions.in"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
```

```hcl
# DynamoDB
resource "aws_dynamodb_table" "users" {
  name         = "${local.name_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true  # never accidentally delete
  }
}
```

### EKS with Terraform

```hcl
# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.name_prefix}-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    general = {
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
    }

    spot = {
      min_size       = 0
      max_size       = 5
      desired_size   = 0
      instance_types = ["m5.large", "m5.xlarge", "m4.large"]
      capacity_type  = "SPOT"
    }
  }

  enable_cluster_creator_admin_permissions = true
}

# IRSA for pods to access AWS services
module "irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${local.name_prefix}-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["production:judicial-api-sa"]
    }
  }

  role_policy_arns = {
    s3    = aws_iam_policy.s3_access.arn
    dynamo = aws_iam_policy.dynamo_access.arn
  }
}
```

---

## PART 9 — CI/CD WITH TERRAFORM

### GitHub Actions Pipeline

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

env:
  TF_VERSION: "1.7.0"
  AWS_REGION: "ap-south-1"

jobs:
  terraform-check:
    name: Validate and Plan
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform/environments/prod

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/terraform-github-role
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        # Fails if any file is not formatted

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        id: plan
        run: terraform plan -out=tfplan -no-color
        continue-on-error: true  # don't fail — comment on PR instead

      - name: Comment Plan on PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const output = `#### Terraform Plan 📖
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            *Pushed by: @${{ github.actor }}*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan
          path: terraform/environments/prod/tfplan

  terraform-apply:
    name: Apply
    needs: terraform-check
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production  # requires manual approval
    defaults:
      run:
        working-directory: terraform/environments/prod

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/terraform-github-role
          aws-region: ${{ env.AWS_REGION }}

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: terraform-plan
          path: terraform/environments/prod/

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan

      - name: Terraform Output
        run: terraform output -json > outputs.json

      - name: Upload Outputs
        uses: actions/upload-artifact@v4
        with:
          name: terraform-outputs
          path: terraform/environments/prod/outputs.json
```

### Atlantis (Pull Request Automation)

```yaml
# atlantis.yaml — in repo root
version: 3
projects:
- name: judicial-prod
  dir: terraform/environments/prod
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars", "../modules/**/*.tf"]
    enabled: true

- name: judicial-staging
  dir: terraform/environments/staging
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
```

```
Atlantis workflow:
  1. Developer creates PR with Terraform changes
  2. Atlantis automatically runs: terraform plan
  3. Posts plan as PR comment
  4. Reviewer approves PR
  5. Developer comments: atlantis apply
  6. Atlantis runs: terraform apply
  7. Posts apply output to PR
  8. PR can be merged

Benefits:
  All Terraform changes require PR review
  Plan visible before merge
  State only modified via Atlantis (not local machines)
  Full audit trail in git

Atlantis server:
  Run as K8s deployment or EC2
  Needs: GitHub webhook + IAM permissions
```

### Security Best Practices for CI/CD

```bash
# Use OIDC instead of access keys
# GitHub → AWS without stored credentials

# IAM role for Terraform CI/CD
# Should have exactly the permissions needed:
# - Create/modify resources in prod
# - Read/write S3 state bucket
# - Read/write DynamoDB lock table
# NOT: AdministratorAccess (too broad)

# Separate roles per environment:
# terraform-github-dev-role
# terraform-github-prod-role  (more restricted, requires approval)

# tfsec — security scanning
docker run --rm \
  -v $(pwd):/src \
  aquasec/tfsec /src

# checkov — compliance scanning
pip install checkov
checkov -d terraform/

# Add to CI pipeline:
- name: Security scan
  run: |
    pip install checkov
    checkov -d . \
      --framework terraform \
      --output github_failed_only \
      --hard-fail-on HIGH
```

---

## PART 10 — COMPLETE HANDS-ON PROJECT

### Directory Structure for judicialsolutions.in

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── lambda/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dynamodb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   ├── dev/
│   │   ├── main.tf          ← calls modules
│   │   ├── variables.tf
│   │   ├── terraform.tfvars ← dev values
│   │   └── backend.tf
│   ├── staging/
│   │   └── ... (same structure)
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars ← prod values
│       └── backend.tf
│
└── global/
    ├── s3/                  ← state bucket (bootstrapped once)
    └── iam/                 ← global IAM roles
```

### Complete Workflow

```bash
# Day 1: Bootstrap state infrastructure
cd terraform/global/s3
terraform init
terraform apply  # creates S3 bucket + DynamoDB table

# Day 2: Deploy dev environment
cd terraform/environments/dev
terraform init   # initialises S3 backend
terraform plan   # see what will be created
terraform apply  # create dev infrastructure

# Feature development
# Edit module, run plan in dev
terraform plan -target=module.lambda

# Deploy to staging
cd ../staging
terraform init
terraform apply

# Deploy to prod (via CI/CD)
git push  # triggers GitHub Actions
# Plan shown on PR → approved → apply on merge

# Useful day-to-day commands
terraform state list         # what resources do I manage?
terraform output             # what are my endpoints?
terraform plan -refresh-only # has anything drifted?
```

---

## INTERVIEW QUESTIONS RAPID FIRE

**Q: What happens if you delete a resource from your Terraform config but don't run apply?**

```
Nothing happens to the real resource.
Terraform only makes changes when you run terraform apply.

If you delete from config and run plan:
  Plan shows: "- aws_instance.web will be destroyed"

If you delete from config and run apply:
  Real resource is destroyed

If you want to remove from Terraform management WITHOUT destroying:
  terraform state rm aws_instance.web
  Then delete from config
  Resource keeps running, Terraform forgets about it
```

---

**Q: What is the difference between terraform taint and terraform apply -replace?**

```
terraform taint (deprecated in Terraform 1.0):
  Marks resource for destruction and recreation on next apply
  terraform taint aws_instance.web

terraform apply -replace (current way):
  Same effect — force recreate specific resource
  terraform apply -replace="aws_instance.web"

When to use:
  Resource is broken/corrupted but Terraform thinks it's fine
  Need to rotate credentials by recreating instance
  Underlying cloud resource is unhealthy
```

---

**Q: How do you handle sensitive data in Terraform?**

```
1. Mark variables as sensitive:
   variable "db_password" {
     sensitive = true  # redacted from plan output
   }

2. Use AWS Secrets Manager:
   data "aws_secretsmanager_secret_version" "db" {
     secret_id = "prod/db/password"
   }

3. Environment variables (TF_VAR_):
   export TF_VAR_db_password="mysecret"
   # Never in code or tfvars files committed to git

4. State file contains sensitive values in plaintext:
   Always encrypt S3 backend
   Restrict access to state bucket (IAM + bucket policy)
   Enable S3 versioning for recovery

5. .gitignore:
   *.tfvars  # if contains secrets
   terraform.tfstate  # never commit state to git
   .terraform/  # local provider cache
```

---

**Q: Terraform plan shows "known after apply" for some values. What does this mean?**

```
Some resource attributes can't be known until the resource is created:
  - Instance ID → assigned by AWS on creation
  - Public IP → assigned on launch
  - ARN → generated on creation

"known after apply" = Terraform will fill this in after running apply

Problem: when other resources depend on "known after apply" values:
  resource "aws_instance" "web" { ... }
  resource "aws_eip_association" "web" {
    instance_id = aws_instance.web.id  ← known after apply
  }

Both must be created in the same apply
Terraform handles this automatically — just run apply

If you see this in outputs:
  output "instance_ip" {
    value = aws_instance.web.public_ip
  }
  # Shows "(known after apply)" in plan
  # Shows real value after apply
```

---

**Q: How do you manage multiple AWS accounts with Terraform?**

```hcl
# Multiple provider aliases
provider "aws" {
  region = "ap-south-1"
  alias  = "primary"
}

provider "aws" {
  region = "ap-south-1"
  alias  = "secondary"
  assume_role {
    role_arn = "arn:aws:iam::SECONDARY_ACCOUNT:role/TerraformRole"
  }
}

# Use specific provider for resource
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "primary-bucket"
}

resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "secondary-bucket"
}

# Cross-account module
module "staging" {
  source = "./modules/app"
  providers = {
    aws = aws.secondary  # module uses secondary account
  }
}
```

---

## QUICK REFERENCE

### File naming convention:
```
main.tf       ← primary resources
variables.tf  ← input variable declarations
outputs.tf    ← output values
locals.tf     ← local computed values
versions.tf   ← required_providers, required_version
backend.tf    ← backend configuration
data.tf       ← data sources (optional, can be in main.tf)
```

### Terraform state file structure:
```json
{
  "version": 4,
  "terraform_version": "1.7.0",
  "resources": [
    {
      "type": "aws_instance",
      "name": "web",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "attributes": {
            "id": "i-1234567890abcdef0",
            "ami": "ami-12345678",
            "instance_type": "t3.micro",
            "public_ip": "1.2.3.4"
          }
        }
      ]
    }
  ]
}
```

### Common error messages:
```
"Error: Error acquiring the state lock"
→ Another apply is running OR stale lock
→ Wait for other apply OR terraform force-unlock LOCK-ID

"Error: Provider produced inconsistent result after apply"
→ Provider bug or race condition
→ Try apply again

"Error: Resource already exists"
→ Resource exists in AWS but not in state
→ Use terraform import

"Error: Invalid count argument"
→ count value depends on resource not yet created
→ Use -target to create dependency first, then full apply

"Error: Cycle"
→ Circular dependency between resources
→ Use depends_on or restructure resources
```

### .gitignore for Terraform:
```
# Local state
*.tfstate
*.tfstate.backup

# Local .terraform directory
.terraform/
.terraform.lock.hcl  # commit this! ensures consistent provider versions

# Variables file with secrets
*.auto.tfvars
secrets.tfvars

# Plan files (contain sensitive data)
*.tfplan

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Crash log
crash.log

# .env files
.env
```
