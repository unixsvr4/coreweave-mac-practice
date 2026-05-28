#!/bin/bash
# Linux Debug Exercise 02 — Memory Pressure
# Simulates memory allocation and walks you through diagnosing it.
# Run: bash linux/02-memory-pressure.sh   (Mac-compatible; Linux equivalents shown in comments)

set -euo pipefail

echo "=== Exercise 02: Memory Pressure Debugging ==="
echo ""
echo "Starting a memory-intensive process (200MB allocation)..."
echo "This will hold memory for 30 seconds."
echo ""

python3 -c "
import time, os
print('Allocating 200MB...')
data = bytearray(200 * 1024 * 1024)
print(f'Allocated. PID: {os.getpid()}')
time.sleep(30)
print('Releasing memory.')
" &
MEM_PID=$!

sleep 1
echo "Memory process PID: ${MEM_PID}"
echo ""
echo "=== Diagnosis commands to run NOW in another terminal ==="
echo ""

echo "1. Overall memory:"
echo "   Mac:   vm_stat | head -10"
echo "          top -l 1 | grep PhysMem"
echo "   Linux: free -h"
echo "          cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|Cached|SwapUsed'"
echo ""

echo "2. Top memory consumers:"
echo "   Mac+Linux: ps aux | sort -k4 -rn | head -10    # column 4 = %MEM"
echo "   Linux:     ps aux --sort=-%mem | head -10"
echo ""

echo "3. This process's memory:"
echo "   Mac:   ps -p ${MEM_PID} -o pid,rss,vsz,pmem,comm"
echo "          vmmap ${MEM_PID} 2>/dev/null | tail -5   # full memory map"
echo "   Linux: cat /proc/${MEM_PID}/status | grep -i vm"
echo "          pmap -x ${MEM_PID} | tail -5"
echo ""

echo "4. OOM score (Linux only — higher = kernel kills it first):"
echo "   Linux: cat /proc/${MEM_PID}/oom_score"
echo "          cat /proc/${MEM_PID}/oom_score_adj"
echo "   Mac:   no direct equivalent; kernel uses its own priority"
echo ""

echo "5. Memory pressure indicator:"
echo "   Mac:   memory_pressure                         # shows system memory pressure level"
echo "          vm_stat 1 5                             # page-in/out rate per second"
echo "   Linux: vmstat 1 5                              # si/so = swap in/out"
echo ""

echo "6. Watch memory live:"
echo "   Mac:   while true; do ps -p ${MEM_PID} -o rss= | xargs printf 'RSS: %d KB\n'; sleep 1; done"
echo "   Linux: watch -n 1 'free -h && ps aux --sort=-%mem | head -5'"
echo ""

echo "Waiting 30s for process to finish..."
wait $MEM_PID 2>/dev/null || true
echo ""
echo "Memory released. Run 'vm_stat | head -5' (Mac) or 'free -h' (Linux) to confirm."
echo ""
echo "=== What you'd report to a customer ==="
echo "  'PID ${MEM_PID} (python3) allocated ~200MB RSS."
echo "   Linux OOM score would be elevated. If memory limit is set in K8s,"
echo "   this process would be OOMKilled (exit 137) once it crosses the cgroup limit.'"
