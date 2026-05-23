# kubectl Debugging — Complete Cheatsheet

## Pod Lifecycle Debugging

```bash
# Quick state overview
kubectl get pods -n <ns> -o wide
kubectl get pods -A --field-selector=status.phase!=Running

# Describe: Events section is always the first thing to check
kubectl describe pod <pod> -n <ns>

# Logs — current and previous container instance
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous          # after CrashLoop restart
kubectl logs <pod> -n <ns> -c <container>      # multi-container pod
kubectl logs <pod> -n <ns> --tail=100 -f       # follow

# Interactive debug (K8s 1.23+)
kubectl debug pod/<pod> -it --image=busybox --copy-to=debug-pod
kubectl debug pod/<pod> -it --image=nicolaka/netshoot  # network tools

# Exec into running container
kubectl exec -it <pod> -n <ns> -- /bin/sh
kubectl exec -it <pod> -n <ns> -c <container> -- bash

# Events — cluster-wide timeline (sort newest last)
kubectl get events -n <ns> --sort-by=.lastTimestamp
kubectl get events -A --sort-by=.lastTimestamp | tail -30
```

## Pod States — What Each Means

| State | Cause | First command |
|-------|-------|---------------|
| `CrashLoopBackOff` | Container starting then dying | `kubectl logs <pod> --previous` |
| `OOMKilled` | Memory limit exceeded | `kubectl describe pod` → Last State exit code 137 |
| `ImagePullBackOff` | Can't pull image | `kubectl describe pod` → Events |
| `ErrImagePull` | Same as above, first attempt | `kubectl describe pod` → Events |
| `Pending` | Scheduler can't place it | `kubectl describe pod` → Events for Unschedulable |
| `Init:0/1` | Init container failing | `kubectl logs <pod> -c <init-container-name>` |
| `CreateContainerConfigError` | Missing ConfigMap/Secret | `kubectl describe pod` → Events |
| `Terminating` | Stuck finalizer or node gone | `kubectl delete pod --grace-period=0 --force` |

## Node Debugging

```bash
# Node overview
kubectl get nodes -o wide
kubectl get nodes --show-labels

# Node conditions
kubectl describe node <node>
# Look for: MemoryPressure, DiskPressure, PIDPressure, Ready=False

# What's running on a node
kubectl get pods -A --field-selector spec.nodeName=<node>

# Resource usage on nodes
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Debug a node directly (creates a privileged pod on the node)
kubectl debug node/<node> -it --image=busybox
# Inside: chroot /host to access node filesystem

# Cordon/uncordon for maintenance
kubectl cordon <node>
kubectl uncordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

## Resource Debugging

```bash
# Check resource requests/limits on pods
kubectl get pods -n <ns> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'

# Check allocatable vs requested on nodes
kubectl describe node <node> | grep -A 10 "Allocated resources"

# Resource quotas in namespace
kubectl get resourcequota -n <ns>
kubectl describe resourcequota -n <ns>

# LimitRange defaults
kubectl get limitrange -n <ns> -o yaml

# Pods that have no resource limits (dangerous on shared clusters)
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name'
```

## Service & Endpoint Debugging

```bash
# Service → endpoints chain
kubectl get svc,endpoints -n <ns>
# If ENDPOINTS shows <none>, the selector is wrong or no pods are Ready

# Check service selector vs pod labels
kubectl get svc <svc> -n <ns> -o jsonpath='{.spec.selector}'
kubectl get pods -n <ns> --show-labels

# Port-forward to test directly
kubectl port-forward svc/<svc> 8080:80 -n <ns>
kubectl port-forward pod/<pod> 8080:8080 -n <ns>

# Test DNS from inside a debug pod
kubectl run debug --image=busybox --rm -it -n <ns> -- nslookup <svc>
kubectl run debug --image=busybox --rm -it -n <ns> -- nslookup <svc>.<ns>.svc.cluster.local
kubectl run debug --image=nicolaka/netshoot --rm -it -- dig <svc>.<ns>.svc.cluster.local

# Test HTTP from inside cluster
kubectl run debug --image=curlimages/curl --rm -it -- curl -v http://<svc>.<ns>:80/
```

## Storage Debugging

```bash
# PVC status
kubectl get pvc -n <ns>
# Pending = can't find matching PV or StorageClass doesn't exist
# Bound = healthy

kubectl describe pvc <pvc> -n <ns>
# Events will tell you: no matching StorageClass, access mode conflict, etc.

# PersistentVolumes (cluster-scoped)
kubectl get pv
kubectl describe pv <pv>

# StorageClasses available
kubectl get storageclass
kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}'

# Check if volume is mounted in pod
kubectl exec <pod> -- df -h
kubectl exec <pod> -- ls -la /mnt/data
```

## GPU / HPC Debugging

```bash
# GPU nodes
kubectl get nodes -l nvidia.com/gpu.present=true
kubectl describe node <gpu-node> | grep -A 10 "nvidia.com"

# GPU resource in pods
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) | {name:.metadata.name, ns:.metadata.namespace, gpu:.spec.containers[].resources.limits."nvidia.com/gpu"}'

# NVIDIA device plugin pods (should be Running on each GPU node)
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset
kubectl logs -n kube-system -l app=nvidia-device-plugin-daemonset

# GPU Operator components
kubectl get pods -n gpu-operator
kubectl get pods -n gpu-operator-resources

# Check if nvidia-smi works on a GPU node
kubectl debug node/<gpu-node> -it --image=busybox
# Inside: nsenter -t 1 -m -u -i -n -p -- nvidia-smi

# Priority classes for HPC workloads
kubectl get priorityclasses
kubectl describe priorityclass high-priority

# Check if pod is preempting others
kubectl get events -A | grep "Preempted\|preempt"
```

## RBAC / Permission Debugging

```bash
# What can a serviceaccount do?
kubectl auth can-i list pods --as=system:serviceaccount:<ns>:<sa>
kubectl auth can-i create deployments --as=system:serviceaccount:<ns>:<sa> -n <ns>

# Check all permissions for a SA
kubectl get rolebinding,clusterrolebinding -A -o json | jq '.items[] | select(.subjects[]?.name=="<sa>" and .subjects[]?.namespace=="<ns>")'

# Impersonate a user to debug
kubectl get pods --as=<user>
kubectl auth can-i --list --as=<user>
```

## ConfigMap / Secret Debugging

```bash
# List
kubectl get configmap,secret -n <ns>

# Check mounted ConfigMap in pod
kubectl exec <pod> -- cat /etc/config/mykey
kubectl exec <pod> -- env | grep MY_VAR

# Decode a secret
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.password}' | base64 -d

# Check secret is projected correctly
kubectl describe pod <pod> | grep -A 5 "Volumes\|Mounts"
```

## Useful Aliases to Mentally Remember

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'

# Get all resources in a namespace (great for audit)
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get -n <ns> --show-kind --ignore-not-found 2>/dev/null
```

## CoreWeave-specific Operators/CRDs to Know

```bash
# VirtualServer (if they use Nginx Ingress Controller)
kubectl get virtualserver -A

# GPU workload CRDs
kubectl get crd | grep nvidia
kubectl get crd | grep gpu

# Check node GPU allocation
kubectl get nodes -o json | jq '.items[] | {node:.metadata.name, gpu_allocatable:.status.allocatable."nvidia.com/gpu", gpu_capacity:.status.capacity."nvidia.com/gpu"}'
```
