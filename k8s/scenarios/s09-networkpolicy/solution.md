# Solution — Scenario 09: NetworkPolicy Blocking Traffic

## Debugging Steps

```bash
# Step 1: List NetworkPolicies
kubectl get networkpolicy -n s09
# NAME               POD-SELECTOR   AGE
# default-deny-all   <none>         5m

# Step 2: Describe the policy
kubectl describe networkpolicy default-deny-all -n s09
# Spec:
#   PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
#   Allowing ingress traffic:
#     <none> (Selected pods are isolated for ingress connectivity)
#   Allowing egress traffic:
#     <none> (Selected pods are isolated for egress connectivity)
# ← "Allowing <none>" = denying all

# Step 3: Test connectivity from a debug pod
kubectl run debug -n s09 --image=busybox --rm -it -- wget -qO- --timeout=5 http://api-server-svc/
# wget: can't connect to remote host: Connection timed out
# ← Confirmed: deny-all is blocking intra-namespace traffic

# Step 4: Also test DNS
kubectl run debug -n s09 --image=busybox --rm -it -- nslookup api-server-svc
# Connection timed out  ← DNS blocked too (egress to port 53 blocked)
```

## Root Cause

The `default-deny-all` NetworkPolicy with empty `podSelector: {}` matches all pods and has `policyTypes: [Ingress, Egress]` with no allow rules. This blocks:
- All ingress traffic to any pod (including Prometheus scraping)
- All egress traffic from any pod (including DNS on port 53!)

## Fix — Add Targeted Allow Rules

```bash
kubectl apply -f - -n s09 <<'EOF'
# Allow intra-namespace traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}   # allow from any pod in same namespace
  egress:
    - to:
        - podSelector: {}   # allow to any pod in same namespace
---
# Allow DNS egress (critical — without this, DNS breaks)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
---
# Allow Prometheus scraping from monitoring namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - port: 9090
          protocol: TCP
EOF
```

## What to Tell the Customer

> "The `default-deny-all` NetworkPolicy you applied is working correctly — it blocks all traffic by design. However, it also blocks DNS resolution (UDP/53) and intra-namespace communication, which breaks your services. I've added three supplementary policies: (1) allow intra-namespace traffic, (2) allow DNS egress — without this, your pods can't resolve any hostname, (3) allow Prometheus to scrape your metrics port from the monitoring namespace. Your security posture is maintained — traffic from external namespaces is still blocked except for monitoring."

## Key NetworkPolicy Gotchas

1. **DNS is egress on port 53** — always add a DNS allow rule when denying all egress
2. **Empty podSelector matches ALL pods** — including system pods if no namespace selector
3. **Additive model** — policies are OR'd together; a pod is allowed if ANY policy permits it
4. **No policy = no restriction** — policies only apply when at least one NetworkPolicy selects a pod
5. **Both directions must be allowed** — blocking egress on the source OR ingress on the destination blocks traffic
