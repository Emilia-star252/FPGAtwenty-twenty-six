create_clock -name {clk_in} -period 10.000 -waveform {0.000 5.000} [get_ports {clk_in}]

derive_clocks

# HDMI: preserve PS/PLL auto-derived clocks, including pixel PLL phase.
# Acquisition oscillator, transport PLL and video PLL are independent domains.
# DRP supports other modes; this timing run covers 1024x600 CVT at 49 MHz pixel / 245 MHz serial.
set_clock_groups -asynchronous -group [get_clocks {clk_in u_pll_sys100/dr1_phy_pll_Inst/u_DR1_PHY_PLL.clkc[0]}] -group [get_clocks {u_axi_system/axi_system_ARM_Processor_System_0_Inst/ARM_Processor_System_Inst/DR1_PHY_PROCESSOR_SYSTEM_Inst.p2f_clk0 u_axi_system/axi_system_HDMI_PLL_0_Inst/dr1_phy_pll_3a04da50d99b_Inst/u_DR1_PHY_PLL.clkc[0] u_axi_system/axi_system_HDMI_PLL_0_Inst/dr1_phy_pll_3a04da50d99b_Inst/u_DR1_PHY_PLL.clkc[1] u_axi_system/axi_system_HDMI_PLL_0_Inst/dr1_phy_pll_3a04da50d99b_Inst/u_DR1_PHY_PLL.clkc[2]}] -group [get_clocks {u_axi_system/axi_system_HDMI_VTG_0_Inst/video_timing_generator_v01_dd045705834d_Inst/dr1_pll_vtc_Inst/u_DR1_PHY_PLL.clkc[0] u_axi_system/axi_system_HDMI_PLL_1_Inst/dr1_phy_pll_2d86d31852c0_Inst/u_DR1_PHY_PLL.clkc[0]}]

# Async reset assertion into the serializer reset synchronizer only.
# Deassertion shifts through three serial-clock registers; their D paths
# and every downstream serializer data/reset path retain normal timing.
set hdmi_serial_asr [get_pins -quiet {u_axi_system/axi_system_HDMI_TX_0_Inst/hdmi_tx_c33abe7c933e_Inst/u_hdmi_tx_phy_wrapper/serial_reset_release_reg*.asr}]
if {[llength $hdmi_serial_asr] > 0} {set_false_path -to $hdmi_serial_asr}

# AD7606 / DAQ001 interface, all values in ns.
# See ../06_doc/ADC_external_timing.md for the budget and validation procedure.
# The ADC is NOT the capture clock: shift_a/shift_b use clk_100m with a CE.
# A 100 MHz virtual deadline clock models arbitrary system-aligned CS/SCLK
# launches, including the first MSB launched by CS. No free-running 6.25 MHz
# phase is assumed (SCLK stops between frames).
create_clock -name {adc_io_budget} -period 10.000 -waveform {0.000 5.000}

# Bound FPGA register -> output-pad arrival to [0.5,7] ns relative to the
# common 100 MHz phase reference. This is an implementation budget, NOT
# an AD7606 setup/hold specification against an external 100 MHz clock.
set_output_delay -clock [get_clocks {adc_io_budget}] -max 3.000 \
    [get_ports {ad_sclk ad_cs ad_convsta ad_convstb ad_rst}]
set_output_delay -clock [get_clocks {adc_io_budget}] -min -0.500 \
    [get_ports {ad_sclk ad_cs ad_convsta ad_convstb ad_rst}]

# Worst-case return from an FPGA clock-aligned CS falling / SCLK rising edge:
#   FPGA output budget                        7.0
#   outgoing translator allowance             6.0
#   outgoing board/connector allowance         2.0
#   AD7606 max(t18,t19), conservative VDRIVE   39.0
#   return translator allowance               6.0
#   return board/connector allowance           2.0
#   extra budget margin                        1.0
#                                             ----
#                                             63.0 ns
# Translator and PCB allowances require confirmation for the actual assembly.
# 39 ns covers the AD7606 0.3/0.7 logic-level table, even below nominal 3.3 V.
# Zero min is deliberately conservative; do not assume a typical tCO minimum.
set_input_delay -clock [get_clocks {adc_io_budget}] -max 63.000 \
    [get_ports {ad_dout_a ad_dout_b}]
set_input_delay -clock [get_clocks {adc_io_budget}] -min 0.000 \
    [get_ports {ad_dout_a ad_dout_b}]

# RTL guarantees >= SPI_HALF_CYCLES=8 system ticks from CS falling / SCLK
# rising to the enabled capture. Apply ONLY to external serial-data paths;
# shift-register feedback, enables, counters and PI remain single-cycle.
# Pair hold 7 with setup 8 to avoid an artificial 70 ns hold requirement.
# B may be optimized away when adc_data_b has no consumer; A must exist.
set_multicycle_path -setup -end 8 \
    -from [get_ports {ad_dout_a ad_dout_b}] \
    -to [get_regs {u_adc/shift_a* u_adc/shift_b*}]
set_multicycle_path -hold -end 7 \
    -from [get_ports {ad_dout_a ad_dout_b}] \
    -to [get_regs {u_adc/shift_a* u_adc/shift_b*}]

# BUSY is asynchronous. Only its input -> first-stage path is exempt.
# busy_meta -> busy_sync and busy_sync -> FSM retain normal 10 ns timing.
set_false_path -from [get_ports {ad_busy}] -to [get_regs {u_adc/busy_meta}]

# Asynchronous RS485 RX: exempt only the pad -> first synchronizer stage.
# rx_meta -> rx_sync and the rest of UART/RTU/control logic remain timed.
set_false_path -from [get_ports {I_rs485_rx}] -to [get_regs {u_rs485/rtu/uart/rx_meta}]

# RANGE is hard-wired low in RTL. It has no timing path, so do not add an
# empty false-path constraint merely to hide the no-output-delay diagnostic.
