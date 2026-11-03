echo "--- board net ---"
ip -4 addr show eth0 | grep inet
ip route | head -3
for h in 223.5.5.5 8.8.8.8; do printf "ping %s: " "$h"; ping -c 1 -W 2 $h >/dev/null 2>&1 && echo ok || echo fail; done
printf "http test: "; (wget -q -O- --timeout=5 http://mirrors.aliyun.com/ >/dev/null 2>&1 && echo ok) || echo fail