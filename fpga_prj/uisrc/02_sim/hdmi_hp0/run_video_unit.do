onerror {quit -code 1 -f}
set project_dir E:/FPGA_2026/fpga_prj
set sim_dir [file join $project_dir uisrc/02_sim/hdmi_hp0]
set ip_dir [file join $project_dir uisrc/03_ip/axi_system/ip/axi_system_AXI4_Stream_to_Video_Out_0]
set work_dir [file join $project_dir tmp/hdmi_hp0_20261022/video_unit_sim]
file mkdir $work_dir
cd $work_dir
vlib work
vmap work work
vlog -sv [file join $ip_dir axi_system_AXI4_Stream_to_Video_Out_0.v]
vlog -sv [file join $ip_dir RTL/alc_axi4s_vid_out_axi_system_AXI4_Stream_to_Video_Out_0.v]
vlog -sv [file join $sim_dir tb_video_out_unit.sv]
vsim -voptargs=+acc -t 1ps work.tb_video_out_unit
onfinish stop
run -all
set passed [examine -radix unsigned /tb_video_out_unit/test_passed]
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
