# Solution — Scenario 03: Node Pressure / Pod Eviction

## How Node Pressure Works

```
kubelet monitors:
  memory.available < evictionHard.memory.available (default: 100Mi)
  nodefs.available < evictionHard.nodefs.available (default: 10%)
  nodefs.inodesFree < evictionHard.nodefs.inodesFree (default: 5%)
  imagefs.available < evictionHard.imagefs.available (default: 15%)

When threshold crossed:
  1. kubelet marks node condition: MemoryPressure=True
  2. Scheduler stops placing new pods on node
  3. kubelet begins evicting pods (BestEffort first, then Burstable)
  4. If still under pressure: evict Guaranteed pods (last resort)
```

## Debugging Commands

```bash
# Node conditions
kubectl describe node <node>
# Conditions:
#   Type              Status    Message
#   MemoryPressure    True      kubelet has insufficient memory.
#   DiskPressure      False     ...
#   PIDPressure       False     ...
#   Ready             False     ...  (if pressure is severe enough)

# Eviction events
kubectl get events -A --sort-by=.lastTimestamp | grep -i "evict\|pressure"

# What pods were evicted
kubectl get pods -A --field-selector=status.phase=Failed | grep Evicted

# Node resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Detailed allocatable vs requested
kubectl describe node <node> | grep -A 15 "Allocated resources"
```

## Root Cause Categories

| Node Condition | Cause | Fix |
|----------------|-------|-----|
| `MemoryPressure` | Pods using too much RAM | Right-size limits, add nodes, check for memory leaks |
| `DiskPressure` | Disk full | Clean up images (`docker system prune`), rotate logs, expand disk |
| `PIDPressure` | Too many processes (fork bombs, container spawning too many procs) | Set `resources.limits.pids`, restart container |

## QoS Classes (eviction priority — worst first)

```yaml
# BestEffort (evicted first): no resources specified at all
spec:
  containers:
    - name: app
      image: nginx

# Burstable: requests != limits, or only partial resources set
spec:
  containers:
    - name: app
      resources:
        requests: {memory: 100Mi}
        limits: {memory: 200Mi}

# Guaranteed (evicted last): requests == limits for CPU AND memory
spec:
  containers:
    - name: app
      resources:
        requests: {memory: 200Mi, cpu: "1"}
        limits: {memory: 200Mi, cpu: "1"}
```

## What to Tell the Customer

> "Your pods are being evicted because the node is experiencing MemoryPressure — available memory dropped below the kubelet's eviction threshold. This happens when the total memory requested by pods on the node exceeds available RAM. Your pods are classified as 'Burstable' QoS class, making them candidates for eviction. To prevent this: (1) Set resource requests equal to limits to achieve 'Guaranteed' QoS — these are the last to be evicted. (2) Spread your workload across more nodes. (3) Consider enabling VPA (Vertical Pod Autoscaler) to automatically right-size your pods based on actual usage."

## Prevent Future Eviction

```yaml
# Use Guaranteed QoS for critical pods
resources:
  requests:
    memory: 4Gi
    cpu: "2"
  limits:
    memory: 4Gi    # same as requests = Guaranteed
    cpu: "2"

# Set PodDisruptionBudget to prevent too many evictions at once
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
```
