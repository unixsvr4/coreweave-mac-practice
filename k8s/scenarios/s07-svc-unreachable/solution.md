# Solution — Scenario 07: Service Unreachable

## Debugging Steps

```bash
# Step 1: Check pods are Running
kubectl get pods -n s07
# Both pods Running ✓

# Step 2: Check endpoints — KEY INSIGHT
kubectl get endpoints -n s07
# NAME                 ENDPOINTS   AGE
# inference-api-svc   <none>      3m
# ← <none> means NO pods match the service selector

# Step 3: Compare service selector vs pod labels
kubectl get svc inference-api-svc -n s07 -o jsonpath='{.spec.selector}'
# {"app":"inference-api","version":"v1"}

kubectl get pods -n s07 --show-labels
# NAME                           LABELS
# inference-api-XXXX  app=inference-api,version=v2   ← pods are v2!
# ← MISMATCH: service wants version=v1, pods are version=v2

# Step 4: Also check targetPort
kubectl get svc inference-api-svc -n s07 -o jsonpath='{.spec.ports}'
# [{"name":"http","port":80,"targetPort":8080}]
# → targetPort=8080 but nginx listens on 80

# Step 5: Verify nginx port
kubectl exec -n s07 $(kubectl get pod -n s07 -o name | head -1) -- ss -tlnp
# Shows: *:80   (not 8080)

# Fix both bugs
kubectl patch svc inference-api-svc -n s07 --type='json' -p='[
  {"op":"replace","path":"/spec/selector/version","value":"v2"},
  {"op":"replace","path":"/spec/ports/0/targetPort","value":80}
]'

# Verify endpoints are populated now
kubectl get endpoints -n s07
# NAME                 ENDPOINTS                         AGE
# inference-api-svc   10.244.0.5:80,10.244.0.6:80      5m
```

## Root Causes

1. **Selector mismatch**: Service has `version: v1` but pods have `version: v2`. No pods match → endpoints `<none>` → all traffic drops.
2. **Wrong targetPort**: `targetPort: 8080` but nginx listens on port 80. Even if selector was fixed, connections would be refused.

## What to Tell the Customer

> "We found two issues. First, your service selector has `version: v1` but your deployment pods are labeled `version: v2` — the service has no matching backends. Second, the service's `targetPort` is 8080 but your nginx container listens on port 80. Both are now fixed and your endpoints are populated with your pod IPs. To prevent this: I recommend using the deployment's `spec.selector` labels as the single source of truth for service selectors, and verifying `targetPort` matches your container's actual listening port — this can be done with `kubectl exec <pod> -- ss -tlnp`."

## Test After Fix

```bash
# Port-forward and test
kubectl port-forward svc/inference-api-svc 8080:80 -n s07 &
curl http://localhost:8080/
# Should return nginx 200 OK
```
