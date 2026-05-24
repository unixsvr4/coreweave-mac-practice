# coreweave-mac-practice Makefile
# Platform: Mac M1/M2/M3 + OrbStack
# Run from repo root: make <target>

REPO_ROOT := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)
GUARD := $(if $(filter coreweave-mac-practice,$(notdir $(REPO_ROOT))),,\
  $(error Run this from inside coreweave-mac-practice/: cd $(REPO_ROOT)))

.DEFAULT_GOAL := help

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD := \033[1m
GREEN := \033[32m
YELLOW := \033[33m
CYAN := \033[36m
RESET := \033[0m

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "$(BOLD)coreweave-mac-practice$(RESET) — CoreWeave Senior Cloud Support Engineer Prep"
	@echo "Platform: Mac M1/M2/M3 + OrbStack Kubernetes"
	@echo ""
	@echo "$(BOLD)SETUP$(RESET)"
	@echo "  install           Install all required tools via Homebrew"
	@echo "  k8s-status        Show cluster status (nodes, system pods)"
	@echo "  obs-up            Start Grafana + Prometheus + Alertmanager"
	@echo "  obs-down          Stop the observability stack"
	@echo "  promql-drill      Run 22 PromQL queries via curl — host, K8s, DNS, GPU, SLO"
	@echo ""
	@echo "$(BOLD)K8S SCENARIOS (run timed — target < 8 min each)$(RESET)"
	@echo "  s01               CrashLoopBackOff — missing ConfigMap"
	@echo "  s02               OOMKilled — memory limit too low"
	@echo "  s03               Node pressure / pod eviction concepts"
	@echo "  s04               ImagePullBackOff — wrong tag + missing secret"
	@echo "  s05               Pending pod — impossible GPU request + bad nodeSelector"
	@echo "  s06               PVC stuck Pending — wrong StorageClass + access mode"
	@echo "  s07               Service Unreachable — selector mismatch + wrong targetPort"
	@echo "  s08               DNS failure — wrong namespace in DNS name"
	@echo "  s09               NetworkPolicy blocking all traffic"
	@echo "  s10               Resource Quota exceeded — pods silently not created"
	@echo "  s11               GPU job Pending (mock) — full GPU debug flow"
	@echo "  s12               Init container failing — DB not reachable"
	@echo "  clean-scenarios   Delete all scenario namespaces"
	@echo "  all-scenarios     Run all scenarios sequentially (full mock run)"
	@echo ""
	@echo "$(BOLD)LINUX EXERCISES$(RESET)"
	@echo "  linux-cpu         Simulate high CPU spike + diagnosis guide"
	@echo "  linux-mem         Simulate memory pressure + diagnosis guide"
	@echo "  linux-net         Network debugging walkthrough"
	@echo "  linux-snapshot    Full system debug snapshot (debug-toolkit)"
	@echo ""
	@echo "$(BOLD)HPC / GPU$(RESET)"
	@echo "  hpc-apply         Apply priority classes and GPU quota to cluster"
	@echo "  hpc-status        Show GPU nodes, allocatable, priority classes"
	@echo ""
	@echo "$(BOLD)CHEATSHEETS$(RESET)"
	@echo "  cs-strategy       Open interview strategy cheatsheet"
	@echo "  cs-kubectl        Open kubectl debug cheatsheet"
	@echo "  cs-linux          Open Linux debug cheatsheet"
	@echo "  cs-network        Open networking cheatsheet"
	@echo "  cs-storage        Open storage/PVC cheatsheet"
	@echo "  cs-promql         Open Prometheus/Grafana cheatsheet"
	@echo "  cs-gpu            Open HPC/GPU cheatsheet"
	@echo "  cs-coreweave      Open CoreWeave platform cheatsheet"
	@echo ""
	@echo "$(BOLD)PYTHON API PROBLEMS$(RESET)"
	@echo "  api-server        Start practice API server (port 8080)"
	@echo "  api-p01           Show p01 problem (POST /shutdown + JSON parse)"
	@echo "  api-p01-solution  Run p01 solution"
	@echo "  api-p02-solution  Run p02 solution (poll job until complete)"
	@echo "  api-p03-solution  Run p03 solution (auth token + session)"
	@echo "  api-p04-solution  Run p04 solution (paginate all items)"
	@echo "  api-p05-solution  Run p05 solution (retry + exponential backoff)"
	@echo ""
	@echo "$(BOLD)PYTHON ASYNC / CONCURRENCY$(RESET)"
	@echo "  async-c01         Async HTTP with asyncio.gather + aiohttp"
	@echo "  async-c02         gather vs wait — exception propagation"
	@echo "  async-c03         Producer-consumer with asyncio.Queue"
	@echo "  async-c04         Timeout and cancellation (wait_for, shield)"
	@echo "  async-c05-broken  Race condition demo (intentionally broken)"
	@echo "  async-c05         Race condition fix (Lock, asyncio.Lock)"
	@echo "  async-c06         ThreadPoolExecutor vs ProcessPoolExecutor"
	@echo "  async-c07         Semaphore rate limiting + token bucket"
	@echo ""
	@echo "$(BOLD)TOOLS$(RESET)"
	@echo "  k9s               Launch k9s cluster explorer"
	@echo "  debug-pod         Launch a netshoot debug pod in default namespace"
	@echo ""

# ── Setup ─────────────────────────────────────────────────────────────────────
.PHONY: install
install:
	@echo "$(BOLD)Installing tools...$(RESET)"
	bash "$(REPO_ROOT)/setup/install-tools.sh"

.PHONY: k8s-status
k8s-status:
	@echo "$(BOLD)=== Cluster Status ===$(RESET)"
	@echo ""
	@echo "$(CYAN)Context:$(RESET)"
	kubectl config current-context
	@echo ""
	@echo "$(CYAN)Nodes:$(RESET)"
	kubectl get nodes -o wide
	@echo ""
	@echo "$(CYAN)System Pods:$(RESET)"
	kubectl get pods -n kube-system
	@echo ""
	@echo "$(CYAN)Resource Usage:$(RESET)"
	kubectl top nodes 2>/dev/null || echo "  (metrics-server not installed)"

# ── Observability ─────────────────────────────────────────────────────────────
.PHONY: obs-up
obs-up:
	@echo "$(BOLD)Starting Grafana + Prometheus + Alertmanager...$(RESET)"
	docker compose -f "$(REPO_ROOT)/observability/docker-compose.yml" up -d
	@echo ""
	@echo "$(GREEN)✓ Observability stack running:$(RESET)"
	@echo "  Grafana    → http://localhost:3000  (admin / admin)"
	@echo "  Prometheus → http://localhost:9090"
	@echo "  Alertmgr   → http://localhost:9093"

.PHONY: obs-down
obs-down:
	docker compose -f "$(REPO_ROOT)/observability/docker-compose.yml" down
	@echo "$(GREEN)✓ Observability stack stopped$(RESET)"

.PHONY: obs-status
obs-status:
	docker compose -f "$(REPO_ROOT)/observability/docker-compose.yml" ps

.PHONY: promql-drill
promql-drill:
	@echo "$(BOLD)Running PromQL drill against Prometheus (localhost:9090)...$(RESET)"
	bash "$(REPO_ROOT)/observability/promql-drill.sh"

# ── K8s Scenarios ─────────────────────────────────────────────────────────────
.PHONY: s01
s01:
	@echo "$(BOLD)=== Scenario 01: CrashLoopBackOff ===$(RESET)"
	@cat "$(REPO_ROOT)/k8s/scenarios/s01-crashloop/README.md" | head -20
	kubectl create namespace s01 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s01-crashloop/broken.yaml" -n s01
	@echo ""
	@echo "$(YELLOW)→ Run: kubectl get pods -n s01 -w$(RESET)"
	@echo "$(YELLOW)→ Read: k8s/scenarios/s01-crashloop/README.md$(RESET)"
	@echo "$(YELLOW)→ Solution: k8s/scenarios/s01-crashloop/solution.md$(RESET)"

.PHONY: s02
s02:
	@echo "$(BOLD)=== Scenario 02: OOMKilled ===$(RESET)"
	kubectl create namespace s02 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s02-oom-killed/broken.yaml" -n s02
	@echo "$(YELLOW)→ kubectl get pods -n s02 -w  (watch it get OOMKilled in ~30s)$(RESET)"

.PHONY: s03
s03:
	@echo "$(BOLD)=== Scenario 03: Node Pressure / Eviction ===$(RESET)"
	@cat "$(REPO_ROOT)/k8s/scenarios/s03-node-pressure/README.md"

.PHONY: s04
s04:
	@echo "$(BOLD)=== Scenario 04: ImagePullBackOff ===$(RESET)"
	kubectl create namespace s04 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s04-imagepull/broken.yaml" -n s04
	@echo "$(YELLOW)→ kubectl get pods -n s04 -w$(RESET)"

.PHONY: s05
s05:
	@echo "$(BOLD)=== Scenario 05: Pod Stuck Pending ===$(RESET)"
	kubectl create namespace s05 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s05-pending-pod/broken.yaml" -n s05
	@echo "$(YELLOW)→ kubectl get pods -n s05 -w  (all Pending)$(RESET)"

.PHONY: s06
s06:
	@echo "$(BOLD)=== Scenario 06: PVC Stuck Pending ===$(RESET)"
	kubectl create namespace s06 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s06-pvc-pending/broken.yaml" -n s06
	@echo "$(YELLOW)→ kubectl get pvc,pods -n s06 -w$(RESET)"

.PHONY: s07
s07:
	@echo "$(BOLD)=== Scenario 07: Service Unreachable ===$(RESET)"
	kubectl create namespace s07 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s07-svc-unreachable/broken.yaml" -n s07
	@echo "$(YELLOW)→ kubectl get pods,svc,endpoints -n s07$(RESET)"

.PHONY: s08
s08:
	@echo "$(BOLD)=== Scenario 08: DNS Broken ===$(RESET)"
	kubectl create namespace s08-frontend 2>/dev/null || true
	kubectl create namespace s08-backend 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s08-dns-broken/broken.yaml"
	@echo "$(YELLOW)→ kubectl logs frontend -n s08-frontend -f$(RESET)"

.PHONY: s09
s09:
	@echo "$(BOLD)=== Scenario 09: NetworkPolicy Blocking Traffic ===$(RESET)"
	kubectl create namespace s09 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s09-networkpolicy/broken.yaml" -n s09
	@echo "$(YELLOW)→ kubectl get pods,netpol -n s09$(RESET)"

.PHONY: s10
s10:
	@echo "$(BOLD)=== Scenario 10: Resource Quota Exceeded ===$(RESET)"
	kubectl create namespace s10 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s10-resource-quota/broken.yaml" -n s10
	@echo "$(YELLOW)→ kubectl get pods,quota -n s10  (only 2 of 4 workers created)$(RESET)"

.PHONY: s11
s11:
	@echo "$(BOLD)=== Scenario 11: GPU Workload (Mock) ===$(RESET)"
	kubectl create namespace s11 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s11-gpu-mock/gpu-pod.yaml" -n s11
	@echo "$(YELLOW)→ kubectl get pods -n s11 -w  (Pending — no GPU nodes in practice cluster)$(RESET)"
	@echo "$(YELLOW)→ Practice the full GPU debug flow from solution.md$(RESET)"

.PHONY: s12
s12:
	@echo "$(BOLD)=== Scenario 12: Init Container Failing ===$(RESET)"
	kubectl create namespace s12 2>/dev/null || true
	kubectl apply -f "$(REPO_ROOT)/k8s/scenarios/s12-init-container/broken.yaml" -n s12
	@echo "$(YELLOW)→ kubectl get pods -n s12 -w  (stuck Init:1/2)$(RESET)"

.PHONY: clean-scenarios
clean-scenarios:
	@echo "Cleaning all scenario namespaces..."
	kubectl delete namespace s01 s02 s03 s04 s05 s06 s07 \
	  s08-frontend s08-backend s09 s10 s11 s12 \
	  --ignore-not-found=true 2>/dev/null
	@echo "$(GREEN)✓ All scenario namespaces deleted$(RESET)"

.PHONY: all-scenarios
all-scenarios: s01 s02 s04 s05 s06 s07 s08 s09 s10 s11 s12
	@echo ""
	@echo "$(GREEN)All scenarios deployed. Practice each one — aim for < 8 min per scenario.$(RESET)"
	@echo "When done: make clean-scenarios"

# ── Linux Exercises ───────────────────────────────────────────────────────────
.PHONY: linux-cpu
linux-cpu:
	bash "$(REPO_ROOT)/linux/01-high-cpu.sh"

.PHONY: linux-mem
linux-mem:
	bash "$(REPO_ROOT)/linux/02-memory-pressure.sh"

.PHONY: linux-net
linux-net:
	bash "$(REPO_ROOT)/linux/03-network-debug.sh"

.PHONY: linux-snapshot
linux-snapshot:
	bash "$(REPO_ROOT)/linux/debug-toolkit.sh"

# ── HPC / GPU ─────────────────────────────────────────────────────────────────
.PHONY: hpc-apply
hpc-apply:
	@echo "Applying HPC priority classes..."
	kubectl apply -f "$(REPO_ROOT)/k8s/hpc/priority-classes.yaml"
	@echo "$(GREEN)✓ Priority classes applied$(RESET)"
	kubectl get priorityclasses

.PHONY: hpc-status
hpc-status:
	@echo "$(BOLD)=== GPU / HPC Status ===$(RESET)"
	@echo ""
	@echo "$(CYAN)GPU Nodes:$(RESET)"
	kubectl get nodes -l nvidia.com/gpu.present=true 2>/dev/null || echo "  (no GPU nodes — practice cluster)"
	@echo ""
	@echo "$(CYAN)Priority Classes:$(RESET)"
	kubectl get priorityclasses
	@echo ""
	@echo "$(CYAN)GPU Operator (if installed):$(RESET)"
	kubectl get pods -n gpu-operator 2>/dev/null || echo "  (gpu-operator namespace not found — not installed)"

# ── Cheatsheets ───────────────────────────────────────────────────────────────
.PHONY: cs-strategy
cs-strategy:
	less "$(REPO_ROOT)/cheatsheets/00-interview-strategy.md"

.PHONY: cs-kubectl
cs-kubectl:
	less "$(REPO_ROOT)/cheatsheets/01-kubectl-debug.md"

.PHONY: cs-linux
cs-linux:
	less "$(REPO_ROOT)/cheatsheets/02-linux-debug.md"

.PHONY: cs-network
cs-network:
	less "$(REPO_ROOT)/cheatsheets/03-networking.md"

.PHONY: cs-storage
cs-storage:
	less "$(REPO_ROOT)/cheatsheets/04-storage.md"

.PHONY: cs-promql
cs-promql:
	less "$(REPO_ROOT)/cheatsheets/05-observability-promql.md"

.PHONY: cs-gpu
cs-gpu:
	less "$(REPO_ROOT)/cheatsheets/06-hpc-gpu.md"

.PHONY: cs-coreweave
cs-coreweave:
	less "$(REPO_ROOT)/cheatsheets/07-coreweave-platform.md"

# ── Tools ─────────────────────────────────────────────────────────────────────
.PHONY: k9s
k9s:
	k9s

.PHONY: debug-pod
debug-pod:
	kubectl run debug-$(shell date +%s) --image=nicolaka/netshoot --rm -it \
	  -- bash

# ── Python API Problems ───────────────────────────────────────────────────────
.PHONY: api-server
api-server:
	@echo "Starting practice API server on http://localhost:8080 ..."
	python "$(REPO_ROOT)/python-api-problems/server/server.py"

.PHONY: api-p01
api-p01:
	@echo "$(BOLD)=== p01: Shutdown the Server ===$(RESET)"
	@cat "$(REPO_ROOT)/python-api-problems/p01-shutdown/problem.md"
	@echo ""
	@echo "$(YELLOW)Start the server first: make api-server$(RESET)"
	@echo "$(YELLOW)Edit: python-api-problems/p01-shutdown/starter.py$(RESET)"
	@echo "$(YELLOW)Run : python python-api-problems/p01-shutdown/starter.py$(RESET)"

.PHONY: api-p01-solution
api-p01-solution: api-server-background
	python "$(REPO_ROOT)/python-api-problems/p01-shutdown/solution.py"

.PHONY: api-p02-solution
api-p02-solution:
	python "$(REPO_ROOT)/python-api-problems/p02-poll-job/solution.py"

.PHONY: api-p03-solution
api-p03-solution:
	python "$(REPO_ROOT)/python-api-problems/p03-auth-token/solution.py"

.PHONY: api-p04-solution
api-p04-solution:
	python "$(REPO_ROOT)/python-api-problems/p04-pagination/solution.py"

.PHONY: api-p05-solution
api-p05-solution:
	python "$(REPO_ROOT)/python-api-problems/p05-retry-backoff/solution.py"

api-server-background:
	@python "$(REPO_ROOT)/python-api-problems/server/server.py" &
	@sleep 0.5

# ── Python Async ──────────────────────────────────────────────────────────────
.PHONY: async-c01
async-c01:
	python "$(REPO_ROOT)/python-async/c01-async-http/solution.py"

.PHONY: async-c02
async-c02:
	python "$(REPO_ROOT)/python-async/c02-gather-vs-wait/solution.py"

.PHONY: async-c03
async-c03:
	python "$(REPO_ROOT)/python-async/c03-producer-consumer/solution.py"

.PHONY: async-c04
async-c04:
	python "$(REPO_ROOT)/python-async/c04-timeout-cancel/solution.py"

.PHONY: async-c05-broken
async-c05-broken:
	python "$(REPO_ROOT)/python-async/c05-race-condition/broken.py"

.PHONY: async-c05
async-c05:
	python "$(REPO_ROOT)/python-async/c05-race-condition/solution.py"

.PHONY: async-c06
async-c06:
	python "$(REPO_ROOT)/python-async/c06-executors/solution.py"

.PHONY: async-c07
async-c07:
	python "$(REPO_ROOT)/python-async/c07-semaphore/solution.py"
