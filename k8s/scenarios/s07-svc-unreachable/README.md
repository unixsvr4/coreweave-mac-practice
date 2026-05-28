# Scenario 07 — Service Unreachable

## Customer Complaint

> "Our inference API is deployed and the pods are Running, but our load balancer can't reach the service. Requests are timing out. We have customers waiting."

## Setup

```bash
kubectl create namespace s07
kubectl apply -f broken.yaml -n s07
kubectl get pods,svc,endpointslices -n s07
```

## Your Mission

The service exists but traffic doesn't reach the pods. Find the two bugs.

**Do NOT look at solution.md until you've tried for at least 6 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Check the endpoints for the service — they should show pod IPs. If it shows "none", the selector is wrong.
</details>

<details>
<summary>Hint 2</summary>
Also check the port configuration — targetPort must match what the container is actually listening on.
</details>

## Teardown

```bash
kubectl delete namespace s07
```
