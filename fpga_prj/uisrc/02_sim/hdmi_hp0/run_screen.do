onerror {quit -code 1 -f}
set root E:/FPGA_2026/fpga_prj
set ip [file join $root uisrc/03_ip/axi_system/ip]
set sim [file join $root uisrc/02_sim/hdmi_hp0]
set workdir [file join $root tmp/screen_1024x600_20261022/screen_sim]
file mkdir $workdir
cd $workdir
vlib work
vmap work work
vlog -sv [file join $sim clock_phy_models.sv]
vlog -sv [file join $ip axi_system_HDMI_VTG_0/axi_system_HDMI_VTG_0.v]
# ModelSim 10.6d cannot compile the vendor PLL constant function. The register
# wrapper substitutes TD-verified PLL tuples; the vendor timing core below is real.
vlog -sv [file join $sim vtg_register_model.sv]
vlog -sv [file join $ip axi_system_HDMI_VTG_0/RTL/vtg_dd045705834d.v]
vlog -sv [file join $sim tb_screen_1024x600.sv]
vsim -voptargs=+acc -t 1ps work.tb_screen_1024x600
onfinish stop
run -all
set passed [examine -radix unsigned /tb_screen_1024x600/test_passed]
if {$passed != 1} {quit -code 1 -f}
quit -code 0 -f
