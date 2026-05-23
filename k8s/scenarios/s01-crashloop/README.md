# Scenario 01 — CrashLoopBackOff

## Customer Complaint

> "Our API service pod keeps restarting. It was running fine yesterday. We haven't changed anything in our code."

## Setup

```bash
kubectl create namespace s01
kubectl apply -f broken.yaml -n s01
kubectl get pods -n s01 -w   # watch it crash
```

## Your Mission

The pod is in `CrashLoopBackOff`. Debug it, find the root cause, and fix it. Time yourself — target < 8 minutes.

**Do NOT look at solution.md until you've tried for at least 5 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Check the container logs — both current and previous instance.
</details>

<details>
<summary>Hint 2</summary>
Look at what the container is trying to execute and what environment variables it expects.
</details>

<details>
<summary>Hint 3</summary>
The application expects a configuration file to be mounted. Check if the volume mount is correct.
</details>

## Teardown

```bash
kubectl delete namespace s01
```
