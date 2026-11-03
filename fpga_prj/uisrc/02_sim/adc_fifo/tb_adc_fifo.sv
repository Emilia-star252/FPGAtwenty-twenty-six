`timescale 1ns/1ps
// Run with a small behavioral FIFO, or define VENDOR_FIFO for the actual TD IP.
module tb_adc_fifo;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg adc_sample_valid = 0;
    reg protection_stop = 0;
    reg [15:0] voltage_raw_in = 0, current_raw_in = 0;
    reg [31:0] voltage_q16_in = 0;
    reg [31:0] current_q16_in = 0;
    reg [31:0] duty_q16_in = 0, control_status_in = 0;
    wire [31:0] vref_active_q16_in = 32'h000c0000;
    wire output_enable_cmd;
    wire fault_clear_cmd;
    integer fault_clear_pulses = 0;
    always @(posedge clk) if (fault_clear_cmd) fault_clear_pulses = fault_clear_pulses + 1;
    wire [31:0] vref_cmd_q16;
    wire [31:0] adc_status_in = 32'h00000019;
    wire capture_enable, fifo_clear, fifo_reset_n;
    wire [31:0] drop_count, level, model_level, src_data, ds_data;
    wire [3:0] src_keep, ds_keep;
    wire src_valid, src_ready, src_last, ds_valid, ds_ready, ds_last;
    reg [7:0] s_axi_awaddr = 0, s_axi_araddr = 0;
    reg [31:0] s_axi_wdata = 0;
    reg [3:0] s_axi_wstrb = 0;
    reg s_axi_awvalid = 0, s_axi_wvalid = 0, s_axi_bready = 0;
    reg s_axi_arvalid = 0, s_axi_rready = 0;
    wire s_axi_awready, s_axi_wready, s_axi_bvalid, s_axi_arready, s_axi_rvalid;
    wire [1:0] s_axi_bresp, s_axi_rresp;
    wire [31:0] s_axi_rdata;

    adc_axis_source producer (
        .clk(clk), .rst_n(rst_n), .capture_enable(capture_enable),
        .fifo_clear(fifo_clear), .adc_sample_valid(adc_sample_valid),
        .voltage_product_in({{16{voltage_q16_in[31]}},voltage_q16_in}),
        .current_product_in({{16{current_q16_in[31]}},current_q16_in}),
        .duty_q16_in(duty_q16_in),
        .m_axis_tdata(src_data), .m_axis_tkeep(src_keep), .m_axis_tlast(src_last),
        .m_axis_tvalid(src_valid), .m_axis_tready(src_ready),
        .drop_count(drop_count), .fifo_reset_n(fifo_reset_n),
        .fifo_out_tvalid(ds_valid), .fifo_out_tready(ds_ready), .fifo_level(level)
    );
    axi4lite_slave regs (
        .clk(clk), .rst_n(rst_n), .adc_sample_valid(adc_sample_valid),
        .control_status_in(control_status_in),
        .vref_active_q16_in(vref_active_q16_in),
        .protection_stop(protection_stop),
        .output_enable_cmd(output_enable_cmd), .vref_cmd_q16(vref_cmd_q16),
        .fault_clear_cmd(fault_clear_cmd),
        .adc_status_in(adc_status_in), .capture_enable(capture_enable),
        .fifo_clear(fifo_clear), .fifo_ready_in(fifo_reset_n),
        .fifo_drop_count_in(drop_count), .fifo_level_in(level),
        .s_axis_tdata(ds_data), .s_axis_tkeep(ds_keep), .s_axis_tlast(ds_last),
        .s_axis_tvalid(ds_valid), .s_axis_tready(ds_ready),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready), .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready), .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );
`ifdef VENDOR_FIFO
    localparam FIFO_DEPTH = 4096;
    axi_system_AXIS_Data_FIFO_0 fifo (
        .us_aclk(clk), .us_aresetn(fifo_reset_n), .us_tvalid(src_valid),
        .us_tready(src_ready), .us_tdata(src_data), .us_tkeep(src_keep),
        .us_tlast(src_last), .almost_full(), .axis_wr_data_count(),
        .ds_tvalid(ds_valid), .ds_tready(ds_ready), .ds_tdata(ds_data),
        .ds_tkeep(ds_keep), .ds_tlast(ds_last), .ds_tuser(),
        .almost_empty(), .axis_rd_data_count()
    );
`else
    localparam FIFO_DEPTH = 16;
    adc_fifo_model #(.DEPTH(FIFO_DEPTH)) fifo (
        .clk(clk), .rst_n(fifo_reset_n), .us_valid(src_valid),
        .us_ready(src_ready), .us_data(src_data), .us_keep(src_keep),
        .us_last(src_last), .ds_valid(ds_valid), .ds_ready(ds_ready),
        .ds_data(ds_data), .ds_keep(ds_keep), .ds_last(ds_last), .level(model_level)
    );
`endif

    integer input_beats = 0, output_beats = 0, clear_pulses = 0;
    reg stalled = 0;
    reg [36:0] stalled_payload;
    always @(posedge clk) begin
        if (!fifo_reset_n) begin
            input_beats = 0;
            output_beats = 0;
            stalled = 0;
        end else begin
            if (stalled && (!src_valid || {src_data, src_keep, src_last} !== stalled_payload))
                $fatal(1, "AXIS payload changed under back-pressure");
            if (src_valid && src_ready) begin
                if (src_keep !== 4'hf || src_last !== ((input_beats % 1024) == 1023))
                    $fatal(1, "TKEEP/TLAST at beat %0d", input_beats);
                input_beats = input_beats + 1;
            end
            if (ds_valid && ds_ready) output_beats = output_beats + 1;
            stalled = src_valid && !src_ready;
            stalled_payload = {src_data, src_keep, src_last};
        end
        if (rst_n && fifo_clear) clear_pulses = clear_pulses + 1;
    end

    task automatic send_aw(input [7:0] addr, input integer delay_cycles);
        repeat (delay_cycles) @(negedge clk);
        @(negedge clk); s_axi_awaddr = addr; s_axi_awvalid = 1;
        do @(posedge clk); while (!s_axi_awready);
        @(negedge clk); s_axi_awvalid = 0;
    endtask
    task automatic send_w(input [31:0] data, input [3:0] strb, input integer delay_cycles);
        repeat (delay_cycles) @(negedge clk);
        @(negedge clk); s_axi_wdata = data; s_axi_wstrb = strb; s_axi_wvalid = 1;
        do @(posedge clk); while (!s_axi_wready);
        @(negedge clk); s_axi_wvalid = 0;
    endtask
    // order 0 = simultaneous, 1 = AW first, 2 = W first.
    task automatic write_reg_resp(input [7:0] addr, input [31:0] data,
                             input [3:0] strb, input integer order_mode, input [1:0] expected_resp);
        fork
            send_aw(addr, (order_mode == 2) ? 3 : 0);
            send_w(data, strb, (order_mode == 1) ? 3 : 0);
        join
        wait (s_axi_bvalid);
        repeat (3) begin
            @(posedge clk); #1;
            if (!s_axi_bvalid || s_axi_bresp !== expected_resp) $fatal(1, "B response unstable");
        end
        @(negedge clk); s_axi_bready = 1;
        @(posedge clk); #1;
        @(negedge clk); s_axi_bready = 0;
    endtask
    task automatic write_reg(input [7:0] addr, input [31:0] data,
                             input [3:0] strb, input integer order_mode);
        write_reg_resp(addr, data, strb, order_mode, 0);
    endtask
    task automatic read_reg(input [7:0] addr, input integer stalls,
                            output [31:0] data, output [1:0] resp);
        integer pops;
        @(negedge clk); s_axi_araddr = addr; s_axi_arvalid = 1; s_axi_rready = 0;
        do @(posedge clk); while (!s_axi_arready);
        #1;
        if (!s_axi_rvalid) $fatal(1, "Missing R response");
        data = s_axi_rdata; resp = s_axi_rresp; pops = output_beats;
        @(negedge clk); s_axi_arvalid = 0;
        repeat (stalls) begin
            @(posedge clk); #1;
            if (!s_axi_rvalid || s_axi_rdata !== data || s_axi_rresp !== resp)
                $fatal(1, "R response changed while stalled");
            if (output_beats != pops) $fatal(1, "Extra FIFO pop while stalled");
        end
        @(negedge clk); s_axi_rready = 1;
        @(posedge clk); #1;
        @(negedge clk); s_axi_rready = 0;
    endtask
    task automatic expect_reg(input [7:0] addr, input [31:0] expected,
                              input [1:0] expected_resp, input integer stalls);
        reg [31:0] data;
        reg [1:0] resp;
        read_reg(addr, stalls, data, resp);
        if (data !== expected || resp !== expected_resp)
            $fatal(1, "addr=%h data=%h expected=%h resp=%b expected_resp=%b",
                   addr, data, expected, resp, expected_resp);
    endtask
    function automatic [31:0] voltage_word(input integer n);
        voltage_word = (n & 1) ? -(n * 65536 + 32768) : n * 131072 + 16384;
    endfunction
    function automatic [31:0] current_word(input integer n);
        current_word = (n & 1) ? n * 32768 + 8192 : -(n * 16384 + 8192);
    endfunction
    function automatic [31:0] duty_word(input integer n);
        duty_word = (n % 1001) * 65536 / 1000;
    endfunction
    function automatic [31:0] status_word(input integer n);
        status_word = 32'h00000014 | (n & 3) | (((n % 3) + 1) << 7);
    endfunction
    function automatic [31:0] stream_word(input integer n);
        reg [47:0] v,c;
        v=$signed(voltage_word(n/4));c=$signed(current_word(n/4));
        case (n % 4)
            0: stream_word = v[31:0];
            1: stream_word = {c[15:0],v[47:32]};
            2: stream_word = c[47:16];
            3: stream_word = duty_word(n / 4);
        endcase
    endfunction
    task automatic drive_frame(input integer n);
        voltage_raw_in = 16'h8000 ^ n[15:0];
        current_raw_in = 16'h3000 + n[15:0];
        voltage_q16_in = voltage_word(n);
        current_q16_in = current_word(n);
        duty_q16_in = duty_word(n);
        control_status_in = status_word(n);
    endtask
    task automatic sample(input integer n);
        @(negedge clk); drive_frame(n); adc_sample_valid = 1;
        @(negedge clk); adc_sample_valid = 0;
        repeat (2) @(negedge clk);
    endtask
    task automatic await_fifo;
        integer timeout_cycles;
        timeout_cycles = 0;
        while (!ds_valid && timeout_cycles < 80) begin
            @(negedge clk); timeout_cycles = timeout_cycles + 1;
        end
        if (!ds_valid) $fatal(1, "FIFO data timeout");
    endtask
    task automatic clear_and_enable;
        integer before_clear;
        before_clear = clear_pulses;
        write_reg('h2c, 3, 1, 1);
        repeat (2) @(negedge clk);
        if (fifo_reset_n) $fatal(1, "FIFO clear did not hold reset");
        if (s_axi_arready !== 1'b1) $fatal(1, "FIFO clear reset AXI bus");
        expect_reg('h28, 0, 2, 1);
        wait (fifo_reset_n); repeat (12) @(negedge clk);
        if (clear_pulses != before_clear + 1 || drop_count !== 0 || ds_valid)
            $fatal(1, "Clear pulse/count/queue failure");
    endtask

    integer n, retained, retained_words;
    reg test_passed = 0;
    initial begin
        repeat (4) @(negedge clk); rst_n = 1;
        wait (fifo_reset_n); repeat (12) @(negedge clk);
        expect_reg('h00, 'h41444331, 0, 0);
        expect_reg('h34, 'h50343831, 0, 0);
        expect_reg('h20, 1, 0, 0);
        expect_reg('h54, 'h43545231, 0, 0);
        expect_reg('h58, 64 * 65536, 0, 0);
        expect_reg('h64, 32'h464c5431, 0, 0);
        expect_reg('h40, 0, 0, 0);
        expect_reg('h44, 0, 0, 0);
        write_reg_resp('h40, 1, 1, 0, 2);
        if (output_enable_cmd) $fatal(1, "Zero-Vref ON command was accepted");
        write_reg('h5c, 1, 1, 0);
        write_reg('h44, 64 * 65536, 15, 0);
        expect_reg('h44, 32'h00400000, 0, 0);
        if (output_enable_cmd) $fatal(1, "64 V SET_VREF enabled output");
        write_reg_resp('h44, 64 * 65536 + 1, 15, 1, 2);
        expect_reg('h44, 64 * 65536, 0, 0);
        // A byte write is checked after merging, so 64 V + one Q16 LSB is rejected.
        write_reg_resp('h44, 1, 1, 2, 2);
        expect_reg('h44, 64 * 65536, 0, 1);
        expect_reg('h5c, 1, 0, 0);
        write_reg('h5c, 1, 1, 0);
        write_reg('h44, 12 * 65536, 15, 1);
        expect_reg('h44, 12 * 65536, 0, 1);
        if (output_enable_cmd) $fatal(1, "SET_VREF enabled output");
        write_reg('h40, 1, 2, 2);
        if (output_enable_cmd) $fatal(1, "OUTPUT ignored WSTRB");
        write_reg('h40, 1, 1, 0);
        if (!output_enable_cmd) $fatal(1, "OUTPUT_ON not latched");
        write_reg_resp('h44, 32'hffffffff, 15, 2, 2);
        write_reg_resp('h44, 65 * 65536, 15, 1, 2);
        write_reg_resp('h45, 6 * 65536, 15, 0, 2);
        expect_reg('h44, 12 * 65536, 0, 0);
        expect_reg('h5c, 1, 0, 0);
        if (!output_enable_cmd) $fatal(1, "Rejected command changed output enable");
        write_reg('h5c, 1, 1, 0);
        expect_reg('h5c, 0, 0, 0);
        write_reg('h44, 32'h000000aa, 1, 0);
        expect_reg('h44, 32'h000c00aa, 0, 0);
        write_reg('h44, 0, 0, 0);
        expect_reg('h44, 32'h000c00aa, 0, 0);
        write_reg('h40, 0, 1, 2);
        expect_reg('h40, 0, 0, 1);
        write_reg('h40, 1, 1, 0);
        write_reg('h44, 0, 15, 0);
        expect_reg('h40, 0, 0, 0);
        expect_reg('h44, 0, 0, 0);
        expect_reg('h50, vref_active_q16_in, 0, 0);
        write_reg('h44, 12 * 65536, 15, 0);
        // ADC driver faults retain their existing ON interlock.
        control_status_in = 32'h00000008;
        write_reg_resp('h40, 1, 1, 0, 2);
        expect_reg('h40, 0, 0, 0);
        write_reg('h40, 0, 1, 0);
        write_reg('h5c, 1, 1, 0);
        control_status_in = 0;
        for (n = 0; n < 2; n = n + 1) begin
            control_status_in = 32'h80 << n;
            write_reg_resp('h40, 1, 1, n, 2);
            expect_reg('h4c, control_status_in, 0, 0);
            write_reg('h40, 0, 1, 0);
        end
        control_status_in = 0;
        write_reg('h40, 1, 1, 0);
        write_reg('h60, 1, 0, 0);
        write_reg('h60, 1, 2, 1);
        write_reg_resp('h61, 1, 1, 2, 2);
        if (fault_clear_pulses != 0 || !output_enable_cmd)
            $fatal(1, "Fault clear ignored WSTRB/alignment");
        write_reg('h60, 1, 1, 0);
        expect_reg('h60, 0, 0, 0);
        expect_reg('h40, 0, 0, 0); expect_reg('h44, 0, 0, 0);
        if (fault_clear_pulses != 1) $fatal(1, "Clear is not one clock pulse");
        write_reg('h44, 12 * 65536, 15, 0);
        write_reg('h40, 1, 1, 0);
        @(negedge clk); protection_stop = 1;
        repeat (2) @(negedge clk); protection_stop = 0;
        expect_reg('h40, 0, 0, 0); expect_reg('h44, 0, 0, 0);
        // ON alone is insufficient. No-strobe and rejected VREF writes cannot rearm.
        write_reg_resp('h40, 1, 1, 1, 2);
        write_reg('h44, 12 * 65536, 0, 0);
        write_reg_resp('h44, 65 * 65536, 15, 2, 2);
        expect_reg('h44, 0, 0, 0);
        write_reg_resp('h40, 1, 1, 2, 2);
        write_reg('h44, 12 * 65536, 15, 0);
        expect_reg('h40, 0, 0, 0);
        write_reg('h40, 1, 1, 1);
        expect_reg('h40, 1, 0, 0);
        // A stop coincident with command processing takes priority over the write.
        @(negedge clk); protection_stop = 1;
        write_reg('h44, 24 * 65536, 15, 2);
        write_reg_resp('h40, 1, 1, 0, 2);
        expect_reg('h40, 0, 0, 0); expect_reg('h44, 0, 0, 0);
        @(negedge clk); protection_stop = 0;
        write_reg('h5c, 1, 1, 0);
        write_reg('h44, 0, 15, 0);
        for (n = 0; n < 32; n = n + 1) begin
            write_reg('h80 + 4*n, 'ha5000000 + n, 15, n % 3);
            write_reg('h80 + 4*n, 'h12345678, 5, n % 3);
            expect_reg('h80 + 4*n, 'ha5340078, 0, n % 4);
        end
        write_reg('h00, 0, 15, 0);
        expect_reg('h00, 'h41444331, 0, 0);
        write_reg('h2c, 3, 2, 0);
        if (capture_enable || clear_pulses) $fatal(1, "CTRL ignored WSTRB");
        sample(7); repeat (10) @(negedge clk);
        if (ds_valid) $fatal(1, "Capture disabled but frame enqueued");
        expect_reg('h08, 1, 0, 0);
        expect_reg('h0c, 0, 2, 0); // retired: samples are DDR only
        expect_reg('h10, 0, 2, 0); // retired: samples are DDR only
        expect_reg('h14, 0, 2, 0); // retired: samples are DDR only
        expect_reg('h18, 0, 2, 0); // retired: samples are DDR only
        expect_reg('h48, 0, 2, 0); // retired: samples are DDR only
        expect_reg('h4c, status_word(7), 0, 0);
        clear_and_enable();
        sample(10); await_fifo();
        expect_reg('h29, 0, 2, 3);
        if (!ds_valid) $fatal(1, "Misaligned read popped data");
        expect_reg('h28, stream_word(4*(10)+0), 0, 8);
        await_fifo(); expect_reg('h28, stream_word(4*(10)+1), 0, 8);
        await_fifo(); expect_reg('h28, stream_word(4*(10)+2), 0, 8);
        await_fifo(); expect_reg('h28, stream_word(4*(10)+3), 0, 8);
        expect_reg('h28, 0, 2, 3);

        clear_and_enable(); sample(0); await_fifo();
        @(negedge clk); s_axi_araddr = 'h28; s_axi_arvalid = 1;
        @(posedge clk); #1;
        if (s_axi_rdata !== voltage_word(0) || s_axi_rresp !== 0)
            $fatal(1, "First pipelined FIFO read");
        repeat (6) begin
            @(posedge clk); #1;
            if (s_axi_arready || output_beats != 1 || s_axi_rdata !== voltage_word(0))
                $fatal(1, "Accepted extra AR under R stall");
        end
        @(negedge clk); s_axi_rready = 1;
        @(posedge clk); #1;
        if (s_axi_rdata !== stream_word(1) || output_beats != 2)
            $fatal(1, "Simultaneous R consume / next AR accept");
        @(negedge clk); s_axi_arvalid = 0;
        @(posedge clk); #1;
        @(negedge clk); s_axi_rready = 0;

        // One complete frame every four clocks, concurrent with one read/clock.
        clear_and_enable(); sample(0); sample(1); await_fifo();
        for (n = 0; n < 200; n = n + 1) begin
            @(negedge clk);
            drive_frame(n / 4 + 2); adc_sample_valid = ((n % 4) == 0);
            s_axi_araddr = 'h28; s_axi_arvalid = 1; s_axi_rready = 1;
            @(posedge clk); #1;
            if (!s_axi_rvalid || s_axi_rresp !== 0 || s_axi_rdata !== stream_word(n))
                $fatal(1, "Continuous Q16 stream order at %0d", n);
        end
        @(negedge clk); adc_sample_valid = 0; s_axi_arvalid = 0;
        @(posedge clk); #1;
        @(negedge clk); s_axi_rready = 0;
        for (n = 200; n < 208; n = n + 1) begin
            await_fifo(); expect_reg('h28, stream_word(n), 0, 0);
        end
        if (drop_count !== 0 || output_beats != 208)
            $fatal(1, "Continuous frame accounting");

        clear_and_enable();
        for (n = 0; n < 300; n = n + 1) begin
            sample(n); await_fifo();
            if (ds_last !== 0) $fatal(1, "TLAST on voltage word");
            expect_reg('h28, stream_word(4*(n)+0), 0, n % 8);
            await_fifo();
            if (ds_last !== 0) $fatal(1, "TLAST on current word");
            expect_reg('h28, stream_word(4*(n)+1), 0, n % 7);
            await_fifo(); expect_reg('h28, stream_word(4*(n)+2), 0, n % 6);
            await_fifo();
            if (ds_last !== ((n % 256) == 255)) $fatal(1, "TLAST missing on final duty word");
            expect_reg('h28, stream_word(4*(n)+3), 0, n % 5);
        end
        if (drop_count !== 0 || output_beats != 1200) $fatal(1, "Normal capture accounting");

        clear_and_enable();
        for (n = 0; n < FIFO_DEPTH / 4 + 13; n = n + 1) sample(n);
        repeat (20) @(negedge clk);
        retained_words = level + producer.words_pending;
        retained = retained_words / 4;
        if ((retained_words % 4) != 0 || drop_count == 0 ||
            drop_count !== FIFO_DEPTH / 4 + 13 - retained)
            $fatal(1, "Full frame accounting: level=%0d pending=%0d drops=%0d",
                   level, producer.words_pending, drop_count);
        expect_reg('h30, drop_count, 0, 2);
        write_reg('h2c, 0, 1, 2);
        for (n = 0; n < retained_words; n = n + 1) begin
            await_fifo(); expect_reg('h28, stream_word(n), 0, n % 5);
        end
        repeat (12) @(negedge clk);
        if (ds_valid || src_valid) $fatal(1, "FIFO did not drain after disabling capture");

        clear_and_enable();
        for (n = 0; n < FIFO_DEPTH / 4 + 4; n = n + 1) sample(n);
        clear_and_enable();
        sample(123); await_fifo();
        expect_reg('h28, stream_word(4*(123)+0), 0, 4);
        await_fifo(); expect_reg('h28, stream_word(4*(123)+1), 0, 4);
        await_fifo(); expect_reg('h28, stream_word(4*(123)+2), 0, 4);
        await_fifo(); expect_reg('h28, stream_word(4*(123)+3), 0, 4);
        @(negedge clk); rst_n = 0;
        repeat (4) @(negedge clk); rst_n = 1;
        wait (fifo_reset_n); repeat (12) @(negedge clk);
        expect_reg('h2c, 0, 0, 0);
        expect_reg('h08, 0, 0, 0);
        expect_reg('h20, 1, 0, 0);
        test_passed = 1;
        $display("ADC_FIFO_TEST_PASS: P481 atomic frames, remote command validation, 1024-beat TLAST, full/drop, clear/reset, AXI stalls and telemetry regression");
        $finish;
    end
    initial begin #20000000; $fatal(1, "Test timeout"); end
endmodule

// Handshake-level model only; vendor FIFO is tested separately when available.
module adc_fifo_model #(parameter DEPTH = 16)(
    input wire clk, rst_n, us_valid, ds_ready,
    input wire [31:0] us_data,
    input wire [3:0] us_keep,
    input wire us_last,
    output wire us_ready, ds_valid,
    output wire [31:0] ds_data,
    output wire [3:0] ds_keep,
    output wire ds_last,
    output wire [31:0] level
);
    reg [36:0] mem [0:DEPTH-1];
    integer wr = 0, rd = 0, count = 0;
    assign us_ready = rst_n && count < DEPTH;
    assign ds_valid = rst_n && count != 0;
    assign {ds_data, ds_keep, ds_last} = mem[rd];
    assign level = count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin wr <= 0; rd <= 0; count <= 0; end
        else begin
            if (us_valid && us_ready) begin
                mem[wr] <= {us_data, us_keep, us_last};
                wr <= (wr == DEPTH - 1) ? 0 : wr + 1;
            end
            if (ds_valid && ds_ready) rd <= (rd == DEPTH - 1) ? 0 : rd + 1;
            case ({us_valid && us_ready, ds_valid && ds_ready})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: ;
            endcase
        end
    end
endmodule
