# Solution — Scenario 12: Init Container Failing

## Debugging Steps

```bash
# Step 1: Check pod state
kubectl get pod db-migration -n s12
# NAME           READY   STATUS     RESTARTS   AGE
# db-migration   0/1     Init:1/2   0          5m
# ← "Init:1/2" = first init done, second stuck

# Step 2: Check init container status in detail
kubectl describe pod db-migration -n s12
# Init Containers:
#   check-secrets:
#     State: Terminated
#     Reason: Completed    ← ✓ success
#   wait-for-db:
#     State: Running       ← still running (looping, never connecting)

# Step 3: Get logs from the FAILING init container (must name it)
kubectl logs db-migration -n s12 -c wait-for-db
# Waiting for database to be ready...
# Connecting to postgres.databases.svc.cluster.local:5432...
#   Database not ready yet, retrying in 5s...
#   Database not ready yet, retrying in 5s...
# ← It's looping forever — can't connect to the DB

# Step 4: Check if the database service exists
kubectl get svc -A | grep postgres
# (nothing — there's no postgres service in the cluster)

# Step 5: Verify the secret content
kubectl get secret db-credentials -n s12 -o jsonpath='{.data.host}' | base64 -d
# postgres.databases.svc.cluster.local
# Check if namespace "databases" exists
kubectl get namespace databases
# Error from server (NotFound)  ← namespace doesn't exist

# Root cause: database hasn't been deployed yet (or wrong namespace)

# Fix Option 1: Deploy a stub postgres for testing
kubectl create namespace databases
kubectl run postgres --image=postgres:16-alpine -n databases \
  --env POSTGRES_PASSWORD=test \
  --port 5432
kubectl expose pod postgres -n databases --port 5432

# Fix Option 2: Update the secret host to point to actual DB
kubectl patch secret db-credentials -n s12 --type='json' \
  -p='[{"op":"replace","path":"/data/host","value":"'"$(echo -n 'postgres.default.svc.cluster.local' | base64)"'"}]'

# Fix Option 3: If DB is not ready yet, delete pod and resubmit after DB is up
kubectl delete pod db-migration -n s12
```

## Root Cause

The `wait-for-db` init container connects to `postgres.databases.svc.cluster.local:5432`. This namespace/service doesn't exist in the cluster. The init container loops indefinitely (designed to wait), blocking the main container from starting.

## What to Tell the Customer

> "Your migration pod is stuck on the second init container `wait-for-db`. It's trying to connect to `postgres.databases.svc.cluster.local:5432` but no PostgreSQL service exists at that address in your cluster. Either the database hasn't been deployed yet, or the hostname in your `db-credentials` secret is incorrect. Can you confirm: (1) Is PostgreSQL deployed, and if so, in which namespace? (2) What is the correct service name? Once I have the right address, I'll update the secret and restart the pod."

## Init Container Cheatsheet

```bash
# Check init container names
kubectl get pod <pod> -o jsonpath='{.spec.initContainers[*].name}'

# Logs for a specific init container
kubectl logs <pod> -c <init-container-name>
kubectl logs <pod> -c <init-container-name> --previous  # after restart

# Status of each init container
kubectl describe pod <pod> | grep -A 20 "Init Containers:"

# Status codes:
# Init:N/M  = N init containers complete, M total
# Init:Error = an init container exited non-zero
# PodInitializing = all init containers done, main starting
```
