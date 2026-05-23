# Scenario 05 — Pod Stuck Pending

## Customer Complaint

> "We submitted a training job 20 minutes ago and the pods are all Pending. Our jobs were running fine yesterday. We have a deadline in 2 hours."

## Setup

```bash
kubectl create namespace s05
kubectl apply -f broken.yaml -n s05
kubectl get pods -n s05 -w   # all Pending
```

## Your Mission

The pods are stuck in `Pending`. There are two separate causes in this scenario — find both.

**Do NOT look at solution.md until you've tried for at least 8 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Check the pod events — the scheduler leaves messages explaining why it can't place the pod.
</details>

<details>
<summary>Hint 2</summary>
Look at what resources the pod is requesting and what's actually available on nodes.
</details>

<details>
<summary>Hint 3</summary>
The second pod has a nodeSelector that no nodes match.
</details>

## Teardown

```bash
kubectl delete namespace s05
```
