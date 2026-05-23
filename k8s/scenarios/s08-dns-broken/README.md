# Scenario 08 — DNS Resolution Failure

## Customer Complaint

> "Our microservices can't talk to each other. We're getting 'name or service not known' errors in our logs. Everything was working fine before our namespace migration."

## Setup

```bash
kubectl create namespace s08-frontend
kubectl create namespace s08-backend
kubectl apply -f broken.yaml
kubectl get pods -n s08-frontend -n s08-backend
```

## Your Mission

The frontend service can't resolve the backend service DNS name. Debug why DNS resolution is failing.

**Do NOT look at solution.md until you've tried for at least 6 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
Run a DNS query from the frontend pod and see what it returns.
</details>

<details>
<summary>Hint 2</summary>
The full DNS name for a service is: <service>.<namespace>.svc.cluster.local
</details>

<details>
<summary>Hint 3</summary>
Check if CoreDNS is running and healthy.
</details>

## Teardown

```bash
kubectl delete namespace s08-frontend s08-backend
```
