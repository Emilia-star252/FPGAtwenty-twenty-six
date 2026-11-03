@echo off
setlocal enabledelayedexpansion
rem tc.cmd - helpers for the 3-class NPU model (uses the DSH python that has numpy)
rem   tc.cmd demo
rem   tc.cmd scan   --csv logs\run1.csv --rate 128 --hop 1.0
rem   tc.cmd input  --csv logs\run1.csv --end 12.5 --out out\case12
rem   tc.cmd push   out\case12
rem   tc.cmd run    case12
rem   tc.cmd live   logs\run1.csv [rate] [hop]   (streaming windows on board)
rem   tc.cmd batch
rem   tc.cmd verify

set "PY=C:\Users\lenovo\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
set "DIR=D:\deepseek\work\npu_train"
set "BOARD=192.168.137.101"
set "PSCP=D:\FPGA\PuTTY\pscp.exe"
set "PLINK=D:\FPGA\PuTTY\plink.exe"

if /I "%~1"=="demo" (
    "%PY%" "%DIR%\gen_capture_phases.py"
    "%PY%" "%DIR%\scan_threeclass.py" --csv "%DIR%\out\cap_phases.csv" --rate 128 --hop 1.0
    goto :eof
)
if /I "%~1"=="scan" (
    if "%~2"=="" (
        echo [tc] no --csv given, scanning the bundled demo capture
        if not exist "%DIR%\out\cap_phases.csv" "%PY%" "%DIR%\gen_capture_phases.py"
        "%PY%" "%DIR%\scan_threeclass.py" --csv "%DIR%\out\cap_phases.csv" --rate 128 --hop 1.0
    ) else (
        "%PY%" "%DIR%\scan_threeclass.py" %2 %3 %4 %5 %6 %7 %8 %9
    )
    goto :eof
)
if /I "%~1"=="input" (
    "%PY%" "%DIR%\make_threeclass_input.py" %2 %3 %4 %5 %6 %7 %8 %9
    goto :eof
)
if /I "%~1"=="verify" (
    "%PY%" "%DIR%\verify_package.py"
    goto :eof
)
if /I "%~1"=="push" (
    if "%~2"=="" ( echo usage: tc.cmd push PREFIX & exit /b 2 )
    for %%A in (%2 %3 %4 %5 %6) do (
        "%PSCP%" -pw root -batch "%%~A.physical_f32.bin" "root@%BOARD%:/opt/npu/threeclass/"
        "%PSCP%" -pw root -batch "%%~A.baseline_f64.bin" "root@%BOARD%:/opt/npu/threeclass/"
    )
    echo [push] done
    goto :eof
)
if /I "%~1"=="run" (
    if "%~2"=="" ( echo usage: tc.cmd run NAME & exit /b 2 )
    "%PLINK%" -ssh -batch -pw root root@%BOARD% "cd /opt/npu/threeclass; ./run.sh %~2.physical_f32.bin %~2.baseline_f64.bin"
    goto :eof
)
if /I "%~1"=="live" (
    if "%~2"=="" ( echo usage: tc.cmd live CSV [rate] [hop] & exit /b 2 )
    set "RATE=128"
    set "HOP=1.0"
    if not "%~3"=="" set "RATE=%~3"
    if not "%~4"=="" set "HOP=%~4"
    for %%F in ("%~f2") do set "CSVNAME=%%~nxF"
    "%PSCP%" -pw root -batch "%~f2" "root@%BOARD%:/opt/npu/threeclass/"
    "%PLINK%" -ssh -batch -pw root root@%BOARD% "cd /opt/npu/threeclass; chmod +x threeclass_live; LD_LIBRARY_PATH=/opt/npu/lib LD_PRELOAD=/opt/npu/lib/libsoftnpu_shim.so ./threeclass_live --model models/condition_threeclass_uint8.onnx --csv !CSVNAME! --rate !RATE! --hop !HOP!"
    goto :eof
)
if /I "%~1"=="grab" (
    set "DUR=30"
    if not "%~2"=="" set "DUR=%~2"
    echo [grab] capturing !DUR!s on board ...
    "%PLINK%" -ssh -batch -pw root root@%BOARD% "/opt/npu/tc/fdma_capture --out /root/data/grab.csv --hz 128 --duration !DUR! --peek 256"
    if errorlevel 1 ( echo [grab] capture failed & exit /b 1 )
    if not exist "%DIR%\out" mkdir "%DIR%\out"
    "%PSCP%" -pw root -batch root@%BOARD%:/root/data/grab.csv "%DIR%\out\grab.csv"
    if errorlevel 1 ( echo [grab] pull failed & exit /b 1 )
    echo [grab] scanning %DIR%\out\grab.csv
    "%PY%" "%DIR%\scan_threeclass.py" --csv "%DIR%\out\grab.csv" --rate 98 --hop 1.0
    goto :eof
)
if /I "%~1"=="batch" (
    "%PLINK%" -ssh -batch -pw root root@%BOARD% "sh /opt/npu/threeclass/batch46.sh"
    goto :eof
)

echo usage: tc.cmd ^<command^> [args]
echo   demo                                     generate demo capture and scan it (no board needed)
echo   scan  --csv FILE [--rate 128] [--hop 1]  scan a capture, print class timeline (PC, numpy)
echo   input --csv FILE --end SEC --out PREFIX  convert one window into model input files
echo   push  PREFIX [PREFIX...]                 upload PREFIX.physical_f32.bin / .baseline_f64.bin
echo   run   NAME                               run one window on board (CLASS + IRQ delta)
echo   live  CSV [rate] [hop]                   streaming windows on board (model loaded once)
echo   batch                                    run the 46 packaged cases on board
echo   verify                                   re-check their model package (bitwise)


