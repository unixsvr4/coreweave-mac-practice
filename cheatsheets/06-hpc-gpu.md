# HPC / GPU Kubernetes — CoreWeave Cheatsheet

## GPU Scheduling in Kubernetes

### How GPU Scheduling Works
```
Customer pod requests: resources.limits."nvidia.com/gpu": 1
         ↓
Kubernetes scheduler: finds node where nvidia.com/gpu allocatable >= 1
         ↓
NVIDIA Device Plugin (DaemonSet on each GPU node):
  - Advertises GPU resources to kubelet
  - Allocates specific GPU devices (e.g., /dev/nvidia0)
  - Mounts GPU device into container
         ↓
Container can call nvidia-smi / CUDA APIs
```

### GPU Pod Spec

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-training-job
spec:
  restartPolicy: Never
  containers:
    - name: trainer
      image: nvcr.io/nvidia/pytorch:24.01-py3
      resources:
        limits:
          nvidia.com/gpu: 2      # Request 2 GPUs — MUST be in limits, not requests
          memory: 32Gi
          cpu: "8"
        requests:
          memory: 32Gi
          cpu: "8"
      env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0,1"
        - name: NCCL_DEBUG
          value: INFO            # Enable NCCL debug logging for distributed training
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule         # Required if GPU nodes are tainted
  nodeSelector:
    nvidia.com/gpu.product: NVIDIA-A100-SXM4-80GB  # Pin to specific GPU model
```

### Priority Classes for HPC

```yaml
# High priority for customer production training jobs
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-high-priority
value: 1000000        # Higher = higher priority
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "For production GPU training jobs"

---
# Low priority for batch/dev jobs
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-low-priority
value: 100
globalDefault: false
preemptionPolicy: Never
description: "For development/batch GPU jobs"
```

### GPU Resource Quota (per namespace)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: customer-a
spec:
  hard:
    requests.cpu: "64"
    requests.memory: 512Gi
    limits.cpu: "128"
    limits.memory: 1Ti
    requests.nvidia.com/gpu: "16"   # Customer has 16 GPUs allocated
    limits.nvidia.com/gpu: "16"
```

## NVIDIA GPU Operator

The GPU Operator automates setup of all NVIDIA components on each node:
- GPU Driver (kernel module)
- NVIDIA Container Toolkit (for Docker/containerd)
- NVIDIA Device Plugin (advertises GPUs to k8s)
- DCGM Exporter (Prometheus metrics)
- GPU Feature Discovery (labels nodes with GPU attributes)

```bash
# Check GPU Operator health
kubectl get pods -n gpu-operator
# All pods should be Running

# GPU node labels added by Feature Discovery
kubectl get node <gpu-node> --show-labels | grep nvidia
# nvidia.com/gpu.present=true
# nvidia.com/gpu.product=NVIDIA-H100-SXM5-80GB
# nvidia.com/gpu.count=8
# nvidia.com/mig.strategy=none

# DCGM exporter (GPU metrics for Prometheus)
kubectl get pods -n gpu-operator -l app=dcgm-exporter
kubectl logs -n gpu-operator -l app=dcgm-exporter

# Device plugin logs
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset
```

## GPU Debugging Scenarios

### Customer: "My GPU job is stuck in Pending"

```bash
kubectl describe pod <pod>
# Check Events for:
# "0/N nodes are available: N Insufficient nvidia.com/gpu"
# → All GPUs allocated to other jobs, or no GPU nodes exist

# Check GPU availability
kubectl get nodes -l nvidia.com/gpu.present=true -o custom-columns="NAME:.metadata.name,GPU:.status.allocatable['nvidia.com/gpu']"

# Check what's consuming GPUs
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) | {pod:.metadata.name, ns:.metadata.namespace, gpus:.spec.containers[0].resources.limits."nvidia.com/gpu"}'

# Solution: customer needs to wait, or free up GPUs from another job
# OR: check if pod has a nodeSelector that's too restrictive
```

### Customer: "GPU job is running but training is much slower than expected"

```bash
# Check GPU utilization
kubectl exec <pod> -- nvidia-smi
# Low GPU utilization = CPU-bound data loading, not GPU-bound training

# Check NCCL for distributed training
kubectl logs <pod> | grep NCCL
# NCCL errors indicate communication issues between GPUs/nodes

# Check GPU temperature (thermal throttling)
kubectl exec <pod> -- nvidia-smi dmon -d 1   # continuous monitoring
# If temp > 83°C on H100, it may throttle → Prometheus alert threshold

# Check NVLink status (for multi-GPU same-node jobs)
kubectl exec <pod> -- nvidia-smi nvlink --status

# Check InfiniBand for multi-node jobs
kubectl debug node/<gpu-node> -it --image=nicolaka/netshoot
# > ibstat | grep Active
# > ib_write_bw --use_cuda=0 <peer-node-ip>  # bandwidth test
```

### Customer: "CUDA out of memory error"

```bash
kubectl logs <pod> | grep "CUDA out of memory\|RuntimeError"
# This is an application-level error — GPU memory limit exceeded by model

# Check GPU memory usage
kubectl exec <pod> -- nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Solution options for customer:
# 1. Reduce batch size
# 2. Enable gradient checkpointing
# 3. Use mixed precision (FP16/BF16) 
# 4. Use a larger GPU (A100 80GB instead of 40GB)
# 5. Use MIG (Multi-Instance GPU) — partition a single GPU
```

## MIG (Multi-Instance GPU) — A100/H100

MIG allows partitioning a single GPU into smaller isolated instances.

```bash
# A100 80GB MIG profiles
# 7 × 1g.10gb  (10GB each)
# 4 × 2g.20gb  (20GB each)
# 3 × 3g.40gb  (40GB each, 40 TFLOPS)
# 1 × 7g.80gb  (full GPU)

# Enable MIG on a node (requires GPU Operator)
kubectl label node <gpu-node> nvidia.com/mig.strategy=mixed

# MIG instances show as separate allocatable resources
kubectl get node <gpu-node> -o json | jq '.status.allocatable | keys | map(select(startswith("nvidia")))'
# Shows: ["nvidia.com/gpu", "nvidia.com/mig-1g.10gb", "nvidia.com/mig-2g.20gb"]
```

## HPC Job Patterns

### MPI Job (distributed training across nodes)

```yaml
# Requires MPI Operator (kubeflow/mpi-operator)
apiVersion: kubeflow.org/v1
kind: MPIJob
metadata:
  name: train-gpt
spec:
  slotsPerWorker: 8           # 8 GPUs per worker node
  runPolicy:
    cleanPodPolicy: Running
    backoffLimit: 2
  mpiReplicaSpecs:
    Launcher:
      replicas: 1
      template:
        spec:
          containers:
            - name: mpi-launcher
              image: nvcr.io/nvidia/pytorch:24.01-py3
              command: ["mpirun", "-np", "16", "python", "train.py"]
    Worker:
      replicas: 2             # 2 nodes × 8 GPUs = 16 total
      template:
        spec:
          containers:
            - name: mpi-worker
              image: nvcr.io/nvidia/pytorch:24.01-py3
              resources:
                limits:
                  nvidia.com/gpu: 8
```

## Key Concepts to Mention in Interview

1. **GPU affinity vs. CPU affinity**: GPU workloads need GPU-specific node selection, not just any node
2. **Preemption**: High-priority training jobs can preempt lower-priority dev jobs — mention `priorityClass`
3. **GPU sharing**: MIG for memory partitioning; Timesharing for throughput sharing (CUDA timesharing)
4. **NCCL**: The communication backbone for distributed training; issues cause job hangs
5. **DCGM**: NVIDIA's data center GPU manager; exposes Prometheus metrics; critical for observability
6. **GPUDirect RDMA**: Allows GPU memory to communicate directly over InfiniBand (bypasses CPU) — used for fastest multi-node training
7. **Checkpoint recovery**: Training jobs often checkpoint periodically; if a pod dies mid-training, customer needs to know if checkpoints are intact
