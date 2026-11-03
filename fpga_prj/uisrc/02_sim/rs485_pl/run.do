onerror {quit -code 1 -f}
onbreak {resume}
set root E:/FPGA_2026/fpga_prj
set workdir $root/tmp/rs485_pl_20261025/sim
file mkdir $workdir
cd $workdir
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv $root/uisrc/01_rtl/rs485_uart.v $root/uisrc/01_rtl/modbus_rtu_slave.v $root/uisrc/01_rtl/rs485_dcdc_control.v $root/uisrc/01_rtl/axi4lite_slave_v11.sv $root/uisrc/02_sim/rs485_pl/tb_rs485_pl.sv
vsim -voptargs=+acc -t 1ps work.tb_rs485_pl
onfinish stop
run -all
set passed [examine -radix unsigned /tb_rs485_pl/test_passed]
puts "RS485_PL_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
