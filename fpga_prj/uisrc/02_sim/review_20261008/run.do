onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file isdirectory work]} {vlib work}
vlog -sv -work work ../../01_rtl/PI.v ../../01_rtl/PWM.v ../../01_rtl/DCDC_top.v ../../03_ip/AD7606/uispi7606.v tb_review.sv
vsim -voptargs=+acc work.tb_review
run -all
quit -code 0 -f
