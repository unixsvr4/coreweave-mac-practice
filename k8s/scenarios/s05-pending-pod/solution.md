# Solution — Scenario 05: Pod Stuck Pending

## Debugging Steps

```bash
# Step 1: Check pod states
kubectl get pods -n s05
# NAME                   READY   STATUS    RESTARTS   AGE
# training-job-main      0/1     Pending   0          5m
# training-job-worker    0/1     Pending   0          5m

# Step 2: Describe each pod — Events will have the scheduler message

# Pod 1:
kubectl describe pod training-job-main -n s05
# Events:
#   Warning  FailedScheduling  ...  0/1 nodes are available:
#            1 Insufficient nvidia.com/gpu.
#            preemption: 0/1 nodes are available: 1 No preemption victims found.
# → Requesting 999 GPUs — no node can satisfy this

# Pod 2:
kubectl describe pod training-job-worker -n s05
# Events:
#   Warning  FailedScheduling  ...  0/1 nodes are available:
#            1 node(s) didn't match Pod's node affinity/selector.
# → nodeSelector for H200 GPUs, but no such node exists

# Step 3: Check what GPU nodes exist
kubectl get nodes --show-labels | grep nvidia
# (no nvidia labels on minikube/OrbStack nodes)

# Step 4: Check actual GPU availability across all nodes
kubectl describe nodes | grep -A 5 "Allocatable:"
```

## Root Causes

**Pod 1 (training-job-main)**: Requests `nvidia.com/gpu: 999` — no single node in the cluster has 999 GPUs.

**Pod 2 (training-job-worker)**: `nodeSelector` requires a node with label `nvidia.com/gpu.product=NVIDIA-H200-SXM5-141GB`. No such node exists (H200 may not be deployed, or this is a minikube practice cluster with no GPUs).

## Fixes

```bash
# Fix Pod 1: reduce GPU request to a realistic number
# In real CoreWeave: ask customer how many GPUs their job actually needs
# For practice: remove GPU request entirely (minikube has no GPUs)
kubectl delete pod training-job-main -n s05
kubectl apply -f - -n s05 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: training-job-main
spec:
  restartPolicy: Never
  containers:
    - name: trainer
      image: busybox:1.36
      command: ["sleep", "3600"]
      resources:
        limits: {cpu: "2", memory: 4Gi}
        requests: {cpu: "2", memory: 4Gi}
EOF

# Fix Pod 2: remove or correct the nodeSelector
kubectl delete pod training-job-worker -n s05
kubectl apply -f - -n s05 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: training-job-worker
spec:
  restartPolicy: Never
  containers:
    - name: trainer
      image: busybox:1.36
      command: ["sleep", "3600"]
      resources:
        limits: {cpu: "2", memory: 4Gi}
        requests: {cpu: "2", memory: 4Gi}
  # nodeSelector removed — or set to an existing label
EOF
```

## What to Tell the Customer

> "We found two issues. First, `training-job-main` requests 999 GPUs — please confirm the actual GPU count needed. Second, `training-job-worker` has a nodeSelector for H200 GPUs (`nvidia.com/gpu.product=NVIDIA-H200-SXM5-141GB`) but your current allocation is on A100 nodes. Either update the nodeSelector to match your allocated GPU type, or remove it to let the scheduler place it on any available GPU node. Once corrected, your jobs should schedule immediately. For next time, use `kubectl describe pod` right away — the scheduler message will tell you exactly what's missing."

## Check Available GPU Types (Real CoreWeave)

```bash
kubectl get nodes -l nvidia.com/gpu.present=true -o custom-columns=\
"NAME:.metadata.name,GPU:.metadata.labels['nvidia\.com/gpu\.product'],COUNT:.status.allocatable['nvidia\.com/gpu']"
```
