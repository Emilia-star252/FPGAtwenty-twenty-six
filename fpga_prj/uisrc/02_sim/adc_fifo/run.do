onerror {quit -code 1 -f}
onbreak {resume}
set root E:/FPGA_2026
if {![info exists vendor_fifo]} {set vendor_fifo 0}
set workdir [file join $root tmp adc_fifo_sim_$vendor_fifo]
file mkdir $workdir
cd $workdir
vlib work
vmap work work
vlog -sv $root/uisrc/01_rtl/adc_axis_source.v $root/uisrc/01_rtl/axi4lite_slave.v $root/uisrc/01_rtl/axi4lite_slave_v11.sv
if {$vendor_fifo} {
    set fifo_dir $root/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0
    vlog -sv $fifo_dir/RTL/axis_data_fifo_axi_system_AXIS_Data_FIFO_0.v $fifo_dir/axi_system_AXIS_Data_FIFO_0.v
    vlog -sv +define+VENDOR_FIFO $root/uisrc/02_sim/adc_fifo/tb_adc_fifo.sv
} else {
    vlog -sv $root/uisrc/02_sim/adc_fifo/tb_adc_fifo.sv
}
vsim -voptargs=+acc -t 1ps work.tb_adc_fifo
onfinish stop
run -all
set passed [examine -radix unsigned /tb_adc_fifo/test_passed]
puts "ADC_FIFO_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
