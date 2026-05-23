# Solution — Scenario 01: CrashLoopBackOff

## Debugging Steps

```bash
# Step 1: Check pod state
kubectl get pods -n s01
# api-server-XXXXX   0/1   CrashLoopBackOff   3  2m

# Step 2: Check events (fastest signal)
kubectl describe pod -n s01 -l app=api-server
# Events:
#   Warning  Failed    ...  Error: configmap "app-config-TYPO" not found
# → The volume references a ConfigMap that doesn't exist

# Step 3: Verify (also shows in logs on second restart attempt)
kubectl logs -n s01 -l app=api-server --previous
# CreateContainerConfigError: configmap "app-config-TYPO" not found

# Confirm actual ConfigMap name
kubectl get configmap -n s01
# NAME         DATA   AGE
# app-config   1      3m
```

## Root Cause

The Deployment's volume references `app-config-TYPO` but the ConfigMap is named `app-config`. Kubernetes cannot create the container because the volume cannot be mounted.

## Fix

```bash
kubectl patch deployment api-server -n s01 --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/volumes/0/configMap/name","value":"app-config"}]'

# Or edit directly
kubectl edit deployment api-server -n s01
# Change: name: app-config-TYPO  → name: app-config
```

## Fixed YAML Snippet

```yaml
volumes:
  - name: config-volume
    configMap:
      name: app-config   # was: app-config-TYPO
```

## What to Tell the Customer

> "We identified the root cause. Your Deployment references a ConfigMap named `app-config-TYPO`, but the actual ConfigMap is named `app-config`. This mismatch prevents the volume from being mounted, causing the container to fail on startup. I've applied the fix — your pod is now Running. To prevent this in future deployments, I recommend using Helm or Kustomize to template your ConfigMap names consistently across manifests."

## Key Takeaway

`CrashLoopBackOff` is often NOT a crash — it can be a **container that never starts** due to missing ConfigMap, Secret, or volume. Always check `kubectl describe pod` Events **before** `kubectl logs` — events appear even before the first log line.
