onerror {quit -code 1 -f}
onbreak {if {[examine -radix unsigned /tb_pi_precision/test_passed] != 1} {quit -code 1 -f} else {resume}}
set root E:/FPGA_2026/fpga_prj
set testdir $root/uisrc/02_sim/pi_precision
set builddir [file join $root tmp pi_precision_20261022 unit]
file mkdir $builddir
cd $builddir
if {![file isdirectory work]} {vlib work}
vmap work work
if {![info exists pi_source]} {set pi_source $root/uisrc/01_rtl/PI.v}
vlog $pi_source
vlog -sv $testdir/tb_pi_precision.sv
vsim -voptargs=+acc -t 1ps work.tb_pi_precision
onfinish stop
run -all
set passed [examine -radix unsigned /tb_pi_precision/test_passed]
puts "PI_PRECISION_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
