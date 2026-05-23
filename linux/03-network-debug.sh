#!/bin/bash
# Linux Debug Exercise 03 — Network Debugging
# Walks through network investigation commands.
# Run: bash linux/03-network-debug.sh

echo "=== Exercise 03: Network Debugging Walkthrough ==="
echo ""
echo "This is a guided walkthrough — run each command and observe output."
echo ""

echo "--- [1] Interface Overview ---"
echo "Command: ip addr show"
ip addr show 2>/dev/null || ifconfig 2>/dev/null
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [2] Routing Table ---"
echo "Command: ip route show"
ip route show 2>/dev/null
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [3] Active Connections ---"
echo "Command: ss -tunapw | head -30"
ss -tunapw 2>/dev/null | head -30 || netstat -tunapw 2>/dev/null | head -30
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [4] DNS Resolution ---"
echo "Testing DNS: nslookup kubernetes.default"
nslookup kubernetes.default 2>/dev/null || echo "(nslookup not available — install bind-utils)"
echo ""
echo "Testing DNS: dig google.com +short"
dig google.com +short 2>/dev/null | head -5 || echo "(dig not available)"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [5] Connectivity Test ---"
echo "Command: ping -c 4 8.8.8.8"
ping -c 4 8.8.8.8 2>/dev/null || echo "(ping not available)"
echo ""
echo "Command: nc -zv google.com 443"
nc -zv google.com 443 2>/dev/null && echo "Port 443 open" || echo "Port 443 unreachable"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [6] Packet Capture (5 seconds) ---"
echo "Command: tcpdump -i any -c 10 -nn 'port 53'"
echo "(Showing first 10 DNS packets or press Ctrl+C)"
timeout 5 tcpdump -i any -c 10 -nn 'port 53' 2>/dev/null || echo "(tcpdump not available or no DNS traffic captured)"
echo ""

echo ""
echo "=== Network Debugging Complete ==="
echo ""
echo "Key commands to remember:"
echo "  ip addr show              # interfaces"
echo "  ip route get <dst>        # which path packets take"
echo "  ss -tunapw                # active connections + PIDs"
echo "  tcpdump -i any port 80    # live packet capture"
echo "  nc -zv <host> <port>      # port reachability test"
echo "  dig <host> @8.8.8.8      # DNS with specific resolver"
