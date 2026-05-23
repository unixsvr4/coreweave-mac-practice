# Networking Debugging — Kubernetes + Linux Cheatsheet

## Kubernetes Networking Architecture

```
Pod → veth pair → CNI bridge/overlay → Node routing → Service (iptables/IPVS) → Endpoint (Pod IP)

DNS flow:
Pod → /etc/resolv.conf → CoreDNS ClusterIP:53 → upstream resolver
Service name → <svc>.<ns>.svc.cluster.local
```

## DNS Debugging in Kubernetes

```bash
# CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# DNS resolution test from a pod
kubectl run dns-test --image=busybox --rm -it -- sh
  > nslookup kubernetes.default
  > nslookup <svc>.<namespace>.svc.cluster.local
  > cat /etc/resolv.conf

# Using nicolaka/netshoot for advanced DNS debug
kubectl run dns-test --image=nicolaka/netshoot --rm -it -- bash
  > dig <svc>.<namespace>.svc.cluster.local
  > dig kubernetes.default.svc.cluster.local A
  > nslookup -debug <hostname>

# Check pod's /etc/resolv.conf
kubectl exec <pod> -- cat /etc/resolv.conf
# Should show: nameserver 10.96.0.10 (CoreDNS ClusterIP)
#              search <ns>.svc.cluster.local svc.cluster.local cluster.local

# CoreDNS logs with query logging (enable temporarily)
kubectl edit configmap coredns -n kube-system
# Add: log under the .:53 block
```

## Service Connectivity Debugging

```bash
# Step 1: Are there endpoints?
kubectl get endpoints <svc> -n <ns>
# If ENDPOINTS = <none>, the selector doesn't match any Ready pods

# Step 2: Check selector vs pod labels
kubectl get svc <svc> -n <ns> -o jsonpath='{.spec.selector}'
kubectl get pods -n <ns> --show-labels

# Step 3: Is the pod actually Ready?
kubectl get pod <pod> -n <ns>
# If not Ready, check readinessProbe

# Step 4: Test within cluster
kubectl run test --image=curlimages/curl --rm -it -- curl -v http://<svc>.<ns>:<port>/

# Step 5: Test the actual pod IP (bypass service)
POD_IP=$(kubectl get pod <pod> -n <ns> -o jsonpath='{.status.podIP}')
kubectl run test --image=curlimages/curl --rm -it -- curl -v http://${POD_IP}:<containerPort>/

# Step 6: If pod works but svc doesn't → iptables/IPVS rules issue
kubectl run test --image=nicolaka/netshoot --rm -it -- bash
  > iptables-save | grep <svc-clusterip>
  > ipvsadm -L -n | grep <svc-clusterip>   # if IPVS mode
```

## NetworkPolicy Debugging

```bash
# List all NetworkPolicies in a namespace
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>

# Common issue: deny-all policy blocking traffic
# A namespace with "deny all ingress" policy:
#   kind: NetworkPolicy
#   spec:
#     podSelector: {}     # matches ALL pods
#     policyTypes: [Ingress]
#     # no ingress rules = deny all

# Test connectivity with netshoot
kubectl run debug --image=nicolaka/netshoot --rm -it -n <source-ns> -- bash
  > curl -v --connect-timeout 5 http://<target-svc>.<target-ns>:80/
  # Timeout = NetworkPolicy blocking OR no route
  # Connection refused = NetworkPolicy ok, app not listening
  # 200/other HTTP = working

# Check if a NetworkPolicy is blocking (negative test)
# Delete the NetworkPolicy temporarily in non-prod, retest
kubectl delete networkpolicy <np> -n <ns>   # CAREFUL in prod

# Cilium-specific (if CoreWeave uses Cilium CNI)
cilium monitor --type drop        # see dropped packets with reason
cilium policy trace --src-endpoint <ep-id> --dst-endpoint <ep-id> --dport 80
```

## Ingress Debugging

```bash
# Ingress resource
kubectl get ingress -n <ns>
kubectl describe ingress <name> -n <ns>
# Check: Address field (should have external IP/hostname)
# Check: Rules — host, path, backend service/port

# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Test HTTP directly to ingress controller pod (bypass DNS)
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: myapp.example.com" http://${INGRESS_IP}/api/health

# Certificate issues (TLS)
kubectl describe ingress <name> | grep -i tls
kubectl get secret <tls-secret> -n <ns>
openssl s_client -connect <host>:443 -servername <host>
```

## InfiniBand / RDMA (CoreWeave HPC — know conceptually)

```bash
# Check if IB interfaces exist
ibstat                          # interface state and info
ibv_devices                     # RDMA devices
ip link | grep ib               # IB interfaces in Linux

# InfiniBand port speed
ibstat | grep "Rate"            # 200Gb/s, 400Gb/s for modern HPC

# RDMA bandwidth test (between two nodes)
# Server: ib_write_bw --use_cuda=0
# Client: ib_write_bw <server-ip> --use_cuda=0

# Check GPUDirect RDMA
nvidia-smi nvlink --status      # NVLink between GPUs
# RDMA + NCCL for distributed training:
# NCCL_DEBUG=INFO in job env shows communication backend

# CoreWeave concept: GPU nodes connected via InfiniBand
# NCCL (NVIDIA Collective Communications Library) uses IB for:
# - AllReduce (gradient aggregation in distributed training)
# - AllGather, ReduceScatter
# InfiniBand error → NCCL timeout → training job hangs → customer escalation
```

## Common Networking Root Causes

| Customer Complaint | Likely Cause | Debug Approach |
|-------------------|-------------|----------------|
| "Can't reach my service" | No endpoints (wrong selector) | `kubectl get endpoints` |
| "DNS not resolving" | CoreDNS down, wrong ns, wrong name | `nslookup` from debug pod |
| "Service works from same ns, not cross-ns" | NetworkPolicy blocking | `kubectl get netpol` |
| "Intermittent connection drops" | Pod restarts, rolling update | `kubectl get pod -w` |
| "Training job hangs at start" | NCCL rendezvous failure / IB issue | Check IB state, NCCL_DEBUG |
| "High latency between pods" | CNI overhead, wrong MTU | `ping -M do -s 8972 <pod-ip>` to test MTU |
| "LoadBalancer stuck Pending" | No cloud LB integration (minikube) | `minikube tunnel` or use NodePort |

## MTU / Packet Fragmentation

```bash
# MTU on node interfaces
ip link show | grep mtu
# Kubernetes overlay networks (VXLAN) need MTU=1450 on pod interfaces
# (1500 Ethernet - 50 bytes VXLAN overhead)

# Test path MTU
ping -M do -s 1450 <pod-ip>   # do=don't fragment, s=payload size
# "Frag needed" error means MTU is too large

# Fix: set mtu in CNI config or adjust pod's interface
```

## CoreWeave Networking Notes

- **GPU nodes connect via InfiniBand** (100Gb/200Gb/400Gb) for RDMA
- **Tenant networking**: Each customer namespace is isolated; traffic crosses IB for training
- **Storage networking**: WEKA filesystem uses 25GbE/100GbE for parallel I/O
- **CoreDNS** is used inside K8s; customer pods resolve each other via service names
- **Egress**: customer traffic NATs out through a gateway; ingress via LoadBalancer or NodePort
- **Security**: OPA/Gatekeeper enforces network policies at admission time
