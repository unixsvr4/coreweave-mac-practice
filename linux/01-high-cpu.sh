#!/bin/bash
# Linux Debug Exercise 01 — High CPU
# Simulates a CPU spike and walks you through diagnosing it.
# Run: bash linux/01-high-cpu.sh   (Mac-compatible; Linux equivalents shown in comments)

set -euo pipefail

echo "=== Exercise 01: High CPU Debugging ==="
echo ""
echo "Starting a CPU-intensive background process..."
echo "You have 60 seconds to diagnose it before it stops."
echo ""

python3 -c "
import time
end = time.time() + 60
while time.time() < end:
    x = sum(range(1000000))
" &
HOG_PID=$!

echo "CPU hog started (PID: ${HOG_PID})"
echo ""
echo "=== Diagnosis commands to run NOW in another terminal ==="
echo ""

echo "1. Load average (identical on Mac and Linux):"
echo "   uptime"
echo "   # look for: load avg 1m > number of cores = CPU saturation"
echo ""

echo "2. Top CPU consumers:"
echo "   Mac:   top -l 1 -o cpu | head -20"
echo "   Linux: top -b -n 1 | head -20"
echo "   Both:  ps aux | sort -k3 -rn | head -10"
echo ""

echo "3. Per-CPU core breakdown:"
echo "   Mac:   top -l 1 | grep -E 'CPU|Load'"
echo "          sysctl -n machdep.cpu.core_count   # total cores"
echo "   Linux: mpstat -P ALL 1 3                  # per-core stats (sysstat package)"
echo ""

echo "4. What the PID is doing (system calls):"
echo "   Mac:   sample ${HOG_PID} 5               # 5s profile, no sudo needed"
echo "   Linux: strace -p ${HOG_PID} -c            # syscall summary"
echo "          sudo perf top -p ${HOG_PID}        # hot functions"
echo ""

echo "5. Process resource usage:"
echo "   Mac+Linux: ps -p ${HOG_PID} -o pid,pcpu,pmem,vsz,rss,comm"
echo ""

echo "6. Real-time CPU watch:"
echo "   Mac:   while true; do ps -p ${HOG_PID} -o pcpu= | xargs printf 'CPU: %s%%\n'; sleep 1; done"
echo "   Linux: pidstat -p ${HOG_PID} 1            # (sysstat package)"
echo ""

echo "=== After 60 seconds the process will stop automatically ==="
echo "Press Ctrl+C to stop early"
echo ""

wait $HOG_PID 2>/dev/null || true
echo ""
echo "CPU hog finished. Load average should recover in ~1 minute."
echo ""
echo "=== What you'd report to a customer ==="
echo "  'PID ${HOG_PID} (python3) is consuming 100% of one CPU core."
echo "   Load average spiked to $(sysctl -n hw.logicalcpu 2>/dev/null || echo N)+ (above core count)."
echo "   sample/strace shows it is in a tight computation loop with no I/O wait.'"
