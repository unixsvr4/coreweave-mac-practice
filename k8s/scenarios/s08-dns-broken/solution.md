# Solution — Scenario 08: DNS Resolution Failure

## Debugging Steps

```bash
# Step 1: Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Both CoreDNS pods should be Running/Ready

# Step 2: Check CoreDNS logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
# Should not show error floods

# Step 3: Test DNS from the frontend pod
kubectl exec -n s08-frontend frontend -- nslookup model-api-svc.s08.svc.cluster.local
# Server:    10.96.0.10
# ** server can't find model-api-svc.s08.svc.cluster.local: NXDOMAIN
# → DNS works, but the name doesn't exist

# Step 4: Try the correct FQDN
kubectl exec -n s08-frontend frontend -- nslookup model-api-svc.s08-backend.svc.cluster.local
# Server:    10.96.0.10
# Name:   model-api-svc.s08-backend.svc.cluster.local
# Address: 10.96.x.x
# → RESOLVES CORRECTLY

# Step 5: Verify backend service exists
kubectl get svc -n s08-backend
# NAME            TYPE        CLUSTER-IP    PORT(S)
# model-api-svc   ClusterIP   10.96.x.x     80/TCP ← it exists

# Root cause identified: application is using "s08" namespace in DNS name
# but the actual namespace is "s08-backend"

# Step 6: Test cross-namespace HTTP connectivity
kubectl exec -n s08-frontend frontend -- wget -qO- http://model-api-svc.s08-backend.svc.cluster.local/
# 200 OK — confirms route works, only DNS name was wrong
```

## Root Cause

The frontend application is resolving `model-api-svc.s08.svc.cluster.local` — the old namespace name before migration. The service moved to `s08-backend` namespace, but the application's DNS name was not updated.

**CoreDNS is healthy.** The problem is incorrect configuration in the client application.

## Fix

**Option 1**: Update the application's service URL to use the correct FQDN:
```
model-api-svc.s08-backend.svc.cluster.local
```

**Option 2**: Use a ConfigMap or environment variable for the backend URL:
```yaml
env:
  - name: BACKEND_URL
    value: "http://model-api-svc.s08-backend.svc.cluster.local"
```

**Option 3**: Create a Service in the frontend namespace that proxies to the backend (ExternalName):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: model-api-svc   # same name as before
  namespace: s08-frontend
spec:
  type: ExternalName
  externalName: model-api-svc.s08-backend.svc.cluster.local
```

## Kubernetes DNS Name Structure (memorize this)

```
<service-name>.<namespace>.svc.<cluster-domain>

Examples:
  model-api-svc.production.svc.cluster.local
  redis.cache.svc.cluster.local
  postgres-primary.databases.svc.cluster.local

Short form (works within same namespace):
  model-api-svc        ← /etc/resolv.conf search domain adds the rest
  model-api-svc.s08-backend  ← cross-namespace short form
```

## What to Tell the Customer

> "CoreDNS is healthy — your DNS infrastructure is working correctly. The issue is that your frontend application is resolving `model-api-svc.s08.svc.cluster.local`, which references your old namespace `s08` before the migration. The service now lives in `s08-backend`, so the correct FQDN is `model-api-svc.s08-backend.svc.cluster.local`. You'll need to update your application config or environment variable `BACKEND_URL` with the new name. Alternatively, I can create an ExternalName Service in your frontend namespace as a temporary bridge while you update the application."
