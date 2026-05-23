# Storage Debugging — PV / PVC / StorageClass Cheatsheet

## Storage Architecture in Kubernetes

```
Pod → PVC (claim) → PV (volume) → StorageClass (provisioner) → Backend storage
           ↓ bind                        ↓ dynamically provisions PV
```

## PVC Debugging

```bash
# Check PVC status
kubectl get pvc -n <ns>
# STATUS: Pending = not bound, Bound = healthy, Lost = PV deleted

# Detailed PVC diagnosis
kubectl describe pvc <pvc> -n <ns>
# Events section tells you WHY it's pending:
#   "no persistent volumes available for this claim"
#   "storageclass.storage.k8s.io "fast-nvme" not found"
#   "volume <pv> already bound to a different claim"

# Check available PVs
kubectl get pv
kubectl describe pv <pv>
# Look at: capacity, accessModes, reclaim policy, storageClass, status

# StorageClasses available
kubectl get storageclass
kubectl describe storageclass <sc>
# Is it the default? (annotation: storageclass.kubernetes.io/is-default-class=true)

# Dynamic provisioner logs (e.g. local-path-provisioner for minikube)
kubectl logs -n local-path-storage -l app=local-path-provisioner
```

## Common PVC Pending Causes

| Cause | Signal | Fix |
|-------|--------|-----|
| StorageClass doesn't exist | Events: `storageclass not found` | Create SC or fix name in PVC |
| No PV with matching capacity | Events: `no volumes available` | Create PV or let provisioner do it |
| Access mode mismatch | Events: `cannot use existing volume` | PV has RWO, PVC wants RWX |
| Wrong namespace | PVC in ns A, PV is cluster-scoped | Check PVC namespace |
| PV Retained from old PVC | PV status `Released` not `Available` | Delete old PV or patch to remove claimRef |
| Node affinity mismatch | PV has `nodeAffinity` for node X, pod schedules on Y | Fix node affinity or use zone-aware SC |

## Access Modes

| Mode | Short | Meaning | Common Use |
|------|-------|---------|-----------|
| ReadWriteOnce | RWO | Mounted by one node at a time | Most databases |
| ReadOnlyMany | ROX | Mounted read-only by many nodes | Dataset serving |
| ReadWriteMany | RWX | Mounted read-write by many nodes | Shared training data (WEKA) |
| ReadWriteOncePod | RWOP | Single pod only (K8s 1.22+) | Single-writer guarantee |

**CoreWeave context**: AI training datasets need **RWX** to be accessed by all training pods simultaneously. WEKA filesystem supports this natively.

## Volume Types

```yaml
# EmptyDir (ephemeral, dies with pod — use for cache/tmp)
volumes:
  - name: cache
    emptyDir:
      medium: Memory     # tmpfs — uses RAM
      sizeLimit: 2Gi

# HostPath (mounts node directory — DANGEROUS, avoid in prod)
volumes:
  - name: host-data
    hostPath:
      path: /data
      type: Directory    # DirectoryOrCreate, FileOrCreate, Socket

# ConfigMap volume
volumes:
  - name: config
    configMap:
      name: my-config
      items:
        - key: app.conf
          path: app.conf   # mounted as /config/app.conf

# Secret volume
volumes:
  - name: creds
    secret:
      secretName: my-secret
      defaultMode: 0400   # read-only for owner

# PVC volume (persistent)
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc
      readOnly: false
```

## StorageClass Definition (for OrbStack/minikube)

```yaml
# local-path provisioner (built into k3s/rancher, install on minikube)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer   # delays bind until pod scheduled
reclaimPolicy: Delete
```

## PersistentVolume Manual Creation

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete   # or Retain
  storageClassName: local-storage
  local:
    path: /data/my-pv
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: ["worker-node-1"]
```

## Fixing a Stuck "Released" PV

```bash
# PV in Released state (old PVC was deleted, but PV is Retained)
kubectl patch pv <pv-name> -p '{"spec":{"claimRef": null}}'
# This resets PV to Available so it can be bound to a new PVC
```

## Volume Debugging Inside a Pod

```bash
# Check if volume is mounted
kubectl exec <pod> -- df -h
kubectl exec <pod> -- mount | grep /data
kubectl exec <pod> -- ls -la /data

# Check write permissions
kubectl exec <pod> -- touch /data/test-write
kubectl exec <pod> -- dd if=/dev/zero of=/data/speed-test bs=1M count=100

# Permissions issues (common when securityContext.fsGroup differs from mount ownership)
kubectl exec <pod> -- stat /data
# If owned by root but pod runs as uid 1001:
# Fix: set spec.securityContext.fsGroup: 1001
#      or initContainer that chowns the mount
```

## CoreWeave / HPC Storage Notes

- **WEKA** is CoreWeave's high-performance parallel filesystem (NFS-like but faster)
  - Supports RWX — all training pods can read/write simultaneously
  - Used for datasets, checkpoints, model artifacts
  - Mounted via WEKA CSI driver (custom StorageClass)

- **Local NVMe** — some GPU nodes have local SSDs for high-speed temp storage
  - `local-path` or `local` StorageClass
  - Only RWO — tied to one node

- **S3-compatible** — for large dataset storage
  - MinIO or AWS S3 accessed via S3 URL in training scripts, not PVC

- **Common AI training storage pattern**:
  ```
  Dataset: WEKA PVC (RWX, ReadOnly) — shared by all worker pods
  Checkpoints: WEKA PVC (RWX, ReadWrite) — all workers write checkpoints
  Logs: local emptyDir or stdout (collected by logging agent)
  ```

- **Checkpoint debugging**: If training job fails mid-run, customer may have partial checkpoints in PVC. Use `kubectl exec` to verify checkpoint files are intact.
