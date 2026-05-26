# Solution — Scenario 04: ImagePullBackOff

## Debugging Steps

```bash
# Step 1: Check pod state
kubectl get pods -n s04
# ml-inference-XXXXX   0/1   ImagePullBackOff   0   2m

# Step 2: Get events — more reliable than describe (events expire after ~1h but kubectl get events always works)
kubectl get events -n s04 --sort-by=.lastTimestamp
# Warning  Failed  pod/ml-inference-...  Failed to pull image "nvcr.io/nvidia/tritonserver:24.01-py3-sdk-NONEXISTENT":
#                  manifest unknown → bad image tag
# Warning  FailedToRetrieveImagePullSecret  pod/ml-inference-...
#                  Unable to retrieve some image pull secrets (ngc-registry-secret-WRONG) → wrong secret name

# describe also works if events haven't expired yet:
kubectl describe pod -n s04 -l app=ml-inference | tail -20

# Step 3: Check if imagePullSecret exists
kubectl get secret -n s04 | grep ngc
# (nothing — secret doesn't exist)

# Step 4: Check what image tags actually exist for tritonserver
# nvcr.io/nvidia/tritonserver requires NGC credentials
# Valid tags: 24.01-py3, 23.12-py3, etc.
# The "-sdk-NONEXISTENT" suffix is wrong

# Fix issue 1: Create the NGC pull secret
# (In real CoreWeave: customer provides their NGC API key)
kubectl create secret docker-registry ngc-registry-secret \
  -n s04 \
  --docker-server=nvcr.io \
  --docker-username=\$oauthtoken \
  --docker-password=<NGC_API_KEY>

# Fix issue 2: Use a valid public image for practice
# Use nginx as a stand-in (tritonserver requires NGC login)
```

## Root Cause

Two bugs:
1. **Wrong image tag**: `24.01-py3-sdk-NONEXISTENT` doesn't exist. The valid tag is `24.01-py3`.
2. **Missing imagePullSecret**: `ngc-registry-secret-WRONG` doesn't exist, and even if correctly named, the NVIDIA GPU Cloud registry (nvcr.io) requires authentication.

## Fix

```yaml
spec:
  containers:
    - name: inference-server
      image: nvcr.io/nvidia/tritonserver:24.01-py3   # fixed tag
  imagePullSecrets:
    - name: ngc-registry-secret   # fixed name (must exist in same namespace)
```

## What to Tell the Customer

> "We found two issues. First, the image tag `24.01-py3-sdk-NONEXISTENT` doesn't exist in the NVIDIA NGC registry — the correct tag is `24.01-py3`. Second, the imagePullSecret is named `ngc-registry-secret-WRONG` in your manifest but should be `ngc-registry-secret`. Please confirm your NGC API key is up to date and re-create the secret if needed. Once both are fixed, your pods should pull successfully."

## Practice Commands

```bash
# For practice: use a public image instead
kubectl set image deployment/ml-inference \
  inference-server=nginx:1.25 -n s04

# Remove the broken imagePullSecrets reference
kubectl patch deployment ml-inference -n s04 --type='json' \
  -p='[{"op":"remove","path":"/spec/template/spec/imagePullSecrets"}]'

kubectl get pods -n s04 -w   # should go Running now
```
