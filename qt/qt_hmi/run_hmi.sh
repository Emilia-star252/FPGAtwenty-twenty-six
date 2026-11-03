#!/bin/sh
# /opt/hmi/run_hmi.sh -- launch the power-monitor HMI on /dev/fb0 (Qt linuxfb + evdev touch)
#
# layout on the board:
#   /opt/hmi/hmi                 (our aarch64 binary)
#   /opt/hmi/qt_lib/lib          (Qt libs)
#   /opt/hmi/qt_lib/plugins      (platform + generic plugins, incl. libqlinuxfb.so)
#
# usage: ./run_hmi.sh [--host IP] [--port PORT]

HERE=$(cd "$(dirname "$0")" && pwd)

export QTDIR="$HERE"
export QTLIB="$HERE/qt_lib"
export QT_PLUGIN_PATH="$QTLIB/plugins"
export LD_LIBRARY_PATH="$QTLIB/lib:${LD_LIBRARY_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$QTLIB/plugins/platforms"
export QT_QPA_PLATFORM="linuxfb:fb=/dev/fb0"

# CJK font: prefer the system font shipped with the rootfs, fall back to qt_lib
if [ -d /usr/share/fonts/wqy-zenhei ]; then
    export QT_QPA_FONTDIR=/usr/share/fonts/wqy-zenhei
else
    export QT_QPA_FONTDIR="$QTLIB/lib/fonts"
fi
export FONTCONFIG_PATH=/etc/fonts

# --- touchscreen -------------------------------------------------------------
# the panel is a "wch.cn USB2IIC_CTP_CONTROL" HID multitouch device:
# locate its /dev/input/eventN node automatically
TOUCHDEV=""
if [ -r /proc/bus/input/devices ]; then
    TOUCHDEV=$(awk '
        /^N: Name=/ { name=$0 }
        /^H: Handlers=/ {
            if (name ~ /CTP|Touch|touch|TouchScreen|Goodix|GT911|FT5/) {
                for (i = 1; i <= NF; i++) if ($i ~ /^event[0-9]+$/) { print "/dev/input/" $i; exit }
            }
        }' /proc/bus/input/devices)
fi
[ -z "$TOUCHDEV" ] && [ -e /dev/input/event0 ] && TOUCHDEV=/dev/input/event0

if [ -n "$TOUCHDEV" ] && [ -e "$TOUCHDEV" ]; then
    export QT_QPA_GENERIC_PLUGINS=evdevtouch
    export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS="$TOUCHDEV"
    echo "[run_hmi] touchscreen: $TOUCHDEV"
else
    echo "[run_hmi] no touchscreen found"
fi

# hide the text console so the UI owns the screen
if [ -w /sys/class/graphics/fbcon/cursor_blink ]; then
    echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null
fi
# blank the framebuffer first (avoid stale console text)
[ -c /dev/fb0 ] && dd if=/dev/zero of=/dev/fb0 bs=3M count=1 2>/dev/null

exec "$HERE/hmi" "$@"
