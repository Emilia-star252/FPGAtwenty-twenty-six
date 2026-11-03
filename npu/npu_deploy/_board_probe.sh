echo "--- tools ---"
for t in gcc g++ cc make cmake python3 ld; do printf "%s: " "$t"; command -v $t || echo none; done
echo "--- /opt ---"
ls /opt 2>/dev/null || echo "(no /opt)"
echo "--- disk ---"
df -h / | tail -2
free -m | head -2
echo "--- armnn on board ---"
ls /usr/lib/libarmnn* 2>/dev/null || echo "(no libarmnn in /usr/lib)"
ls /opt/npu 2>/dev/null || echo "(no /opt/npu)"
echo "--- modules ---"
ls /lib/modules/$(uname -r) 2>/dev/null | head -5