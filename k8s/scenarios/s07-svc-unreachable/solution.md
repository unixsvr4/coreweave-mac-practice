# Solution — Scenario 07: Service Unreachable

## Debugging Steps

```bash
# Step 1: Check pods are Running
kubectl get pods -n s07
# Both pods Running ✓

# Step 2: Check endpointslices — KEY INSIGHT
kubectl get endpointslices -n s07
# NAME                          ADDRESSTYPE   PORTS   ENDPOINTS   AGE
# inference-api-svc-xxxxx       IPv4          8080    <none>      3m
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

# Step 5: Verify nginx port (ss not available in slim nginx image — use cat /etc/nginx/conf.d/default.conf)
kubectl exec -n s07 $(kubectl get pod -n s07 -o name | head -1) -- cat /etc/nginx/conf.d/default.conf | grep listen
# listen  80;
# OR check the pod spec directly — faster and always works:
kubectl get pod -n s07 $(kubectl get pod -n s07 -o name | head -1 | cut -d/ -f2) -o jsonpath='{.spec.containers[*].ports}'
# [{"containerPort":80,"protocol":"TCP"}]  ← container exposes 80, not 8080

# Fix both bugs
kubectl patch svc inference-api-svc -n s07 --type='json' -p='[
  {"op":"replace","path":"/spec/selector/version","value":"v2"},
  {"op":"replace","path":"/spec/ports/0/targetPort","value":80}
]'

# Verify endpointslices are populated now
kubectl get endpointslices -n s07
# NAME                        ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
# inference-api-svc-xxxxx     IPv4          80      10.244.0.5,10.244.0.6       5m
```

## Root Causes

1. **Selector mismatch**: Service has `version: v1` but pods have `version: v2`. No pods match → endpoints `<none>` → all traffic drops.
2. **Wrong targetPort**: `targetPort: 8080` but nginx listens on port 80. Even if selector was fixed, connections would be refused.

## What to Tell the Customer

> "We found two issues. First, your service selector has `version: v1` but your deployment pods are labeled `version: v2` — the service has no matching backends. Second, the service's `targetPort` is 8080 but your nginx container listens on port 80. Both are now fixed and your endpoints are populated with your pod IPs. To prevent this: I recommend using the deployment's `spec.selector` labels as the single source of truth for service selectors, and verifying `targetPort` matches your container's actual listening port — check `kubectl get pod <name> -o jsonpath='{.spec.containers[*].ports}'` or `kubectl exec <pod> -- cat /etc/nginx/conf.d/default.conf`."

## Test After Fix

```bash
# Port-forward and test (sleep 1 lets the forwarder bind before curl fires)
kubectl port-forward svc/inference-api-svc 8080:80 -n s07 &
sleep 1 && curl http://localhost:8080/
# Should return nginx 200 OK

# Cleanup port-forward when done
kill %1 2>/dev/null || true
```
