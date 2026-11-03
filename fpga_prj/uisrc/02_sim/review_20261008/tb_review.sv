`timescale 1ns/1ps
// Audit-only models: no vendor PLL timing, analog plant, or gate delays.
module PLL_sys100(input refclk, input reset, output clk0_out, output lock);
    assign clk0_out = refclk;
    assign lock = !reset;
endmodule

module ChipWatcher_0(input clk, input [15:0] probe0, probe1,
                     input probe2, probe3);
endmodule

module adc7606_model(input convst, cs, sclk, reset,
                     input [1:0] fault_mode,
                     output reg busy = 0, dout_a = 0, dout_b = 0);
    localparam [63:0] A = {16'h1234,16'd40,16'd1,16'hFEDC};
    localparam [63:0] B = {16'h8000,16'h5555,16'hAAAA,16'h7FFF};
    integer bit_index = 0;
    always @(posedge convst) begin
        if (!reset) begin
            if (fault_mode != 1) begin
                #25 busy = 1;
                if (fault_mode != 2) begin
                    #4000 busy = 0;
                end
            end
        end
    end
    always @(posedge reset) busy = 0;
    always @(negedge cs) begin
        bit_index = 0;
        #30;
        dout_a = A[63]; dout_b = B[63];
    end
    always @(posedge sclk) begin
        if (!cs && bit_index < 63) begin
            bit_index = bit_index + 1;
            #30;
            dout_a = A[63-bit_index]; dout_b = B[63-bit_index];
        end
    end
endmodule

module tb_review;
    reg clk = 0;
    always #5 clk = !clk;
    reg rst_n = 0;
    reg [1:0] fault_mode = 0;
    wire busy0, da0, db0, cs0, sclk0, reset0, conv0;
    wire busy1, da1, db1, cs1, sclk1, reset1, conv1;
    wire h0,l0,h1,l1,h20,l20,h21,l21;
    DCDC_top #(.ADC_RESET_CYCLES(8)) defaults (
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy0),
        .ad_dout_a(da0), .ad_dout_b(db0), .ad_cs(cs0),
        .ad_sclk(sclk0), .ad_rst(reset0), .ad_convsta(conv0),
        .pwm1_h(h0), .pwm1_l(l0), .pwm2_h(h20), .pwm2_l(l20),
        .card_power_en(), .ad_convstb(), .ad_range());
    DCDC_top #(.ADC_RESET_CYCLES(8), .V_KP_Q16(32768),
               .I_KP_Q16(16384)) configured (
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy1),
        .ad_dout_a(da1), .ad_dout_b(db1), .ad_cs(cs1),
        .ad_sclk(sclk1), .ad_rst(reset1), .ad_convsta(conv1),
        .pwm1_h(h1), .pwm1_l(l1), .pwm2_h(h21), .pwm2_l(l21),
        .card_power_en(), .ad_convstb(), .ad_range());
    adc7606_model adc0(conv0,cs0,sclk0,reset0,fault_mode,busy0,da0,db0);
    adc7606_model adc1(conv1,cs1,sclk1,reset1,fault_mode,busy1,da1,db1);

    reg pi_rst = 0, pi_clear = 0, pi_valid = 0;
    reg signed [31:0] pi_ref = 0, pi_fbk = 0, kp = 65536, ki = 65536;
    reg signed [31:0] pi_min = 0, pi_max = 262144;
    wire signed [31:0] pi_result;
    wire pi_ready, pi_ov, pi_busy;
    cntl_pi_fixed pi(clk,pi_rst,pi_clear,pi_valid,pi_ready,
                     pi_ref,pi_fbk,kp,ki,pi_max,pi_min,
                     pi_result,pi_ov,pi_busy);
    task automatic transact(input signed [31:0] r, f, expected);
        integer cycles;
        begin
            @(negedge clk);
            if (!pi_ready) $fatal(1,"PI not ready");
            pi_ref=r; pi_fbk=f; pi_valid=1;
            @(posedge clk); #1;
            if (pi_ready || !pi_busy) $fatal(1,"PI handshake");
            @(negedge clk); pi_valid=0;
            cycles=0;
            while (!pi_ov && cycles < 5) begin
                @(posedge clk); #1; cycles=cycles+1;
            end
            if (cycles != 3 || pi_result !== expected)
                $fatal(1,"PI result=%0d expected=%0d latency=%0d",pi_result,expected,cycles);
        end
    endtask
    task automatic clear_pi;
        begin
            @(negedge clk); pi_clear=1;
            @(negedge clk); pi_clear=0;
        end
    endtask

    reg pwm_rst=0;
    reg [11:0] requested_duty=0;
    wire pwm, trig;
    PWM pwm_test(clk,pwm_rst,requested_duty,pwm,trig);
    task automatic check_pwm_period(input integer requested, expected);
        integer k, highs, triggers;
        begin
            @(negedge clk); requested_duty=requested;
            // Wait for the next atomic duty latch at wrap.
            do begin @(posedge clk); #1; end while (pwm_test.counter != 0);
            highs=0; triggers=0;
            for (k=0; k<4000; k=k+1) begin
                if (pwm_test.counter != k || pwm_test.duty_active != expected)
                    $fatal(1,"PWM counter/duty mismatch");
                if (pwm) highs=highs+1;
                if (trig) begin
                    triggers=triggers+1;
                    if (k != (expected == 0 ? 2000 : expected/2))
                        $fatal(1,"PWM trigger phase");
                end
                if (k == 25) begin
                    @(negedge clk); requested_duty=4000-expected;
                end
                if (k != 3999) begin @(posedge clk); #1; end
            end
            if (highs != expected || triggers != 1)
                $fatal(1,"PWM width %0d / triggers %0d",highs,triggers);
            $display("PASS PWM requested=%0d high_ticks=%0d trigger_count=%0d",requested,highs,triggers);
        end
    endtask

    integer cycle=0, sample_cycle=-1, nsamples=0;
    integer duty_events=0;
    time request_time=0, conversion_time=0;
    always @(posedge configured.adc_trigger) request_time=$time;
    always @(posedge conv1) if (!reset1) begin
        conversion_time=$time;
        if ($time-request_time != 50) $fatal(1,"Trigger to CONVST timing");
    end
    always @(posedge clk) begin
        cycle=cycle+1;
        #1;
        if (!configured.adc_initialized && {h1,l1,h21,l21} !== 4'b0000)
            $fatal(1,"Configured ADC initialization must keep all PWM outputs low");
        if (!defaults.adc_initialized && {h0,l0,h20,l20} !== 4'b0000)
            $fatal(1,"Default ADC initialization must keep all PWM outputs low");
        if (configured.control_rst_n) begin
            if (configured.adc_valid) begin
                sample_cycle=cycle; nsamples=nsamples+1;
                if (configured.adc_data_a !== adc1.A || configured.adc_data_b !== adc1.B)
                    $fatal(1,"ADC channel frame mismatch");
                $display("TRACE sample=%0d trigger_to_convst=50ns convst_to_valid=%0t",nsamples,$time-conversion_time-1);
            end
            if (configured.voltage_pi_valid && cycle-sample_cycle != 5)
                $fatal(1,"Voltage loop latency");
            if (configured.pi_out_valid && cycle-sample_cycle != 10)
                $fatal(1,"Current loop latency");
            if (sample_cycle >= 0 && cycle-sample_cycle == 11) begin
                duty_events=duty_events+1;
                if (configured.voltage_fbk_q16 != 40*65536 ||
                    configured.current_fbk_q16 != 65536 ||
                    configured.current_ref_q16 != 4*65536 ||
                    configured.duty_counts != 3000)
                    $fatal(1,"Configured cascade value/latency");
                $display("PASS cascade sample_to_duty=110ns voltage=40 current=1 iref=4 duty=3000");
            end
            if (configured.sample_overrun) $fatal(1,"Sample overrun");
            if (h1 && l1) $fatal(1,"RTL complement overlap");
            if ({h1,l1} !== {h21,l21}) $fatal(1,"Two PWM pairs differ");
        end
    end

    integer before_fault;
    initial begin
        $timeformat(-9,0,"ns",0);
        #32 rst_n=1; pi_rst=1; pwm_rst=1;
        // Exact unsaturated fixed-point arithmetic and clear.
        kp=32768; ki=32768;
        transact(65536,0,49152);
        transact(65536,0,65536);
        clear_pi();
        // Confirm lower-limit lock: inward positive error cannot integrate.
        kp=6554; ki=65536; pi_min=3277; pi_max=62259;
        transact(0,0,3277);
        repeat(8) transact(6554,0,3277);
        if (pi.i1 != 0 || pi.prev_unsaturated != 0)
            $fatal(1,"Lower saturation reproduction failed");
        $display("REPRO lower saturation: positive error=0.1, Kp~0.1, Ki=1, i1=0 output stays 0.05 for 8 updates");
        clear_pi();
        // Confirm upper-limit lock even with negative error to unwind.
        kp=65536; ki=65536; pi_min=0; pi_max=262144;
        transact(6*65536,0,4*65536);
        repeat(8) transact(-65536,0,4*65536);
        if (pi.i1 != 6*65536) $fatal(1,"Upper saturation reproduction failed");
        $display("REPRO upper saturation: i1=6, error=-1, output stays 4 for 8 updates");
        clear_pi();
        // Full-width subtraction/multiply should saturate without wrapping.
        kp=32'h7fffffff; ki=32'h7fffffff;
        transact(32'h7fffffff,32'h80000000,262144);
        clear_pi();
        transact(32'h80000000,32'h7fffffff,0);
        $display("PASS PI signed extrema, arithmetic and 3-clock accepted-to-valid latency");
        check_pwm_period(0,0);
        check_pwm_period(1,1);
        check_pwm_period(200,200);
        check_pwm_period(2001,2001);
        check_pwm_period(3800,3800);
        check_pwm_period(4000,4000);
        check_pwm_period(4095,4000);
        if (defaults.duty_counts != 200 || defaults.current_ref_q16 != 0)
            $fatal(1,"Default coefficients did not produce fixed 5 percent duty");
        $display("REPRO defaults: zero gains give Iref=0, duty_counts=200");
        if (nsamples < 3 || duty_events < 3) $fatal(1,"Insufficient full-chain samples");
        // Stop BUSY assertion on next conversion; observe timeout and stale PWM.
        fault_mode=1; before_fault=nsamples;
        wait(configured.adc_error); #1;
        repeat(5000) @(posedge clk);
        #1;
        if (configured.adc_ready || configured.duty_counts != 3000 ||
            configured.u_pwm.duty_active != 3000 || nsamples != before_fault ||
            !configured.pwm_output_enable)
            $fatal(1,"Missing BUSY fault reproduction failed");
        $display("REPRO ADC missing BUSY: error=1, ready=0, no new samples, PWM keeps 75 percent duty");
        @(negedge clk); force configured.pll_locked=0; #1;
        if ({h1,l1,h21,l21} !== 4'b0000 || configured.adc_error)
            $fatal(1,"PLL loss shutdown/clear");
        release configured.pll_locked;
        $display("PASS injected PLL loss immediately shuts down all configured PWM outputs");
        // Reset shuts down both outputs and clears fault.
        @(negedge clk); rst_n=0; #1;
        if ({h0,l0,h1,l1,h20,l20,h21,l21} !== 8'b00000000 || configured.adc_error)
            $fatal(1,"Reset shutdown/clear");
        sample_cycle=-1;
        fault_mode=2; @(negedge clk); rst_n=1;
        wait(configured.adc_error); #1;
        if (!configured.pwm_output_enable || configured.duty_counts != 0 || l1 != 1)
            $fatal(1,"Stuck BUSY startup reproduction failed");
        $display("REPRO startup stuck BUSY: first conversion never valid, duty=0 but low-side output stays 1");
        $display("AUDIT_PASS all assertions and issue reproductions completed");
        $finish;
    end
    initial begin #1000000; $fatal(1,"Audit watchdog expired"); end
endmodule
