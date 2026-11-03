echo "--- stdc++/gcc ---"
ls -l /usr/lib/libstdc++.so.6* /lib/libstdc++.so.6* /usr/lib/libgcc_s.so.1 2>/dev/null || echo "(missing stdc++/gcc_s)"
echo "--- opencv / armnn / drm ---"
ls /usr/lib | grep -i -E "opencv|armnn|protobuf|drm" || echo "(none)"
echo "--- ld-linux ---"
ls -l /lib/ld-linux-aarch64.so.1 2>/dev/null || ls -l /lib/ld-* 2>/dev/null