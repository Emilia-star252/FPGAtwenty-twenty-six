#!/bin/bash
# build_hmi.sh -- cross-compile the HMI with the 米联客 uisrc-lab-qt SDK
#
# usage (in the VM):
#   cp -r /mnt/hgfs/FPGA/work/qt_hmi ~/qt_hmi
#   cd ~/qt_hmi && bash build_hmi.sh
#
# The SDK's qmake has /home/uisrc/uisrc-lab-qt baked in, so we create that
# symlink if the SDK lives elsewhere, and we always set QMAKESPEC explicitly.
set -e

QTROOT=${QTROOT:-$HOME/uisrc-lab-qt}
[ -d "$QTROOT" ] || { echo "ERROR: $QTROOT not found (set QTROOT=/path/to/uisrc-lab-qt)"; exit 1; }

if [ ! -f "$QTROOT/scripts/qt_cfg.sh" ]; then
    echo "ERROR: $QTROOT/scripts/qt_cfg.sh not found"; exit 1
fi

echo "== source $QTROOT/scripts/qt_cfg.sh =="
# shellcheck disable=SC1091
source "$QTROOT/scripts/qt_cfg.sh" || true

# figure out the target Qt dir (images/qt5-arm64-X.Y.Z)
if [ -z "$QTDIR" ] || [ ! -d "$QTDIR" ]; then
    QTDIR=$(ls -d "$QTROOT"/images/qt5-arm64-* 2>/dev/null | head -1)
fi
[ -n "$QTDIR" ] || { echo "ERROR: cannot find $QTROOT/images/qt5-arm64-*"; exit 1; }
echo "   QTDIR = $QTDIR"

# qmake was configured with QT_HOST_PREFIX=/home/uisrc/uisrc-lab-qt -- make that path valid
BAKED=/home/uisrc/uisrc-lab-qt
if [ ! -e "$BAKED" ]; then
    echo "== link $BAKED -> $QTROOT (needs sudo) =="
    sudo mkdir -p /home/uisrc
    sudo ln -sfn "$QTROOT" "$BAKED"
fi
ls -ld "$BAKED"

# the cross mkspec (qmake's baked QMAKE_SPEC is linux-g++, we must override)
SPEC=$QTDIR/mkspecs/linux-aarch64-gnu-g++
[ -d "$SPEC" ] || { echo "ERROR: $SPEC missing"; ls "$QTDIR/mkspecs" | head -20; exit 1; }
export QMAKESPEC="$(cd "$SPEC" && pwd)"

# cross compiler: the SDK needs aarch64-linux-gnu-g++ on PATH.
# prefer the buildroot toolchain shipped with uisrc-lab-anlogic.
for TC in "$HOME/uisrc-lab-anlogic/tools/aarch64-linux/bin" \
          "$QTROOT/tools/aarch64-linux/bin" \
          "$QTROOT/images/gcc-aarch64-linux-gnu/bin" \
          "/opt/gcc-aarch64-linux-gnu/bin"; do
    if [ -x "$TC/aarch64-linux-gnu-g++" ]; then
        export PATH="$TC:$PATH"
        echo "   toolchain: $TC"
        break
    fi
done
if ! command -v aarch64-linux-gnu-g++ >/dev/null 2>&1; then
    echo "ERROR: aarch64-linux-gnu-g++ not found."
    echo "       install it:  sudo apt install g++-aarch64-linux-gnu"
    exit 1
fi
aarch64-linux-gnu-g++ --version | head -1

# put the SDK bin (qmake/moc) first so the right moc is used
export PATH="$QTDIR/bin:$PATH"
export LD_LIBRARY_PATH="$QTDIR/lib:${LD_LIBRARY_PATH}"

echo "== toolchain =="
which qmake
qmake -query QMAKE_XSPEC 2>/dev/null || qmake -query | grep -E 'QMAKE_(XSPEC|SPEC)|QT_VERSION'
which moc

echo "== build =="
cd "$(dirname "$0")"
rm -rf build
mkdir -p build
cd build
qmake ../hmi.pro
make -j"$(nproc)"

echo
echo "== result =="
ls -lh hmi
file hmi 2>/dev/null || true
echo
echo "next: deploy to the board"
echo "  mkdir -p /opt/hmi && cp hmi run_hmi.sh /opt/hmi/"
echo "  cp -r $QTROOT/applications/qt_play/qt_lib /opt/hmi/"
echo "  cp S99hmi /etc/init.d/ && chmod 755 /etc/init.d/S99hmi"
