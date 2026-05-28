# Scenario 06 — PVC Stuck Pending

## Customer Complaint

> "Our training job can't start. The pod is stuck in 'ContainerCreating' and we can't access our dataset volume. This is blocking our entire team."

## Setup

```bash
kubectl create namespace s06
kubectl apply -f broken.yaml -n s06
kubectl get pvc -n s06
kubectl get pods -n s06
# To watch both live (watch re-runs the full command every 2s):
watch -n 2 'kubectl get pvc,pods -n s06'
```

## Your Mission

The PVC is stuck Pending. There are two issues — find both and fix them.

**Do NOT look at solution.md until you've tried for at least 5 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Check what StorageClasses exist in the cluster.
</details>

<details>
<summary>Hint 2</summary>
Look at the access mode the PVC is requesting vs what's available.
</details>

## Teardown

```bash
kubectl delete namespace s06
```
