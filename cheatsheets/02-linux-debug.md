# Linux System Administration Debugging — Cheatsheet

## CPU Debugging

```bash
# High-level CPU overview
top -b -n 1         # batch mode, one snapshot
htop                # interactive (if installed)
uptime              # load averages: 1m, 5m, 15m (vs nproc)

# Per-process CPU
ps aux --sort=-%cpu | head -20
pidstat 1 5         # CPU usage per PID, 1-sec intervals, 5 samples (sysstat)

# CPU breakdown by state
vmstat 1 5          # us=user, sy=system, wa=iowait, id=idle
sar -u 1 5          # historical CPU utilization (sysstat)

# Per-core CPU (useful for NUMA/HPC)
mpstat -P ALL 1 3   # per-core, 1-sec intervals

# Find what's burning CPU
perf top -g         # live flamegraph (needs perf installed)
perf record -g -p <pid> sleep 10 && perf report

# strace a process (overhead warning: use briefly)
strace -p <pid> -c  # syscall summary counts
strace -p <pid> -e trace=read,write,open  # filter by syscall

# eBPF — zero-overhead profiling (bpftools/bcc)
execsnoop                    # new process exec events
opensnoop -p <pid>           # files opened by pid
profile -F 99 -a             # CPU flamegraph at 99Hz
```

## Memory Debugging

```bash
# Overview
free -h              # total/used/free/buff+cache/available
cat /proc/meminfo    # detailed: MemFree, MemAvailable, SwapUsed, Slab

# Per-process memory
ps aux --sort=-%mem | head -20
pmap -x <pid>        # memory map of a process
/proc/<pid>/status   # VmRSS, VmSize, VmSwap

# OOM killer
dmesg | grep -i "oom\|killed\|memory"
journalctl -k | grep -i oom
cat /var/log/kern.log | grep -i oom   # Ubuntu

# OOM score of a process (higher = more likely to be killed)
cat /proc/<pid>/oom_score
cat /proc/<pid>/oom_score_adj         # -1000 to 1000

# Prevent a critical process from being OOM-killed
echo -1000 > /proc/<pid>/oom_score_adj  # requires root

# Memory leak investigation
valgrind --leak-check=full <command>    # for binaries
# For containers: watch RSS over time
watch -n 1 'cat /proc/<pid>/status | grep VmRSS'

# Hugepages (common in HPC/GPU workloads)
cat /proc/meminfo | grep -i huge
cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

## Disk I/O Debugging

```bash
# Disk I/O overview
iostat -xz 1 5      # extended stats: util%, await, svctm
iotop -b -n 5       # per-process I/O (needs root)
dstat --disk --top-io  # live I/O with top process

# Disk usage
df -h               # filesystem usage
du -sh /* 2>/dev/null | sort -h | tail -20   # top dirs
ncdu /              # interactive disk usage explorer (if installed)

# Find large files
find / -xdev -size +1G -exec ls -lh {} \; 2>/dev/null

# I/O latency (fio benchmark)
fio --name=test --rw=randread --bs=4k --numjobs=4 --size=1G --runtime=30 --group_reporting

# Check inode usage (often overlooked)
df -i               # inode usage per filesystem

# Identify files open by a process
lsof -p <pid>
lsof /path/to/file  # who has this file open

# Check write speed to a path
dd if=/dev/zero of=/tmp/testfile bs=1M count=512 oflag=dsync

# NVMe / SSD health
nvme smart-log /dev/nvme0
nvme list
```

## Network Debugging

```bash
# Interfaces
ip addr show
ip link show
ethtool <iface>    # speed, duplex, link detected

# Routing
ip route show
ip route get <dst-ip>   # which interface/gateway handles this IP

# Active connections
ss -tunapw          # all TCP/UDP with PIDs (modern netstat)
netstat -tunapw     # older systems
lsof -i :<port>     # what process owns a port

# DNS resolution
nslookup <hostname>
dig <hostname>
dig <hostname> @8.8.8.8    # force specific resolver
dig +trace <hostname>       # full resolution trace
cat /etc/resolv.conf        # configured resolvers

# Connectivity testing
ping -c 4 <host>
traceroute <host>
mtr <host>                  # combined ping+traceroute, live

# Packet capture
tcpdump -i any port 80 -w /tmp/capture.pcap
tcpdump -i eth0 host <ip> -nn -v
tcpdump -i eth0 'tcp port 443 and host 10.0.0.1'

# Bandwidth testing
iperf3 -c <server-ip>              # client
iperf3 -s                          # server
# For RDMA (InfiniBand) — CoreWeave specific:
# ib_write_bw, ib_read_bw, ib_send_bw (perftest package)

# Check for port reachability
nc -zv <host> <port>
curl -v telnet://<host>:<port>
```

## Process & System State

```bash
# Process tree
pstree -p <pid>
ps auxf              # forest view

# Process limits
ulimit -a            # current shell limits
cat /proc/<pid>/limits  # limits for a specific process
cat /etc/security/limits.conf   # system-wide defaults

# Systemd service debugging
systemctl status <service>
journalctl -u <service> -n 100 --no-pager
journalctl -u <service> -f          # follow
systemctl list-failed               # all failed units

# Check kernel parameters
sysctl -a | grep vm.max_map_count   # Elasticsearch requires >= 262144
sysctl -a | grep net.core
cat /proc/sys/kernel/pid_max

# cgroups — what resources is a container allocated
# cgroup v2 (Ubuntu 22.04+)
cat /sys/fs/cgroup/<scope>/memory.max
cat /sys/fs/cgroup/<scope>/cpu.max
systemd-cgls                # tree view of cgroup hierarchy

# Container-specific (from host)
crictl ps                   # containerd: list containers
crictl inspect <container>  # container details
crictl logs <container>     # container logs without kubectl

# NUMA (critical for HPC performance)
numactl --hardware           # node layout
numactl -N 0 --membind 0 <cmd>  # pin to NUMA node 0
numastat -p <pid>            # NUMA hit/miss per process
```

## Performance Profiling

```bash
# Flame graphs with perf
perf record -g -p <pid> -- sleep 30
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# Function call tracing
ltrace -p <pid>              # library calls
strace -p <pid> -f           # syscalls including forks
strace -e trace=network <cmd> # only network syscalls

# Kernel tracing with bpftrace
bpftrace -e 'tracepoint:syscalls:sys_enter_read { @[comm] = count(); }'
bpftrace -e 'kretprobe:vfs_read { @bytes[comm] = sum(retval); }'

# Application-level
# Python: py-spy top --pid <pid>
# Java: jstack <pid>, async-profiler
# Go: go tool pprof http://localhost:6060/debug/pprof/goroutine
```

## Common Root Causes and Their Symptoms

| Symptom | Likely Cause | First Check |
|---------|-------------|-------------|
| Load > 2× CPU count | CPU saturation or I/O wait | `vmstat 1` — check `wa` column |
| Swap usage increasing | Memory pressure | `free -h`, check OOM logs |
| High `iowait` | Slow disk / full disk | `iostat -x 1`, `df -h` |
| Packet loss | NIC saturation, bad cable, MTU | `ethtool <iface>`, `ping -f` |
| DNS resolution slow | DNS server overloaded | `dig @<resolver>`, `ss -u` |
| Container OOMKilled | cgroup memory limit too low | `dmesg | grep oom` |
| Process in D state | Waiting on I/O (uninterruptible) | `ps aux | grep ' D '`, I/O subsystem |
| High context switches | Too many threads / CPU affinity | `vmstat 1` — cs column, `pidstat -w` |
