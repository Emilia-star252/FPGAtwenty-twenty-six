cwd=$(cd `dirname $0` && pwd)
export LD_LIBRARY_PATH=$cwd/../armnn_lib/lib:$cwd/../ffmpeg_opencv4.7.0_aarch64/lib:$LD_LIBRARY_PATH

$cwd/../bin/yolo_demo_hdmi_camera \
    -m $cwd/../inputs/fire_detect_sim_quant_uint8.onnx \
    -u $cwd/../inputs/fire_detect_sim_quant_uint8.json \
    -i /dev/mipicam \
    -o /dev/fb0 \
    --yolov8 1

