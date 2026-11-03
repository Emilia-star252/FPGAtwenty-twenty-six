onerror {quit -code 1 -f}
onbreak {if {[examine -radix unsigned /$current_top/test_passed] != 1} {quit -code 1 -f} else {resume}}
set root E:/FPGA_2026/fpga_prj
set builddir $root/tmp/dual_loop_parameters_20261025/sim
file mkdir $builddir
cd $builddir
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv $root/uisrc/01_rtl/rs485_uart.v $root/uisrc/01_rtl/modbus_rtu_slave.v $root/uisrc/01_rtl/rs485_dcdc_control.v $root/uisrc/01_rtl/axi4lite_slave_v11.sv $root/uisrc/01_rtl/axi4lite_slave.v $root/uisrc/01_rtl/DCDC_top.v $root/uisrc/01_rtl/PI.v $root/uisrc/01_rtl/PWM.v $root/uisrc/03_ip/AD7606/uispi7606.v $root/uisrc/02_sim/adc_fifo/tb_protection.sv $root/uisrc/02_sim/dual_loop/tb_dual_loop.sv $root/uisrc/02_sim/dual_loop/tb_dual_loop_gains.sv
foreach current_top {tb_dual_loop tb_dual_loop_gains} {
    vsim -voptargs=+acc -t 1ps work.$current_top
    onfinish stop
    run -all
    set passed [examine -radix unsigned /$current_top/test_passed]
    puts "${current_top}_RESULT=$passed"
    if {$passed != 1} {quit -code 1 -f}
    quit -sim
}
quit -code 0 -f
