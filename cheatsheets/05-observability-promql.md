# Observability — Prometheus PromQL + Grafana Cheatsheet

## Prometheus Query Language (PromQL) — Essential Queries

### CPU
```promql
# Node CPU utilization (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU per mode (user, system, iowait, etc.)
rate(node_cpu_seconds_total[5m])

# Container CPU usage (cores)
rate(container_cpu_usage_seconds_total{container!=""}[5m])

# Top 10 CPU-hungry pods
topk(10, sum by (pod, namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))

# CPU throttling (important for performance issues)
rate(container_cpu_cfs_throttled_seconds_total[5m])
# High value → container hitting CPU limit; customer workload throttled
```

### Memory
```promql
# Node memory utilization (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Container memory usage (bytes → MiB)
container_memory_working_set_bytes{container!=""} / 1024 / 1024

# Memory limit utilization per pod (%)
container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100

# OOMKilled events
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}

# Top 10 memory consumers
topk(10, sum by (pod, namespace) (container_memory_working_set_bytes{container!=""}))
```

### Kubernetes State
```promql
# Pods not in Running state
kube_pod_status_phase{phase!~"Running|Succeeded"} == 1

# Pod restarts per minute
rate(kube_pod_container_status_restarts_total[5m])

# Pods with high restart count
kube_pod_container_status_restarts_total > 5

# Node conditions (MemoryPressure, DiskPressure)
kube_node_status_condition{condition!="Ready", status="true"}

# Deployment unavailable replicas
kube_deployment_status_replicas_unavailable > 0

# PVC that are not Bound
kube_persistentvolumeclaim_status_phase{phase!="Bound"} == 1
```

### Network
```promql
# Node network receive rate (bytes/s)
rate(node_network_receive_bytes_total{device!="lo"}[5m])

# Pod network transmit errors
rate(container_network_transmit_errors_total[5m]) > 0

# DNS query rate via CoreDNS
rate(coredns_dns_requests_total[5m])

# CoreDNS error rate
rate(coredns_dns_responses_total{rcode!="NOERROR"}[5m])

# CoreDNS latency (p99)
histogram_quantile(0.99, rate(coredns_dns_request_duration_seconds_bucket[5m]))
```

### GPU (CoreWeave-specific)
```promql
# GPU utilization (%)
DCGM_FI_DEV_GPU_UTIL

# GPU memory used (bytes)
DCGM_FI_DEV_FB_USED * 1024 * 1024   # MiB → bytes

# GPU memory free
DCGM_FI_DEV_FB_FREE * 1024 * 1024

# GPU temperature
DCGM_FI_DEV_GPU_TEMP

# GPU power usage (watts)
DCGM_FI_DEV_POWER_USAGE

# NVLink bandwidth (inter-GPU for NVLink clusters)
DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL

# All DCGM metrics (NVIDIA DataCenter GPU Manager exports these)
{__name__=~"DCGM_.*"}
```

### SLO / Error Budget
```promql
# Request error rate (for HTTP services)
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# Availability = 1 - error rate (rolling 30d)
1 - (
  sum(rate(http_requests_total{status=~"5.."}[30d]))
  /
  sum(rate(http_requests_total[30d]))
)

# Error budget remaining (for 99.9% SLO over 30 days)
# Budget = 0.1% × 30d × 24h × 60min = 43.2 min
# Burned = actual downtime minutes
```

## Grafana Skills for the Interview

### Create a Dashboard Panel
1. New Dashboard → Add Panel
2. Select Prometheus datasource
3. Enter PromQL query
4. Choose visualization: Time series, Stat, Gauge, Table, Heatmap
5. Set unit: percentage, bytes, short (for counts)

### Alert Rules in Grafana
```yaml
# Grafana Alert (UI or YAML)
alert: HighPodRestarts
expr: rate(kube_pod_container_status_restarts_total[5m]) > 0.1
for: 5m
labels:
  severity: warning
annotations:
  summary: "Pod {{ $labels.pod }} is restarting frequently"
  description: "Restart rate: {{ $value | humanize }} per second"
```

### Prometheus Alert Rules (prometheus/alert-rules.yml)
```yaml
groups:
  - name: kubernetes
    rules:
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is crash-looping"

      - alert: NodeMemoryPressure
        expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.node }} has memory pressure"

      - alert: GPUHighTemperature
        expr: DCGM_FI_DEV_GPU_TEMP > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GPU {{ $labels.gpu }} temperature is {{ $value }}°C"
```

## Key Grafana Dashboards to Know

| Dashboard | What it shows |
|-----------|--------------|
| Kubernetes / Compute Resources / Cluster | CPU/memory usage across all nodes |
| Kubernetes / Compute Resources / Namespace | Usage per namespace |
| Kubernetes / Nodes | Node CPU, memory, disk, network |
| Node Exporter / Full | Detailed Linux node metrics |
| NVIDIA DCGM | GPU utilization, memory, temperature, power |

These are available in Grafana's dashboard marketplace (grafana.com/grafana/dashboards).
Import by ID: 315 (Node Exporter), 6417 (Kubernetes cluster), 12239 (DCGM GPU)

## Talking Points for the Interview

- "I'd instrument SLOs as recording rules in Prometheus to avoid expensive raw queries at dashboard render time."
- "For GPU workloads I'd set up DCGM exporter alerts on GPU utilization below 80% — that signals a scheduling or CUDA initialization problem."
- "Alert fatigue reduction: I reduced alerts by 41% by using error rate alerts instead of absolute count alerts — they're more meaningful and don't fire during low traffic."
- "For customer-facing SLOs I export burn rate alerts using multi-window, multi-burn-rate strategy (Google SRE Book chapter 5)."
