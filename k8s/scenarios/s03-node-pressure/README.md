# Scenario 03 — Node Under Pressure / Pod Eviction

## Customer Complaint

> "Our pods keep getting evicted. We're not doing anything different. Is something wrong with your nodes?"

## Concept (OrbStack/minikube simulation note)

In a real cluster, node pressure evicts pods when node RAM, disk, or PIDs are exhausted. In minikube/OrbStack, we can simulate this by deploying pods that consume large amounts of memory and watching the scheduler/kubelet respond.

## Setup

```bash
kubectl create namespace s03

# Apply a pod that simulates a memory-hungry workload
kubectl apply -f simulate.sh -n s03   # see simulate.sh for manual steps

# Alternative: apply the heavy pod manually
kubectl apply -f - -n s03 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
spec:
  containers:
    - name: hog
      image: polinux/stress
      command: ["stress"]
      args: ["--vm", "1", "--vm-bytes", "500M", "--vm-hang", "0"]
      resources:
        limits:
          memory: 600Mi
        requests:
          memory: 500Mi
EOF
```

## What to Practice

In this scenario, study and understand:
1. How node conditions (`MemoryPressure`, `DiskPressure`, `PIDPressure`) are reported
2. How kubelet eviction policy works (soft vs. hard eviction thresholds)
3. What gets evicted first (QoS classes: BestEffort → Burstable → Guaranteed)
4. How to read node conditions and events

## Practice Commands

```bash
# Node conditions
kubectl get nodes
kubectl describe node $(kubectl get node -o jsonpath='{.items[0].metadata.name}')

# Watch for pod eviction events
kubectl get events -A --sort-by=.lastTimestamp | grep -i evict

# QoS class of pods
kubectl get pods -n s03 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}'

# Pod priority and QoS
# BestEffort: no requests/limits set → evicted FIRST
# Burstable: requests < limits or only some set
# Guaranteed: requests == limits for all containers → evicted LAST
```

## Teardown

```bash
kubectl delete namespace s03
```
