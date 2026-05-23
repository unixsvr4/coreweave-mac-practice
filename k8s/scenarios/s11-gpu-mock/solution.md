# Solution — Scenario 11: GPU Workload Debugging

## Full Debugging Flow (memorize this for the interview)

```bash
# Step 1: Check pod state
kubectl get pods -n s11
# llm-trainer-XXXXX   0/1   Pending   0   10m

# Step 2: Describe — scheduler message is key
kubectl describe pod -n s11 -l app=llm-trainer
# Events:
#   Warning  FailedScheduling  ...
#   0/N nodes available:
#     N node(s) didn't match Pod's node affinity/selector (nvidia.com/gpu.product=NVIDIA-H100-SXM5-80GB)
#     N Insufficient nvidia.com/gpu
#   → Two separate problems OR just "no H100 nodes exist"

# Step 3: Check what GPU nodes exist
kubectl get nodes -l nvidia.com/gpu.present=true
# (none in minikube — but in real CoreWeave:)
kubectl get nodes -l nvidia.com/gpu.product=NVIDIA-H100-SXM5-80GB
# Check if H100 nodes exist AND are schedulable

# Step 4: Check GPU allocatable on H100 nodes
kubectl get nodes -l nvidia.com/gpu.product=NVIDIA-H100-SXM5-80GB \
  -o custom-columns="NAME:.metadata.name,GPU:.status.allocatable['nvidia.com/gpu']"

# Step 5: Check what's consuming GPUs
kubectl get pods -A -o json | jq '.items[] | 
  select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) |
  {pod:.metadata.name, ns:.metadata.namespace, gpu:.spec.containers[0].resources.limits."nvidia.com/gpu"}'

# Step 6: Check namespace GPU quota
kubectl describe resourcequota gpu-quota -n s11
# requests.nvidia.com/gpu: 0/8 used  ← quota fine, problem is no physical GPUs

# Step 7: Check GPU operator health (if it exists)
kubectl get pods -n gpu-operator
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset | tail -20

# Step 8: Check node taints
kubectl get nodes -o json | jq '.items[] | {node:.metadata.name, taints:.spec.taints}'
# If GPU nodes have nvidia.com/gpu=true:NoSchedule taint,
# the pod toleration must match exactly

# Step 9: Check if GPU driver is loaded on the node
kubectl debug node/<gpu-node> -it --image=busybox
# > nsenter -t 1 -m -u -i -n -- sh
# > ls /dev/nvidia*     ← should show /dev/nvidia0 /dev/nvidia1 etc.
# > nvidia-smi          ← if not found: driver not loaded
```

## Diagnosis Decision Tree

```
Pod Pending with GPU request
    │
    ├─ "Insufficient nvidia.com/gpu"
    │       → All GPUs allocated to other jobs
    │       → Check: who has GPUs? kubectl get pods -A with GPU labels
    │       → Fix: wait for jobs to finish, or preempt with higher priority
    │
    ├─ "node(s) didn't match node affinity/selector"
    │       → nodeSelector for GPU model that doesn't exist in cluster
    │       → Fix: check kubectl get nodes --show-labels, correct nodeSelector
    │
    ├─ "node(s) had taint not tolerated"
    │       → GPU node tainted but pod has no matching toleration
    │       → Fix: add tolerations to pod spec
    │
    ├─ Quota exceeded
    │       → kubectl describe resourcequota shows GPU at limit
    │       → Fix: scale down other jobs, or request quota increase
    │
    └─ GPU device plugin not running
            → GPU nodes exist but nvidia.com/gpu shows 0 allocatable
            → kubectl get pods -n gpu-operator → device plugin crashed?
            → Fix: restart device plugin DaemonSet
```

## What to Tell the Customer (P1 scenario)

> "I've immediately picked up your escalation. Your pods are pending because [specific scheduler message]. I'm checking GPU node availability across your allocated infrastructure now. [Based on findings:] All 8 of your H100 nodes are currently allocated — your existing `batch-job-X` is consuming all available GPUs. You have two options: (1) wait ~40 minutes for that job to complete, or (2) terminate it early — please confirm which you prefer. While we resolve this, I'll monitor your new pods every 5 minutes and update you. I'll also set up a GPU utilization alert in Grafana so you're notified before you hit capacity next time."

## Key Interview Points

1. **GPUs must be in `limits` not just `requests`** — unlike CPU/memory, GPU requests and limits must be equal
2. **NVIDIA device plugin** advertises GPUs; if it crashes, GPUs disappear from allocatable
3. **Toleration is required** if GPU nodes have `nvidia.com/gpu=NoSchedule` taint
4. **NCCL_IB_DISABLE=0** enables InfiniBand for distributed training — mention this
5. **CUDA_VISIBLE_DEVICES** controls which GPUs the process sees inside the container
6. **Node must have GPU driver loaded** — NVIDIA GPU Operator handles this automatically
