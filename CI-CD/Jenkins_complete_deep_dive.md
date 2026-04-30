# Jenkins Complete Deep Dive
## Architecture + Pipeline as Code + Shared Libraries + Agents
### Theory → Jenkinsfile → Interview Questions

---

## 📌 TABLE OF CONTENTS

| # | Section | Key Topics |
|---|---|---|
| 1 | [CI/CD Fundamentals](#part-1--cicd-fundamentals) | CI vs CD, DORA metrics, pipeline stages |
| 2 | [Jenkins Architecture](#part-2--jenkins-architecture) | Master/agent, executors, plugins |
| 3 | [Jenkins Pipeline as Code](#part-3--jenkins-pipeline-as-code) | Declarative vs Scripted, full Jenkinsfile |
| 4 | [Jenkins Shared Libraries](#part-4--jenkins-shared-libraries) | Reusable pipeline code, vars, structure |

---

## Jenkins + GitHub Actions + Docker + Kubernetes + Zero Downtime
### Theory → Pipeline Code → Interview Questions

---

## README

**Total sections:** 11
**Your real experience:** Jenkins + GitHub Actions, 45→8 min, 3 environments, EKS, Docker
**Target level:** Mid-level to Senior DevOps/Cloud Engineer

### Priority sections:
| Section | Why it matters |
|---|---|
| Part 1 — Fundamentals | DORA metrics — senior-level signal |
| Part 3 — Jenkins Declarative | Pipeline as code — your real work |
| Part 5 — GitHub Actions | deploy.yaml for judicialsolutions.in |
| Part 7 — Secrets | Never hardcode credentials |
| Part 9 — K8s Deploy | EKS + rolling + zero downtime |

### Power phrases:
- *"CI/CD reduced our deployment time from 45 to 8 minutes and cut release failures by 60%"*
- *"I use pipeline as code — Jenkinsfile and GitHub Actions YAML committed to git"*
- *"Zero downtime via rolling updates — maxUnavailable=1, maxSurge=1, with smoke tests"*
- *"OIDC eliminates stored AWS credentials in CI — GitHub exchanges token with AWS directly"*
- *"DORA metrics: deployment frequency, lead time, MTTR, change failure rate"*

---

## 📌 TABLE OF CONTENTS

| # | Section | Key Topics |
|---|---|---|
| 1 | [CI/CD Fundamentals](#part-1--cicd-fundamentals) | CI vs CD vs CD, DORA metrics, pipeline stages |
| 2 | [Jenkins Architecture](#part-2--jenkins-architecture) | Master/agent, executors, plugins, security |
| 3 | [Jenkins Pipeline as Code](#part-3--jenkins-pipeline-as-code) | Declarative vs Scripted, Jenkinsfile, stages |
| 4 | [Jenkins Shared Libraries](#part-4--jenkins-shared-libraries) | Reusable pipeline code, vars, resources |
| 5 | [GitHub Actions Fundamentals](#part-5--github-actions-fundamentals) | Workflows, jobs, steps, runners, triggers |
| 6 | [GitHub Actions Advanced](#part-6--github-actions-advanced) | Matrix, reusable workflows, OIDC, caching |
| 7 | [Secrets Management in CI/CD](#part-7--secrets-management-in-cicd) | GitHub Secrets, Jenkins credentials, OIDC |
| 8 | [Docker in CI/CD](#part-8--docker-in-cicd) | Build, scan, push, cache, multi-platform |
| 9 | [CI/CD for Kubernetes](#part-9--cicd-for-kubernetes) | EKS deploy, kubectl, Helm, ArgoCD, zero downtime |
| 10 | [Zero Downtime Deployments](#part-10--zero-downtime-deployments) | Rolling, blue-green, canary, health checks |
| 11 | [CI/CD Best Practices](#part-11--cicd-best-practices) | Branching, environments, rollback, DORA |
| — | [Complete Pipeline Examples](#complete-pipeline-examples) | Full real-world pipelines end-to-end |
| — | [Interview Questions](#interview-questions) | 20 Q&A — basic to senior |

---

## PART 1 — CI/CD FUNDAMENTALS

### CI vs CD vs CD

```
CI (Continuous Integration):
  Developers merge code frequently (multiple times/day)
  Each merge triggers: automated build + automated tests
  Goal: detect integration problems early
  Output: verified, tested build artifact

CD (Continuous Delivery):
  Every successful CI build is potentially releasable
  Deployment to production is MANUAL (one-click)
  Goal: always have a deployable artifact
  Human decides WHEN to release (business decision)

CD (Continuous Deployment):
  Every successful CI build automatically deploys to production
  No human approval — fully automated end-to-end
  Goal: maximum deployment frequency
  Requires: excellent test coverage, feature flags, monitoring

Your resume maps to:
  CI:  build + test + Docker image creation → automatic on every push
  CD:  auto-deploy to dev/staging → manual approval for production
  = Continuous Delivery (not full Continuous Deployment)
```

### Pipeline Stages — Standard Flow

```
Code Push
    │
    ▼
┌─────────────┐
│    BUILD    │  Compile, package, build Docker image
└──────┬──────┘
       │
    ▼
┌─────────────┐
│    TEST     │  Unit tests, integration tests, coverage check
└──────┬──────┘
       │
    ▼
┌─────────────┐
│    SCAN     │  SAST (code), dependency CVE scan, Docker image scan
└──────┬──────┘
       │
    ▼
┌─────────────┐
│   PUBLISH   │  Push Docker image to ECR/Docker Hub, tag with git SHA
└──────┬──────┘
       │
    ▼
┌─────────────┐
│  DEPLOY DEV │  Auto-deploy to dev environment (always)
└──────┬──────┘
       │
    ▼
┌─────────────┐
│ DEPLOY STG  │  Auto-deploy to staging (on main branch)
│ Smoke Tests │  Run smoke tests, E2E tests
└──────┬──────┘
       │ Manual approval gate
    ▼
┌─────────────┐
│ DEPLOY PROD │  Deploy to production with zero downtime
│ Smoke Tests │  Verify, monitor, auto-rollback on failure
└─────────────┘
```

### DORA Metrics — Senior-Level Signal

```
DORA (DevOps Research and Assessment) = 4 key metrics for DevOps performance

1. Deployment Frequency:
   How often you deploy to production
   Elite:  Multiple times per day
   High:   Once per day to once per week
   Medium: Once per week to once per month
   Low:    Less than once per month

   Your metric: daily deployments across 3 environments ✓

2. Lead Time for Changes:
   Time from code commit to running in production
   Elite:  < 1 hour
   High:   1 day to 1 week
   Medium: 1 week to 1 month
   Low:    > 1 month

   Your metric: 45 min → 8 min commit-to-deploy ✓ (Elite range)

3. Mean Time to Restore (MTTR):
   How long to recover from a production failure
   Elite:  < 1 hour
   High:   < 1 day
   Medium: 1 day to 1 week
   Low:    > 1 week

4. Change Failure Rate:
   % of deployments that cause production failures
   Elite:  0-15%
   High:   16-30%
   Medium: 16-30%
   Low:    > 30%

   Your metric: 60% failure reduction → likely < 10% failure rate ✓

How to answer "how did you improve CI/CD?":
  "We tracked DORA metrics. Lead time reduced from 45 to 8 minutes
  (Elite tier). Deployment frequency moved from weekly to daily.
  Change failure rate dropped 60% through better test gates and
  automated smoke tests with auto-rollback."
```

---

## PART 2 — JENKINS ARCHITECTURE

### Components

```
Jenkins Master (Controller):
  Central server — the brain
  Manages: jobs, pipelines, scheduling
  Stores: configuration, build history, credentials
  Does NOT run builds directly (delegates to agents)
  High availability: configure with multiple masters (complex)

Jenkins Agent (formerly Slave):
  Worker machine where builds actually run
  Can be: EC2, Docker container, Kubernetes pod
  Connects to master via: JNLP (Java), SSH
  Multiple agents = parallel builds
  Label agents: linux, docker, gpu → assign jobs to correct agent

Executor:
  Thread on an agent that runs one build at a time
  Agent with 4 executors = 4 simultaneous builds
  Master executor count: set to 0 (don't run builds on master)

Build Queue:
  Jobs waiting for an available executor
  If all executors busy → job waits in queue
  Solution: add more agents or more executors

Jenkins distributed build:
  Master: job scheduling, UI, API
  Agent-1 (2 executors): Java builds
  Agent-2 (4 executors): Docker builds
  Agent-3 (K8s pod): ephemeral, auto-scaled
```

### Jenkins Setup Best Practices

```
1. Never run builds on master
   master.setNumExecutors(0)  # set via Jenkins config

2. Use dedicated agents per technology
   docker-agent:  docker installed, ECR access
   k8s-agent:    kubectl, helm, aws-cli
   python-agent: python3, pip, test tools

3. Use Kubernetes plugin (ephemeral agents)
   Each build creates a K8s pod
   Pod deleted after build completes
   Auto-scaling: no idle agent cost
   Clean environment: no state between builds

4. Secure Jenkins
   Enable security: Matrix-based authorization
   Use API tokens (not passwords)
   LDAP/OAuth for authentication
   No anonymous access in production

5. Backup Jenkins
   Back up: $JENKINS_HOME (config, jobs, credentials)
   Jobs as code: Jenkinsfiles in git (don't need backup)
   Configuration as code: JCasC plugin
```

### Jenkins Plugins (Must Know)

```
Pipeline:          Jenkinsfile support (core)
Git:               Git repository integration
GitHub:            GitHub webhook triggers
Credentials:       Secure credential storage
Blue Ocean:        Modern pipeline UI
Docker Pipeline:   Docker commands in pipeline
Kubernetes:        Ephemeral K8s build agents
AWS Credentials:   AWS IAM credential binding
Slack Notify:      Slack notifications
JUnit:             Test result publishing
Cobertura/Jacoco:  Code coverage reports
AnsiColor:         Colored console output
Timestamper:       Add timestamps to logs
SSH Agent:         SSH key injection
Artifactory/Nexus: Artifact repository integration
SonarQube:         Code quality analysis
OWASP:             Dependency security scanning
```

---

## PART 3 — JENKINS PIPELINE AS CODE

### Declarative vs Scripted

```
Declarative (recommended):
  Structured syntax with predefined sections
  More readable, easier to learn
  Built-in validation
  Limited flexibility (by design)
  
  pipeline {
    agent any
    stages {
      stage('Build') {
        steps { ... }
      }
    }
  }

Scripted (older, more flexible):
  Groovy code — full programming language
  More powerful but more complex
  No built-in structure
  Use when declarative can't do what you need
  
  node {
    stage('Build') {
      ...
    }
  }

Use Declarative unless you specifically need Scripted's flexibility.
```

### Complete Declarative Jenkinsfile

```groovy
// Jenkinsfile — Production-grade pipeline
pipeline {
    // ─── AGENT ──────────────────────────────────────────────────
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['sleep', 'infinity']
  - name: python
    image: python:3.12-slim
    command: ['sleep', 'infinity']
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }

    // ─── ENVIRONMENT ─────────────────────────────────────────────
    environment {
        APP_NAME        = 'judicial-api'
        ECR_REGISTRY    = "${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com"
        IMAGE_TAG       = "${GIT_COMMIT.take(8)}"   // short git SHA
        IMAGE_FULL      = "${ECR_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
        AWS_REGION      = 'ap-south-1'
    }

    // ─── OPTIONS ─────────────────────────────────────────────────
    options {
        timeout(time: 30, unit: 'MINUTES')      // fail if takes > 30 min
        buildDiscarder(logRotator(numToKeepStr: '20'))  // keep last 20 builds
        disableConcurrentBuilds()               // no parallel builds of same job
        timestamps()                            // add timestamps to logs
        ansiColor('xterm')                      // colored output
    }

    // ─── PARAMETERS ──────────────────────────────────────────────
    parameters {
        choice(name: 'DEPLOY_ENV',
               choices: ['none', 'staging', 'production'],
               description: 'Deploy to environment after build')
        booleanParam(name: 'SKIP_TESTS',
                     defaultValue: false,
                     description: 'Skip test stage (emergency only)')
        string(name: 'IMAGE_OVERRIDE',
               defaultValue: '',
               description: 'Override image tag (leave empty to build new)')
    }

    // ─── TRIGGERS ────────────────────────────────────────────────
    triggers {
        githubPush()                            // trigger on GitHub push
        // pollSCM('H/5 * * * *')              // poll every 5 min (fallback)
    }

    // ─── STAGES ──────────────────────────────────────────────────
    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.GIT_AUTHOR = sh(
                        script: 'git log -1 --pretty=%an',
                        returnStdout: true
                    ).trim()
                }
                echo "Commit: ${env.IMAGE_TAG} by ${env.GIT_AUTHOR}"
                echo "Message: ${env.GIT_COMMIT_MSG}"
            }
        }

        stage('Test') {
            when {
                not { expression { params.SKIP_TESTS } }
            }
            parallel {
                stage('Unit Tests') {
                    steps {
                        container('python') {
                            sh '''
                                pip install -r requirements.txt -q
                                pip install pytest pytest-cov -q
                                pytest tests/unit/ \
                                    --cov=src \
                                    --cov-report=xml:coverage.xml \
                                    --junitxml=junit-unit.xml \
                                    -v
                            '''
                        }
                    }
                    post {
                        always {
                            junit 'junit-unit.xml'
                        }
                    }
                }
                stage('Lint') {
                    steps {
                        container('python') {
                            sh '''
                                pip install flake8 black isort -q
                                flake8 src/ --max-line-length=100
                                black --check src/
                                isort --check-only src/
                            '''
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                container('docker') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh '''
                            # Login to ECR
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REGISTRY}

                            # Build with cache
                            docker build \
                                --cache-from ${ECR_REGISTRY}/${APP_NAME}:cache \
                                --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
                                --build-arg GIT_COMMIT=${IMAGE_TAG} \
                                -t ${IMAGE_FULL} \
                                -t ${ECR_REGISTRY}/${APP_NAME}:latest \
                                .
                        '''
                    }
                }
            }
        }

        stage('Security Scan') {
            parallel {
                stage('Image CVE Scan') {
                    steps {
                        container('docker') {
                            sh '''
                                docker run --rm \
                                    -v /var/run/docker.sock:/var/run/docker.sock \
                                    aquasec/trivy:latest image \
                                    --severity HIGH,CRITICAL \
                                    --exit-code 1 \
                                    --no-progress \
                                    ${IMAGE_FULL}
                            '''
                        }
                    }
                }
                stage('Dependency Scan') {
                    steps {
                        container('python') {
                            sh '''
                                pip install safety -q
                                safety check --json -r requirements.txt > safety-report.json || true
                            '''
                        }
                    }
                }
            }
        }

        stage('Push to ECR') {
            when {
                anyOf {
                    branch 'main'
                    branch 'release/*'
                    expression { params.DEPLOY_ENV != 'none' }
                }
            }
            steps {
                container('docker') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]]) {
                        sh '''
                            docker push ${IMAGE_FULL}
                            docker push ${ECR_REGISTRY}/${APP_NAME}:latest

                            # Push cache layer
                            docker tag ${IMAGE_FULL} ${ECR_REGISTRY}/${APP_NAME}:cache
                            docker push ${ECR_REGISTRY}/${APP_NAME}:cache
                        '''
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'main'
                not { expression { params.DEPLOY_ENV == 'none' } }
            }
            steps {
                container('kubectl') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]]) {
                        sh '''
                            aws eks update-kubeconfig \
                                --name judicial-staging \
                                --region ${AWS_REGION}

                            kubectl set image deployment/${APP_NAME} \
                                ${APP_NAME}=${IMAGE_FULL} \
                                -n staging

                            kubectl rollout status \
                                deployment/${APP_NAME} \
                                -n staging \
                                --timeout=300s
                        '''
                    }
                }
            }
            post {
                success {
                    sh '''
                        # Smoke test staging
                        sleep 10
                        curl -f https://staging.judicialsolutions.in/health || \
                            (kubectl rollout undo deployment/${APP_NAME} -n staging && exit 1)
                    '''
                }
            }
        }

        stage('Approve Production') {
            when {
                branch 'main'
                expression { params.DEPLOY_ENV == 'production' }
            }
            steps {
                timeout(time: 2, unit: 'HOURS') {
                    input message: "Deploy ${env.IMAGE_TAG} to PRODUCTION?",
                          ok: 'Deploy',
                          submitter: 'devops-leads,tech-leads'
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
                expression { params.DEPLOY_ENV == 'production' }
            }
            steps {
                container('kubectl') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-prod-credentials'
                    ]]) {
                        sh '''
                            aws eks update-kubeconfig \
                                --name judicial-prod \
                                --region ${AWS_REGION}

                            kubectl set image deployment/${APP_NAME} \
                                ${APP_NAME}=${IMAGE_FULL} \
                                -n production

                            kubectl rollout status \
                                deployment/${APP_NAME} \
                                -n production \
                                --timeout=600s
                        '''
                    }
                }
            }
        }
    }

    // ─── POST ────────────────────────────────────────────────────
    post {
        always {
            // Publish test results
            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'htmlcov',
                reportFiles: 'index.html',
                reportName: 'Coverage Report'
            ])
            // Clean workspace
            cleanWs()
        }
        success {
            slackSend(
                color: 'good',
                message: """
                    ✅ *${APP_NAME}* deployed successfully
                    Branch: `${BRANCH_NAME}` | Tag: `${IMAGE_TAG}`
                    Build: <${BUILD_URL}|#${BUILD_NUMBER}>
                """.stripIndent()
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: """
                    ❌ *${APP_NAME}* build FAILED
                    Branch: `${BRANCH_NAME}` | Commit: `${GIT_COMMIT_MSG}`
                    Build: <${BUILD_URL}|#${BUILD_NUMBER}>
                """.stripIndent()
            )
        }
        unstable {
            slackSend(
                color: 'warning',
                message: "⚠️ ${APP_NAME} build UNSTABLE - tests failed"
            )
        }
    }
}
```

---

## PART 4 — JENKINS SHARED LIBRARIES

### Why Shared Libraries?

```
Problem: 20 microservices, each with nearly identical Jenkinsfile
  Change Docker build logic → update 20 files
  Bug in pipeline code → present in 20 places
  Inconsistent pipelines across teams

Solution: Shared Library
  Common pipeline code extracted to separate git repo
  All Jenkinsfiles call shared functions
  Update in one place → all pipelines benefit
  Consistent patterns enforced across org
```

### Shared Library Structure

```
jenkins-shared-library/           ← separate git repo
├── vars/                         ← global variables/functions (callable from Jenkinsfile)
│   ├── buildDockerImage.groovy   ← var: buildDockerImage(...)
│   ├── deployToK8s.groovy        ← var: deployToK8s(...)
│   ├── runTests.groovy           ← var: runTests(...)
│   └── sendSlackNotification.groovy
├── src/                          ← helper classes (Groovy)
│   └── com/judicialsolutions/
│       ├── Docker.groovy
│       └── Kubernetes.groovy
├── resources/                    ← static files (scripts, templates)
│   └── scripts/
│       └── smoke-test.sh
└── README.md
```

### Shared Library Functions

```groovy
// vars/buildDockerImage.groovy
def call(Map config = [:]) {
    def registry   = config.registry   ?: error("registry required")
    def appName    = config.appName    ?: error("appName required")
    def imageTag   = config.imageTag   ?: env.GIT_COMMIT.take(8)
    def buildArgs  = config.buildArgs  ?: [:]
    def dockerfile = config.dockerfile ?: 'Dockerfile'

    def buildArgsStr = buildArgs.collect { k, v -> "--build-arg ${k}=${v}" }.join(' ')
    def imageFull = "${registry}/${appName}:${imageTag}"

    echo "Building image: ${imageFull}"

    sh """
        docker build \
            ${buildArgsStr} \
            --cache-from ${registry}/${appName}:cache \
            -t ${imageFull} \
            -f ${dockerfile} \
            .
    """

    return imageFull   // return full image name for use in later stages
}
```

```groovy
// vars/deployToK8s.groovy
def call(Map config = [:]) {
    def clusterName = config.cluster    ?: error("cluster required")
    def namespace   = config.namespace  ?: 'default'
    def deployment  = config.deployment ?: error("deployment required")
    def image       = config.image      ?: error("image required")
    def region      = config.region     ?: 'ap-south-1'
    def timeout     = config.timeout    ?: 300

    sh """
        aws eks update-kubeconfig \
            --name ${clusterName} \
            --region ${region}

        kubectl set image deployment/${deployment} \
            ${deployment}=${image} \
            -n ${namespace}

        kubectl rollout status deployment/${deployment} \
            -n ${namespace} \
            --timeout=${timeout}s
    """
}
```

```groovy
// vars/withDockerECR.groovy — wraps ECR auth
def call(String registry, String region, Closure body) {
    withCredentials([[
        $class: 'AmazonWebServicesCredentialsBinding',
        credentialsId: 'aws-credentials'
    ]]) {
        sh """
            aws ecr get-login-password --region ${region} | \
            docker login --username AWS --password-stdin ${registry}
        """
        body()  // execute the wrapped code
    }
}
```

### Using Shared Library in Jenkinsfile

```groovy
// In Jenkins: Manage Jenkins → Configure System → Global Pipeline Libraries
// Add library: name=judicial-pipeline, SCM=GitHub repo

// Jenkinsfile (much simpler now!)
@Library('judicial-pipeline') _  // load shared library

pipeline {
    agent any

    environment {
        ECR_REGISTRY = "${AWS_ACCOUNT}.dkr.ecr.ap-south-1.amazonaws.com"
        APP_NAME     = 'judicial-api'
        IMAGE_TAG    = "${GIT_COMMIT.take(8)}"
    }

    stages {
        stage('Build') {
            steps {
                script {
                    // Call shared library function
                    env.IMAGE_FULL = buildDockerImage(
                        registry:  ECR_REGISTRY,
                        appName:   APP_NAME,
                        imageTag:  IMAGE_TAG,
                        buildArgs: [GIT_COMMIT: IMAGE_TAG]
                    )
                }
            }
        }

        stage('Deploy Staging') {
            when { branch 'main' }
            steps {
                script {
                    deployToK8s(
                        cluster:    'judicial-staging',
                        namespace:  'staging',
                        deployment: APP_NAME,
                        image:      env.IMAGE_FULL
                    )
                }
            }
        }
    }

    post {
        always {
            sendSlackNotification(
                appName:    APP_NAME,
                imageTag:   IMAGE_TAG,
                buildUrl:   BUILD_URL,
                buildNumber:BUILD_NUMBER
            )
        }
    }
}
```

---
