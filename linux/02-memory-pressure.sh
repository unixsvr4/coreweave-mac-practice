#!/bin/bash
# Linux Debug Exercise 02 — Memory Pressure
# Simulates memory allocation and walks you through diagnosing memory issues.
# Run: bash linux/02-memory-pressure.sh

set -euo pipefail

echo "=== Exercise 02: Memory Pressure Debugging ==="
echo ""
echo "Starting a memory-intensive process (200MB allocation)..."
echo "This will hold memory for 30 seconds."
echo ""

# Allocate ~200MB for 30 seconds
python3 -c "
import time
print('Allocating 200MB...')
data = bytearray(200 * 1024 * 1024)  # 200MB
print(f'Allocated. PID: {__import__(\"os\").getpid()}')
time.sleep(30)
print('Releasing memory.')
" &
MEM_PID=$!

sleep 1
echo "Memory process PID: ${MEM_PID}"
echo ""
echo "=== Diagnosis commands to run NOW ==="
echo ""
echo "1. Check overall memory:"
echo "   free -h"
echo ""
echo "2. Check process memory:"
echo "   ps aux --sort=-%mem | head -10"
echo "   cat /proc/${MEM_PID}/status | grep -i vm"
echo ""
echo "3. Memory detail:"
echo "   cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|Cached|SwapUsed'"
echo ""
echo "4. OOM score (higher = more likely to be killed by kernel):"
echo "   cat /proc/${MEM_PID}/oom_score"
echo "   cat /proc/${MEM_PID}/oom_score_adj"
echo ""
echo "5. Process memory map:"
echo "   pmap -x ${MEM_PID} | tail -5"
echo ""
echo "6. Watch memory in real-time:"
echo "   watch -n 1 'free -h && echo \"\" && ps aux --sort=-%mem | head -5'"
echo ""
echo "Waiting 30s for process to finish..."
wait $MEM_PID 2>/dev/null || true
echo ""
echo "Memory released. Check free -h again to see it restored."
