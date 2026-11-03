`timescale 1ns/1ps
module tb_adc_fdma;
    reg clk=0;always #5 clk=~clk;
    reg reset_n=0,valid=0;
    reg [47:0] voltage=0,current=0;
    reg [31:0] duty=0,status=0;
    wire axi_reset_n,output_enable_cmd,fault_clear_cmd;
    wire [31:0] vref_cmd_q16;
    reg test_passed=0;
    axi_system dut(.axi_clk(clk),.pll_locked(1'b1),.ext_reset_n(reset_n),
        .adc_sample_valid(valid),.adc_status_in(32'd0),
        .voltage_product_in(voltage),.current_product_in(current),
        .duty_q16_in(duty),.control_status_in(status),.vref_active_q16_in(32'd0),
        .protection_stop(1'b0),.axi_reset_n(axi_reset_n),
        .output_enable_cmd(output_enable_cmd),.vref_cmd_q16(vref_cmd_q16),.fault_clear_cmd(fault_clear_cmd));
    `define PS dut.axi_system_ARM_Processor_System_0_Inst
    `define FDMA dut.axi_system_adc_fdma_writer_0_Inst.u_writer
    reg [31:0] data;reg [1:0] resp;
    integer n,bytes_before;
    function automatic [127:0] frame_value(input integer id,input integer f);
        reg [47:0] v,c;reg [31:0] d;
        begin
            v=48'h123480000000+f+id*256;
            c=48'hfedc7fffffff-f-id*256;
            d=32'h8000+f;
            case(f)
                0: begin v=48'h800000000000;c=48'h7fffffffffff;end
                1: begin v=48'hffffffffffff;c=48'h800000000001;end
            endcase
            frame_value={d,c,v};
        end
    endfunction
    task automatic check_read(input [32:0] a,input [31:0] expected);
        begin `PS.read32(a,data,resp);if(resp!=0 || data!==expected)$fatal(1,"read %h got %h resp %b expected %h",a,data,resp,expected);end
    endtask
    task automatic await_producer(input integer expected);
        begin
            for(integer p=0;p<4000;p++) begin
                `PS.read32(33'h8001000c,data,resp);if(resp!=0 || data!=0)$fatal(1,"FDMA error %h",data);
                `PS.read32(33'h8001001c,data,resp);if(resp==0 && data==expected)return;
            end
            $fatal(1,"producer timeout expected=%0d got=%0d state=%0d",expected,data,`FDMA.state);
        end
    endtask
    task automatic send_packet(input integer id);
        reg [127:0] x;
        begin
            for(integer f=0;f<256;f++) begin
                x=frame_value(id,f);
                @(negedge clk);valid=1;voltage=x[47:0];current=x[95:48];duty=x[127:96];status=32'ha5000000+f;
                @(negedge clk);valid=0;repeat(49)@(negedge clk);
            end
        end
    endtask
    task automatic verify_packet(input integer id,input [31:0] destination);
        reg [127:0] expected;integer offset;
        begin
            for(integer f=0;f<256;f++) begin
                expected=frame_value(id,f);offset=destination-32'h10000000+f*16;
                for(integer b=0;b<16;b++)
                    if(`PS.memory[offset+b]!==expected[b*8+:8])$fatal(1,"DDR mismatch packet=%d frame=%d byte=%d got=%h exp=%h",id,f,b,`PS.memory[offset+b],expected[b*8+:8]);
            end
            $display("FDMA_48_48_32_PACKET_PASS packet=%0d address=%h",id,destination);
        end
    endtask
    task automatic reset_capture;
        begin
            `PS.write32(33'h8000002c,0);
            `PS.write32(33'h80010004,2);
            for(integer p=0;p<4000;p++) begin
                `PS.read32(33'h80010004,data,resp);if(data==0)break;
            end
            if(data!=0)$fatal(1,"reset drain timeout");
            `PS.write32(33'h8000002c,2);repeat(60)@(posedge clk);
            check_read(33'h8001001c,0);check_read(33'h80010020,0);check_read(33'h8001000c,0);
        end
    endtask
    task automatic start_capture;
        begin `PS.write32(33'h80010004,1);`PS.write32(33'h8000002c,1);end
    endtask
    initial begin
        #100;reset_n=1;wait(axi_reset_n);repeat(50)@(posedge clk);
        check_read(33'h80000000,32'h41444331);check_read(33'h80000054,32'h43545231);
        check_read(33'h80000064,32'h464c5431);check_read(33'h80000034,32'h50343831);
        check_read(33'h80010000,32'h46444d31);check_read(33'h80010024,4096);
        check_read(33'h80010028,32'h50343831);
        // GP0 has no measurement readout. CTR1 is intentionally unchanged.
        for(integer idx=0;idx<5;idx++) begin
            case(idx)
                0: `PS.read32(33'h8000000c,data,resp);
                1: `PS.read32(33'h80000010,data,resp);
                2: `PS.read32(33'h80000014,data,resp);
                3: `PS.read32(33'h80000018,data,resp);
                4: `PS.read32(33'h80000048,data,resp);
            endcase
            if(resp!=2 || data!==0)$fatal(1,"retired GP0 sample register still exposed idx=%d",idx);
        end
        $display("GP0_CONTROL_ONLY_CTR1_AND_RETIRED_READS_PASS");
        reset_capture();
        `PS.write32(33'h80010004,1,2); // zero slots: cannot start
        `PS.write32(33'h80010018,3);`PS.write32(33'h80010004,1,2);
        `PS.write32(33'h80010014,2,2); // address exceeds 33 bits
        `PS.write32(33'h80010010,32'h10000fc0,2,4'h3); // no partial writes
        `PS.write32(33'h80010020,1,2); // cannot release unpublished data
        `PS.write32(33'h80010010,32'h10000fc1);`PS.write32(33'h80010018,2);
        `PS.write32(33'h80010004,1,2); // misaligned buffer
        $display("FDMA_CONFIGURATION_REJECTION_PASS");
        `PS.write32(33'h80010010,32'h10000fc0);`PS.write32(33'h80010014,0);`PS.write32(33'h80010018,2);
        start_capture();
        `PS.write32(33'h80010010,32'h10004000,2); // active base is immutable
        send_packet(0);await_producer(1);verify_packet(0,32'h10000fc0);
        // Commands/status are independent of the DDR sample values.
        @(negedge clk);status=0; // remove synthetic fault bits before requesting ON
        `PS.write32(33'h80000044,12*65536);
        `PS.write32(33'h80000040,1);
        check_read(33'h80000044,12*65536);check_read(33'h80000040,1);
        `PS.write32(33'h80000060,1);
        check_read(33'h80000044,0);check_read(33'h80000040,0);
        check_read(33'h80000054,32'h43545231);
        $display("GP0_COMMANDS_DURING_DDR_CAPTURE_PASS");
        send_packet(1);await_producer(2);verify_packet(1,32'h10001fc0);
        bytes_before=`PS.write_bytes;
        send_packet(2);repeat(200)@(posedge clk);
        if(`PS.write_bytes!=bytes_before)$fatal(1,"unread ring overwritten");
        `PS.read32(33'h80010008,data,resp);if(!data[2])$fatal(1,"ring full missing");
        verify_packet(0,32'h10000fc0);verify_packet(1,32'h10001fc0);
        `PS.write32(33'h80010020,1);await_producer(3);verify_packet(2,32'h10000fc0);
        check_read(33'h80000030,0);
        $display("FDMA_RING_FULL_WRAP_AND_BACKPRESSURE_PASS");
        reset_capture();start_capture();
        send_packet(3);await_producer(1);send_packet(4);await_producer(2);
        bytes_before=`PS.write_bytes;
        for(n=5;n<10;n++)send_packet(n);
        `PS.read32(33'h80000030,data,resp);if(data==0)$fatal(1,"FIFO overflow not counted");
        if(`PS.write_bytes!=bytes_before)$fatal(1,"ring overwritten during FIFO overflow");
        verify_packet(3,32'h10000fc0);verify_packet(4,32'h10001fc0);
        $display("FDMA_FIFO_OVERFLOW_COUNT_PASS drops=%0d",data);
        reset_capture();`PS.inject_error=1;start_capture();send_packet(10);
        for(n=0;n<4000;n++)begin `PS.read32(33'h8001000c,data,resp);if(data[1])break;end
        if(!data[1])$fatal(1,"DDR SLVERR not propagated");check_read(33'h8001001c,0);
        $display("FDMA_SLVERR_UNPUBLISHED_PASS");
        reset_capture();`PS.inject_error=0;start_capture();send_packet(11);await_producer(1);verify_packet(11,32'h10000fc0);
        // Hold B, request soft reset in-flight, then release B. Reset must drain.
        reset_capture();`PS.hold_b=1;start_capture();
        fork
            send_packet(12);
            begin
                wait(`PS.response_delay!=0);
                `PS.write32(33'h8000002c,0);`PS.write32(33'h80010004,2);
                repeat(100)@(posedge clk);
                `PS.read32(33'h80010004,data,resp);if(!data[1])$fatal(1,"reset completed before B response");
                @(negedge clk);`PS.hold_b=0;
            end
        join
        reset_capture();start_capture();send_packet(13);await_producer(1);verify_packet(13,32'h10000fc0);
        $display("FDMA_DRAIN_RESET_RECOVERY_PASS");
        reset_capture();start_capture();
        force `FDMA.s_axis_s2mm_tlast=1'b1;
        send_packet(14);
        release `FDMA.s_axis_s2mm_tlast;
        `PS.read32(33'h8001000c,data,resp);if(!data[2])$fatal(1,"bad TLAST not detected");
        check_read(33'h8001001c,0);
        reset_capture();start_capture();
        force `FDMA.s_axis_s2mm_tkeep=4'h3;
        send_packet(15);
        release `FDMA.s_axis_s2mm_tkeep;
        `PS.read32(33'h8001000c,data,resp);if(!data[2])$fatal(1,"bad TKEEP not detected");
        check_read(33'h8001001c,0);
        $display("FDMA_STREAM_FORMAT_ERROR_PASS");
        reset_capture();start_capture();send_packet(16);await_producer(1);verify_packet(16,32'h10000fc0);
        `PS.read32(33'h80000028,data,resp);if(resp!=2)$fatal(1,"legacy FIFO read must fail");
        `PS.read32(33'h80020000,data,resp);if(resp!=3)$fatal(1,"unmapped GP0 must DECERR");
        if(output_enable_cmd!==0 || vref_cmd_q16!==0 || fault_clear_cmd!==0)$fatal(1,"FDMA altered controls");
        $display("ADC_FDMA_ALL_TESTS_PASS bytes=%0d bursts=%0d",`PS.write_bytes,`PS.burst_count);
        test_passed=1;$finish;
    end
    initial begin #10000000;$fatal(1,"global timeout");end
    reg aw_stall=0,w_stall=0,source_stall=0;
    reg [32:0] prev_awaddr;
    reg [7:0] prev_awlen;
    reg [63:0] prev_wdata;
    reg prev_wlast;
    reg [31:0] prev_source_data;
    reg prev_source_last;
    always @(posedge clk) begin
        if(axi_reset_n)begin
            if(aw_stall && (!`FDMA.m_axi_s2mm_awvalid || `FDMA.m_axi_s2mm_awaddr!==prev_awaddr || `FDMA.m_axi_s2mm_awlen!==prev_awlen))$fatal(1,"FDMA unstable AW under stall");
            if(w_stall && (!`FDMA.m_axi_s2mm_wvalid || `FDMA.m_axi_s2mm_wdata!==prev_wdata || `FDMA.m_axi_s2mm_wlast!==prev_wlast))$fatal(1,"FDMA unstable W under stall");
            if(source_stall && dut.w_port__adc_axis_source_0__fifo_reset_n &&
              (!dut.w_port__adc_axis_source_0__m_axis_tvalid || dut.w_port__adc_axis_source_0__m_axis_tdata!==prev_source_data || dut.w_port__adc_axis_source_0__m_axis_tlast!==prev_source_last))$fatal(1,"source unstable under stall");
        end
        aw_stall<=axi_reset_n && `FDMA.m_axi_s2mm_awvalid && !`FDMA.m_axi_s2mm_awready;
        w_stall<=axi_reset_n && `FDMA.m_axi_s2mm_wvalid && !`FDMA.m_axi_s2mm_wready;
        prev_awaddr<=`FDMA.m_axi_s2mm_awaddr;prev_awlen<=`FDMA.m_axi_s2mm_awlen;
        prev_wdata<=`FDMA.m_axi_s2mm_wdata;prev_wlast<=`FDMA.m_axi_s2mm_wlast;
        source_stall<=axi_reset_n && dut.w_port__adc_axis_source_0__m_axis_tvalid && !dut.w_port__adc_axis_source_0__m_axis_tready;
        prev_source_data<=dut.w_port__adc_axis_source_0__m_axis_tdata;
        prev_source_last<=dut.w_port__adc_axis_source_0__m_axis_tlast;
    end
endmodule
