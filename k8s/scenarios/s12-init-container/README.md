# Scenario 12 — Init Container Failing

## Customer Complaint

> "Our database migration pod is stuck. kubectl get pods shows 'Init:0/2' — it never gets past initialization. Our deployment window closes in 30 minutes."

## Setup

```bash
kubectl create namespace s12
kubectl apply -f broken.yaml -n s12
kubectl get pods -n s12 -w
```

## Your Mission

The pod is stuck in init phase. Find out why and fix it. Two init containers — one succeeds, one fails.

**Do NOT look at solution.md until you've tried for at least 5 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
`kubectl logs <pod> -c <init-container-name>` — you must specify the container name for init containers.
</details>

<details>
<summary>Hint 2</summary>
Check what init containers are defined and their status separately.
</details>

## Teardown

```bash
kubectl delete namespace s12
```
