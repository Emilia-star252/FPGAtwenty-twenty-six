# 在 Windows 上用 SDK 自带的 aarch64-linux sysroot + 裸机 gcc 12 交叉编译板端程序。
#
# 为什么这么绕：本机没有 Linux 主机/WSL，SDK 里的 aarch64-linux-gnu-g++ 是 x86-64 Linux 程序跑不了；
# 但它自带的 sysroot（glibc 2.25 + libstdc++ 6.0.24 + C++ 头 + crt）是纯文件，可以给裸机 gcc 当前端用。
# 板子的 rootfs 正好也是 glibc 2.25 / libstdc++ 6.0.24，ABI 对得上。
#
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File board\build_win.ps1 [-Weights]
param([switch]$Weights)

$ErrorActionPreference = 'Stop'
$gxx = 'D:\FPGA\FD\toolchain\gcc\aarch64\bin\aarch64-none-elf-g++.exe'
$sysroot = 'D:\deepseek\work\_sysroot'
$gccinc = 'D:\FPGA\FD\toolchain\gcc\aarch64\lib\gcc\aarch64-none-elf\12.3.1\include'
$gcclib = 'D:\FPGA\FD\toolchain\gcc\aarch64\lib\gcc\aarch64-none-elf\12.3.1'
$stage = 'D:\deepseek\work\_stage\lib'
$armnn = 'D:\deepseek\work\npu_train\_sdk\app\face_detection\libs\armnn_lib\include'
$qheader = 'D:\deepseek\work\npu_train\out'          # dcdc_npu_qdq_weights.h 所在目录
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $here) { $here = 'D:\deepseek\work\npu_train\board' }
$build = 'D:\deepseek\work\_build'
New-Item -ItemType Directory -Force $build | Out-Null

$stdFlags = @(
    '-std=c++17', '-O2', '-fPIC', '-march=armv8-a', '-D_GNU_SOURCE', '-nostdinc', '-nostdinc++',
    '-isystem', $gccinc,
    '-isystem', "$sysroot\include\c++\7.5.0",
    '-isystem', "$sysroot\include\c++\7.5.0\aarch64-linux-gnu",
    '-isystem', "$sysroot\libc\usr\include",
    '-I', $armnn, '-I', $here, '-I', $qheader
)
if ($Weights) { $stdFlags += '-DDCDC_USE_WEIGHTS_HEADER' }

Write-Host '[build] compile'
& $gxx @stdFlags -c "$here\dcdc_npu_demo.cpp" -o "$build\demo.o"
if ($LASTEXITCODE -ne 0) { throw 'compile failed' }

Write-Host '[build] link'
$link = @(
    '-nostdlib', '-o', "$build\dcdc_npu_demo", "$build\demo.o",
    "$sysroot\libc\usr\lib\crt1.o", "$sysroot\libc\usr\lib\crti.o", "$gcclib\crtbegin.o",
    "$stage\libarmnn.so.32", "$stage\libarmnnOnnxParser.so.24", "$stage\libprotobuf.so.23",
    "$stage\libstdc++.so.6", "$stage\libm.so.6", "$stage\libc.so.6",
    "$stage\libpthread.so.0", "$stage\libdl.so.2",
    "$sysroot\libc\usr\lib\libc_nonshared.a", "$stage\ld-linux-aarch64.so.1",
    "$stage\libgcc_s.so.1", '-Wl,--no-as-needed', "$gcclib\libgcc.a",
    "$gcclib\crtend.o", "$sysroot\libc\usr\lib\crtn.o",
    '-Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1',
    '-Wl,-rpath,/opt/npu/lib', "-Wl,-rpath-link,$stage"
)
& $gxx @link
if ($LASTEXITCODE -ne 0) { throw 'link failed' }
Write-Host "[build] ok -> $build\dcdc_npu_demo"
Get-Item "$build\dcdc_npu_demo" | Select-Object Length
