`timescale 1ns/1ps
// ADC serial driver, calibration, PI, PWM and AXI register bank are production RTL.
module PLL_sys100(input refclk, reset, output clk0_out, lock);
    assign clk0_out = refclk;
    assign lock = !reset;
endmodule
module ChipWatcher_0(input clk, input [15:0] probe0, probe1, input probe2, probe3);
endmodule
module axi_system(output [2:0] O_hdmi_tx_p, output O_hdmi_clk_p, input axi_clk, pll_locked, ext_reset_n, adc_sample_valid, protection_stop,
    input [31:0] adc_status_in,
    input [47:0] voltage_product_in, current_product_in,
    input [31:0] duty_q16_in, control_status_in, vref_active_q16_in,
    output output_enable_cmd, output [31:0] vref_cmd_q16, output axi_reset_n,
    output fault_clear_cmd);
    assign axi_reset_n = pll_locked && ext_reset_n;
    reg [7:0] awaddr = 0;
    reg [31:0] wdata = 0;
    reg awvalid = 0, wvalid = 0, bready = 0;
    wire awready, wready, bvalid;
    wire [1:0] bresp;
    axi4lite_slave registers (
        .clk(axi_clk), .rst_n(axi_reset_n), .protection_stop(protection_stop),
        .fault_clear_cmd(fault_clear_cmd),
        .adc_sample_valid(adc_sample_valid), .adc_status_in(adc_status_in),
        .control_status_in(control_status_in),
        .vref_active_q16_in(vref_active_q16_in), .output_enable_cmd(output_enable_cmd),
        .vref_cmd_q16(vref_cmd_q16), .s_axis_tdata(32'd0), .s_axis_tkeep(4'hf),
        .s_axis_tlast(1'b0), .s_axis_tvalid(1'b0), .s_axis_tready(),
        .fifo_level_in(32'd0), .fifo_drop_count_in(32'd0), .fifo_ready_in(1'b1),
        .capture_enable(), .fifo_clear(),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(4'hf), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(8'd0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b0));
    task automatic write_command(input [7:0] addr, input [31:0] data,
                                 input [1:0] expected_resp = 0);
        @(negedge axi_clk); awaddr = addr; awvalid = 1;
        do @(posedge axi_clk); while (!awready);
        @(negedge axi_clk); awvalid = 0; wdata = data; wvalid = 1;
        do @(posedge axi_clk); while (!wready);
        @(negedge axi_clk); wvalid = 0;
        wait (bvalid); #1;
        if (bresp !== expected_resp) $fatal(1, "AXI command addr=%h resp=%b expected=%b", addr, bresp, expected_resp);
        @(negedge axi_clk); bready = 1;
        @(posedge axi_clk); @(negedge axi_clk); bready = 0;
    endtask
endmodule
module protection_adc_model(input convst, cs, sclk, reset,
    input [15:0] voltage_raw, current_raw,
    output reg busy = 0, dout_a = 0, dout_b = 0);
    reg [63:0] held_frame = 0;
    integer bit_index = 0;
    always @(posedge convst) if (!reset) begin
        held_frame = {16'h1234, voltage_raw, current_raw, 16'hfedc};
        #25 busy = 1;
        #4000 busy = 0;
    end
    always @(posedge reset) busy = 0;
    always @(negedge cs) begin bit_index = 0; #30 dout_a = held_frame[63]; end
    always @(posedge sclk) if (!cs && bit_index < 63) begin
        bit_index = bit_index + 1; #30 dout_a = held_frame[63 - bit_index];
    end
endmodule

module tb_protection;
    reg clk = 0, rst_n = 0;
    always #5 clk = !clk;
    reg signed [15:0] voltage_raw = 1966, current_raw = 3277;
    reg signed [47:0] injected_voltage, injected_current;
    wire busy, da, db, cs, sclk, adc_reset, convst, h1, l1, h2, l2;
    reg test_passed = 0;
    integer adc_frames = 0, before_fault;
    // Nonzero simulation-only gains ensure shutdown also clears a live PI state.
    DCDC_top #(.ADC_RESET_CYCLES(8), .V_SOFT_START_MS(1),
               .V_KP_Q16(655), .V_KI_Q16(655)) dut (
        .I_rs485_rx(1'b1), .O_rs485_tx(), .O_rs485_de(), .O_hdmi_tx_p(), .O_hdmi_clk_p(),
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy), .ad_dout_a(da), .ad_dout_b(db),
        .ad_cs(cs), .ad_sclk(sclk), .ad_rst(adc_reset), .ad_convsta(convst),
        .ad_convstb(), .ad_range(), .card_power_en(),
        .pwm1_h(h1), .pwm1_l(l1), .pwm2_h(h2), .pwm2_l(l2));
    protection_adc_model adc(convst, cs, sclk, adc_reset,
                             voltage_raw, current_raw, busy, da, db);
    always @(posedge dut.adc_valid) adc_frames = adc_frames + 1;
    always @(posedge clk) begin
        #1;
        if (dut.protection_stop && ({h1,l1,h2,l2} !== 4'b0 ||
            dut.pwm_output_enable || dut.control_rst_n))
            $fatal(1, "Latched protection failed to hold all gates and control OFF");
    end

    task automatic frames(input integer count);
        repeat (count) begin @(posedge dut.adc_valid); repeat (24) @(posedge clk); end
        #1;
    endtask
    task automatic command(input bit enabled);
        dut.u_axi_system.write_command('h40, enabled);
    endtask
    task automatic set_reference(input integer volts);
        dut.u_axi_system.write_command('h44, volts * 65536);
    endtask
    task automatic reset_system;
        @(negedge clk); rst_n = 0; voltage_raw = 1966; current_raw = 3277;
        repeat (5) @(negedge clk); rst_n = 1;
        frames(3);
        if (dut.protection_stop || dut.output_enable_cmd || dut.pwm_output_enable)
            $fatal(1, "System reset must clear faults and old output requests");
    endtask
    task automatic start_output;
        set_reference(12); command(1); frames(10);
        if (!dut.pwm_output_enable || dut.u_voltage_pi.i1 === 0)
            $fatal(1, "Test requires active PWM and nonzero PI integrator before trip");
    endtask
    task automatic sample_raw(input signed [15:0] volts, amps);
        @(negedge clk); voltage_raw = volts; current_raw = amps;
        @(posedge convst);
        @(posedge dut.adc_valid);
        // adc_valid/data are published by the driver, consumed on this next edge.
        @(posedge clk); #1;
    endtask
    task automatic expect_shutdown;
        if (dut.output_status[8:7] !== {dut.overvoltage_fault,dut.overcurrent_fault} ||
            dut.u_axi_system.adc_status_in[8:7] !== dut.output_status[8:7])
            $fatal(1, "Protection fault upload does not match latched causes");
        if ({h1,l1,h2,l2} !== 4'b0 || dut.applied_duty_q16 !== 0 ||
            dut.control_rst_n || dut.pwm_armed || dut.duty_counts !== 0 ||
            dut.v_ref_soft_q16 !== 0 || dut.u_voltage_pi.i1 !== 0 ||
            dut.voltage_pi_busy || dut.loop_state !== dut.WAIT_SAMPLE)
            $fatal(1, "Trip did not immediately stop/clear PI and force every PWM gate low");
        if (dut.output_status[1]) $fatal(1, "Trip still reports actual output active");
    endtask
    task automatic clear_faults(input [1:0] expected_faults = 0);
        dut.u_axi_system.write_command('h60, 1);
        repeat (4) @(posedge clk); #1;
        expect_commands_cleared();
        if (dut.output_status[8:7] !== expected_faults)
            $fatal(1, "Clear fault result expected=%b actual=%b", expected_faults, dut.output_status[8:7]);
    endtask
    task automatic expect_commands_cleared;
        repeat (4) @(posedge clk); #1;
        expect_shutdown();
        if (dut.output_enable_cmd || dut.vref_cmd_q16 !== 0 || dut.protection_stop)
            $fatal(1, "Stop handshake did not clear both old commands and acknowledge stop");
    endtask

    initial begin
        reset_system(); start_output();
        // Highest calibrated ADC codes at or below +80 V / +2.5 A must not trip.
        sample_raw((80*65536-dut.V_OFFSET_Q16)/dut.V_SCALE_Q16,
                   (163840-dut.I_OFFSET_Q16)/dut.I_SCALE_Q16);
        if (!dut.pwm_output_enable) $fatal(1, "Below-threshold calibrated raw sample tripped");
        // Signed negative values must not become large unsigned positives.
        sample_raw(-32768, -32768);
        if (!dut.pwm_output_enable) $fatal(1, "Negative signed measurement tripped positive limit");
        // Exact physical thresholds are between ADC codes at the nominal gains.
        // Inject the calibrated products to test strict '>' at exactly 80 V / 2.5 A.
        injected_voltage = 80 * 65536; injected_current = 163840;
        force dut.voltage_product = injected_voltage;
        force dut.current_product = injected_current;
        frames(1);
        if (!dut.pwm_output_enable) $fatal(1, "Equality at 80 V / 2.5 A must not trip");
        release dut.voltage_product; release dut.current_product;
        sample_raw(1966, 3277);

        // Over-limit data without a complete valid ADC sample must be ignored.
        @(negedge clk);
        injected_voltage = 80 * 65536 + 1; injected_current = 163840 + 1;
        force dut.voltage_product = injected_voltage;
        force dut.current_product = injected_current;
        repeat (4) begin
            @(posedge clk); #1;
            if (dut.adc_valid || !dut.pwm_output_enable)
                $fatal(1, "Invalid/unfinished ADC data caused a trip");
        end
        release dut.voltage_product; release dut.current_product;

        // First raw code above +2.5 A under the current calibration parameters.
        sample_raw(1966, (163840-dut.I_OFFSET_Q16)/dut.I_SCALE_Q16+1); expect_shutdown(); expect_commands_cleared();
        if (dut.output_status[8:7] !== 2'b01) $fatal(1, "Overcurrent reason not latched");
        clear_faults(2'b01); // Latest completed sample is still unsafe.
        before_fault = adc_frames;
        sample_raw(1966, 3277); frames(3); expect_shutdown();
        if (adc_frames < before_fault + 4 || !dut.adc_initialized || dut.adc_error)
            $fatal(1, "Protection stopped healthy ADC acquisition");
        // An old ON, a rejected VREF, or VREF alone must never restart PWM.
        dut.u_axi_system.write_command('h40, 1, 2);
        dut.u_axi_system.write_command('h44, 65 * 65536, 2);
        dut.u_axi_system.write_command('h40, 1, 2);
        expect_shutdown();
        set_reference(12); frames(1); expect_shutdown();
        dut.u_axi_system.write_command('h40, 1, 2);
        clear_faults(); // Safe sample observed; clears commands and stays OFF.
        set_reference(12);
        command(1); frames(10);
        if (!dut.pwm_output_enable || dut.v_ref_soft_q16 !== 12 * 65536)
            $fatal(1, "Clear then VREF/ON failed to resume after overcurrent without reset");

        // First raw code above +80 V under the current calibration parameters.
        sample_raw((80*65536-dut.V_OFFSET_Q16)/dut.V_SCALE_Q16+1, 3277); expect_shutdown(); expect_commands_cleared();
        if (dut.output_status[8:7] !== 2'b10) $fatal(1, "Overvoltage reason not latched");
        clear_faults(2'b10);
        sample_raw(1966, 3277); frames(2); expect_shutdown();
        clear_faults();
        start_output();

        // One Q16 LSB above either threshold also trips, before a PWM boundary.
        injected_voltage = 12 * 65536; injected_current = 163840 + 1;
        force dut.voltage_product = injected_voltage;
        force dut.current_product = injected_current;
        @(posedge dut.adc_valid); @(posedge clk); #1; expect_shutdown(); expect_commands_cleared();
        release dut.voltage_product; release dut.current_product;
        sample_raw(1966, 3277); clear_faults();
        start_output();
        injected_voltage = 80 * 65536 + 1; injected_current = 65536;
        force dut.voltage_product = injected_voltage;
        force dut.current_product = injected_current;
        @(posedge dut.adc_valid); @(posedge clk); #1; expect_shutdown(); expect_commands_cleared();
        release dut.voltage_product; release dut.current_product;

        // Both limits remain active while OFF. New commands under persistent
        // overload must trip again at the next valid sample, without auto-retry.
        sample_raw((80*65536-dut.V_OFFSET_Q16)/dut.V_SCALE_Q16+1,
                   (163840-dut.I_OFFSET_Q16)/dut.I_SCALE_Q16+1);
        expect_shutdown(); expect_commands_cleared();
        if (dut.output_status[8:7] !== 2'b11) $fatal(1, "Simultaneous causes not uploaded");
        clear_faults(2'b11);
        set_reference(12); dut.u_axi_system.write_command('h40, 1, 2);
        sample_raw(1966, 3277); frames(2); expect_shutdown();
        // New unsafe sample wins over a simultaneous clear, preserving both causes.
        injected_voltage = 80 * 65536 + 1; injected_current = 163840 + 1;
        force dut.voltage_product = injected_voltage;
        force dut.current_product = injected_current;
        @(posedge dut.adc_valid); force dut.fault_clear_cmd = 1;
        @(posedge clk); #1;
        if (dut.output_status[8:7] !== 2'b11) $fatal(1, "Clear overrode a new trip");
        release dut.fault_clear_cmd; release dut.voltage_product; release dut.current_product;
        sample_raw(1966, 3277); clear_faults();
        start_output();
        force dut.pll_locked = 0;
        repeat (5) @(negedge clk); release dut.pll_locked;
        voltage_raw = 1966; current_raw = 3277;
        frames(3);
        if (dut.protection_stop || dut.output_enable_cmd || dut.pwm_output_enable)
            $fatal(1, "PLL/system reset restored stale output or failed to clear fault");
        start_output();
        test_passed = 1;
        $display("PROTECTION_TEST_PASS: calibrated OCP/OVP upload, sticky causes, unsafe clear refused, safe clear leaves OFF/VREF=0, real AXI clear/VREF/ON recovery, concurrent trip wins, ADC continues");
        $finish;
    end
    initial begin #20000000; $fatal(1, "Protection test timeout"); end
endmodule
