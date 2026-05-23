# Scenario 04 — ImagePullBackOff

## Customer Complaint

> "We just updated our Helm chart with our latest container image and now the deployment is broken. Nothing is running."

## Setup

```bash
kubectl create namespace s04
kubectl apply -f broken.yaml -n s04
kubectl get pods -n s04 -w
```

## Your Mission

The pod is in `ErrImagePull` / `ImagePullBackOff`. Debug it and identify the two issues present.

**Do NOT look at solution.md until you've tried for at least 5 minutes.**

## Teardown

```bash
kubectl delete namespace s04
```
