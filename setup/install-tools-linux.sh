#!/usr/bin/env bash
# CoreWeave Practice — Install Tools (Linux Ubuntu 24.04)
# Run: bash setup/install-tools-linux.sh
# Assumes Docker is already installed and minikube is already running.

set -euo pipefail

echo "=== CoreWeave Practice — Installing Tools (Ubuntu 24.04) ==="
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

ARCH=$(dpkg --print-architecture)   # amd64 or arm64
echo "Architecture: $ARCH"
echo ""

# ── kubectl ───────────────────────────────────────────────────────────────────
echo "[1] kubectl..."
if check_or_skip kubectl; then :
else
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
      | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
      | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update -q && sudo apt-get install -y kubectl
    echo "  ✓ kubectl installed"
fi
kubectl version --client

# ── Helm ──────────────────────────────────────────────────────────────────────
echo ""
echo "[2] Helm..."
if check_or_skip helm; then :
else
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "  ✓ helm installed"
fi

# ── kubectx / kubens ──────────────────────────────────────────────────────────
echo ""
echo "[3] kubectx + kubens..."
if check_or_skip kubectx; then :
else
    KUBECTX_VER=$(curl -s https://api.github.com/repos/ahmetb/kubectx/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)
    curl -sL "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VER}/kubectx_${KUBECTX_VER}_linux_${ARCH}.tar.gz" \
      | sudo tar xz -C /usr/local/bin kubectx
    curl -sL "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VER}/kubens_${KUBECTX_VER}_linux_${ARCH}.tar.gz" \
      | sudo tar xz -C /usr/local/bin kubens
    echo "  ✓ kubectx + kubens installed"
fi

# ── k9s ───────────────────────────────────────────────────────────────────────
echo ""
echo "[4] k9s..."
if check_or_skip k9s; then :
else
    K9S_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)
    curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_${ARCH}.tar.gz" \
      | sudo tar xz -C /usr/local/bin k9s
    echo "  ✓ k9s installed"
fi

# ── stern ─────────────────────────────────────────────────────────────────────
echo ""
echo "[5] stern..."
if check_or_skip stern; then :
else
    STERN_VER=$(curl -s https://api.github.com/repos/stern/stern/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)
    # stern uses amd64/arm64 directly in filename
    STERN_ARCH="$ARCH"
    curl -sL "https://github.com/stern/stern/releases/download/${STERN_VER}/stern_${STERN_VER#v}_linux_${STERN_ARCH}.tar.gz" \
      | sudo tar xz -C /usr/local/bin stern
    echo "  ✓ stern installed"
fi

# ── jq ────────────────────────────────────────────────────────────────────────
echo ""
echo "[6] jq..."
if check_or_skip jq; then :
else
    sudo apt-get install -y jq
    echo "  ✓ jq installed"
fi

# ── Docker ────────────────────────────────────────────────────────────────────
echo ""
echo "[7] Docker..."
if check_or_skip docker; then
    echo "     (used as minikube driver — good)"
else
    echo "  [!] Docker not found."
    echo "      Install: sudo apt-get install -y docker.io && sudo usermod -aG docker \$USER"
    echo "      Then log out and back in (or run: newgrp docker)"
fi

# ── minikube ──────────────────────────────────────────────────────────────────
echo ""
echo "[8] minikube..."
if check_or_skip minikube; then
    echo "     Status: $(minikube status --format='{{.Host}}' 2>/dev/null || echo 'not started')"
else
    echo "  [!] minikube not found."
    echo "      Install:"
    echo "        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}"
    echo "        sudo install minikube-linux-${ARCH} /usr/local/bin/minikube"
    echo "      Start:"
    echo "        minikube start --driver=docker --cpus=4 --memory=8192"
fi

# ── kube-state-metrics (in cluster) ───────────────────────────────────────────
echo ""
echo "[9] kube-state-metrics (in cluster — optional)..."
echo "     To install for Prometheus scraping:"
echo "     helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
echo "     helm install kube-state-metrics prometheus-community/kube-state-metrics -n kube-system"

# ── nicolaka/netshoot ─────────────────────────────────────────────────────────
echo ""
echo "[10] Pulling debug image nicolaka/netshoot..."
docker pull nicolaka/netshoot 2>/dev/null && echo "  ✓ netshoot ready" || echo "  (will pull on first use)"

# ── Python deps ───────────────────────────────────────────────────────────────
echo ""
echo "[11] Python dependencies..."
if command -v pip3 &>/dev/null; then
    pip3 install --quiet python-docx requests beautifulsoup4 aiohttp 2>/dev/null \
      && echo "  ✓ python-docx, requests, beautifulsoup4, aiohttp installed" \
      || echo "  [!] pip3 install failed — run manually: pip3 install python-docx requests beautifulsoup4 aiohttp"
else
    echo "  [!] pip3 not found — install: sudo apt-get install -y python3-pip"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Quick start:"
echo "  make k8s-status     # Verify cluster is up"
echo "  make s01            # Load and debug scenario 01"
echo "  make obs-up         # Start Grafana + Prometheus"
echo "  make k9s            # Launch k9s cluster explorer"
echo ""
echo "K8s context:"
kubectl config get-contexts 2>/dev/null | head -5 || echo "  (no contexts configured)"
echo ""
echo "Minikube status:"
minikube status 2>/dev/null || echo "  (minikube not running — start with: minikube start --driver=docker --cpus=4 --memory=8192)"
