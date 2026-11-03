# deploy_board.ps1 - one-shot deploy of the 3-class NPU runtime to the board
#   powershell -NoProfile -ExecutionPolicy Bypass -File D:\deepseek\work\npu_train\deploy_board.ps1
#
# includes: kernel modules, armnn libs, inference tools, resident NPU daemon
#           (writes /tmp/npu.status for the HMI panel), 46-case regression.
$ErrorActionPreference = 'Stop'
$BOARD = '192.168.137.101'
$PSCP = 'D:\FPGA\PuTTY\pscp.exe'
$PLINK = 'D:\FPGA\PuTTY\plink.exe'
$STAGE = 'D:\deepseek\work\_stage\lib'
$BUILD = 'D:\deepseek\work\_build'
$NUPT = 'D:\deepseek\work\npu_train'
$PKG = 'D:\deepseek\work\_incoming\dcdc_npu_threeclass_image_20261027_v2\rootfs_overlay\opt\dcdc_npu_threeclass'

function Put($files, $dest) {
    $list = @($files) + @("root@${BOARD}:$dest")
    & $PSCP -pw root -batch -q @list
    if ($LASTEXITCODE -ne 0) { throw "pscp failed -> $dest" }
}

Write-Host '[1/6] mkdir'
& $PLINK -ssh -batch -pw root "root@$BOARD" "mkdir -p /opt/npu/lib /opt/npu/ko /opt/npu/threeclass/bin /opt/npu/threeclass/models /opt/npu/tc /root/data && echo ok"

Write-Host '[2/6] upload kernel modules + libs'
Put @("$BUILD\ko\cma_mem.ko", "$BUILD\ko\jpu.ko", "$BUILD\ko\hard_npu.ko") '/opt/npu/ko/'
Put @("$STAGE\libarmnn.so.32", "$STAGE\libarmnnOnnxParser.so.24", "$STAGE\libprotobuf.so.23",
      "$STAGE\libstdc++.so.6", "$STAGE\libgcc_s.so.1", "$BUILD\libsoftnpu_shim.so") '/opt/npu/lib/'

Write-Host '[3/6] upload binaries (incl. resident daemon)'
Put @("$BUILD\threeclass_live", "$BUILD\probe_fdma", "$BUILD\fdma_capture", "$BUILD\probe_ddr",
      "$BUILD\npu_daemon") '/opt/npu/tc/'
Put @("$PKG\bin\dcdc_npu_threeclass_infer") '/opt/npu/threeclass/bin/'

Write-Host '[4/6] upload model / vectors / scripts'
Put @("$PKG\models\condition_threeclass_uint8.onnx", "$PKG\models\quant_params.txt") '/opt/npu/threeclass/models/'
& $PSCP -pw root -batch -q -r "$PKG\vectors" "root@${BOARD}:/opt/npu/threeclass/"
Put @("$NUPT\board\batch46.sh", "$NUPT\board\install_npu_env.sh") '/opt/npu/threeclass/'
Put @("$NUPT\board\S99npu_daemon") '/etc/init.d/'

Write-Host '[5/6] install env'
& $PLINK -ssh -batch -pw root "root@$BOARD" "chmod +x /opt/npu/threeclass/*.sh /opt/npu/tc/* /etc/init.d/S99npu_daemon; sh /opt/npu/threeclass/install_npu_env.sh"

Write-Host '[6/6] 46-case regression + start daemon'
& $PLINK -ssh -batch -pw root "root@$BOARD" "sh /opt/npu/threeclass/batch46.sh 2>&1 | tail -3"
& $PLINK -ssh -batch -pw root "root@$BOARD" "sh /etc/init.d/S99npu_daemon restart; sleep 4; /etc/init.d/S99npu_daemon status"
