#!/bin/bash
# Linux Debug Exercise 03 — Network Debugging Walkthrough
# Run: bash linux/03-network-debug.sh   (Mac-compatible; Linux equivalents shown in comments)

echo "=== Exercise 03: Network Debugging Walkthrough ==="
echo ""
echo "Each section shows the Mac command and the Linux equivalent."
echo "On the real screen you'll use the Linux version."
echo ""

echo "--- [1] Interface Overview ---"
echo "Mac:   ifconfig | grep -E 'flags|inet '"
echo "Linux: ip addr show"
echo ""
ifconfig 2>/dev/null | grep -E 'flags|inet ' | head -20 || ip addr show 2>/dev/null
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [2] Routing Table ---"
echo "Mac:   netstat -rn | head -20"
echo "Linux: ip route show"
echo "       ip route get 8.8.8.8   # which interface/gateway for a specific destination"
echo ""
netstat -rn 2>/dev/null | head -20 || ip route show 2>/dev/null
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [3] Active Connections + Listening Ports ---"
echo "Mac:   netstat -an | grep -E 'LISTEN|ESTABLISHED' | head -20"
echo "       lsof -i -n -P | head -20"
echo "Linux: ss -tunapw | head -20        # preferred (faster, more info)"
echo "       netstat -tunapw | head -20   # fallback"
echo ""
netstat -an 2>/dev/null | grep -E 'LISTEN|ESTABLISHED' | head -15 || ss -tunapw 2>/dev/null | head -15
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [4] DNS Resolution ---"
echo "Mac+Linux: nslookup kubernetes.default"
echo "           dig google.com +short"
echo "           dig @8.8.8.8 google.com +short   # test with specific resolver"
echo ""
echo "Testing nslookup:"
nslookup kubernetes.default 2>/dev/null | tail -5 || echo "(no response — expected if not in cluster)"
echo ""
echo "Testing dig:"
dig google.com +short 2>/dev/null | head -3 || echo "(dig not installed — brew install bind)"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [5] Connectivity Tests ---"
echo "Mac+Linux: ping -c 4 8.8.8.8"
echo "           nc -zv google.com 443     # TCP port check"
echo "           curl -sv https://google.com -o /dev/null 2>&1 | grep -E 'Connected|HTTP'"
echo ""
echo "Running ping -c 4 8.8.8.8:"
ping -c 4 8.8.8.8 2>/dev/null | tail -3 || echo "(ping failed)"
echo ""
echo "Running nc -zv google.com 443:"
nc -zv google.com 443 2>/dev/null && echo "Port 443 open" || echo "Port 443 unreachable"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "--- [6] Packet Capture ---"
echo "Mac:   sudo tcpdump -i en0 -c 10 -nn 'port 53'   # en0 = primary interface"
echo "Linux: sudo tcpdump -i any -c 10 -nn 'port 53'   # 'any' captures all interfaces"
echo ""
echo "Running (5s DNS capture — requires sudo on Mac):"
sudo tcpdump -i any -c 10 -nn 'port 53' 2>/dev/null &
TCPID=$!
sleep 5
kill $TCPID 2>/dev/null || true
echo "(stopped after 5s)"
echo ""

echo ""
echo "=== Network Debugging Complete ==="
echo ""
echo "=== Command Quick-Reference: Mac vs Linux ==="
printf "%-35s %-35s\n" "MAC" "LINUX"
printf "%-35s %-35s\n" "---" "-----"
printf "%-35s %-35s\n" "ifconfig"                   "ip addr show"
printf "%-35s %-35s\n" "netstat -rn"                "ip route show"
printf "%-35s %-35s\n" "netstat -an | grep LISTEN"  "ss -tunapw"
printf "%-35s %-35s\n" "lsof -i -n -P"              "ss -tunapw  or  netstat -tunapw"
printf "%-35s %-35s\n" "tcpdump -i en0"             "tcpdump -i any  or  -i eth0"
printf "%-35s %-35s\n" "ping / nc / dig / curl"     "same (identical)"
