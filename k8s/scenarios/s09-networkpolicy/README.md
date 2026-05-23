# Scenario 09 — NetworkPolicy Blocking Traffic

## Customer Complaint

> "We applied security policies to our namespace yesterday per your recommendation, but now our monitoring system can't scrape metrics from our pods and our services can't talk to each other."

## Setup

```bash
kubectl create namespace s09
kubectl apply -f broken.yaml -n s09
kubectl get pods,netpol -n s09
```

## Your Mission

After applying a NetworkPolicy, traffic is blocked. Identify what the policy is blocking and fix it without removing security entirely.

**Do NOT look at solution.md until you've tried for at least 8 minutes.**

## Hints (only if stuck)

<details>
<summary>Hint 1</summary>
List the NetworkPolicies in the namespace and describe them carefully.
</details>

<details>
<summary>Hint 2</summary>
A NetworkPolicy with empty podSelector matches ALL pods. An empty ingress rule block means DENY ALL.
</details>

<details>
<summary>Hint 3</summary>
You need to add explicit allow rules for: (1) intra-namespace traffic, (2) Prometheus scraping from monitoring namespace.
</details>

## Teardown

```bash
kubectl delete namespace s09
```
