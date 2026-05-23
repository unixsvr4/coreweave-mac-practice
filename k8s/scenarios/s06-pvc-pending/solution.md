# Solution — Scenario 06: PVC Stuck Pending

## Debugging Steps

```bash
# Step 1: Check PVC status
kubectl get pvc -n s06
# NAME               STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS       AGE
# training-dataset   Pending                                       weka-parallel-fs   2m

# Step 2: Describe the PVC
kubectl describe pvc training-dataset -n s06
# Events:
#   Warning  ProvisioningFailed  ... no volume plugin matched name "weka-parallel-fs"
# → StorageClass "weka-parallel-fs" doesn't exist in this cluster

# Step 3: Check what StorageClasses exist
kubectl get storageclass
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# standard (default)   docker.io/hostpath      Delete          Immediate
# OR: local-path       rancher.io/local-path   Delete          WaitForFirstConsumer

# Step 4: Check what access modes local-path supports
kubectl describe storageclass local-path
# local-path only supports ReadWriteOnce (RWO) — single node

# Fix 1: Use an existing StorageClass
kubectl patch pvc training-dataset -n s06 -p '{"spec":{"storageClassName":"standard"}}'
# Note: storageClassName is immutable after creation — must delete and recreate

# Fix 2: Fix access mode too
kubectl delete pvc training-dataset -n s06
kubectl apply -f - -n s06 <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-dataset
spec:
  storageClassName: standard   # use existing SC
  accessModes:
    - ReadWriteOnce             # local-path supports RWO
  resources:
    requests:
      storage: 1Gi             # also reduce to realistic local size
EOF
```

## Root Causes

1. **Non-existent StorageClass**: `weka-parallel-fs` is CoreWeave's production WEKA storage class but doesn't exist in a local practice cluster. Must use the local provisioner's class.
2. **Unsupported access mode**: `ReadWriteMany` (RWX) requires a shared filesystem backend. Local-path provisioner only supports `ReadWriteOnce` (single node).

## What to Tell the Customer

> "The PVC is Pending for two reasons. First, the StorageClass `weka-parallel-fs` doesn't exist in this namespace — it needs to be provisioned as part of your storage entitlement. Let me check if WEKA storage is configured for your account. Second, `ReadWriteMany` access mode requires WEKA or another shared filesystem. If you're on local SSD storage, only `ReadWriteOnce` is supported. For training jobs needing shared dataset access across multiple pods simultaneously, WEKA RWX is the right solution — I'll escalate to have your storage entitlement configured."

## Real CoreWeave Storage Classes

```yaml
# In real CoreWeave clusters these StorageClasses exist:
# weka-nvme          → WEKA high-performance NVMe, RWX supported
# pure-block         → Pure Storage block, RWO only
# local-nvme         → Node-local NVMe, RWO only (fastest, but not shared)
```
