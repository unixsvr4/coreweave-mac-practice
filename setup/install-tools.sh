#!/usr/bin/env bash
# CoreWeave Mac Practice — Install Tools (Mac M1/M2/M3 + OrbStack)
# Run: bash setup/install-tools.sh

set -euo pipefail

echo "=== CoreWeave Mac Practice — Installing Tools ==="
echo "Platform: Mac M1/M2/M3 + Homebrew + OrbStack"
echo ""

check_or_skip() {
    local cmd="$1"
    local name="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $name already installed ($(command -v "$cmd"))"
        return 0
    fi
    return 1
}

# ── Homebrew ──────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "[!] Homebrew not found. Install from https://brew.sh first."
    exit 1
fi
echo "[0] Updating Homebrew..."
brew update --quiet

# ── kubectl ───────────────────────────────────────────────────────────────────
echo ""
echo "[1] kubectl..."
if check_or_skip kubectl; then :
else
    brew install kubectl
    echo "  ✓ kubectl installed"
fi
kubectl version --client --short 2>/dev/null || kubectl version --client

# ── Helm ──────────────────────────────────────────────────────────────────────
echo ""
echo "[2] Helm..."
if check_or_skip helm; then :
else
    brew install helm
    echo "  ✓ helm installed"
fi

# ── kube-ps1 (prompt showing current cluster/namespace) ───────────────────────
echo ""
echo "[3] kube-ps1 (optional but useful)..."
if brew list kube-ps1 &>/dev/null 2>&1; then
    echo "  ✓ kube-ps1 already installed"
else
    brew install kube-ps1 && echo "  ✓ kube-ps1 installed" || echo "  (skip)"
fi

# ── kubectx / kubens ──────────────────────────────────────────────────────────
echo ""
echo "[4] kubectx + kubens (context/namespace switcher)..."
if check_or_skip kubectx; then :
else
    brew install kubectx
    echo "  ✓ kubectx + kubens installed"
fi

# ── k9s ───────────────────────────────────────────────────────────────────────
echo ""
echo "[5] k9s (TUI for Kubernetes)..."
if check_or_skip k9s; then :
else
    brew install k9s
    echo "  ✓ k9s installed"
fi

# ── stern (multi-pod log tailing) ─────────────────────────────────────────────
echo ""
echo "[6] stern (multi-pod log tailing)..."
if check_or_skip stern; then :
else
    brew install stern
    echo "  ✓ stern installed"
fi

# ── jq ────────────────────────────────────────────────────────────────────────
echo ""
echo "[7] jq (JSON processor)..."
if check_or_skip jq; then :
else
    brew install jq
    echo "  ✓ jq installed"
fi

# ── Docker (OrbStack provides this) ───────────────────────────────────────────
echo ""
echo "[8] Docker..."
if check_or_skip docker; then
    echo "     (OrbStack or Docker Desktop provides the docker CLI)"
else
    echo "  [!] docker not found — please install OrbStack (https://orbstack.dev)"
fi

# ── OrbStack check ────────────────────────────────────────────────────────────
echo ""
echo "[9] OrbStack..."
if command -v orb &>/dev/null || [ -d "/Applications/OrbStack.app" ]; then
    echo "  ✓ OrbStack is installed"
    echo "     K8s context: $(kubectl config current-context 2>/dev/null || echo 'none set')"
else
    echo "  [!] OrbStack not found — install from https://orbstack.dev"
    echo "       OrbStack provides: Docker runtime + Kubernetes cluster (no minikube needed on Mac)"
fi

# ── kube-state-metrics (in cluster) ───────────────────────────────────────────
echo ""
echo "[10] kube-state-metrics (in cluster)..."
echo "     To install kube-state-metrics in your K8s cluster for Prometheus scraping:"
echo "     helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
echo "     helm install kube-state-metrics prometheus-community/kube-state-metrics -n kube-system"

# ── nickolaka/netshoot (debugging image) ──────────────────────────────────────
echo ""
echo "[11] Pulling debugging image nicolaka/netshoot..."
docker pull nicolaka/netshoot 2>/dev/null && echo "  ✓ netshoot ready" || echo "  (will pull on first use)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Quick start:"
echo "  make scenario-01    # Load and debug scenario 01"
echo "  make obs-up         # Start Grafana + Prometheus"
echo "  make k9s            # Launch k9s cluster explorer"
echo ""
echo "K8s context:"
kubectl config get-contexts 2>/dev/null | head -5 || echo "  (no contexts configured)"
