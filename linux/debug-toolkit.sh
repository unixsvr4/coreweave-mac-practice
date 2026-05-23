#!/bin/bash
# CoreWeave Support — Linux Debug Toolkit
# Quick system snapshot — run this first when investigating a node issue.
# Usage: bash linux/debug-toolkit.sh [--full]

FULL=${1:-""}
DIVIDER="=============================================="

section() {
    echo ""
    echo "$DIVIDER"
    echo " $1"
    echo "$DIVIDER"
}

section "SYSTEM OVERVIEW"
echo "Hostname: $(hostname)"
echo "Date    : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Uptime  : $(uptime)"
uname -r 2>/dev/null | xargs echo "Kernel  :"

section "CPU"
echo "CPUs    : $(nproc) cores"
echo "Load    : $(cat /proc/loadavg)"
echo ""
echo "Top CPU processes:"
ps aux --sort=-%cpu | head -8

section "MEMORY"
free -h
echo ""
echo "Swap usage:"
swapon --show 2>/dev/null || echo "(no swap)"

section "DISK"
df -h --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null || df -h
echo ""
echo "Disk I/O (brief):"
iostat -x 1 1 2>/dev/null | tail -10 || echo "(iostat not available)"

section "NETWORK"
ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | head -20
echo ""
echo "Routing:"
ip route show 2>/dev/null | head -10
echo ""
echo "Active TCP connections (top 10):"
ss -tn 2>/dev/null | head -12 || netstat -tn 2>/dev/null | head -12

section "PROCESSES"
echo "Total processes: $(ps aux | wc -l)"
echo "Top memory consumers:"
ps aux --sort=-%mem | head -6
echo ""
echo "Zombie processes:"
ps aux | awk '{if ($8 == "Z") print}' | head -5

section "KERNEL MESSAGES (recent)"
dmesg --time-format iso 2>/dev/null | tail -20 || dmesg | tail -20

section "OOM KILLER (recent)"
dmesg 2>/dev/null | grep -i "oom\|killed\|out of memory" | tail -10 || echo "(no recent OOM events)"

if [[ "$FULL" == "--full" ]]; then
    section "OPEN FILES (lsof)"
    lsof 2>/dev/null | wc -l | xargs echo "Total open files:"
    echo ""
    echo "Open files by process:"
    lsof 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

    section "SOCKET STATISTICS"
    ss -s 2>/dev/null

    section "SYSCTLS (network/memory)"
    sysctl vm.max_map_count vm.swappiness net.core.somaxconn net.ipv4.tcp_max_syn_backlog 2>/dev/null
fi

echo ""
echo "$DIVIDER"
echo " Snapshot complete — $(date -u '+%H:%M:%S UTC')"
echo "$DIVIDER"
