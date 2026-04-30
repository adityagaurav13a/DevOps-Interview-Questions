# GitHub Actions Complete Deep Dive
## Fundamentals + Advanced + OIDC + Docker + K8s Deploy
### Theory → Workflow YAML → Interview Questions

---

## 📌 TABLE OF CONTENTS

| # | Section | Key Topics |
|---|---|---|
| 1 | [GitHub Actions Fundamentals](#part-5--github-actions-fundamentals) | Workflows, jobs, steps, runners, triggers |
| 2 | [GitHub Actions Advanced](#part-6--github-actions-advanced) | Matrix, reusable workflows, OIDC, caching |
| 3 | [Secrets Management](#part-7--secrets-management-in-cicd) | GitHub Secrets, Jenkins credentials, OIDC |
| 4 | [Docker in CI/CD](#part-8--docker-in-cicd) | Build, scan, push, multi-platform |
| 5 | [CI/CD for Kubernetes](#part-9--cicd-for-kubernetes) | EKS deploy, kubectl, Helm, ArgoCD |
| 6 | [Zero Downtime Deployments](#part-10--zero-downtime-deployments) | Rolling, Blue-Green, Canary |
| 7 | [CI/CD Best Practices](#part-11--cicd-best-practices) | Branching, environments, rollback, DORA |

---

## PART 5 — GITHUB ACTIONS FUNDAMENTALS

### Core Concepts

```
Workflow:    YAML file in .github/workflows/ — the CI/CD definition
Event:       what triggers the workflow (push, PR, schedule, manual)
Job:         group of steps that run on same runner (can run in parallel)
Step:        individual task within a job (action or shell command)
Runner:      machine that executes jobs (GitHub-hosted or self-hosted)
Action:      reusable unit of work (from GitHub Marketplace or your own)
Artifact:    files produced by workflow (test reports, binaries, images)
```

### Workflow Triggers

```yaml
on:
  # Push to specific branches
  push:
    branches:
      - main
      - 'release/*'         # wildcard matching
    paths:
      - 'src/**'            # only trigger if these paths changed
      - 'Dockerfile'
    paths-ignore:
      - '**.md'             # ignore markdown changes

  # Pull request events
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]

  # Manual trigger with inputs
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deploy environment'
        required: true
        type: choice
        options: [staging, production]
      version:
        description: 'Version to deploy'
        required: false
        type: string

  # Schedule (cron)
  schedule:
    - cron: '0 2 * * *'    # 2am UTC daily

  # Another workflow completes
  workflow_run:
    workflows: ['CI']
    types: [completed]
    branches: [main]

  # Repository dispatch (API trigger)
  repository_dispatch:
    types: [deploy-trigger]
```

### Jobs and Steps

```yaml
jobs:
  build:
    name: Build and Test
    runs-on: ubuntu-latest            # GitHub-hosted runner

    # Job-level environment variables
    env:
      NODE_ENV: test
      APP_NAME: judicial-api

    # Job outputs (pass to other jobs)
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
      version: ${{ steps.version.outputs.version }}

    steps:
      # Step: use pre-built action
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0              # full git history (for versioning)

      # Step: run shell command
      - name: Get version
        id: version                   # id allows referencing output
        run: |
          VERSION=$(cat VERSION)
          echo "version=${VERSION}" >> $GITHUB_OUTPUT
          echo "Building version: $VERSION"

      # Step: set environment variable for subsequent steps
      - name: Set image tag
        run: echo "IMAGE_TAG=${GITHUB_SHA::8}" >> $GITHUB_ENV

      # Step: conditional
      - name: Run only on main
        if: github.ref == 'refs/heads/main'
        run: echo "On main branch"

      # Step: run script file
      - name: Run integration tests
        run: ./scripts/integration-test.sh
        env:
          DB_HOST: localhost
          API_KEY: ${{ secrets.API_KEY }}

  test:
    name: Test
    runs-on: ubuntu-latest
    needs: []                         # no dependencies (runs in parallel with build)

    strategy:
      matrix:
        python-version: ['3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - run: pytest tests/

  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    needs: [build, test]              # wait for both build AND test to complete
    if: github.ref == 'refs/heads/main' && needs.build.result == 'success'

    environment:
      name: production               # GitHub environment (has protection rules)
      url: https://judicialsolutions.in

    steps:
      - run: echo "Deploying ${{ needs.build.outputs.image_tag }}"
```

### Contexts and Expressions

```yaml
# GitHub Contexts — data available in workflows
${{ github.sha }}              # full commit SHA
${{ github.sha[:8] }}          # first 8 chars (short SHA) — NOT valid, use:
${{ env.SHORT_SHA }}           # set this via: echo "SHORT_SHA=${GITHUB_SHA::8}" >> $GITHUB_ENV

${{ github.ref }}              # refs/heads/main
${{ github.ref_name }}         # main
${{ github.event_name }}       # push, pull_request, workflow_dispatch
${{ github.actor }}            # who triggered
${{ github.repository }}       # owner/repo-name
${{ github.run_number }}       # build number
${{ github.workspace }}        # /home/runner/work/repo/repo

${{ secrets.MY_SECRET }}       # encrypted secret
${{ vars.MY_VAR }}             # non-sensitive variable (GitHub Variables)
${{ env.MY_ENV_VAR }}          # environment variable set in job/step

${{ needs.build.outputs.image_tag }}  # output from another job
${{ steps.my-step.outputs.value }}    # output from another step

# Expressions
${{ github.ref == 'refs/heads/main' }}          # boolean
${{ contains(github.ref, 'release') }}          # string contains
${{ startsWith(github.ref, 'refs/tags/') }}     # string starts with
${{ needs.test.result == 'success' }}           # job result check
${{ failure() }}                                # current job failed
${{ always() }}                                 # always run (even on failure)
${{ cancelled() }}                              # workflow was cancelled
```

---

## PART 6 — GITHUB ACTIONS ADVANCED

### Matrix Builds

```yaml
# Test across multiple versions, platforms, or configurations
jobs:
  test:
    strategy:
      fail-fast: false           # don't cancel other matrix jobs if one fails
      matrix:
        os: [ubuntu-latest, macos-latest]
        python: ['3.10', '3.11', '3.12']
        include:
          # Add extra variables to specific combinations
          - python: '3.12'
            coverage: true
        exclude:
          # Skip specific combinations
          - os: macos-latest
            python: '3.10'

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - run: pytest tests/
      - name: Run coverage (only on Python 3.12)
        if: matrix.coverage == true
        run: pytest --cov=src tests/
```

### Reusable Workflows

```yaml
# .github/workflows/reusable-docker.yml — define once, call from many workflows
name: Reusable Docker Build

on:
  workflow_call:                 # makes this workflow callable
    inputs:
      app_name:
        required: true
        type: string
      ecr_registry:
        required: true
        type: string
      dockerfile:
        required: false
        type: string
        default: 'Dockerfile'
    secrets:
      aws_role_arn:
        required: true
    outputs:
      image_tag:
        description: "Built image tag"
        value: ${{ jobs.build.outputs.image_tag }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - id: meta
        run: echo "tags=${{ inputs.ecr_registry }}/${{ inputs.app_name }}:${GITHUB_SHA::8}" >> $GITHUB_OUTPUT
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          aws-region: ap-south-1
      - uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        run: |
          docker build -t ${{ steps.meta.outputs.tags }} -f ${{ inputs.dockerfile }} .
          docker push ${{ steps.meta.outputs.tags }}
```

```yaml
# .github/workflows/ci.yml — call the reusable workflow
name: CI

on:
  push:
    branches: [main]

jobs:
  build-api:
    uses: ./.github/workflows/reusable-docker.yml  # local reusable workflow
    with:
      app_name: judicial-api
      ecr_registry: ${{ vars.ECR_REGISTRY }}
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}

  build-frontend:
    uses: ./.github/workflows/reusable-docker.yml
    with:
      app_name: judicial-frontend
      ecr_registry: ${{ vars.ECR_REGISTRY }}
      dockerfile: frontend/Dockerfile
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

### Caching

```yaml
steps:
  # Cache pip packages
  - uses: actions/setup-python@v5
    with:
      python-version: '3.12'
      cache: 'pip'               # built-in pip caching (easiest)

  # Manual cache control
  - name: Cache dependencies
    uses: actions/cache@v4
    with:
      path: ~/.cache/pip
      key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
      restore-keys: |
        ${{ runner.os }}-pip-

  # Cache Docker layers
  - name: Build with cache
    uses: docker/build-push-action@v5
    with:
      cache-from: type=gha       # use GitHub Actions cache
      cache-to: type=gha,mode=max

  # Cache node_modules
  - name: Cache Node modules
    uses: actions/cache@v4
    with:
      path: ~/.npm
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: ${{ runner.os }}-node-
```

### OIDC — Keyless AWS Authentication

```yaml
# Why OIDC: no stored AWS credentials in GitHub Secrets
# GitHub gets JWT from its OIDC provider → exchanges with AWS STS → temp credentials

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write    # REQUIRED for OIDC
      contents: read

    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-role
          role-session-name: github-actions
          aws-region: ap-south-1
          # No access-key-id or secret-access-key needed!

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name judicial-prod --region ap-south-1
          kubectl set image deployment/judicial-api judicial-api=$IMAGE

# AWS IAM Trust Policy for the role:
# {
#   "Principal": {
#     "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
#   },
#   "Action": "sts:AssumeRoleWithWebIdentity",
#   "Condition": {
#     "StringLike": {
#       "token.actions.githubusercontent.com:sub":
#         "repo:adityagaurav13a/cloud_learning:*"
#     }
#   }
# }
```

---

## PART 7 — SECRETS MANAGEMENT IN CI/CD

### GitHub Secrets

```yaml
# Secret types:
# Repository secrets:    specific to one repo
# Organization secrets:  shared across repos in org
# Environment secrets:   specific to deployment environment (prod, staging)

# Access in workflow
steps:
  - name: Deploy
    env:
      API_KEY: ${{ secrets.API_KEY }}              # repository secret
      DB_PASS: ${{ secrets.PROD_DB_PASSWORD }}     # environment secret
    run: ./deploy.sh

# NEVER do this (leaks secret to logs):
- run: echo ${{ secrets.MY_SECRET }}    # WRONG — visible in logs
- run: echo ${MY_SECRET}               # RIGHT — env var, not expanded in logs

# GitHub automatically masks secrets in logs
# But only if you access via ${{ secrets.X }} or $ENV_VAR
# Direct substitution in string → NOT masked
```

### Jenkins Credentials

```groovy
// Types of credentials in Jenkins:
// Username+Password, Secret Text, SSH Key, Certificate, AWS Credentials

// Bind credential to environment variable
withCredentials([
    string(credentialsId: 'api-key', variable: 'API_KEY'),
    usernamePassword(credentialsId: 'docker-hub',
                     usernameVariable: 'DOCKER_USER',
                     passwordVariable: 'DOCKER_PASS'),
    sshUserPrivateKey(credentialsId: 'deploy-key',
                      keyFileVariable: 'SSH_KEY'),
    [$class: 'AmazonWebServicesCredentialsBinding',
     credentialsId: 'aws-credentials',
     accessKeyVariable: 'AWS_ACCESS_KEY_ID',
     secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
]) {
    sh '''
        echo ${API_KEY}          # Jenkins masks in logs
        docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}
        ssh -i ${SSH_KEY} deploy@server
        aws s3 ls
    '''
}

// Use credential in environment block
environment {
    AWS_CREDS = credentials('aws-credentials')  // sets AWS_CREDS_USR and AWS_CREDS_PSW
    API_KEY   = credentials('api-key-text')
}
```

### Secrets Best Practices

```
1. Never hardcode secrets in code or Jenkinsfile
   Bad:  AWS_KEY = "AKIAXXXXXXXXXXXXXXXX"
   Good: ${{ secrets.AWS_KEY }} or credentials('aws-key')

2. Never echo/print secrets
   Bad:  echo "Key is: ${API_KEY}"
   Good: Use secret-aware tools (they mask output)

3. Use OIDC instead of long-lived keys for AWS
   No keys to rotate, no keys to leak
   GitHub + AWS → temporary credentials

4. Rotate secrets regularly
   AWS: rotate access keys every 90 days
   DB passwords: rotate via Secrets Manager automatically

5. Least privilege for CI/CD credentials
   CI role needs: ECR push, EKS deploy, S3 sync
   NOT: AdministratorAccess

6. Separate credentials per environment
   staging-aws-role, prod-aws-role (different permissions)
   Prod requires manual approval + separate credentials

7. Audit secret access
   GitHub: audit log shows who accessed secrets
   AWS CloudTrail: logs every API call made by CI credentials

8. Environment-specific secrets in GitHub Environments
   production secrets: require reviewer approval before access
   staging secrets: auto-accessible

9. Use Vault for complex secret management
   Dynamic secrets (auto-expire), fine-grained policies
   Full audit trail per secret
```

---

## PART 8 — DOCKER IN CI/CD

### Complete Docker Build Pipeline

```yaml
# .github/workflows/docker.yml
name: Docker Build, Scan, Push

on:
  push:
    branches: [main]

env:
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT }}.dkr.ecr.ap-south-1.amazonaws.com
  IMAGE_NAME: judicial-api

jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      security-events: write      # for SARIF upload

    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}

    steps:
      - uses: actions/checkout@v4

      # Set up Docker Buildx (enables caching, multi-platform)
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # AWS OIDC auth
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-south-1

      # ECR login
      - name: Login to ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      # Generate image metadata and tags
      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=,suffix=,format=short   # git short SHA
            type=ref,event=branch                   # branch name
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      # Build image (don't push yet — scan first)
      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          load: true                          # load into local daemon for scanning

      # Scan for CVEs
      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'                      # fail on critical/high CVEs

      # Upload scan results to GitHub Security tab
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      # Push to ECR (only if scan passed)
      - name: Push to ECR
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true                    # supply chain security
          sbom: true                          # software bill of materials
```

### Multi-Platform Builds

```yaml
# Build for both x86 and ARM (Graviton EC2/EKS)
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3      # enables non-native platform builds

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build multi-platform image
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64   # build both architectures
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Docker Image Tagging Strategy

```
Use MULTIPLE tags:

1. Git SHA (immutable — exact code):
   judicial-api:abc1234f
   → Never changes → perfect for rollback
   → Use in K8s deployments

2. Branch name (mutable — latest of branch):
   judicial-api:main
   judicial-api:release-1.2

3. Semantic version (from git tag):
   judicial-api:1.2.3
   judicial-api:1.2
   judicial-api:1

4. latest (mutable — most recent main build):
   judicial-api:latest
   → Use for development/testing
   → NEVER use in production Kubernetes (non-deterministic)

5. cache (build cache layer):
   judicial-api:cache

CI/CD rule:
  Deploy to K8s with git SHA tag (deterministic)
  kubectl set image ... judicial-api:abc1234f
  Rollback = deploy previous SHA tag
```

---

## PART 9 — CI/CD FOR KUBERNETES

### Complete EKS Deployment Workflow

```yaml
# .github/workflows/deploy-eks.yml
name: Deploy to EKS

on:
  workflow_run:
    workflows: ['Docker Build, Scan, Push']
    types: [completed]
    branches: [main]

jobs:
  deploy-staging:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    environment: staging
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS (staging)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.STAGING_AWS_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig \
            --name judicial-staging \
            --region ap-south-1

      - name: Set image tag
        run: |
          SHORT_SHA="${{ github.event.workflow_run.head_sha }}"
          SHORT_SHA="${SHORT_SHA::8}"
          echo "IMAGE_TAG=${SHORT_SHA}" >> $GITHUB_ENV
          echo "IMAGE=${{ secrets.ECR_REGISTRY }}/judicial-api:${SHORT_SHA}" >> $GITHUB_ENV

      - name: Deploy to staging
        run: |
          kubectl set image deployment/judicial-api \
            judicial-api=${IMAGE} \
            -n staging

          # Wait for rollout
          kubectl rollout status deployment/judicial-api \
            -n staging \
            --timeout=5m

      - name: Smoke test staging
        run: |
          # Wait for load balancer to propagate
          sleep 15

          # Check health endpoint
          for i in $(seq 1 10); do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
              https://staging.judicialsolutions.in/health)
            if [ "$STATUS" == "200" ]; then
              echo "Staging is healthy!"
              exit 0
            fi
            echo "Attempt $i: Status $STATUS, waiting..."
            sleep 10
          done
          echo "Staging smoke test FAILED"
          exit 1

      - name: Rollback staging on failure
        if: failure()
        run: |
          kubectl rollout undo deployment/judicial-api -n staging
          echo "Rolled back staging to previous version"

  deploy-production:
    needs: [deploy-staging]
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://judicialsolutions.in
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS (production)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PROD_AWS_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name judicial-prod --region ap-south-1

      - name: Deploy to production (zero downtime)
        run: |
          kubectl set image deployment/judicial-api \
            judicial-api=${IMAGE} \
            -n production

          kubectl rollout status deployment/judicial-api \
            -n production \
            --timeout=10m

      - name: Production smoke test
        run: |
          sleep 20
          curl -f https://judicialsolutions.in/health
          curl -f https://api.judicialsolutions.in/health

      - name: Rollback on failure
        if: failure()
        run: |
          kubectl rollout undo deployment/judicial-api -n production
          echo "⚠️ PRODUCTION ROLLBACK EXECUTED"

      - name: Notify success
        if: success()
        run: |
          echo "✅ Production deployment successful: ${IMAGE}"
```

### Helm-Based Deployment

```yaml
# Deploy using Helm (recommended for complex apps)
- name: Setup Helm
  uses: azure/setup-helm@v4
  with:
    version: '3.14.0'

- name: Deploy with Helm
  run: |
    helm upgrade --install judicial-api ./helm/judicial-api \
      --namespace production \
      --create-namespace \
      --set image.repository=${{ env.ECR_REGISTRY }}/judicial-api \
      --set image.tag=${{ env.IMAGE_TAG }} \
      --set replicaCount=3 \
      --set ingress.host=judicialsolutions.in \
      --wait \
      --timeout 10m \
      --atomic                  # rollback automatically if deployment fails
      --history-max 5           # keep last 5 releases for rollback

# Helm --atomic = install/upgrade + wait + rollback on failure
# One flag gives you zero-downtime + auto-rollback
```

### ArgoCD GitOps Deployment

```yaml
# Instead of kubectl in CI, push new image tag to git
# ArgoCD watches git and deploys automatically

- name: Update image tag in git
  run: |
    # Update the image tag in Kubernetes manifest
    sed -i "s|image: .*judicial-api:.*|image: ${{ env.IMAGE }}|g" \
      k8s/production/deployment.yaml

    # Also update via yq (more reliable)
    yq e '.spec.template.spec.containers[0].image = "${{ env.IMAGE }}"' \
      -i k8s/production/deployment.yaml

    git config user.email "ci@judicialsolutions.in"
    git config user.name "GitHub Actions"
    git add k8s/production/deployment.yaml
    git commit -m "ci: update judicial-api image to ${{ env.IMAGE_TAG }}"
    git push

# ArgoCD detects the git change and deploys automatically
# This is the GitOps pattern — git is single source of truth
# CI builds image → updates git → ArgoCD deploys
```

---

## PART 10 — ZERO DOWNTIME DEPLOYMENTS

### Why Zero Downtime Matters

```
Downtime cost:
  E-commerce: $5,000-$50,000 per minute of downtime
  SaaS: customer trust, SLA breach, support tickets
  Legal platform: active court sessions, filings in progress

Zero downtime = users never see errors during deployment
Achieved by:
  Rolling update: replace pods one at a time
  Blue-green:     instant traffic switch between versions
  Canary:         gradual traffic shift

Your resume claim: "zero downtime across production clusters"
Make sure you can explain HOW in interview
```

### Rolling Update — Zero Downtime in Kubernetes

```yaml
# Deployment config for zero downtime
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0         # NEVER reduce below 3 running pods
      maxSurge: 1               # allow 4 pods temporarily during update

  # These settings are CRITICAL for zero downtime:
  minReadySeconds: 30           # pod must be ready 30s before next pod updated
  progressDeadlineSeconds: 600  # fail rollout after 10 minutes

  template:
    spec:
      # Graceful shutdown — give in-flight requests time to complete
      terminationGracePeriodSeconds: 60  # 60s before SIGKILL

      containers:
      - name: judicial-api
        image: judicial-api:1.2.3

        # READINESS probe — CRITICAL for zero downtime
        # Pod only gets traffic AFTER readiness passes
        # Ensures new pod is ready before old pod removed
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          successThreshold: 2       # must pass twice before ready
          failureThreshold: 3

        # LIVENESS probe — restart if pod hangs
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10

        # Lifecycle hooks — graceful shutdown
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]  # give load balancer time to stop sending traffic
```

### Zero Downtime Flow — Step by Step

```
Initial: 3 pods running (v1.0)
         [v1] [v1] [v1]  → 3/3 receiving traffic

Deploy v1.1 with maxUnavailable=0, maxSurge=1:

Step 1: Create new pod (v1.1)
  [v1] [v1] [v1] [v1.1-starting]
  Old: 3 receiving traffic
  New: NOT receiving traffic (readiness not passed yet)

Step 2: v1.1 pod passes readiness probe (30+ seconds)
  [v1] [v1] [v1] [v1.1-ready]
  Old: still 3 receiving traffic
  New: ADDED to service endpoints

Step 3: minReadySeconds passes (30s of stability)
  Now Kubernetes terminates one v1 pod

Step 4: v1 pod receives SIGTERM
  preStop hook: sleep 15s (load balancer updates, drains connections)
  App: finishes in-flight requests, stops accepting new ones
  After 15s: app exits

  [v1] [v1] [v1.1]  → 3/3 receiving traffic (seamless!)

Step 5: Repeat for remaining v1 pods

Final: [v1.1] [v1.1] [v1.1]
  Zero downtime — users never saw an error

Key insight: maxUnavailable=0 ensures we never drop below 3 ready pods
             Readiness probe ensures new pod is truly ready before old one leaves
```

### Blue-Green Zero Downtime

```yaml
# Two identical environments — switch instantly
# Blue: current production (v1)
# Green: new version (v2) — fully tested before switch

# Deploy green (v2) — not serving traffic yet
kubectl create deployment judicial-api-green \
  --image=judicial-api:v2 \
  --replicas=3

# Wait for green to be healthy
kubectl rollout status deployment/judicial-api-green

# Run smoke tests against green directly (not public)
kubectl port-forward deployment/judicial-api-green 8080:8080 &
curl http://localhost:8080/health
curl http://localhost:8080/api/cases

# Switch service selector → instant traffic switch (no downtime)
kubectl patch service judicial-api \
  -p '{"spec":{"selector":{"version":"green"}}}'

# All traffic now goes to green
# Blue still running — instant rollback if needed

# Monitor for 10 minutes
sleep 600

# If healthy: scale down blue
kubectl scale deployment judicial-api-blue --replicas=0

# If issues: instant rollback
kubectl patch service judicial-api \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Health Check Endpoint — What to Check

```python
# /health endpoint — what readiness probe calls
# Must return 200 when ready, non-200 when not ready

from fastapi import FastAPI, status
from fastapi.responses import JSONResponse
import boto3
import redis

app = FastAPI()

@app.get("/health")
async def health():
    """
    Readiness health check.
    Returns 200 only when all dependencies are healthy.
    Returns 503 when dependencies are down (removes from LB rotation).
    """
    checks = {}
    overall_healthy = True

    # Check database connectivity
    try:
        db.execute("SELECT 1")
        checks["database"] = "healthy"
    except Exception as e:
        checks["database"] = f"unhealthy: {str(e)}"
        overall_healthy = False

    # Check cache connectivity
    try:
        redis_client.ping()
        checks["cache"] = "healthy"
    except Exception as e:
        checks["cache"] = f"unhealthy: {str(e)}"
        overall_healthy = False

    status_code = status.HTTP_200_OK if overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE

    return JSONResponse(
        status_code=status_code,
        content={
            "status": "healthy" if overall_healthy else "unhealthy",
            "checks": checks,
            "version": "1.2.3"
        }
    )

@app.get("/ready")
async def ready():
    """Simple liveness check — is the process running?"""
    return {"status": "ok"}
```

---

## PART 11 — CI/CD BEST PRACTICES

### Branching Strategy

```
GitFlow (for versioned releases):
  main:     production code
  develop:  integration branch
  feature/: individual features
  release/: release preparation
  hotfix/:  urgent production fixes

  Pros: clear, handles multiple versions
  Cons: complex, slow (feature → develop → release → main)

Trunk-Based Development (for high-frequency deployment):
  main (trunk): always deployable
  feature/*:    short-lived (1-3 days max), merged frequently
  No long-lived branches

  Pros: simple, fast CI/CD, fewer merge conflicts
  Cons: requires feature flags for incomplete features

Your setup (from resume): likely GitFlow or simplified:
  feature → main → auto-deploy dev/staging → manual prod
  This is standard and correct for a 4-person team

Feature Flags (enables trunk-based):
  Deploy code but hide unfinished features
  FEATURE_NEW_UI=false → feature not visible
  Toggle in config → no deployment needed to enable
  Gradual rollout: 5% → 25% → 100%
```

### Environment Strategy

```
Environment    Branch         Deploy       Approval
─────────────────────────────────────────────────────
dev            any branch     auto         none
staging        main           auto         none
production     main           auto/manual  required

Rules:
  Same Docker image across all environments (no rebuild per env)
  Config injected at runtime (env vars, ConfigMaps)
  prod uses environment protection rules (GitHub Environments)
  prod deployment requires 2 approvers from devops-leads

Your resume matches this: dev → staging → production (3 environments)
```

### Rollback Strategy

```
Layer 1: Kubernetes rollback (fastest, seconds)
  kubectl rollout undo deployment/judicial-api
  Previous ReplicaSet exists → instant, no image pull
  Use for: bad deployment, bug introduced

Layer 2: Helm rollback (if using Helm)
  helm rollback judicial-api 3   # rollback to revision 3
  Same speed as kubectl rollout undo

Layer 3: CI/CD re-deploy previous image (1-2 minutes)
  Trigger pipeline with specific image tag
  GitHub: workflow_dispatch with version input
  Jenkins: "Replay" previous build

Layer 4: Git revert + redeploy (3-5 minutes)
  git revert HEAD → push → pipeline triggers → redeploy
  Best for: rolling back code changes (not just image)
  Creates audit trail in git history

Auto-rollback on failure:
  kubectl rollout status --timeout=5m || kubectl rollout undo
  helm upgrade --atomic          # auto-rollback on failure
  In CI: smoke test fails → kubectl rollout undo → exit 1

Keep: last 5 Docker image versions in ECR (delete older)
Keep: Kubernetes rollout history (default 10, set --revision-history-limit=5)
```

### Pipeline Optimization

```
Problem: CI/CD taking too long → developers wait → slow feedback loop

Solutions:

1. Parallelize independent jobs
   # BAD: sequential
   build → lint → test → scan → push
   
   # GOOD: parallel
   build ──┬── lint      ─┐
           ├── unit test  ─┤── push (when all pass)
           └── scan       ─┘

2. Cache aggressively
   Python: cache pip downloads (requirements.txt hash)
   Docker: use BuildKit cache, GitHub Actions cache
   Node:   cache node_modules

3. Only run what changed
   paths: filter in GitHub Actions triggers
   If only docs changed → skip docker build
   If only frontend changed → skip API tests

4. Use lightweight base images in CI
   python:3.12-slim not python:3.12 (saves 800MB download)

5. Fail fast
   Quick checks first: lint, format (seconds)
   Slow checks after: integration tests (minutes)
   If lint fails → don't run integration tests

6. Self-hosted runners for heavy workloads
   GitHub-hosted: 2 vCPU, 7GB RAM (limited)
   Self-hosted EC2: 8 vCPU, 32GB RAM (much faster Docker builds)

Your improvement: 45 min → 8 min
  Likely achieved by: parallelization + caching + lighter images
```

---

## COMPLETE PIPELINE EXAMPLES

### Complete App CI/CD — Docker + K8s + Zero Downtime

```yaml
# .github/workflows/complete-cicd.yml
name: Complete CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true        # cancel in-progress runs when new push

env:
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT }}.dkr.ecr.ap-south-1.amazonaws.com
  APP_NAME: judicial-api
  AWS_REGION: ap-south-1

jobs:
  # ─── QUALITY CHECKS (parallel) ──────────────────────────────────
  lint:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      - run: pip install flake8 black isort -q
      - run: flake8 src/ --max-line-length=100
      - run: black --check src/
      - run: isort --check-only src/

  test:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      - run: pip install -r requirements.txt pytest pytest-cov -q
      - name: Run tests
        run: |
          pytest tests/unit/ \
            --cov=src \
            --cov-report=xml \
            --cov-fail-under=80 \
            --junitxml=junit.xml \
            -v
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: |
            junit.xml
            coverage.xml

  # ─── BUILD & SCAN ────────────────────────────────────────────────
  build:
    name: Build & Scan Docker Image
    runs-on: ubuntu-latest
    needs: [lint, test]
    permissions:
      id-token: write
      contents: read
      security-events: write

    outputs:
      image_full: ${{ steps.image.outputs.full }}
      image_tag: ${{ steps.image.outputs.tag }}

    steps:
      - uses: actions/checkout@v4

      - id: image
        run: |
          TAG="${GITHUB_SHA::8}"
          FULL="${{ env.ECR_REGISTRY }}/${{ env.APP_NAME }}:${TAG}"
          echo "tag=${TAG}" >> $GITHUB_OUTPUT
          echo "full=${FULL}" >> $GITHUB_OUTPUT

      - uses: docker/setup-buildx-action@v3

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - uses: aws-actions/amazon-ecr-login@v2

      - name: Build image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          load: true
          tags: ${{ steps.image.outputs.full }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.image.outputs.full }}
          format: sarif
          output: trivy.sarif
          severity: CRITICAL,HIGH
          exit-code: 1

      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy.sarif

      - name: Push to ECR
        if: github.ref == 'refs/heads/main'
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ steps.image.outputs.full }}
            ${{ env.ECR_REGISTRY }}/${{ env.APP_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ─── DEPLOY STAGING ──────────────────────────────────────────────
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [build]
    if: github.ref == 'refs/heads/main'
    environment:
      name: staging
      url: https://staging.judicialsolutions.in
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.STAGING_AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to staging EKS
        run: |
          aws eks update-kubeconfig --name judicial-staging --region ${{ env.AWS_REGION }}

          # Rolling update — zero downtime
          kubectl set image deployment/${{ env.APP_NAME }} \
            ${{ env.APP_NAME }}=${{ needs.build.outputs.image_full }} \
            -n staging

          # Wait for rollout (5 min timeout)
          kubectl rollout status deployment/${{ env.APP_NAME }} \
            -n staging --timeout=5m || {
              kubectl rollout undo deployment/${{ env.APP_NAME }} -n staging
              echo "Rollout failed — rolled back"
              exit 1
            }

      - name: Smoke test staging
        run: |
          sleep 20
          for i in $(seq 1 5); do
            if curl -sf https://staging.judicialsolutions.in/health; then
              echo "✅ Staging healthy"
              exit 0
            fi
            echo "Attempt $i failed, retrying..."
            sleep 10
          done
          kubectl rollout undo deployment/${{ env.APP_NAME }} -n staging
          echo "❌ Smoke tests failed — rolled back"
          exit 1

  # ─── DEPLOY PRODUCTION ───────────────────────────────────────────
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [deploy-staging]
    environment:
      name: production             # requires manual approval in GitHub
      url: https://judicialsolutions.in
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PROD_AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to production EKS (zero downtime)
        run: |
          aws eks update-kubeconfig --name judicial-prod --region ${{ env.AWS_REGION }}

          # Zero downtime rolling update
          kubectl set image deployment/${{ env.APP_NAME }} \
            ${{ env.APP_NAME }}=${{ needs.build.outputs.image_full }} \
            -n production

          kubectl rollout status deployment/${{ env.APP_NAME }} \
            -n production --timeout=10m || {
              echo "⚠️ Production rollout failed — rolling back!"
              kubectl rollout undo deployment/${{ env.APP_NAME }} -n production
              exit 1
            }

      - name: Production smoke tests
        run: |
          sleep 30
          curl -f https://judicialsolutions.in/health
          curl -f https://api.judicialsolutions.in/health
          echo "✅ Production deployment verified"

      - name: Tag release in git
        if: success()
        run: |
          git tag "release-${{ needs.build.outputs.image_tag }}"
          git push origin "release-${{ needs.build.outputs.image_tag }}"
```

---

## INTERVIEW QUESTIONS

**Q: How did you reduce deployment time from 45 to 8 minutes?**

```
"We analysed where time was being spent in the pipeline:
  - Package download: 12 min → cached pip/npm = 1 min
  - Docker build:    20 min → BuildKit cache = 3 min
  - Sequential jobs: 8 min  → parallel = 2 min
  - Deploy wait:     5 min  → optimised health checks = 2 min

Specific changes:
1. Dependency caching: hash requirements.txt, restore cache on match
   12 min pip install → 30 seconds (cache hit)

2. Docker layer caching: BuildKit with GitHub Actions cache
   20 min build → 3 min (only rebuilds changed layers)
   Moved COPY . . to last layer (code changes don't bust dep cache)

3. Parallelised jobs: lint + unit tests + security scan all parallel
   Previously sequential: 15 min → parallel: 5 min

4. Removed redundant steps: duplicate builds, unnecessary waits

Result: 45 → 8 minutes lead time, 60% fewer failures
(failures dropped because parallel scan caught bugs before deploy)"
```

**Q: What is OIDC and why is it better than storing AWS access keys in CI?**

```
Access keys (old way):
  Store AWS_ACCESS_KEY_ID + SECRET in GitHub Secrets
  Long-lived credentials — never expire unless rotated
  If GitHub is breached → permanent AWS access
  Must manually rotate every 90 days
  Often forgotten and left for years

OIDC (new way):
  GitHub → requests short-lived JWT from GitHub OIDC provider
  JWT → exchanged with AWS STS → 1-hour temporary credentials
  No stored credentials anywhere
  Credentials auto-expire after job completes
  GitHub breach → attacker gets JWT that expires in minutes

Setup:
  AWS: create OIDC provider for token.actions.githubusercontent.com
  AWS: create IAM role with trust policy allowing GitHub repo
  GitHub Actions: uses: aws-actions/configure-aws-credentials
                  with: role-to-assume: arn:aws:iam::...:role/github-role
  
  No secrets to manage, rotate, or accidentally commit.
  This is the modern best practice — what I use for judicialsolutions.in"
```

**Q: How do you achieve zero downtime deployment?**

```
Zero downtime = users never experience errors during deployment

In Kubernetes (my primary approach):
  RollingUpdate strategy with:
    maxUnavailable: 0     → never drop below desired pod count
    maxSurge: 1           → temporarily add one extra pod
  
  Readiness probe:        new pod only gets traffic after health check passes
  preStop hook:           15s sleep before termination (LB updates)
  terminationGracePeriod: 60s to finish in-flight requests

The flow:
  1. New pod created, passes readiness probe (30s)
  2. Added to service endpoints → starts receiving traffic
  3. Old pod receives SIGTERM → preStop hook (15s)
  4. LB stops sending new connections to old pod
  5. Old pod finishes in-flight requests → exits
  6. 0 users see errors throughout

Plus: smoke test after rollout, auto-rollback on failure:
  kubectl rollout status --timeout=5m || kubectl rollout undo

In CI/CD (GitHub Actions):
  deploy-staging → smoke test → (manual approval) → deploy-prod → smoke test
  If smoke test fails: auto-rollback + pipeline failure notification
```

**Q: What's the difference between Declarative and Scripted Jenkins pipelines?**

```
Declarative:
  Fixed structure with predefined sections (pipeline, stages, steps)
  Validates syntax before running
  More readable — team members understand it easily
  Built-in post section, options, triggers
  Limited to what the DSL supports (sometimes not enough)
  
  pipeline {
    agent any
    stages {
      stage('Build') { steps { sh 'make' } }
    }
  }

Scripted:
  Full Groovy code — anything is possible
  More flexible and powerful
  Harder to read, steeper learning curve
  No built-in structure — you define everything
  Error appears at runtime (not validated beforehand)
  
  node {
    stage('Build') { sh 'make' }
  }

Choose:
  Declarative for: standard CI/CD pipelines (90% of cases)
  Scripted for: complex dynamic pipeline logic, advanced Groovy needed

  My pipelines: Declarative with script blocks for complex logic
  Shared libraries: Groovy classes/functions called from Declarative
```

**Q: How do you handle a failed production deployment?**

```
Automated layer (happens in seconds):
  kubectl rollout status --timeout=5m
  If timeout: kubectl rollout undo deployment/judicial-api
  Smoke test: curl -f https://api.judicialsolutions.in/health
  If fails: kubectl rollout undo + pipeline exit 1 + Slack alert

Manual layer (if automated rollback fails):
  kubectl rollout history deployment/judicial-api
  kubectl rollout undo deployment/judicial-api --to-revision=5
  Verify: kubectl get pods -n production (all pods running new version)

Root cause (after service restored):
  Check logs: kubectl logs -l app=judicial-api --tail=100
  Check events: kubectl get events -n production --sort-by=lastTimestamp
  Check metrics: CloudWatch/Grafana for error rate, latency

Post-mortem:
  What changed? (git diff between old and new SHA)
  Why didn't tests catch it? (add test coverage)
  How to detect faster? (improve alerting thresholds)
  How to prevent? (add gate in pipeline)

My setup:
  Each production deploy creates git tag: release-abc1234
  Rollback = deploy tag from 2 releases ago
  Full audit trail in both git and Slack
```

---

## QUICK REFERENCE

### CI/CD Commands Cheatsheet

```bash
# ─── GITHUB ACTIONS ─────────────────────────────────────────────
gh workflow run deploy.yml              # trigger workflow
gh workflow list                        # list workflows
gh run list                            # list recent runs
gh run view RUN_ID                     # view run details
gh run watch                           # watch current run

# ─── JENKINS ────────────────────────────────────────────────────
# Trigger build via API
curl -X POST https://jenkins/job/my-job/build \
  --user user:api-token

# Get build status
curl https://jenkins/job/my-job/lastBuild/api/json?pretty=true

# ─── KUBERNETES DEPLOY ──────────────────────────────────────────
kubectl set image deployment/app app=image:tag -n production
kubectl rollout status deployment/app -n production --timeout=5m
kubectl rollout history deployment/app -n production
kubectl rollout undo deployment/app -n production
kubectl rollout undo deployment/app --to-revision=3 -n production

# ─── HELM ───────────────────────────────────────────────────────
helm upgrade --install app ./chart --atomic --timeout 10m
helm rollback app 3                    # rollback to revision 3
helm history app                       # deployment history
helm diff upgrade app ./chart          # show what would change

# ─── ECR ────────────────────────────────────────────────────────
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com

aws ecr describe-images --repository-name judicial-api \
  --query 'imageDetails | sort_by(@, &imagePushedAt) | [-5:]'
```

### DORA Metrics Targets

```
Metric                  Elite           High            Medium         Low
─────────────────────────────────────────────────────────────────────────
Deployment frequency    Multiple/day    Daily/weekly    Weekly/monthly < Monthly
Lead time               < 1 hour        < 1 day         < 1 week       > 1 month
MTTR                    < 1 hour        < 1 day         < 1 week       > 1 week
Change failure rate     0-15%           16-30%          16-30%         > 30%

Your numbers:
  Lead time: 45 min → 8 min  ✅ Elite
  Failure rate: -60%          ✅ Likely Elite/High
```

### Zero Downtime Checklist

```
Kubernetes deployment:
□ maxUnavailable: 0 (never go below desired count)
□ maxSurge: 1 (allow temporary extra pod)
□ readinessProbe configured and tested
□ livenessProbe configured
□ terminationGracePeriodSeconds: 60
□ preStop hook: sleep 15 (LB drain time)
□ minReadySeconds: 30 (stability before next pod)
□ PodDisruptionBudget: minAvailable >= 2

CI/CD pipeline:
□ Health check URL available (/health returns 200)
□ Smoke test after each environment deploy
□ Auto-rollback on smoke test failure
□ rollout status --timeout check in pipeline
□ Slack/email notification on failure
□ Git tag on successful production deploy
```
