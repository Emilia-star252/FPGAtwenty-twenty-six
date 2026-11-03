onerror {quit -code 1 -f}
onbreak {resume}
set root E:/FPGA_2026
set workdir $root/tmp/remote_control_20261013/top_sim
file mkdir $workdir
cd $workdir
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv $root/uisrc/01_rtl/DCDC_top.v $root/uisrc/01_rtl/PI.v $root/uisrc/01_rtl/PWM.v $root/uisrc/03_ip/AD7606/uispi7606.v $root/uisrc/02_sim/adc_fifo/tb_remote_control.sv
vsim -voptargs=+acc -t 1ps work.tb_remote_control
onfinish stop
run -all
set passed [examine -radix unsigned /tb_remote_control/test_passed]
puts "REMOTE_CONTROL_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
