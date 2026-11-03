cwd=$(cd `dirname $0` && pwd)

# 检查设备文件是否存在
if [ ! -e /dev/mipicam ]; then
    insmod $cwd/../bin/mipicam.ko
fi

export LD_LIBRARY_PATH=$cwd/../armnn_lib/lib:$cwd/../ffmpeg_opencv4.7.0_aarch64/lib:$LD_LIBRARY_PATH

$cwd/../bin/yolo_demo_hdmi_camera \
    -m $cwd/../inputs/yolo_face_uint8_15.onnx \
    -u $cwd/../inputs/example_yolo_face.json \
    -s 192.168.1.1:12345 \
    -i /dev/mipicam \
    -o /dev/fb0

