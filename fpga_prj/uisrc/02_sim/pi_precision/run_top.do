onerror {quit -code 1 -f}
onbreak {if {[examine -radix unsigned /tb_pi_precision_top/test_passed] != 1} {quit -code 1 -f} else {resume}}
set root E:/FPGA_2026/fpga_prj
if {![info exists builddir]} {set builddir $root/tmp/pi_precision_20261022/top}
file mkdir $builddir
cd $builddir
if {![file isdirectory work]} {vlib work}
vmap work work
if {![info exists pi_source]} {set pi_source $root/uisrc/01_rtl/PI.v}
vlog $pi_source $root/uisrc/01_rtl/PWM.v $root/uisrc/01_rtl/DCDC_top.v $root/uisrc/03_ip/AD7606/uispi7606.v
vlog -sv $root/uisrc/02_sim/pi_precision/tb_pi_precision_top.sv
vsim -voptargs=+acc -t 1ps work.tb_pi_precision_top
onfinish stop
run -all
set passed [examine -radix unsigned /tb_pi_precision_top/test_passed]
puts "PI_PRECISION_TOP_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
