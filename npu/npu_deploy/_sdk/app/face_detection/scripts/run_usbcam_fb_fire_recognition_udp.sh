cwd=$(cd `dirname $0` && pwd)
export LD_LIBRARY_PATH=$cwd/../armnn_lib/lib:$cwd/../ffmpeg_opencv4.7.0_aarch64/lib:$LD_LIBRARY_PATH

$cwd/../bin/yolo_demo_hdmi_camera_udp \
    -m $cwd/../inputs/fire_detect_sim_quant_uint8.onnx \
    -u $cwd/../inputs/fire_detect_sim_quant_uint8.json \
    -s 172.21.1.2:12345 \
    -i /dev/video0 \
    -o /dev/fb0 \
    --yolov8 1

