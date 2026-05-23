# Solution — Scenario 10: Resource Quota Exceeded

## Debugging Steps

```bash
# Step 1: Check pods — only 2 training workers, not 4
kubectl get pods -n s10
# existing-service-XXXX   Running  (×2)
# training-workers-XXXX   Running  (×2, not 4)

# Step 2: Check ReplicaSet events (this is where quota errors appear)
kubectl get rs -n s10
kubectl describe rs -n s10 -l app=training-worker
# Events:
#   Warning  FailedCreate  ...  Error creating: pods "training-workers-XXXXX" is forbidden:
#            exceeded quota: customer-gpu-quota, requested: pods=1, used: pods=4, limited: pods=4
# ← QUOTA EXCEEDED for pod count

# Step 3: Check the quota directly
kubectl describe resourcequota customer-gpu-quota -n s10
# Name:           customer-gpu-quota
# Namespace:      s10
# Resource        Used    Hard
# --------        ----    ----
# limits.cpu      8       8      ← AT LIMIT
# limits.memory   16Gi   16Gi   ← AT LIMIT
# pods            4       4      ← AT LIMIT
# requests.cpu    4       4      ← AT LIMIT
# requests.memory 8Gi    8Gi    ← AT LIMIT

# The existing-service (2 pods × 2 CPU limit = 4 CPU total) plus
# training-workers (2 pods × 1 CPU limit = 2 CPU total) = 6 CPU... hmm
# Actually the pod count (4) is the binding constraint here

# Fix options:
# 1. Scale down existing-service to free up pod slots
kubectl scale deployment existing-service -n s10 --replicas=1

# 2. Ask CoreWeave to increase quota (real scenario: submit support request)
# kubectl patch resourcequota customer-gpu-quota -n s10 --type='json' \
#   -p='[{"op":"replace","path":"/spec/hard/pods","value":"8"}]'

# 3. Scale training-workers down to what the quota allows
kubectl scale deployment training-workers -n s10 --replicas=2
```

## Root Cause

The namespace `ResourceQuota` limits pods to 4. With 2 existing service pods, only 2 training worker slots remain. The Deployment tries to create 4 workers — 2 succeed, 2 fail silently (error only visible in ReplicaSet events).

## What to Tell the Customer

> "Your training worker scale-up is blocked by a namespace ResourceQuota. Your namespace is limited to 4 pods total, and 2 are already used by your inference service. To run 4 training workers, you have two options: (1) temporarily scale down your existing service to 0 during training, or (2) request a quota increase. I can initiate a quota increase request on your behalf — please provide your expected GPU and memory requirements. To catch this earlier next time, I recommend monitoring `kube_resourcequota` in your Grafana dashboard."

## Check Quota Utilization (PromQL)

```promql
# Quota utilization per resource
kube_resourcequota{namespace="s10", type="used"} /
kube_resourcequota{namespace="s10", type="hard"} * 100

# Alert when > 80% of quota used
```
