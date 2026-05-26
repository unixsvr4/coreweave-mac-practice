# Solution — Scenario 02: OOMKilled

## Debugging Steps

```bash
# Step 1: Check pod state after it gets killed
kubectl get pod data-processor -n s02
# NAME             READY   STATUS      RESTARTS   AGE
# data-processor   0/1     OOMKilled   2          90s

# Step 2: Describe to see Last State
kubectl describe pod data-processor -n s02
# Containers:
#   processor:
#     ...
#     Last State:  Terminated
#       Reason:    OOMKilled
#       Exit Code: 137
#       ...
# → exit code 137 = killed by signal 9 (SIGKILL from kernel OOM killer)

# Step 3: Check current resource limits
kubectl describe pod data-processor -n s02 | grep -A 5 Limits
# Limits:
#   cpu:     500m
#   memory:  64Mi      ← WAY too low

# Step 4: Check actual memory usage while running
# NOTE (OrbStack): this pod crashes in ~4s — too fast for metrics-server to scrape.
# kubectl top will return NotFound. That's expected. Skip to Step 5.
# On a real cluster with a slower OOM, you'd see:
#   kubectl top pod data-processor -n s02
#   NAME             CPU(cores)   MEMORY(bytes)
#   data-processor   210m         61Mi          ← at limit and climbing

# Step 5: Check kernel OOM logs
# On Linux host:   sudo dmesg | grep -i oom
# On Mac/OrbStack: kubectl debug node/orbstack -it --image=busybox -- chroot /host dmesg | grep -i oom
kubectl debug node/orbstack -it --image=busybox -- chroot /host dmesg | grep -i oom
# [448506.163662] python3 invoked oom-killer: gfp_mask=...
# [448506.164657] Memory cgroup out of memory: Killed process ... (python3) anon-rss:65276kB oom_score_adj:996
# This confirms the kernel cgroup OOM killer terminated the process

# Step 6: Determine how much memory the job actually needs
# From the code: 300 × 1MB chunks = ~300MB minimum
# Add overhead: Python runtime ~50MB, safety margin 25%
# Recommended: 512Mi

# Fix: pods are immutable on resources — must delete and recreate
# See "Fixed YAML" section below for the full apply command
kubectl delete pod data-processor -n s02
```

## Root Cause

The container's memory limit (64Mi) is far below what the data processing job needs (~300MB). When Python allocates more memory than the cgroup limit allows, the Linux OOM killer terminates the process with SIGKILL (exit code 137).

## Fix — Proper Resource Sizing

```yaml
resources:
  requests:
    memory: 384Mi   # Scheduler uses this for placement
    cpu: 100m
  limits:
    memory: 512Mi   # Container hard limit — ~30% buffer above expected usage
    cpu: 500m
```

## Fixed YAML (delete old pod, apply new)

```bash
kubectl delete pod data-processor -n s02
kubectl apply -f - -n s02 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: data-processor
spec:
  restartPolicy: Always
  containers:
    - name: processor
      image: python:3.11-slim
      command: ["/bin/sh", "-c"]
      args:
        - |
          python3 -c "
          import time
          data = []
          for i in range(300):
              data.append(bytearray(1024*1024))
              print(f'Loaded {i+1}MB')
              time.sleep(0.05)
          print('Done')
          time.sleep(3600)
          "
      resources:
        requests:
          memory: 384Mi
          cpu: 100m
        limits:
          memory: 512Mi
          cpu: 500m
EOF
```

## What to Tell the Customer

> "The pod is being killed by the Linux kernel's OOM (Out-Of-Memory) killer — exit code 137 confirms this. It's not a hardware issue. Your container has a memory limit of 64Mi but the data processing job allocates ~300MB. I've increased the limit to 512Mi with a 30% safety buffer. To right-size your containers going forward, I recommend running without a memory limit first to measure peak RSS, then set the limit 20-30% above peak. We can also set up a Grafana alert when memory utilization exceeds 80% of the limit to catch this before it crashes."

## Key Takeaway

Exit code 137 = OOM kill (128 + signal 9). Always check `kubectl describe pod` → "Last State: Terminated: Reason: OOMKilled". For GPU training jobs on CoreWeave, this can also mean **GPU memory OOM** (CUDA error) — different from host memory OOM. GPU OOM shows in container logs as `RuntimeError: CUDA out of memory` before the process exits.
