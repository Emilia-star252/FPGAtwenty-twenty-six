`timescale 1ns/1ps

module pi_precision_case #(parameter W=32, F=16)(output reg done=0);
    reg clk=0, rst_n=0, clear=0, valid=0;
    always #5 clk=~clk;
    reg signed [W-1:0] ref_in=0, fbk_in=0, kp=0, ki=0, hi=0, lo=0;
    wire signed [W-1:0] out;
    wire ready, busy, out_valid;
    cntl_pi_fixed #(.WIDTH(W), .FRAC(F)) dut(
        .clk(clk), .rst_n(rst_n), .clear(clear), .in_valid(valid),
        .in_ready(ready), .ref_in(ref_in), .fbk_in(fbk_in),
        .kp_in(kp), .ki_in(ki), .umax_in(hi), .umin_in(lo),
        .out(out), .out_valid(out_valid), .busy(busy));

    // Independent 128-bit arithmetic oracle. No DUT intermediate is used
    // to compute expected results. Check internal state only against the oracle.
    reg signed [127:0] integral=0, product, next_i, sum, limited, expected;
    reg unsaturated=1;
    localparam signed [127:0] ONE=128'sd1 << F;
    localparam signed [127:0] IBOUND=128'sd30 << (3*F);
    localparam signed [127:0] MAX_INPUT=(128'sd1 << (W-1))-1;
    localparam signed [127:0] MIN_INPUT=-(128'sd1 << (W-1));
    integer checks=0, j;
    reg signed [127:0] positive_integral;
    reg [31:0] rng=32'h2451aabb;

    task automatic flush;
        begin
            @(negedge clk); valid=0; clear=1;
            @(posedge clk); #1;
            if (out !== 0 || out_valid || busy || ready || dut.i1 !== 0)
                $fatal(1,"W=%0d F=%0d clear failed",W,F);
            integral=0; unsaturated=1;
            @(negedge clk); clear=0;
        end
    endtask

    task automatic sample(input signed [127:0] r, b, p, i, h, l);
        begin
            @(negedge clk);
            if (!ready) $fatal(1,"Unexpected backpressure");
            ref_in=r; fbk_in=b; kp=p; ki=i; hi=h; lo=l; valid=1;
            // Use the sign-extended, actual interface values for all formats.
            product=$signed(ref_in); product=product-$signed(fbk_in);
            product=product*$signed(kp);
            next_i=integral;
            if (unsaturated) next_i=next_i+product*$signed(ki);
            sum=((product >>> F) <<< (2*F))+next_i;
            limited=sum;
            if (limited > (h <<< (2*F))) limited=h <<< (2*F);
            if (limited < (l <<< (2*F))) limited=l <<< (2*F);
            expected=limited >>> (2*F);
            unsaturated=(sum==limited);
            if (next_i > IBOUND) integral=IBOUND;
            else if (next_i < -IBOUND) integral=-IBOUND;
            else integral=next_i;
            @(posedge clk); #1;
            if (!busy || ready || out_valid) $fatal(1,"Accept handshake failed");
            // All inputs may change while busy; the accepted frame is held.
            @(negedge clk); valid=0; ref_in=0; fbk_in=0; kp=0; ki=0; hi=0; lo=0;
            repeat (2) begin
                @(posedge clk); #1;
                if (!busy || ready || out_valid) $fatal(1,"Early result");
            end
            @(posedge clk); #1;
            if (!out_valid || busy || !ready || $signed(out) !== expected)
                $fatal(1,"W=%0d F=%0d n=%0d output=%0d expected=%0d",W,F,checks,$signed(out),expected);
            if ($signed(dut.i1) !== integral || dut.prev_unsaturated !== unsaturated)
                $fatal(1,"W=%0d F=%0d n=%0d accumulator=%0d expected=%0d or anti-windup mismatch",W,F,checks,$signed(dut.i1),integral);
            checks=checks+1;
            @(posedge clk); #1;
            if (out_valid) $fatal(1,"out_valid must pulse for one cycle");
        end
    endtask

    initial begin
        #12; rst_n=1;
        if (F==16) begin
            // The reported 24 V - 23.455856 V error. Old delta_i was zero.
            for (j=0;j<256;j=j+1) sample(1572864,1537203,66,655,13107,-13107);
            if (out <= 35) $fatal(1,"Reported small error did not integrate");
            $display("SMALL_ERROR_PASS samples=256 out_q16=%0d integral_q48=%0d",out,integral);
            positive_integral=integral;
            flush();
            for (j=0;j<256;j=j+1) sample(1537203,1572864,66,655,13107,-13107);
            if (integral !== -positive_integral) $fatal(1,"Signed integral is asymmetric");
            // Below one Q16 P LSB: even the first product must be retained.
            flush();
            for (j=0;j<1024;j=j+1) sample(388,0,66,655,13107,-13107);
            if (out <= 0) $fatal(1,"One ADC code error did not integrate");
            $display("ONE_ADC_CODE_PASS samples=1024 out_q16=%0d",out);
            // Saturation freeze must retain the fractional accumulator.
            flush();
            for (j=0;j<80;j=j+1) sample(35661,0,66,655,10,-10);
            sample(0,0,66,655,13107,-13107);
            sample(35661,0,66,655,13107,-13107);
            flush();
        end
        // Proportional-only transfer, both stored-integral clamps, extreme
        // signed products, saturation freeze/recovery, and all supported F.
        sample(ONE,0,ONE/2,0,ONE,-ONE);
        flush();
        sample(2*ONE,0,2*ONE,8*ONE,MAX_INPUT,MIN_INPUT);
        sample(0,0,ONE,ONE,MAX_INPUT,MIN_INPUT);
        flush();
        sample(-2*ONE,0,2*ONE,8*ONE,MAX_INPUT,MIN_INPUT);
        sample(0,0,ONE,ONE,MAX_INPUT,MIN_INPUT);
        flush();
        sample(MAX_INPUT,MIN_INPUT,MAX_INPUT,MAX_INPUT,MAX_INPUT,MIN_INPUT);
        sample(MIN_INPUT,MAX_INPUT,MIN_INPUT,MIN_INPUT,MAX_INPUT,MIN_INPUT);
        flush();
        for (j=0;j<200;j=j+1) begin
            rng=rng ^ (rng << 13); rng=rng ^ (rng >> 17); rng=rng ^ (rng << 5);
            sample($signed(rng[15:0]),0,ONE/4,ONE/8,4*ONE,-4*ONE);
        end
        // Clear a live fractional value, then interrupt an accepted frame.
        flush();
        @(negedge clk); valid=1; ref_in=ONE; kp=ONE; ki=ONE; hi=ONE; lo=-ONE;
        @(posedge clk); #1;
        @(negedge clk); clear=1; valid=0;
        @(posedge clk); #1;
        if (out_valid || busy || out !== 0 || dut.i1 !== 0) $fatal(1,"Busy clear failed");
        @(negedge clk); clear=0;
        sample(ONE,0,ONE/2,ONE/2,ONE,-ONE);
        #2; rst_n=0; #1;
        if (out_valid || busy || out !== 0 || dut.i1 !== 0) $fatal(1,"Async reset failed");
        $display("PI_FORMAT_PASS W=%0d F=%0d checks=%0d",W,F,checks);
        done=1;
    end
endmodule

module tb_pi_precision;
    wire a,b,c,d;
    reg test_passed=0;
    pi_precision_case #(32,16) q16(a);
    pi_precision_case #(24,12) q12(b);
    pi_precision_case #(16,11) q11(c);
    pi_precision_case #(16,0) integer_only(d);
    initial begin
        wait(a&&b&&c&&d);
        test_passed=1;
        $display("PI_PRECISION_ALL_TESTS_PASS");
        $finish;
    end
    initial begin #2000000; $fatal(1,"Watchdog"); end
endmodule
