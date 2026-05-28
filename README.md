# coreweave-practice

**Platforms:** Mac M1/M2/M3 (OrbStack) · Linux Ubuntu 24.04 (minikube)
**Role:** Senior Cloud Support Engineer — CoreWeave
**Screen:** 90-minute technical screen
**Deadline:** 4 days

---

## What This Repo Contains

| Directory | Contents |
|-----------|----------|
| `cheatsheets/` | 8 reference guides covering every topic the screen tests |
| `k8s/scenarios/` | 12 live debugging scenarios (broken YAML + solution) |
| `k8s/hpc/` | GPU pod spec, priority classes, resource quota examples |
| `observability/` | Grafana + Prometheus + Alertmanager stack + `promql-drill.sh` |
| `linux/` | Linux debugging exercises + system snapshot script |
| `python-api-problems/` | 5 API scripting problems — POST /shutdown, poll jobs, auth, pagination, retry |
| `python-async/` | 7 async/concurrency exercises — asyncio, threading, executors, semaphores |
| `setup/` | Tooling installers (Mac + Linux) |

---

## Prerequisites

### Mac M1/M2/M3

1. **OrbStack** — provides Docker + a real local Kubernetes cluster: https://orbstack.dev
2. **Homebrew** — package manager: https://brew.sh
3. Install all tools:
   ```bash
   bash setup/install-tools.sh
   ```
4. Install Metrics Server (required for `kubectl top` in s02):
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   kubectl patch deployment metrics-server -n kube-system --type='json' \
     -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   ```

### Linux Ubuntu 24.04

1. **Docker** — required for minikube's Docker driver:
   ```bash
   sudo apt-get update && sudo apt-get install -y docker.io
   sudo usermod -aG docker $USER && newgrp docker
   ```
2. **minikube** — local Kubernetes cluster:
   ```bash
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   minikube start --driver=docker --cpus=4 --memory=8192
   ```
3. Install all CLI tools:
   ```bash
   bash setup/install-tools-linux.sh
   ```
4. Install Metrics Server (same as Mac):
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   kubectl patch deployment metrics-server -n kube-system --type='json' \
     -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   ```

> **Note:** The `Makefile` expects the repo directory to be named `coreweave-mac-practice`. If you clone it under a different name, `make` commands will error. Rename the directory or update the `GUARD` line in the Makefile.

---

## 4-Day Study Plan

### Day 1 — Kubernetes Debugging Core

| Task | Command | Time |
|------|---------|------|
| Read interview strategy | `make cs-strategy` | 15 min |
| Read kubectl cheatsheet | `make cs-kubectl` | 20 min |
| Run scenario 01 (CrashLoop) | `make s01` | 8 min |
| Run scenario 02 (OOMKilled) | `make s02` | 8 min |
| Run scenario 04 (ImagePull) | `make s04` | 8 min |
| Run scenario 05 (Pending) | `make s05` | 8 min |
| Run scenario 12 (Init container) | `make s12` | 8 min |
| Linux CPU exercise | `make linux-cpu` | 10 min |
| Review all solutions | — | 20 min |

**End of Day 1 — Shutdown**

```bash
# Both platforms — delete scenario namespaces
make clean-scenarios

# Mac (OrbStack) — K8s keeps running in the background (low overhead)
# To stop K8s only:   orb stop k8s
# To quit completely: quit OrbStack from the macOS menu bar

# Linux (minikube) — stop the cluster, preserves state for tomorrow
minikube stop
# Hard reset (slower start tomorrow):  minikube delete --all
```

---

### Day 2 — Networking + Storage + DNS

| Task | Command | Time |
|------|---------|------|
| Read networking cheatsheet | `make cs-network` | 20 min |
| Read storage cheatsheet | `make cs-storage` | 15 min |
| Run scenario 06 (PVC Pending) | `make s06` | 8 min |
| Run scenario 07 (Svc Unreachable) | `make s07` | 8 min |
| Run scenario 08 (DNS) | `make s08` | 8 min |
| Run scenario 09 (NetworkPolicy) | `make s09` | 10 min |
| Run scenario 10 (ResourceQuota) | `make s10` | 8 min |
| Linux memory exercise | `make linux-mem` | 10 min |
| Network debug walkthrough | `make linux-net` | 15 min |

**End of Day 2 — Shutdown**

```bash
# Both platforms — delete scenario namespaces
make clean-scenarios

# Mac (OrbStack)
# To stop K8s only:   orb stop k8s
# To quit completely: quit OrbStack from the macOS menu bar

# Linux (minikube)
minikube stop
```

---

### Day 3 — GPU/HPC + Observability

| Task | Command | Time |
|------|---------|------|
| Read GPU/HPC cheatsheet | `make cs-gpu` | 25 min |
| Read PromQL cheatsheet | `make cs-promql` | 20 min |
| Read CoreWeave platform notes | `make cs-coreweave` | 20 min |
| Run scenario 11 (GPU mock) | `make s11` | 10 min |
| Start observability stack | `make obs-up` | — |
| Explore Grafana dashboard | `open http://localhost:3000` | 20 min |
| Run PromQL drill (22 live queries) | `make promql-drill` | 15 min |
| Apply HPC priority classes | `make hpc-apply` | 5 min |

> **Linux:** Replace `open http://localhost:3000` with `xdg-open http://localhost:3000` or just visit it in a browser manually.

**End of Day 3 — Shutdown**

```bash
# Both platforms — stop Grafana + Prometheus + Alertmanager (Docker containers)
make obs-down

# Both platforms — delete scenario namespaces
make clean-scenarios

# Mac (OrbStack)
# To stop K8s only:   orb stop k8s
# To quit completely: quit OrbStack from the macOS menu bar

# Linux (minikube)
minikube stop
```

---

### Day 4 — Full Mock Run

| Task | Time |
|------|------|
| Read `cheatsheets/00-interview-strategy.md` (the whole thing) | 20 min |
| Run ALL scenarios without looking at solutions first | 90 min |
| Time each one — flag any > 8 min for extra review | — |
| Practice customer communication scripts out loud | 20 min |
| Review CoreWeave platform notes + questions to ask | 15 min |
| Light review of solutions you got stuck on | 20 min |

**End of Day 4 — Full Shutdown**

```bash
# Both platforms — full cleanup
make clean-scenarios
make obs-down 2>/dev/null || true

# Remove orphaned OPA Gatekeeper webhook if present (blocks kubectl create if left behind)
kubectl delete validatingwebhookconfiguration gatekeeper-validating-webhook-configuration 2>/dev/null || true

# Mac (OrbStack) — stop or quit
orb stop k8s            # stop K8s only, keep OrbStack
# or quit OrbStack from the macOS menu bar to stop everything

# Linux (minikube) — stop or delete
minikube stop           # stop, preserves cluster state
# minikube delete --all # wipe cluster entirely (clean slate)
```

---

## Platform Behavior Reference

### OrbStack (Mac) vs minikube (Linux) vs Production Kubernetes

| Root cause | Production K8s | OrbStack (Mac) | minikube (Linux) |
|------------|---------------|----------------|-----------------|
| Missing ConfigMap/Secret volume | `ContainerCreating` stuck | `ContainerCreating` stuck | `ContainerCreating` stuck |
| Bad image / image pull fails | `ImagePullBackOff` | `ImagePullBackOff` | `ImagePullBackOff` |
| Container exits non-zero repeatedly | `CrashLoopBackOff` | `CrashLoopBackOff` | `CrashLoopBackOff` |
| OOM kill (exit 137) | `OOMKilled` → `CrashLoopBackOff` | same | same |
| No nodes match nodeSelector/taint | `Pending` | `Pending` | `Pending` |

**Key point:** `ContainerCreating` stuck = the container never started, usually a volume mount problem (missing ConfigMap, Secret, or PVC). Always check `kubectl describe pod` → Events — the error is there even before a single log line exists.

**Events expire after ~1h.** If `kubectl describe pod` shows no Events, use the fallback:
```bash
kubectl get events -n <ns> --sort-by=.lastTimestamp
```

### Node OOM Logs

| Platform | Command |
|----------|---------|
| Mac (OrbStack) | `kubectl debug node/orbstack -it --image=busybox -- chroot /host dmesg \| grep -i oom` |
| Linux (minikube) | `kubectl debug node/minikube -it --image=busybox -- chroot /host dmesg \| grep -i oom` |
| Linux (direct host) | `sudo dmesg \| grep -i oom` or `journalctl -k \| grep oom` |

### kubectl top Limitation

`kubectl top pod <name>` returns `NotFound` for pods that crash in < 15s (faster than the metrics scrape interval). This is expected on both platforms. Use `kubectl describe pod` → `Last State: OOMKilled, Exit Code: 137` instead.

---

## Quick Reference — The 5-Step Pod Debug

```bash
kubectl get pod <name> -n <ns> -o wide            # state, node, IP
kubectl describe pod <name> -n <ns>               # Events section first (expires ~1h)
kubectl get events -n <ns> --sort-by=.lastTimestamp  # use this if describe shows no Events
kubectl logs <name> -n <ns> [--previous]          # container output
kubectl debug pod/<name> -it --image=busybox      # interactive probe
```

---

## Observability Stack

```
http://localhost:3000   Grafana        (admin / admin)
http://localhost:9090   Prometheus
http://localhost:9093   Alertmanager
http://localhost:9100   node-exporter metrics
```

Start: `make obs-up`
Stop: `make obs-down`

Pre-built dashboard: **CoreWeave Practice — K8s & Node Overview**

---

## All Make Commands

```bash
make install           # Mac: Install kubectl, helm, k9s, kubectx, jq, stern via Homebrew
make k8s-status        # Show cluster state

# Scenarios
make s01               # CrashLoopBackOff
make s02               # OOMKilled
make s03               # Node pressure (conceptual)
make s04               # ImagePullBackOff
make s05               # Pending pod (GPU + nodeSelector)
make s06               # PVC Pending
make s07               # Service unreachable
make s08               # DNS failure
make s09               # NetworkPolicy blocks all
make s10               # ResourceQuota exceeded
make s11               # GPU workload mock
make s12               # Init container failing
make clean-scenarios   # Delete all scenario namespaces
make all-scenarios     # Deploy all at once

# Linux
make linux-cpu         # CPU spike exercise
make linux-mem         # Memory pressure exercise
make linux-net         # Network debugging walkthrough
make linux-snapshot    # Full system debug snapshot

# Observability
make obs-up            # Start Grafana + Prometheus
make obs-down          # Stop the stack
make promql-drill      # Run 22 PromQL queries against live Prometheus + print results

# HPC
make hpc-apply         # Apply priority classes to cluster
make hpc-status        # Show GPU node status

# Cheatsheets (open in less)
make cs-strategy       # Interview strategy
make cs-kubectl        # kubectl debug commands
make cs-linux          # Linux debugging
make cs-network        # Networking
make cs-storage        # Storage/PVC
make cs-promql         # Prometheus PromQL + Grafana
make cs-gpu            # HPC/GPU Kubernetes
make cs-coreweave      # CoreWeave platform

# Python API Problems (server must be running: make api-server)
make api-server        # Start practice API on localhost:8080
make api-p01           # Show p01 problem (shutdown + JSON parse)
make api-p01-solution  # Run p01 solution
make api-p02-solution  # Run p02 solution (poll job)
make api-p03-solution  # Run p03 solution (auth token)
make api-p04-solution  # Run p04 solution (paginate all items)
make api-p05-solution  # Run p05 solution (retry + backoff)

# Python Async / Concurrency
make async-c01         # asyncio.gather — concurrent HTTP (sequential vs concurrent timing)
make async-c02         # gather vs wait — exception propagation
make async-c03         # producer-consumer — asyncio.Queue (fan-out, pipeline)
make async-c04         # timeout + cancel — wait_for, shield, task.cancel()
make async-c05-broken  # race condition demo (broken — see the lost updates)
make async-c05         # race condition fix — threading.Lock, asyncio.Lock
make async-c06         # ThreadPool vs ProcessPool — I/O vs CPU bound
make async-c07         # Semaphore rate limiting + token bucket

# Tools
make k9s               # Launch k9s TUI
make debug-pod         # Launch nicolaka/netshoot debug pod
```

---

## Cleanup — After Practice

```bash
# Remove all scenario namespaces
make clean-scenarios

# Stop the observability stack
make obs-down

# Remove orphaned OPA Gatekeeper webhook (left behind if Gatekeeper was ever installed)
# Without this, kubectl create will fail with InternalError on webhook calls
kubectl delete validatingwebhookconfiguration gatekeeper-validating-webhook-configuration 2>/dev/null || true

# Mac — stop OrbStack K8s
orb stop k8s

# Linux — stop minikube
minikube stop
```

---

## What CoreWeave's Screen Tests

Based on JD analysis + Glassdoor/Taro research:

1. **Live K8s debugging** (~30 min) — broken pods, you fix them in a shared terminal
2. **Linux system debugging** (~20 min) — CPU/memory/disk/network issues
3. **Networking** (~15 min) — DNS, service connectivity, NetworkPolicy
4. **Observability** (~10 min) — reading Grafana, writing PromQL
5. **HPC/GPU concepts** (~10 min) — GPU scheduling, NCCL, DCGM
6. **Customer communication** (~5 min) — P1 escalation scenario

**The whole thing is practical, not theoretical. Think out loud. Show your methodology.**

---

## Key Things to Mention Proactively

- `kubectl describe pod` → Events section (not just logs)
- `kubectl debug node/<name>` — node-level debugging
- NVIDIA GPU Operator, DCGM Exporter
- InfiniBand / RDMA for HPC training traffic
- WEKA filesystem for RWX dataset storage
- Priority classes + preemption for HPC job scheduling
- Error budget-based SLO monitoring

---

## File Naming

| File | Purpose |
|------|---------|
| `k8s/scenarios/s*/broken.yaml` | Apply this to break the cluster |
| `k8s/scenarios/s*/README.md` | Customer complaint + your mission |
| `k8s/scenarios/s*/solution.md` | Step-by-step debug + fix + customer message |
| `cheatsheets/00-interview-strategy.md` | Read this the morning of the screen |
| `cheatsheets/06-hpc-gpu.md` | CoreWeave's core differentiator |
| `cheatsheets/07-coreweave-platform.md` | Company knowledge for the screen |
| `observability/promql-drill.sh` | 22 live PromQL queries via curl — run with `make promql-drill` |
| `python-api-problems/server/server.py` | Local API server (stdlib, no deps) — run with `make api-server` |
| `python-api-problems/p*/starter.py` | Fill in your solution here |
| `python-api-problems/p*/solution.py` | Reference solution with explanation |
| `python-async/c*/solution.py` | Runnable async exercise — `make async-c01` through `async-c07` |
| `python-async/c05-race-condition/broken.py` | Intentionally broken — run to see the race |
