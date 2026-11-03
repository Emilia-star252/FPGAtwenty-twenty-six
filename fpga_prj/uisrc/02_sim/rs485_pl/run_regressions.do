onerror {quit -code 1 -f}
onbreak {resume}
set root E:/FPGA_2026/fpga_prj
file mkdir $root/tmp/rs485_pl_20261025/regressions
cd $root/tmp/rs485_pl_20261025/regressions
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv $root/uisrc/01_rtl/rs485_uart.v $root/uisrc/01_rtl/modbus_rtu_slave.v $root/uisrc/01_rtl/rs485_dcdc_control.v $root/uisrc/01_rtl/axi4lite_slave_v11.sv $root/uisrc/01_rtl/axi4lite_slave.v $root/uisrc/01_rtl/DCDC_top.v $root/uisrc/01_rtl/PI.v $root/uisrc/01_rtl/PWM.v $root/uisrc/03_ip/AD7606/uispi7606.v $root/uisrc/02_sim/adc_fifo/tb_protection.sv $root/uisrc/02_sim/rs485_pl/tb_rs485_top.sv $root/uisrc/02_sim/rs485_pl/tb_rs485_uart_formats.sv
foreach top {tb_rs485_uart_formats tb_rs485_top tb_protection} {
    vsim -voptargs=+acc -t 1ps work.$top
    onfinish stop
    run -all
    set passed [examine -radix unsigned /$top/test_passed]
    puts "${top}_RESULT=$passed"
    if {$passed != 1} {quit -code 1 -f}
    quit -sim
}
# The legacy reference-ramp/PWM test has a different AXI model.
vlog -sv $root/uisrc/02_sim/adc_fifo/tb_remote_control.sv
vsim -voptargs=+acc -t 1ps work.tb_remote_control
onfinish stop
run -all
set passed [examine -radix unsigned /tb_remote_control/test_passed]
puts "REMOTE_CONTROL_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
