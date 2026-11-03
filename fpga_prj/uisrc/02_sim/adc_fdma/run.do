onerror {quit -code 1 -f}
onbreak {resume}
set root E:/FPGA_2026
file mkdir $root/tmp/fdma_hp1_20261019/sim
cd $root/tmp/fdma_hp1_20261019/sim
vlib work
vmap work work
vlog -sv +incdir+{E:/FPGA_2026/uisrc/01_rtl} {E:/FPGA_2026/uisrc/01_rtl/adc_axis_source.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/01_rtl} {E:/FPGA_2026/uisrc/01_rtl/axi4lite_slave.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/01_rtl} {E:/FPGA_2026/uisrc/01_rtl/axi4lite_slave_v11.sv}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/hdl} {E:/FPGA_2026/uisrc/03_ip/axi_system/hdl/axi_system.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0/axi_system_AXI_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0/RTL/axi_protocol_converter_merge_axi_system_AXI_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0/axi_system_Processor_System_Reset_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0/RTL/proc_sys_reset_axi_system_Processor_System_Reset_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0/axi_system_Constant_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0/RTL/Constant_axi_system_Constant_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0/axi_system_Constant_0_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0/RTL/Constant_axi_system_Constant_0_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0/axi_system_AXIS_Data_FIFO_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0/RTL/axis_data_fifo_axi_system_AXIS_Data_FIFO_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_adc_axis_source_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_adc_axis_source_0/axi_system_adc_axis_source_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_axi4lite_slave_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_axi4lite_slave_0/axi_system_axi4lite_slave_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0/axi_system_AXI_Lite_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0/RTL/axi_matrix_wrapper_axi_system_AXI_Lite_Matrix_0.v}
vlog -sv {E:/FPGA_2026/uisrc/01_rtl/adc_fdma_writer.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_adc_fdma_writer_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_adc_fdma_writer_0/axi_system_adc_fdma_writer_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0/axi_system_HP1_AXI_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0/RTL/axi_matrix_wrapper_axi_system_HP1_AXI_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0/axi_system_HP1_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0/RTL} {E:/FPGA_2026/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0/RTL/axi_protocol_converter_merge_axi_system_HP1_Protocol_Converter_0.v}
vlog -sv {E:/FPGA_2026/uisrc/02_sim/adc_fdma/ps_axi_bfm.sv}
vlog -sv {E:/FPGA_2026/uisrc/02_sim/adc_fdma/tb_adc_fdma.sv}
vsim -voptargs=+acc -t 1ps work.tb_adc_fdma
onfinish stop
run -all
set passed [examine -radix unsigned /tb_adc_fdma/test_passed]
puts "ADC_FDMA_RESULT=$passed"
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
