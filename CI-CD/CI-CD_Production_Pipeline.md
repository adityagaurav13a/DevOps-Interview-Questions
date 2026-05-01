# End-to-End Production Grade CI/CD Pipeline

> **Stack:** GitHub Actions · AWS ECR · Amazon EKS · OIDC · kubectl
> 
> **Stages:** Build → Test → Push → Deploy → Rollback (on failure)

-----

## How the Jobs Connect

```
Push to main
     │
     ▼
  BUILD       →  builds Docker image, tags with commit SHA
     │
     ▼
  TEST        →  unit tests + integration tests + Trivy security scan
     │  (pipeline stops here if anything fails)
     ▼
  PUSH        →  authenticates via OIDC, pushes image to ECR
     │
     ▼
  DEPLOY      →  kubectl applies the manifest to EKS
     │
     ├── success → done ✅
     │
     └── failure → ROLLBACK triggers automatically ⚠️
```

-----

## Folder Structure Expected

```
your-repo/
├── .github/
│   └── workflows/
│       └── cicd.yaml          ← this pipeline file
├── k8s/
│   └── deployment.yaml        ← kubernetes manifest (template)
├── Dockerfile
└── docker-compose.test.yaml   ← used for integration tests
```

-----

## Kubernetes Manifest Template

> Save this as `k8s/deployment.yaml`.
> `${IMAGE_TAG}` is injected by the pipeline at deploy time using `envsubst`.

```yaml
# k8s/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3                          # number of pods to run
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate                # replace pods gradually, not all at once
    rollingUpdate:
      maxSurge: 1                      # allow 1 extra pod during update
      maxUnavailable: 0                # never bring a pod down before new one is ready
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}   # injected by CI
          ports:
            - containerPort: 3000
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:              # pod only receives traffic when this passes
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:               # restart pod if this fails
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 3000
  type: ClusterIP
```

-----

## The Pipeline

> Save this as `.github/workflows/cicd.yaml`

```yaml
name: Production CI/CD Pipeline

# ─────────────────────────────────────────────
# TRIGGER
# Runs only when code is pushed to main branch
# ─────────────────────────────────────────────
on:
  push:
    branches:
      - main

# ─────────────────────────────────────────────
# GLOBAL VARIABLES
# Change these to match your AWS setup
# ─────────────────────────────────────────────
env:
  AWS_REGION: ap-south-1
  ECR_REGISTRY: 123456789.dkr.ecr.ap-south-1.amazonaws.com
  ECR_REPOSITORY: myapp
  EKS_CLUSTER_NAME: my-production-cluster
  NAMESPACE: production

# ─────────────────────────────────────────────
# PERMISSIONS
# Required for OIDC to work with AWS
# ─────────────────────────────────────────────
permissions:
  id-token: write
  contents: read

# =============================================
# JOBS
# =============================================
jobs:

  # -------------------------------------------
  # JOB 1: BUILD
  # Builds Docker image and saves it as artifact
  # so the next job doesn't rebuild from scratch
  # -------------------------------------------
  build:
    name: Build Docker Image
    runs-on: ubuntu-latest

    outputs:
      image_tag: ${{ steps.set_tag.outputs.image_tag }}

    steps:

      - name: Checkout Code
        uses: actions/checkout@v4

      # Tag image with first 7 chars of commit SHA
      # Example: a3f92bc
      - name: Set Image Tag
        id: set_tag
        run: |
          echo "image_tag=${GITHUB_SHA::7}" >> $GITHUB_OUTPUT
          echo "Image tag → ${GITHUB_SHA::7}"

      - name: Build Docker Image
        run: |
          docker build \
            -t ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${GITHUB_SHA::7} \
            -t ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:latest \
            .

      # Save image as a file to share between jobs
      - name: Save Image as Artifact
        run: |
          docker save \
            ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${GITHUB_SHA::7} \
            -o myapp-image.tar

      - name: Upload Image Artifact
        uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: myapp-image.tar
          retention-days: 1


  # -------------------------------------------
  # JOB 2: TEST
  # Runs unit, integration, and security tests.
  # If ANY test fails → pipeline stops here.
  # Nothing gets pushed to ECR.
  # -------------------------------------------
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: build

    steps:

      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Download Image Artifact
        uses: actions/download-artifact@v4
        with:
          name: docker-image

      - name: Load Docker Image
        run: docker load -i myapp-image.tar

      # Replace "npm test" with your test command
      # Python → pytest | Java → mvn test | Go → go test ./...
      - name: Run Unit Tests
        run: |
          docker run --rm \
            ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ needs.build.outputs.image_tag }} \
            npm test

      # Spins up app + dependencies (e.g. database) together
      # and runs tests against the real stack
      - name: Run Integration Tests
        run: |
          docker compose -f docker-compose.test.yaml up \
            --abort-on-container-exit \
            --exit-code-from app

      # Scans image for known CVEs
      # CRITICAL or HIGH severity = pipeline fails
      - name: Security Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ needs.build.outputs.image_tag }}
          format: table
          exit-code: 1
          severity: CRITICAL,HIGH


  # -------------------------------------------
  # JOB 3: PUSH TO ECR
  # Authenticates with AWS via OIDC (no static keys)
  # and pushes the image to ECR
  # -------------------------------------------
  push:
    name: Push Image to ECR
    runs-on: ubuntu-latest
    needs: test

    steps:

      - name: Download Image Artifact
        uses: actions/download-artifact@v4
        with:
          name: docker-image

      - name: Load Docker Image
        run: docker load -i myapp-image.tar

      # OIDC: GitHub gets a JWT → AWS STS validates it
      # → issues temporary credentials (no long-lived keys)
      - name: Configure AWS Credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-ecr-role
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: GitHubActions-Push-${{ github.run_id }}

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Push Image to ECR
        run: |
          docker push ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ needs.build.outputs.image_tag }}
          docker push ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:latest
          echo "✅ Pushed → ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ needs.build.outputs.image_tag }}"


  # -------------------------------------------
  # JOB 4: DEPLOY TO EKS
  # Uses envsubst to inject image tag into the
  # manifest, then applies it with kubectl.
  # RollingUpdate strategy ensures zero downtime.
  # -------------------------------------------
  deploy:
    name: Deploy to EKS
    runs-on: ubuntu-latest
    needs: [build, push]

    steps:

      - name: Checkout Code
        uses: actions/checkout@v4

      # Different role from ECR push
      # This role needs eks:DescribeCluster permission
      - name: Configure AWS Credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-eks-role
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: GitHubActions-Deploy-${{ github.run_id }}

      # Updates kubeconfig so kubectl can talk to your cluster
      - name: Update kubeconfig for EKS
        run: |
          aws eks update-kubeconfig \
            --region ${{ env.AWS_REGION }} \
            --name ${{ env.EKS_CLUSTER_NAME }}

      # envsubst replaces ${IMAGE_TAG} in deployment.yaml
      # with the actual commit SHA before applying
      - name: Inject Image Tag into Manifest
        env:
          IMAGE_TAG: ${{ needs.build.outputs.image_tag }}
        run: |
          envsubst < k8s/deployment.yaml > k8s/deployment-final.yaml
          echo "--- Final manifest ---"
          cat k8s/deployment-final.yaml

      - name: Apply Manifest to EKS
        run: |
          kubectl apply -f k8s/deployment-final.yaml

      # Wait until rollout completes or fails (timeout: 5 min)
      # If pods don't become healthy → this step fails
      # → triggers the rollback job below
      - name: Wait for Rollout to Complete
        run: |
          kubectl rollout status deployment/myapp \
            -n ${{ env.NAMESPACE }} \
            --timeout=5m

      - name: Verify Running Pods
        run: |
          kubectl get pods -n ${{ env.NAMESPACE }}
          echo "✅ Deployment complete → image: ${{ needs.build.outputs.image_tag }}"


  # -------------------------------------------
  # JOB 5: ROLLBACK
  # Only runs if the deploy job fails.
  # kubectl rollout undo reverts to the previous
  # ReplicaSet that was healthy and running.
  # -------------------------------------------
  rollback:
    name: Rollback on Failure
    runs-on: ubuntu-latest
    needs: deploy
    if: failure()     # ← ONLY triggers when deploy job fails

    steps:

      - name: Configure AWS Credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-eks-role
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: GitHubActions-Rollback-${{ github.run_id }}

      - name: Update kubeconfig for EKS
        run: |
          aws eks update-kubeconfig \
            --region ${{ env.AWS_REGION }} \
            --name ${{ env.EKS_CLUSTER_NAME }}

      # kubectl rollout undo reverts to the previous
      # deployment revision automatically
      - name: Rollback Deployment
        run: |
          echo "⚠️ Deploy failed. Rolling back..."
          kubectl rollout undo deployment/myapp \
            -n ${{ env.NAMESPACE }}

      - name: Wait for Rollback to Complete
        run: |
          kubectl rollout status deployment/myapp \
            -n ${{ env.NAMESPACE }} \
            --timeout=3m

      - name: Confirm Pod Health After Rollback
        run: |
          kubectl get pods -n ${{ env.NAMESPACE }}
          echo "✅ Rollback complete"

      # Notify your team — swap with Slack/PagerDuty as needed
      - name: Notify Team
        run: |
          echo "🚨 ROLLBACK triggered"
          echo "Failed commit : ${{ github.sha }}"
          echo "Triggered by  : ${{ github.actor }}"
          echo "Run ID        : ${{ github.run_id }}"
          # Uncomment for Slack:
          # curl -X POST -H 'Content-type: application/json' \
          #   --data '{"text":"🚨 Rollback on myapp. Commit: ${{ github.sha }}"}' \
          #   ${{ secrets.SLACK_WEBHOOK_URL }}
```

-----

## What Replaces Helm Here

|Helm (removed)          |kubectl equivalent used           |
|------------------------|----------------------------------|
|`helm upgrade --install`|`kubectl apply -f`                |
|`--set image.tag=xyz`   |`envsubst` injects tag into YAML  |
|`helm rollback`         |`kubectl rollout undo`            |
|`--atomic --wait`       |`kubectl rollout status --timeout`|

-----

## IAM Roles You Need

### Role 1 — `github-actions-ecr-role`

Used in the **Push** job. Needs these permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload"
  ],
  "Resource": "*"
}
```

### Role 2 — `github-actions-eks-role`

Used in the **Deploy** and **Rollback** jobs. Needs:

```json
{
  "Effect": "Allow",
  "Action": [
    "eks:DescribeCluster"
  ],
  "Resource": "arn:aws:eks:ap-south-1:123456789:cluster/my-production-cluster"
}
```

> **Note:** EKS access is also controlled by the `aws-auth` ConfigMap inside the cluster.
> Make sure your IAM role is mapped to a Kubernetes group with deploy permissions.

-----

## Trust Policy for Both Roles (OIDC)

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:ref:refs/heads/main"
    }
  }
}
```

-----

## Key Concepts at a Glance

|Concept                 |What it does                                              |
|------------------------|----------------------------------------------------------|
|`${GITHUB_SHA::7}`      |Short commit SHA used as image tag — unique per build     |
|`envsubst`              |Replaces `${VARIABLE}` placeholders in YAML at deploy time|
|`RollingUpdate`         |Replaces pods gradually — zero downtime                   |
|`readinessProbe`        |Pod only gets traffic when app is healthy                 |
|`kubectl rollout status`|Waits and confirms rollout success or failure             |
|`kubectl rollout undo`  |Reverts to previous ReplicaSet instantly                  |
|`if: failure()`         |Rollback job only runs when deploy fails                  |
|Two IAM roles           |Least privilege — ECR role ≠ EKS role                     |