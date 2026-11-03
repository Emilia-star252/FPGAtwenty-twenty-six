echo "--- board glibc ---"
/lib/ld-2.25.so --version 2>&1 | head -1
echo "--- board GLIBCXX ---"
strings /lib/libstdc++.so.6.0.24 | grep -E "^GLIBCXX_3\.4\.[0-9]+$" | sort -V | tail -5
echo "--- board GLIBC ---"
strings /lib/libc-2.25.so 2>/dev/null | grep -E "^GLIBC_2\.[0-9]+$" | sort -V | tail -3