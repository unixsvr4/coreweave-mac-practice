# Scenario 11 — GPU Workload (Mock)

## Customer Complaint

> "Our H100 training job submitted 10 minutes ago and all pods are Pending. We have a $50k/month GPU contract — this is completely unacceptable."

## Context

This is a HIGH PRIORITY simulation. In a real CoreWeave cluster, GPU nodes exist and `nvidia.com/gpu` resources are available. In minikube/OrbStack, no GPUs exist, so these pods will stay Pending — but the DEBUG PROCESS is identical.

## Setup

```bash
kubectl create namespace s11
kubectl apply -f gpu-pod.yaml -n s11
kubectl get pods -n s11 -w
```

## Your Mission

1. Debug why the GPU pods are Pending
2. Know the full debugging flow for a real CoreWeave GPU issue
3. Understand how to distinguish: "no GPU available" vs "wrong nodeSelector" vs "quota exceeded" vs "GPU driver issue"

## Practice Flow (even though pods stay Pending here)

Work through all debug commands in solution.md as if this were a real cluster. The commands and reasoning are what the interviewer wants to hear.

## Teardown

```bash
kubectl delete namespace s11
```
