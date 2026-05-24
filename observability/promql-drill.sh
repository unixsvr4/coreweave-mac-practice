#!/usr/bin/env bash
# PromQL Drill — runs 15 real queries against live Prometheus and prints results.
# Run from repo root: bash observability/promql-drill.sh
# Or:                 make promql-drill
#
# Prerequisites:
#   make obs-up   (Prometheus on localhost:9090, node-exporter on localhost:9100)
#   brew install jq

set -euo pipefail

PROM="http://localhost:9090"
BOLD=$'\033[1m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# ── helpers ───────────────────────────────────────────────────────────────────

query() {
    # Usage: query "promql expression"
    # Returns scalar value string, or "NO DATA" / "ERROR"
    local expr="$1"
    local encoded
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$expr")
    local raw
    raw=$(curl -sf "${PROM}/api/v1/query?query=${encoded}" 2>/dev/null) || { echo "ERROR"; return; }

    local status result_type
    status=$(echo "$raw" | jq -r '.status' 2>/dev/null)
    if [[ "$status" != "success" ]]; then echo "ERROR"; return; fi

    result_type=$(echo "$raw" | jq -r '.data.resultType' 2>/dev/null)

    case "$result_type" in
        vector)
            local count
            count=$(echo "$raw" | jq '.data.result | length')
            if [[ "$count" -eq 0 ]]; then
                echo "NO DATA"
            elif [[ "$count" -eq 1 ]]; then
                echo "$raw" | jq -r '.data.result[0].value[1]'
            else
                # Multiple series — print metric labels + value, one per line
                echo ""
                echo "$raw" | jq -r '.data.result[] | "    " + ((.metric | to_entries | map(.key+"="+.value) | join(",")) + " → " + .value[1])'
            fi
            ;;
        scalar)
            echo "$raw" | jq -r '.data.result[1]'
            ;;
        *)
            echo "($result_type)"
            ;;
    esac
}

drill() {
    # Usage: drill "LABEL" "promql" "explanation"
    local label="$1" expr="$2" explanation="$3"
    local result
    result=$(query "$expr")

    printf "${CYAN}%-52s${RESET}" "$label"
    if [[ "$result" == "NO DATA" ]]; then
        printf "${YELLOW}%-20s${RESET}" "no data (ok)"
    elif [[ "$result" == "ERROR" ]]; then
        printf "${RED}%-20s${RESET}" "error"
    elif [[ "$result" == "" ]]; then
        printf "\n"   # multi-series already printed inline
    else
        printf "${GREEN}%-20s${RESET}" "$result"
    fi
    printf "  ${DIM}%s${RESET}\n" "$explanation"
}

check_prometheus() {
    if ! curl -sf "${PROM}/-/ready" &>/dev/null && ! curl -sf "${PROM}/api/v1/query?query=1" &>/dev/null; then
        echo "${RED}ERROR:${RESET} Prometheus not reachable at ${PROM}"
        echo "Run:  make obs-up"
        exit 1
    fi
}

# ── main ─────────────────────────────────────────────────────────────────────

check_prometheus

echo ""
echo "${BOLD}PromQL Drill — $(date '+%H:%M:%S')${RESET}   Prometheus: ${PROM}"
echo "$(printf '%.0s─' {1..80})"
printf "${BOLD}%-52s %-20s  %s${RESET}\n" "QUERY" "RESULT" "WHAT IT MEANS"
echo "$(printf '%.0s─' {1..80})"

echo ""
echo "${BOLD}── HOST / NODE ──────────────────────────────────────────────────────────────${RESET}"

drill \
    "Host CPU usage %" \
    '(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100' \
    "all cores; >80% = investigate"

drill \
    "CPU iowait %" \
    'avg(rate(node_cpu_seconds_total{mode="iowait"}[5m])) * 100' \
    "high = disk or NFS bottleneck"

drill \
    "Host memory used %" \
    '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100' \
    ">90% = memory pressure risk"

drill \
    "Memory available (bytes)" \
    'node_memory_MemAvailable_bytes' \
    "raw bytes available to processes"

drill \
    "Disk usage % (largest mount)" \
    'max((1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) * 100)' \
    ">85% = alert threshold"

drill \
    "Network RX rate (bytes/s)" \
    'sum(rate(node_network_receive_bytes_total{device!="lo"}[5m]))' \
    "total inbound across all interfaces"

drill \
    "Network TX rate (bytes/s)" \
    'sum(rate(node_network_transmit_bytes_total{device!="lo"}[5m]))' \
    "total outbound"

echo ""
echo "${BOLD}── KUBERNETES ──────────────────────────────────────────────────────────────${RESET}"

drill \
    "Pods NOT Running or Succeeded" \
    'count(kube_pod_status_phase{phase!~"Running|Succeeded"}) or vector(0)' \
    "0 = healthy; >0 = investigate"

drill \
    "Pod restart rate (restarts/min)" \
    'sum(rate(kube_pod_container_status_restarts_total[5m])) * 60' \
    "any value >0 = active crash loops"

drill \
    "OOMKilled containers right now" \
    'sum(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}) or vector(0)' \
    "count of containers OOMKilled"

drill \
    "Deployments with unavailable pods" \
    'sum(kube_deployment_status_replicas_unavailable) or vector(0)' \
    "0 = all deployments healthy"

drill \
    "PVCs not Bound" \
    'count(kube_persistentvolumeclaim_status_phase{phase!="Bound"}) or vector(0)' \
    "0 = all PVCs healthy"

echo ""
echo "${BOLD}── OBSERVABILITY / COREDNS ─────────────────────────────────────────────────${RESET}"

drill \
    "CoreDNS query rate (req/s)" \
    'sum(rate(coredns_dns_requests_total[5m]))' \
    "DNS traffic load"

drill \
    "CoreDNS error rate (NXDOMAIN etc)" \
    'sum(rate(coredns_dns_responses_total{rcode!="NOERROR"}[5m]))' \
    ">0 = DNS failures (check pod /etc/resolv.conf)"

drill \
    "CoreDNS p99 latency (s)" \
    'histogram_quantile(0.99, rate(coredns_dns_request_duration_seconds_bucket[5m]))' \
    ">0.1s = slow DNS (impacts all pod comms)"

echo ""
echo "${BOLD}── GPU (DCGM — returns NO DATA on practice cluster without GPUs) ───────────${RESET}"

drill \
    "GPU utilization avg %" \
    'avg(DCGM_FI_DEV_GPU_UTIL)' \
    "<20% = idle GPU (wasted spend)"

drill \
    "GPU memory used MiB" \
    'avg(DCGM_FI_DEV_FB_USED)' \
    "MiB used across all GPUs"

drill \
    "GPU max temperature °C" \
    'max(DCGM_FI_DEV_GPU_TEMP)' \
    ">85°C = thermal throttle risk"

drill \
    "GPU power usage (watts)" \
    'sum(DCGM_FI_DEV_POWER_USAGE)' \
    "total cluster GPU power draw"

echo ""
echo "${BOLD}── SLO / ERROR BUDGET ──────────────────────────────────────────────────────${RESET}"

drill \
    "HTTP 5xx rate (need http_requests_total)" \
    'sum(rate(http_requests_total{status=~"5.."}[5m])) or vector(0)' \
    "0 = no server errors"

drill \
    "Prometheus scrape failures" \
    'sum(up == 0) or vector(0)' \
    "0 = all targets reachable"

drill \
    "Prometheus targets total" \
    'count(up)' \
    "number of scrape targets configured"

echo ""
echo "$(printf '%.0s─' {1..80})"
echo "${BOLD}Quick reference:${RESET}"
echo "  Instant query : curl -s '${PROM}/api/v1/query?query=<expr>' | jq '.data.result'"
echo "  Range query   : curl -s '${PROM}/api/v1/query_range?query=<expr>&start=<t>&end=<t>&step=15s'"
echo "  All targets   : curl -s '${PROM}/api/v1/targets' | jq '.data.activeTargets[].labels'"
echo "  Grafana       : open http://localhost:3000  (admin / admin)"
echo ""
