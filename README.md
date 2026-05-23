# coreweave-mac-practice

**Platform:** Mac M1/M2/M3 + OrbStack  
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
| `observability/` | Grafana + Prometheus + Alertmanager docker-compose stack |
| `linux/` | Linux debugging exercises + system snapshot script |
| `setup/` | Mac tooling installer |

---

## Prerequisites

- **OrbStack** — provides Docker + a real local Kubernetes cluster: https://orbstack.dev
- **Homebrew** — package manager for everything else
- `bash setup/install-tools.sh` — installs kubectl, helm, k9s, kubectx, jq, stern

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

### Day 3 — GPU/HPC + Observability

| Task | Command | Time |
|------|---------|------|
| Read GPU/HPC cheatsheet | `make cs-gpu` | 25 min |
| Read PromQL cheatsheet | `make cs-promql` | 20 min |
| Read CoreWeave platform notes | `make cs-coreweave` | 20 min |
| Run scenario 11 (GPU mock) | `make s11` | 10 min |
| Start observability stack | `make obs-up` | — |
| Explore Grafana dashboard | `open http://localhost:3000` | 20 min |
| Write 5 PromQL queries from memory | (practice) | 15 min |
| Apply HPC priority classes | `make hpc-apply` | 5 min |

### Day 4 — Full Mock Run

| Task | Time |
|------|------|
| Read `cheatsheets/00-interview-strategy.md` (the whole thing) | 20 min |
| Run ALL scenarios without looking at solutions first | 90 min |
| Time each one — flag any > 8 min for extra review | — |
| Practice customer communication scripts out loud | 20 min |
| Review CoreWeave platform notes + questions to ask | 15 min |
| Light review of solutions you got stuck on | 20 min |

---

## Quick Reference — The 5-Step Pod Debug

```bash
kubectl get pod <name> -n <ns> -o wide            # state, node, IP
kubectl describe pod <name> -n <ns>               # Events section first
kubectl logs <name> -n <ns> [--previous]          # container output
kubectl get events -n <ns> --sort-by=.lastTimestamp  # timeline
kubectl debug pod/<name> -it --image=busybox      # interactive probe
```

---

## All Make Commands

```bash
make install           # Install kubectl, helm, k9s, kubectx, jq, stern
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

# Tools
make k9s               # Launch k9s TUI
make debug-pod         # Launch nicolaka/netshoot debug pod
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

## Observability Stack

```
http://localhost:3000   Grafana   (admin / admin)
http://localhost:9090   Prometheus
http://localhost:9093   Alertmanager
http://localhost:9100   node-exporter metrics
```

Start: `make obs-up`  
Stop: `make obs-down`

Pre-built dashboard: **CoreWeave Practice — K8s & Node Overview**

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
