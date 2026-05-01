# Kubernetes Production Commands Reference

> From Basic to Advanced — Every command explained with when and why to use it

-----

## Table of Contents

1. [Cluster Info & Context](#1-cluster-info--context)
1. [Namespace](#2-namespace)
1. [Pods](#3-pods)
1. [Deployments](#4-deployments)
1. [Services](#5-services)
1. [ConfigMaps & Secrets](#6-configmaps--secrets)
1. [Logs](#7-logs)
1. [Exec & Debug](#8-exec--debug)
1. [Resource Usage & Monitoring](#9-resource-usage--monitoring)
1. [Scaling](#10-scaling)
1. [Rollout & Rollback](#11-rollout--rollback)
1. [Nodes](#12-nodes)
1. [Persistent Volumes](#13-persistent-volumes)
1. [RBAC](#14-rbac)
1. [Network & DNS](#15-network--dns)
1. [Jobs & CronJobs](#16-jobs--cronjobs)
1. [Taints, Tolerations & Affinity](#17-taints-tolerations--affinity)
1. [Advanced Debugging](#18-advanced-debugging)
1. [Cleanup](#19-cleanup)
1. [Pro Tips & Shortcuts](#20-pro-tips--shortcuts)

-----

## 1. Cluster Info & Context

> First thing you do when you connect to any cluster — confirm where you are before running anything.

|Command                                                      |Purpose                                          |When to Use                                 |
|-------------------------------------------------------------|-------------------------------------------------|--------------------------------------------|
|`kubectl version`                                            |Shows client and server Kubernetes version       |Verify version compatibility                |
|`kubectl cluster-info`                                       |Shows API server and CoreDNS endpoint            |Confirm cluster is reachable                |
|`kubectl config get-contexts`                                |Lists all clusters you have access to            |See which clusters are configured locally   |
|`kubectl config current-context`                             |Shows which cluster you’re currently pointed at  |**Always run before anything in production**|
|`kubectl config use-context <name>`                          |Switch to a different cluster                    |Switching between dev/staging/prod          |
|`kubectl config set-context --current --namespace=production`|Set default namespace for current context        |Avoid typing `-n production` every time     |
|`kubectl api-resources`                                      |Lists all resource types available in the cluster|When you’re unsure what resource name to use|
|`kubectl api-versions`                                       |Lists all API versions supported                 |Checking if a resource version is available |

-----

## 2. Namespace

> Namespaces are logical separations inside a cluster. Production usually has its own namespace.

|Command                                |Purpose                                       |When to Use                                        |
|---------------------------------------|----------------------------------------------|---------------------------------------------------|
|`kubectl get namespaces`               |List all namespaces                           |See what environments exist in the cluster         |
|`kubectl create namespace production`  |Create a new namespace                        |First time setting up an environment               |
|`kubectl describe namespace production`|Show resource quotas and limits on a namespace|Debug resource exhaustion issues                   |
|`kubectl delete namespace staging`     |Delete a namespace and everything inside it   |Cleanup non-prod environments — **careful in prod**|
|`kubectl get all -n production`        |List every resource in a namespace            |Quick full overview of what’s running              |
|`kubectl get all --all-namespaces`     |List resources across all namespaces          |Cluster-wide health check                          |

-----

## 3. Pods

> Pod is the smallest unit in Kubernetes. A pod runs one or more containers.

### Listing Pods

|Command                                                               |Purpose                         |When to Use                               |
|----------------------------------------------------------------------|--------------------------------|------------------------------------------|
|`kubectl get pods -n production`                                      |List all pods in a namespace    |Most frequent command — daily health check|
|`kubectl get pods -n production -o wide`                              |List pods with node name and IP |Find which node a pod is on               |
|`kubectl get pods --all-namespaces`                                   |List pods in all namespaces     |Cluster-wide pod health check             |
|`kubectl get pods -n production -w`                                   |Watch pods in real time         |Monitor pod status during a deployment    |
|`kubectl get pods -n production --show-labels`                        |Show labels attached to each pod|Debug label selector issues               |
|`kubectl get pods -n production -l app=myapp`                         |Filter pods by label            |Find all pods of a specific app           |
|`kubectl get pods -n production --field-selector=status.phase=Running`|Filter pods by status           |Find only Running pods                    |
|`kubectl get pods -n production --sort-by=.metadata.creationTimestamp`|Sort pods by creation time      |Find newest or oldest pods                |

### Describing & Inspecting Pods

|Command                                                               |Purpose                                      |When to Use                                   |
|----------------------------------------------------------------------|---------------------------------------------|----------------------------------------------|
|`kubectl describe pod <pod-name> -n production`                       |Full details: events, image, node, conditions|**First command to run when a pod is failing**|
|`kubectl get pod <pod-name> -n production -o yaml`                    |Full pod spec in YAML format                 |Compare running config vs what you expect     |
|`kubectl get pod <pod-name> -n production -o json`                    |Full pod spec in JSON format                 |Script-friendly output for parsing            |
|`kubectl get pod <pod-name> -o jsonpath='{.status.podIP}'`            |Extract specific field from pod              |Get pod IP without parsing full output        |
|`kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'`|Get image name running in pod                |Verify which image tag is deployed            |

### Pod Status Quick Reference

|Status            |Meaning                                  |What to do                               |
|------------------|-----------------------------------------|-----------------------------------------|
|`Running`         |Pod is healthy and running               |Nothing                                  |
|`Pending`         |Waiting to be scheduled                  |Check node resources or PVC binding      |
|`CrashLoopBackOff`|Container keeps crashing and restarting  |Check logs immediately                   |
|`OOMKilled`       |Container ran out of memory              |Increase memory limits                   |
|`ImagePullBackOff`|Cannot pull image from registry          |Check image name, tag, or ECR permissions|
|`Terminating`     |Pod is being deleted                     |Normal during rollouts                   |
|`Error`           |Container exited with error              |Check logs                               |
|`Evicted`         |Pod removed due to node resource pressure|Check node disk or memory                |

-----

## 4. Deployments

> Deployments manage ReplicaSets which manage Pods. Most apps run as Deployments.

|Command                                                          |Purpose                                |When to Use                                         |
|-----------------------------------------------------------------|---------------------------------------|----------------------------------------------------|
|`kubectl get deployments -n production`                          |List all deployments                   |Check what apps are deployed                        |
|`kubectl get deployment myapp -n production -o wide`             |Deployment with image and selector info|Verify image tag and replica count                  |
|`kubectl describe deployment myapp -n production`                |Full deployment details and events     |Debug deployment issues                             |
|`kubectl create deployment myapp --image=myapp:v1`               |Create a deployment imperatively       |Quick testing only — not for production             |
|`kubectl apply -f deployment.yaml`                               |Apply manifest file (create or update) |**Standard way to deploy in production**            |
|`kubectl diff -f deployment.yaml`                                |Show what will change before applying  |**Review changes before applying — use this always**|
|`kubectl set image deployment/myapp myapp=myapp:v2 -n production`|Update image tag directly              |Quick image update without editing YAML             |
|`kubectl edit deployment myapp -n production`                    |Open deployment YAML in editor         |Live edits — use with caution in production         |
|`kubectl delete deployment myapp -n production`                  |Delete a deployment                    |Decommissioning an app                              |
|`kubectl get replicasets -n production`                          |List ReplicaSets                       |See deployment history and old versions             |

-----

## 5. Services

> Services expose your pods to traffic — internal (ClusterIP) or external (LoadBalancer/NodePort).

|Command                                                       |Purpose                                   |When to Use                                        |
|--------------------------------------------------------------|------------------------------------------|---------------------------------------------------|
|`kubectl get services -n production`                          |List all services                         |Check what’s exposed and on which port             |
|`kubectl get svc -n production -o wide`                       |Services with selector and endpoints      |Verify service is targeting right pods             |
|`kubectl describe service myapp -n production`                |Full service details and endpoints        |Debug traffic not reaching pods                    |
|`kubectl get endpoints myapp -n production`                   |Show actual pod IPs behind a service      |Verify pods are registered with the service        |
|`kubectl apply -f service.yaml`                               |Create or update a service                |Standard way to create services                    |
|`kubectl expose deployment myapp --port=80 --target-port=3000`|Quickly expose a deployment as a service  |Quick testing — not recommended for production     |
|`kubectl delete service myapp -n production`                  |Remove a service                          |Decommissioning                                    |
|`kubectl port-forward svc/myapp 8080:80 -n production`        |Forward service port to your local machine|Test a service locally without exposing it publicly|
|`kubectl port-forward pod/<pod-name> 8080:3000 -n production` |Forward pod port directly to local        |Debug a specific pod locally                       |

-----

## 6. ConfigMaps & Secrets

> ConfigMaps store plain config. Secrets store sensitive data (base64 encoded).

### ConfigMaps

|Command                                                            |Purpose                        |When to Use                      |
|-------------------------------------------------------------------|-------------------------------|---------------------------------|
|`kubectl get configmaps -n production`                             |List all configmaps            |Check what configs exist         |
|`kubectl describe configmap app-config -n production`              |Show configmap data            |Verify config values             |
|`kubectl get configmap app-config -n production -o yaml`           |Full configmap YAML            |Copy or compare configs          |
|`kubectl create configmap app-config --from-file=config.properties`|Create configmap from file     |Load config from a file          |
|`kubectl create configmap app-config --from-literal=ENV=production`|Create configmap from key-value|Quick config creation            |
|`kubectl edit configmap app-config -n production`                  |Edit configmap live            |Update config without redeploying|
|`kubectl delete configmap app-config -n production`                |Delete a configmap             |Cleanup                          |

### Secrets

|Command                                                                                                                                           |Purpose                           |When to Use                            |
|--------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|---------------------------------------|
|`kubectl get secrets -n production`                                                                                                               |List all secrets                  |Check what secrets exist               |
|`kubectl describe secret db-secret -n production`                                                                                                 |Show secret metadata (not values) |Verify secret exists and its keys      |
|`kubectl get secret db-secret -n production -o yaml`                                                                                              |Show secret in base64             |Inspect secret structure               |
|`kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 --decode`                                                                   |Decode a specific secret value    |Read actual secret value               |
|`kubectl create secret generic db-secret --from-literal=password=mysecret`                                                                        |Create a secret from literal value|Quick secret creation                  |
|`kubectl create secret docker-registry ecr-secret --docker-server=<ecr-url> --docker-username=AWS --docker-password=$(aws ecr get-login-password)`|Create ECR pull secret            |When pods need to pull from private ECR|
|`kubectl delete secret db-secret -n production`                                                                                                   |Delete a secret                   |Rotation or cleanup                    |

-----

## 7. Logs

> Logs are your first source of truth when something goes wrong.

|Command                                                             |Purpose                                   |When to Use                                     |
|--------------------------------------------------------------------|------------------------------------------|------------------------------------------------|
|`kubectl logs <pod-name> -n production`                             |Print logs of a pod                       |Basic log check                                 |
|`kubectl logs <pod-name> -n production -f`                          |Stream logs in real time                  |Watch live traffic or errors                    |
|`kubectl logs <pod-name> -n production --tail=100`                  |Last 100 lines of logs                    |Quick recent log check                          |
|`kubectl logs <pod-name> -n production --since=1h`                  |Logs from the last 1 hour                 |Check recent errors without full dump           |
|`kubectl logs <pod-name> -n production --since=2024-01-15T10:00:00Z`|Logs since a specific timestamp           |Narrow down to an incident window               |
|`kubectl logs <pod-name> -c <container-name> -n production`         |Logs of a specific container in a pod     |When pod has multiple containers                |
|`kubectl logs <pod-name> -n production --previous`                  |Logs from the previous (crashed) container|**Debug CrashLoopBackOff — most useful command**|
|`kubectl logs -l app=myapp -n production`                           |Logs from all pods matching a label       |Aggregate logs from all replicas                |
|`kubectl logs -l app=myapp -n production --all-containers=true`     |All container logs from matching pods     |Full log dump across all pods                   |

-----

## 8. Exec & Debug

> Get inside a running pod or spawn a debug container to investigate issues.

|Command                                                                                      |Purpose                              |When to Use                                         |
|---------------------------------------------------------------------------------------------|-------------------------------------|----------------------------------------------------|
|`kubectl exec -it <pod-name> -n production -- /bin/sh`                                       |Open shell inside a running pod      |Inspect filesystem, env vars, network               |
|`kubectl exec -it <pod-name> -n production -- /bin/bash`                                     |Open bash shell (if available)       |Same as above, bash preferred                       |
|`kubectl exec -it <pod-name> -n production -- env`                                           |List all environment variables in pod|Verify env vars are injected correctly              |
|`kubectl exec -it <pod-name> -n production -- cat /etc/config/app.properties`                |Read a file inside the pod           |Verify configmap is mounted correctly               |
|`kubectl exec -it <pod-name> -c <container> -n production -- /bin/sh`                        |Shell into specific container        |When pod has multiple containers                    |
|`kubectl exec <pod-name> -n production -- curl http://other-service/health`                  |Test connectivity to another service |Debug service-to-service communication              |
|`kubectl exec <pod-name> -n production -- nslookup myapp.production.svc.cluster.local`       |DNS resolution check inside cluster  |Debug DNS issues between services                   |
|`kubectl debug node/<node-name> -it --image=ubuntu`                                          |Attach debug pod to a node           |Debug node-level networking or filesystem           |
|`kubectl run debug-pod --image=busybox --rm -it --restart=Never -- /bin/sh`                  |Spin up a temporary debug pod        |Test DNS, network, service connectivity from scratch|
|`kubectl run debug-pod --image=curlimages/curl --rm -it --restart=Never -- curl http://myapp`|Run curl from inside cluster         |Verify internal service is responding               |

-----

## 9. Resource Usage & Monitoring

> Understand CPU and memory consumption across pods and nodes.

|Command                                                         |Purpose                                        |When to Use                                   |
|----------------------------------------------------------------|-----------------------------------------------|----------------------------------------------|
|`kubectl top nodes`                                             |CPU and memory usage of all nodes              |Check if nodes are under pressure             |
|`kubectl top pods -n production`                                |CPU and memory usage of all pods               |Find which pod is consuming too many resources|
|`kubectl top pods -n production --sort-by=memory`               |Sort pods by memory usage                      |Find the highest memory consumers             |
|`kubectl top pods -n production --sort-by=cpu`                  |Sort pods by CPU usage                         |Find CPU-hungry pods                          |
|`kubectl top pods -n production --containers`                   |Resource usage per container                   |When pod has multiple containers              |
|`kubectl describe node <node-name>`                             |Full node details including allocated resources|Find how much capacity is left on a node      |
|`kubectl get events -n production`                              |List recent cluster events                     |See warnings and errors across all resources  |
|`kubectl get events -n production --sort-by=.lastTimestamp`     |Events sorted by time                          |Find most recent events first                 |
|`kubectl get events -n production --field-selector=type=Warning`|Only show warning events                       |Focus on problems only                        |

-----

## 10. Scaling

> Control how many pods are running for a deployment.

|Command                                                               |Purpose                                  |When to Use                                 |
|----------------------------------------------------------------------|-----------------------------------------|--------------------------------------------|
|`kubectl scale deployment myapp --replicas=5 -n production`           |Manually set replica count               |Scale up during high traffic                |
|`kubectl scale deployment myapp --replicas=1 -n production`           |Scale down to 1 replica                  |Scale down during low traffic or maintenance|
|`kubectl scale deployment myapp --replicas=0 -n production`           |Stop all pods without deleting deployment|Temporarily shut down an app                |
|`kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=70`|Create Horizontal Pod Autoscaler         |Auto-scale based on CPU usage               |
|`kubectl get hpa -n production`                                       |List all HPAs                            |Check autoscaler status and current replicas|
|`kubectl describe hpa myapp -n production`                            |HPA details and scaling events           |Debug why autoscaler isn’t triggering       |
|`kubectl delete hpa myapp -n production`                              |Remove autoscaler                        |Disable autoscaling                         |

-----

## 11. Rollout & Rollback

> Control and monitor how deployments are rolled out and how to undo them.

|Command                                                              |Purpose                                |When to Use                                   |
|---------------------------------------------------------------------|---------------------------------------|----------------------------------------------|
|`kubectl rollout status deployment/myapp -n production`              |Watch rollout progress until done      |After every deploy — confirm success          |
|`kubectl rollout history deployment/myapp -n production`             |List all previous deployment revisions |See what changed and when                     |
|`kubectl rollout history deployment/myapp --revision=3 -n production`|See details of a specific revision     |Inspect what image was used in revision 3     |
|`kubectl rollout undo deployment/myapp -n production`                |Rollback to previous revision          |**Immediate rollback when deploy breaks prod**|
|`kubectl rollout undo deployment/myapp --to-revision=2 -n production`|Rollback to a specific revision        |Roll back to a specific known-good version    |
|`kubectl rollout pause deployment/myapp -n production`               |Pause ongoing rollout                  |Stop mid-deploy to investigate                |
|`kubectl rollout resume deployment/myapp -n production`              |Resume a paused rollout                |Continue rollout after investigation          |
|`kubectl rollout restart deployment/myapp -n production`             |Restart all pods with a rolling restart|Force pods to reload config or pick up a fix  |

-----

## 12. Nodes

> Nodes are the EC2 instances that run your pods.

|Command                                                               |Purpose                                       |When to Use                                  |
|----------------------------------------------------------------------|----------------------------------------------|---------------------------------------------|
|`kubectl get nodes`                                                   |List all nodes and their status               |Cluster health overview                      |
|`kubectl get nodes -o wide`                                           |Nodes with IP, OS, kernel, container runtime  |Detailed node info                           |
|`kubectl describe node <node-name>`                                   |Full node details — capacity, pods, conditions|Debug node pressure or scheduling issues     |
|`kubectl cordon <node-name>`                                          |Mark node as unschedulable                    |Prevent new pods from landing on this node   |
|`kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data`|Evict all pods from node safely               |Before terminating or updating a node        |
|`kubectl uncordon <node-name>`                                        |Re-enable scheduling on a node                |After node maintenance is done               |
|`kubectl label node <node-name> env=production`                       |Add a label to a node                         |Enable node affinity rules                   |
|`kubectl taint node <node-name> dedicated=gpu:NoSchedule`             |Add taint to a node                           |Prevent non-GPU pods from running on GPU node|

-----

## 13. Persistent Volumes

> Persistent storage that survives pod restarts.

|Command                                        |Purpose                                   |When to Use                                        |
|-----------------------------------------------|------------------------------------------|---------------------------------------------------|
|`kubectl get pv`                               |List all Persistent Volumes (cluster-wide)|Check available storage                            |
|`kubectl get pvc -n production`                |List Persistent Volume Claims in namespace|Check if storage is bound to pods                  |
|`kubectl describe pvc <pvc-name> -n production`|PVC details and binding status            |Debug storage not attaching to pod                 |
|`kubectl get storageclass`                     |List storage classes available            |Check what types of storage you can provision      |
|`kubectl delete pvc <pvc-name> -n production`  |Delete a PVC                              |Cleanup — **data will be lost if policy is Delete**|

-----

## 14. RBAC

> Role-Based Access Control — who can do what inside the cluster.

|Command                                                                               |Purpose                                       |When to Use                                    |
|--------------------------------------------------------------------------------------|----------------------------------------------|-----------------------------------------------|
|`kubectl get roles -n production`                                                     |List roles in a namespace                     |Check what permissions exist                   |
|`kubectl get clusterroles`                                                            |List cluster-wide roles                       |Check global permissions                       |
|`kubectl get rolebindings -n production`                                              |List role bindings in a namespace             |See who has which role                         |
|`kubectl get clusterrolebindings`                                                     |List cluster-wide role bindings               |See global role assignments                    |
|`kubectl describe role <role-name> -n production`                                     |Show what a role allows                       |Audit permissions for a role                   |
|`kubectl describe rolebinding <binding-name> -n production`                           |Show who is bound to a role                   |Audit who has what access                      |
|`kubectl auth can-i create pods -n production`                                        |Check if your current identity can create pods|Verify your permissions                        |
|`kubectl auth can-i delete deployments --as=system:serviceaccount:production:myapp-sa`|Check permissions of a service account        |Debug IRSA or service account permission issues|
|`kubectl get serviceaccounts -n production`                                           |List service accounts                         |See what SAs exist in namespace                |
|`kubectl describe serviceaccount myapp-sa -n production`                              |Service account details                       |Verify IRSA annotation is attached             |

-----

## 15. Network & DNS

> Debug connectivity between services inside the cluster.

|Command                                                                                                               |Purpose                                 |When to Use                                  |
|----------------------------------------------------------------------------------------------------------------------|----------------------------------------|---------------------------------------------|
|`kubectl get ingress -n production`                                                                                   |List all ingress rules                  |Check which URLs are routed to which services|
|`kubectl describe ingress myapp -n production`                                                                        |Full ingress details                    |Debug routing or TLS issues                  |
|`kubectl get networkpolicies -n production`                                                                           |List network policies                   |Check if traffic is being blocked by policy  |
|`kubectl describe networkpolicy <name> -n production`                                                                 |Show what traffic a policy allows/denies|Debug service-to-service connection refused  |
|`kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default`                        |Test DNS inside cluster                 |Verify cluster DNS is working                |
|`kubectl run net-test --image=busybox --rm -it --restart=Never -- wget -qO- http://myapp.production.svc.cluster.local`|Test internal HTTP from inside cluster  |Debug service-to-service connectivity        |

### Kubernetes DNS Format

```
<service-name>.<namespace>.svc.cluster.local
```

|Example                             |Resolves To               |
|------------------------------------|--------------------------|
|`myapp`                             |Within same namespace     |
|`myapp.production`                  |Cross-namespace short form|
|`myapp.production.svc.cluster.local`|Full DNS — always works   |

-----

## 16. Jobs & CronJobs

> One-time tasks (Jobs) and scheduled tasks (CronJobs).

|Command                                                                |Purpose                               |When to Use                                  |
|-----------------------------------------------------------------------|--------------------------------------|---------------------------------------------|
|`kubectl get jobs -n production`                                       |List all jobs                         |See what batch tasks are running or completed|
|`kubectl describe job <job-name> -n production`                        |Job details and pod status            |Debug why a job failed                       |
|`kubectl logs job/<job-name> -n production`                            |Logs from job pod                     |See output of a batch job                    |
|`kubectl delete job <job-name> -n production`                          |Delete a job and its pods             |Cleanup completed or failed jobs             |
|`kubectl get cronjobs -n production`                                   |List all cronjobs                     |See scheduled tasks and their schedule       |
|`kubectl describe cronjob <name> -n production`                        |CronJob details and last schedule     |Debug cronjob not triggering                 |
|`kubectl create job manual-run --from=cronjob/myapp-cron -n production`|Manually trigger a cronjob immediately|Test a cronjob without waiting for schedule  |

-----

## 17. Taints, Tolerations & Affinity

> Control which pods land on which nodes.

|Command                                                               |Purpose                                        |When to Use                            |
|----------------------------------------------------------------------|-----------------------------------------------|---------------------------------------|
|`kubectl taint node <node> key=value:NoSchedule`                      |Prevent pods without toleration from scheduling|Reserve nodes for specific workloads   |
|`kubectl taint node <node> key=value:NoSchedule-`                     |Remove a taint from a node                     |Re-open node to all pods               |
|`kubectl describe node <node> | grep Taints`                          |Check what taints are on a node                |Debug why pods won’t schedule on a node|
|`kubectl get pods -n production -o wide`                              |See which node each pod landed on              |Verify affinity rules are working      |
|`kubectl describe pod <pod> -n production | grep -A5 "Node-Selectors"`|See node selectors applied to pod              |Debug pod not scheduling on right node |

-----

## 18. Advanced Debugging

> When basic logs and describe aren’t enough.

|Command                                                                                                       |Purpose                                      |When to Use                                     |
|--------------------------------------------------------------------------------------------------------------|---------------------------------------------|------------------------------------------------|
|`kubectl get pod <pod> -n production -o yaml | grep -A5 "conditions"`                                         |Check pod conditions in detail               |Understand why pod isn’t ready                  |
|`kubectl get pod <pod> -n production -o jsonpath='{.status.conditions}'`                                      |Get conditions as JSON                       |Script-friendly condition check                 |
|`kubectl describe pod <pod> -n production | grep -A 20 "Events:"`                                             |Only show events section                     |Focus on what Kubernetes is doing with the pod  |
|`kubectl get pod <pod> -n production -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'`|Get reason for last termination              |Understand why container crashed                |
|`kubectl get pod <pod> -n production -o jsonpath='{.status.containerStatuses[0].restartCount}'`               |Get restart count of a container             |Know how many times pod has crashed             |
|`kubectl debug -it <pod> --image=busybox --copy-to=debug-pod -n production`                                   |Copy a failing pod and attach debug container|Debug without disturbing the original pod       |
|`kubectl get events -n production --field-selector involvedObject.name=<pod-name>`                            |Events for a specific pod only               |Focused event history for one pod               |
|`kubectl proxy`                                                                                               |Opens local proxy to Kubernetes API          |Access API directly in browser for debugging    |
|`kubectl get componentstatuses`                                                                               |Health of core control plane components      |Check if scheduler or controller-manager is down|

-----

## 19. Cleanup

> Clean up unused resources to free space and reduce confusion.

|Command                                                                                                      |Purpose                                           |When to Use                           |
|-------------------------------------------------------------------------------------------------------------|--------------------------------------------------|--------------------------------------|
|`kubectl delete pod <pod-name> -n production`                                                                |Delete a specific pod (deployment will restart it)|Force restart a stuck pod             |
|`kubectl delete pods --all -n staging`                                                                       |Delete all pods in a namespace                    |Force full restart of all pods        |
|`kubectl delete pod <pod> -n production --grace-period=0 --force`                                            |Force delete a stuck pod immediately              |When pod is stuck in Terminating state|
|`kubectl get pods -n production | grep Evicted | awk '{print $1}' | xargs kubectl delete pod -n production`  |Delete all evicted pods                           |Cleanup after node pressure events    |
|`kubectl get pods -n production | grep Completed | awk '{print $1}' | xargs kubectl delete pod -n production`|Delete completed job pods                         |Housekeeping                          |
|`kubectl delete all --all -n staging`                                                                        |Delete everything in a namespace                  |Wipe out a staging environment        |
|`kubectl delete namespace staging`                                                                           |Delete namespace and all its resources            |Full environment teardown             |

-----

## 20. Pro Tips & Shortcuts

### Aliases — Save Time Every Day

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kns='kubectl config set-context --current --namespace'
```

-----

### Output Formats

|Flag                      |Format                        |Use Case                                  |
|--------------------------|------------------------------|------------------------------------------|
|`-o wide`                 |Extended table                |More columns — node, IP                   |
|`-o yaml`                 |YAML                          |Full spec — great for copying or comparing|
|`-o json`                 |JSON                          |Script-friendly — pipe to jq              |
|`-o jsonpath='{.field}'`  |Specific field                |Extract one value                         |
|`-o name`                 |Resource name only            |Use in scripts                            |
|`--dry-run=client -o yaml`|Generate YAML without applying|Scaffold manifests quickly                |

-----

### Useful One-Liners

```bash
# Watch pods update in real time during a deploy
kubectl get pods -n production -w

# Get image of every running pod
kubectl get pods -n production -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Find all pods NOT in Running state
kubectl get pods -n production --field-selector=status.phase!=Running

# Get all resource limits across all pods
kubectl get pods -n production -o json | jq '.items[].spec.containers[].resources'

# Check which pods are on which node
kubectl get pods -n production -o wide | awk '{print $1, $7}'

# Force restart all pods in a deployment
kubectl rollout restart deployment/myapp -n production

# Copy a file from pod to local machine
kubectl cp production/<pod-name>:/app/logs/app.log ./app.log

# Copy a file from local machine into a pod
kubectl cp ./config.json production/<pod-name>:/app/config.json

# Get all images running across the cluster
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq
```

-----

### Debugging Decision Tree

```
Pod not working?
     │
     ├── kubectl get pods           → check STATUS column
     │
     ├── STATUS = Pending?
     │     └── kubectl describe pod → check Events for scheduling failure
     │                              → node resources? PVC not bound? Taint?
     │
     ├── STATUS = CrashLoopBackOff?
     │     └── kubectl logs --previous → see why it crashed last time
     │
     ├── STATUS = ImagePullBackOff?
     │     └── kubectl describe pod → check image name, tag, ECR permissions
     │
     ├── STATUS = Running but not working?
     │     ├── kubectl logs -f       → check for app errors
     │     ├── kubectl exec -it -- sh → get inside and test manually
     │     └── kubectl port-forward  → test locally
     │
     └── Service not reachable?
           ├── kubectl get endpoints → are pods registered?
           ├── kubectl describe svc  → check selector matches pod labels
           └── kubectl exec -- curl  → test from inside cluster
```

-----

> **Golden rule in production:**
> Always run `kubectl config current-context` before any command.
> One wrong context = commands running against the wrong cluster.