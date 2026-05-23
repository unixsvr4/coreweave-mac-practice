# Scenario 02 — OOMKilled

## Customer Complaint

> "Our data processing job keeps getting killed randomly. We see exit code 137. Is there a hardware issue with your GPU nodes? This is a production workload."

## Setup

```bash
kubectl create namespace s02
kubectl apply -f broken.yaml -n s02
# The pod will start, consume memory, and get OOMKilled within ~30 seconds
kubectl get pods -n s02 -w
```

## Your Mission

The pod keeps being killed. Exit code 137 = OOMKilled (signal 9 = SIGKILL from the OOM killer). Debug it and fix the memory limit.

**Do NOT look at solution.md until you've tried for at least 5 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Check the "Last State" section of kubectl describe pod — it shows the exit code and reason.
</details>

<details>
<summary>Hint 2</summary>
Look at the resource limits set on the container vs how much memory the job actually needs.
</details>

<details>
<summary>Hint 3</summary>
kubectl top pod will show actual memory consumption while the pod is running.
</details>

## Teardown

```bash
kubectl delete namespace s02
```
