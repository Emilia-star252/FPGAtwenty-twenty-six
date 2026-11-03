onerror {quit -code 1 -f}
file mkdir E:/FPGA_2026/fpga_prj/tmp/hdmi_hp0_20261022/reset_sim
cd E:/FPGA_2026/fpga_prj/tmp/hdmi_hp0_20261022/reset_sim
vlib work
vmap work work
vlog -sv E:/FPGA_2026/fpga_prj/uisrc/01_rtl/hdmi_clock_reset.v
vlog -sv E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/hdmi_phy_warpper_c33abe7c933e.v
vlog -sv E:/FPGA_2026/fpga_prj/uisrc/03_ip/axi_system/ip/axi_system_HDMI_TX_0/RTL/lane_lvds_10_1_c33abe7c933e.v
vlog -sv E:/FPGA_2026/fpga_prj/uisrc/02_sim/hdmi_hp0/tb_hdmi_reset.sv
vsim -voptargs=+acc -t 1ps work.tb_hdmi_reset
onfinish stop
run -all
set passed [examine -radix unsigned /tb_hdmi_reset/test_passed]
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
