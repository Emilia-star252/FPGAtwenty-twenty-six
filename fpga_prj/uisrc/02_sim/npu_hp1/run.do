onerror {quit -code 1 -f}
onbreak {resume}
file mkdir {E:/FPGA_2026/fpga_prj/tmp/npu_hp1_20261024/sim}
cd {E:/FPGA_2026/fpga_prj/tmp/npu_hp1_20261024/sim}
vlib work
vmap work work
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/common/al_map_lut.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/common/al_map_seq.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/common/al_phy_glbl.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/dr1/dr1_phy_gsr.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/dr1/dr1_phy_config.sv}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/dr1/dr1_logic_io.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/dr1/dr1_phy_pad.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/dr1/dr1_phy_eram.v}
vlog -sv -timescale 1ns/1ps {E:/anlu/TD/sim_release/dr1/dr1_phy_lslice.v}
vlog -sv -timescale 1ns/1ps {E:/FPGA_2026/fpga_prj/tmp/video_lock_debug_20261022/gate/video_out_gate.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/01_rtl} {E:/FPGA_2026/fpga_prj/uisrc/01_rtl/adc_axis_source.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/01_rtl} {E:/FPGA_2026/fpga_prj/uisrc/01_rtl/adc_fdma_writer.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/01_rtl} {E:/FPGA_2026/fpga_prj/uisrc/01_rtl/axi4lite_slave.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/01_rtl} {E:/FPGA_2026/fpga_prj/uisrc/01_rtl/axi4lite_slave_v11.sv}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/01_rtl} {E:/FPGA_2026/fpga_prj/uisrc/01_rtl/hdmi_clock_reset.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/hdl} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/hdl/axi_system.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0/axi_system_AXI_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Protocol_Converter_0/RTL/axi_protocol_converter_merge_axi_system_AXI_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0/axi_system_Processor_System_Reset_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Processor_System_Reset_0/RTL/proc_sys_reset_axi_system_Processor_System_Reset_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0/axi_system_Constant_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0/RTL/Constant_axi_system_Constant_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0/axi_system_Constant_0_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_Constant_0_0/RTL/Constant_axi_system_Constant_0_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0/axi_system_AXIS_Data_FIFO_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXIS_Data_FIFO_0/RTL/axis_data_fifo_axi_system_AXIS_Data_FIFO_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_adc_axis_source_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_adc_axis_source_0/axi_system_adc_axis_source_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_axi4lite_slave_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_axi4lite_slave_0/axi_system_axi4lite_slave_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0/axi_system_AXI_Lite_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_AXI_Lite_Matrix_0/RTL/axi_matrix_wrapper_axi_system_AXI_Lite_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_adc_fdma_writer_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_adc_fdma_writer_0/axi_system_adc_fdma_writer_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0/axi_system_HP1_AXI_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_AXI_Matrix_0/RTL/axi_matrix_wrapper_axi_system_HP1_AXI_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0/axi_system_HP1_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HP1_Protocol_Converter_0/RTL/axi_protocol_converter_merge_axi_system_HP1_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_VDMA_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_VDMA_0/axi_system_VDMA_0.v}
vlog -sv -suppress 2255 +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_VDMA_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_VDMA_0/RTL/VDMA_63adc97de4db.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_VTG_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_VTG_0/axi_system_HDMI_VTG_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_VTG_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_VTG_0/RTL/vtg_dd045705834d.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/02_sim/hdmi_hp0} {E:/FPGA_2026/fpga_prj/uisrc/02_sim/hdmi_hp0/vtg_register_model.sv}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/axi_system_HDMI_TX_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/hdmi_data_distribution_c33abe7c933e.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/hdmi_tmds_encode_c33abe7c933e.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/hdmi_tx_c33abe7c933e.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/hdmi_tx_controller_wrapper_c33abe7c933e.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/hdmi_video_data_assemble_c33abe7c933e.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_IRQ_Concat_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_IRQ_Concat_0/axi_system_HDMI_IRQ_Concat_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_HP0_Protocol_Converter_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_HP0_Protocol_Converter_0/axi_system_HDMI_HP0_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_HP0_Protocol_Converter_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_HP0_Protocol_Converter_0/RTL/axi_protocol_converter_merge_axi_system_HDMI_HP0_Protocol_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_Reset_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_Reset_0/axi_system_HDMI_Reset_0.v}
vlog -sv {E:/FPGA_2026/fpga_prj/uisrc/02_sim/hdmi_hp0/clock_phy_models.sv}
vlog -sv {E:/FPGA_2026/fpga_prj/uisrc/01_rtl/npu_hp1_axi_adapter.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Matrix_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Matrix_0/axi_system_NPU_Control_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Matrix_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Matrix_0/RTL/axi_matrix_wrapper_axi_system_NPU_Control_Matrix_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Converter_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Converter_0/axi_system_NPU_Control_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Converter_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_Control_Converter_0/RTL/axi_protocol_converter_merge_axi_system_NPU_Control_Converter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_HP1_Adapter_0} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_NPU_HP1_Adapter_0/axi_system_NPU_HP1_Adapter_0.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_IRQ_Concat_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_IRQ_Concat_0/RTL/Concat_6a1244b0da87.v}
vlog -sv +incdir+{E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_IRQ_Concat_0/RTL} {E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_IRQ_Concat_0/RTL/Concat_axi_system_HDMI_IRQ_Concat_0.v}
vlog -sv {E:/FPGA_2026/fpga_prj/uisrc/02_sim/npu_hp1/npu_bus_bfm.sv}
vlog -sv {E:/FPGA_2026/fpga_prj/uisrc/02_sim/npu_hp1/ps_axi_bfm.sv}
vlog -sv {E:/FPGA_2026/fpga_prj/uisrc/02_sim/npu_hp1/tb_npu_hp1.sv}
vsim -t 1ps work.tb_npu_hp1 work.DR1_PHY_GSR
onfinish stop
run -all
set passed [examine -radix unsigned /tb_npu_hp1/test_passed]
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
