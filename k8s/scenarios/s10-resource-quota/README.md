# Scenario 10 — Resource Quota Exceeded

## Customer Complaint

> "We're trying to scale up our training job from 2 to 8 workers but the new pods aren't being created. No error in our deployment — they just don't appear."

## Setup

```bash
kubectl create namespace s10
kubectl apply -f broken.yaml -n s10
kubectl get pods,quota -n s10
```

## Your Mission

New pods aren't being created. No obvious error. Find why the scale-up is failing.

**Do NOT look at solution.md until you've tried for at least 5 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Check the ReplicaSet events — rejected pods show up there, not on the Deployment.
</details>

<details>
<summary>Hint 2</summary>
Check the ResourceQuota in the namespace — it may be exhausted.
</details>

## Teardown

```bash
kubectl delete namespace s10
```
