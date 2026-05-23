#!/bin/bash
# Linux Debug Exercise 01 — High CPU
# Simulates a CPU spike and walks you through diagnosing it.
# Run: bash linux/01-high-cpu.sh

set -euo pipefail

echo "=== Exercise 01: High CPU Debugging ==="
echo ""
echo "Starting a CPU-intensive background process..."
echo "You have 60 seconds to diagnose it before it stops."
echo ""

# Start a CPU hog in the background
python3 -c "
import time
end = time.time() + 60
while time.time() < end:
    x = sum(range(1000000))
" &
HOG_PID=$!

echo "CPU hog started (PID: ${HOG_PID})"
echo ""
echo "=== Now run these diagnosis commands ==="
echo ""
echo "1. Check load average:"
echo "   uptime"
echo ""
echo "2. Find the top CPU consumers:"
echo "   top -b -n 1 | head -20"
echo "   ps aux --sort=-%cpu | head -10"
echo ""
echo "3. Check per-CPU breakdown:"
echo "   mpstat -P ALL 1 3"
echo ""
echo "4. Check what Python is doing (if installed):"
echo "   strace -p ${HOG_PID} -c -e trace=all &   # run for 5s then Ctrl+C"
echo ""
echo "5. Real-time monitoring:"
echo "   vmstat 1 10"
echo ""
echo "=== After 60 seconds the process will stop ==="
echo "Press Ctrl+C to stop early if needed"
echo ""

wait $HOG_PID 2>/dev/null || true
echo ""
echo "CPU hog finished. Load average should recover in ~1 minute."
