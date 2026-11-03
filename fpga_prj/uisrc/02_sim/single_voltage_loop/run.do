onerror {quit -code 1 -f}
onbreak {if {[examine -radix unsigned /tb_single_voltage_loop/test_passed] != 1} {quit -code 1 -f} else {resume}}
set root E:/FPGA_2026
set workdir [file join $root tmp single_voltage_loop_sim]
file mkdir $workdir
cd $workdir
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv $root/uisrc/01_rtl/PI.v $root/uisrc/01_rtl/PWM.v $root/uisrc/01_rtl/DCDC_top.v $root/uisrc/03_ip/AD7606/uispi7606.v $root/uisrc/02_sim/single_voltage_loop/tb_single_voltage_loop.sv
vsim -voptargs=+acc -t 1ps work.tb_single_voltage_loop
onfinish stop
run -all
set passed [examine -radix unsigned /tb_single_voltage_loop/test_passed]
puts "SINGLE_VOLTAGE_LOOP_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
