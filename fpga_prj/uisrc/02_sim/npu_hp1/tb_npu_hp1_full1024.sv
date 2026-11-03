`timescale 1ns/1ps
module tb_npu_hp1(output reg test_passed=0);
    reg clk=0;always #5 clk=~clk;
    reg reset_n=0,valid=0;
    reg [47:0] voltage=0,current=0;
    reg [31:0] duty=0,status=0;
    wire axi_reset_n,output_enable_cmd,fault_clear_cmd;
    wire [31:0] vref_cmd_q16;

    integer pixels_checked=0, pixel_index=0, native_count=0, vtg_count=0;
    reg irq_seen=0;
    reg [23:0] expected_pixel;
    axi_system dut(.axi_clk(clk),.pll_locked(1'b1),.ext_reset_n(reset_n),
        .adc_sample_valid(valid),.adc_status_in(32'd0),
        .voltage_product_in(voltage),.current_product_in(current),
        .duty_q16_in(duty),.control_status_in(status),.vref_active_q16_in(32'd0),
        .protection_stop(1'b0),.axi_reset_n(axi_reset_n),
        .output_enable_cmd(output_enable_cmd),.vref_cmd_q16(vref_cmd_q16),.fault_clear_cmd(fault_clear_cmd));
    `define PS dut.axi_system_ARM_Processor_System_0_Inst
    `define FDMA dut.axi_system_adc_fdma_writer_0_Inst.u_writer

    integer native_index=0,native_checked=0;
    reg native_sync_seen=0,previous_native_vs=0;
    reg [23:0] native_expected;
    always @(posedge dut.w_port__HDMI_VTG_0__vtg_pclk) begin
        if(dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_vsync !== previous_native_vs) begin
            native_index=0;
            if(dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.locked)native_sync_seen=1;
        end
        previous_native_vs=dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_vsync;
        if(native_sync_seen && dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_active_video)begin
            native_expected={`PS.frame_byte(native_index*3+2),`PS.frame_byte(native_index*3+1),`PS.frame_byte(native_index*3)};
            if(dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_data!==native_expected)
                $fatal(1,"MAPPED_NATIVE_RGB_MISMATCH index=%0d actual=%h expected=%h",native_index,
                    dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_data,native_expected);
            native_index++;native_checked++;
        end
    end
    initial begin
        repeat(13)begin
           #10000000;
           $display("MAPPED_PROGRESS time_ns=%0.3f lock=%b native=%0d checked=%0d axis=%0d tx_reset=%b",$realtime,
              dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.locked,native_count,native_checked,pixels_checked,
              dut.axi_system_HDMI_Reset_0_Inst.tx_reset);
        end
    end


    `define NPU dut.axi_system_Video_NPU_0_Inst
    reg npu_go=0,npu_done=0;
    initial begin
        wait(npu_go);
        for(integer id=0;id<64;id++)begin
            `NPU.test_write(33'h1000e000+(id%8)*128,id,16);
            `NPU.test_read(33'h1000e000+(id%8)*128,id,16);
        end
        fork
            `NPU.test_write(33'h1000ec00,6'h2a,16);
            `NPU.test_read(33'h1000e000,6'h38,16);
        join
        `PS.npu_write_error=1;
        `NPU.test_write(33'h1000e800,6'h3f,1,2);
        `PS.npu_write_error=0;`PS.npu_read_error=1;
        `NPU.test_read(33'h1000e800,6'h3f,1,2);
        `PS.npu_read_error=0;npu_done=1;
        $display("NPU_HP1_ALL_64_IDS_RW_BACKPRESSURE_SLVERR_PASS");
    end
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
        `PS.write_gp1(33'h1f0000040,32'h81fedcba);
        `PS.read_gp1(33'h1f0000040,data,resp);
        if(resp!=0 || data!==32'h81fedcba)$fatal(1,"GP1 NPU control readback failed");
        `PS.write_gp1(33'h1f0000000,1);repeat(5)@(posedge clk);
        if(`PS.f2p_irq[15]!==1)$fatal(1,"NPU IRQ15 missing");
        `PS.write_gp1(33'h1f0000000,0);repeat(5)@(posedge clk);
        if(`PS.f2p_irq[15]!==0)$fatal(1,"NPU IRQ15 did not clear");
        `PS.read_gp1(33'h1f0010000,data,resp);
        if(resp!=3)$fatal(1,"GP1 address aperture failed resp=%h",resp);
        $display("NPU_GP1_33BIT_CONTROL_IRQ15_AND_DECERR_PASS");

        // Exercise all four GP0 targets before simultaneous capture/display.
        check_read(33'h80100004,1024);
        check_read(33'h80100014,600);
        `PS.write32(33'h80100020,0);
        `PS.write32(33'h80100000,48);  // preserve reference blanking widths
        `PS.write32(33'h80100004,1024);
        `PS.write32(33'h80100008,96);  // sync
        `PS.write32(33'h8010000c,144);  // back porch
        `PS.write32(33'h80100010,3);
        `PS.write32(33'h80100014,600);
        `PS.write32(33'h80100018,7);
        `PS.write32(33'h8010001c,14);
        check_read(33'h80100004,1024);
        check_read(33'h80100014,600);
        `PS.read32(33'h80101008,data,resp);
        if(resp!=0 || !data[0]) $fatal(1,"dynamic PLL register window not decoded");
        // RGB888, 128x32, four frame-store pointers to the same modeled buffer.
        `PS.write32(33'h80200000,32'h00011003); // IOC IRQ enabled
        for(n=0;n<4;n++) `PS.write32(33'h8020005c+n*4,32'h20000000);
        `PS.write32(33'h80200058,3072);
        `PS.write32(33'h80200054,3072);
        `PS.write32(33'h80200050,600);  // VSIZE last starts the transfer
        repeat(500) @(posedge clk);
        `PS.write32(33'h80100020,1);
        $display("HDMI_GP0_VTG_VDMA_CONFIGURATION_PASS");

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
        start_capture();npu_go=1;
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
        wait(npu_done);reset_capture();`PS.inject_error=1;start_capture();send_packet(10);
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

        #125000000;
        `PS.read32(33'h80200004,data,resp);
        if(resp!=0 || (data & 32'h00000ff0)!=0) $fatal(1,"VDMA status error %h",data);

        $display("FULL1024_SNAPSHOT hp0_beats=%0d axis_pixels=%0d native_pixels=%0d vtg_pixels=%0d lock=%b status=%h fifo=%0d sof=%b uf=%b of=%b ce=%b axis_rst_n=%b pixel_rst=%b pixel_lock=%b serial_lock=%b tx_reset=%b dmasr=%h",
          `PS.read_beats,pixels_checked,native_count,vtg_count,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.locked,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.status,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.fifo_read_level,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.sof_state_out,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.underflow,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.overflow,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vtg_ce,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.aresetn,
          dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_io_out_reset,
          dut.axi_system_HDMI_VTG_0_Inst.vtg_pclk_locked,
          dut.axi_system_HDMI_Reset_0_Inst.serial_pll_locked,
          dut.axi_system_HDMI_Reset_0_Inst.tx_reset,data);
        if (!dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.locked || native_count<614400)
          $fatal(1,"FULL1024_NATIVE_VIDEO_FAIL");
        if(`PS.read_beats<1536 || pixels_checked<4096)
            $fatal(1,"insufficient HP0/AXIS pixel coverage");
        if(!irq_seen) $fatal(1,"VDMA IRQ did not reach PS f2p_irq[0]");
        $display("HDMI_HP0_RGB888_GP0_IRQ_HP1_CONCURRENT_PASS pixels=%0d read_bursts=%0d",pixels_checked,`PS.read_bursts);
        if(!$test$plusargs("interface_only") && !dut.w_port__AXI4_Stream_to_Video_Out_0__locked)
            $fatal(1,"display progress beats=%0d pixels=%0d lock=%b status=%h uf=%b of=%b ce=%b native=%0d timing=%0d pixel_lock=%b reset=%b",`PS.read_beats,pixels_checked,dut.w_port__AXI4_Stream_to_Video_Out_0__locked,dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.status,dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.underflow,dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.overflow,dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vtg_ce,native_count,vtg_count,dut.axi_system_HDMI_VTG_0_Inst.vtg_pclk_locked,dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_io_out_reset);
        if(!$test$plusargs("interface_only"))
            $display("HDMI_NATIVE_VIDEO_LOCK_PASS native_pixels=%0d",native_count);
        if(native_checked<614400 || dut.axi_system_HDMI_Reset_0_Inst.tx_reset)
            $fatal(1,"MAPPED_NATIVE_COVERAGE_FAIL checked=%0d",native_checked);
        $display("HDMI_1024X600_MAPPED_NATIVE_RGB_AND_TX_RELEASE_PASS checked=%0d",native_checked);

        if(!npu_done || `PS.npu_rd_beats!=1041 || `PS.npu_wr_bursts!=66)$fatal(1,"NPU insufficient coverage");
        $display("NPU_HP1_FDMA_HDMI_CONCURRENT_INTERFACE_PASS npu_reads=%0d npu_writes=%0d",`PS.npu_rd_bursts,`PS.npu_wr_bursts);
        test_passed=1;$finish;

    end
    initial begin #180000000;$fatal(1,"global timeout");end
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

always @(posedge dut.w_port__VDMA_0__m_axis_mm2s_aclk) begin
    if(dut.w_port__VDMA_0__m_axis_mm2s_tvalid && dut.w_port__VDMA_0__m_axis_mm2s_tready) begin
        if(dut.w_port__VDMA_0__m_axis_mm2s_tuser) pixel_index=0;
        expected_pixel={ `PS.frame_byte(pixel_index*3+2),`PS.frame_byte(pixel_index*3+1),`PS.frame_byte(pixel_index*3)};
        if(dut.w_port__VDMA_0__m_axis_mm2s_tdata!==expected_pixel)
            $fatal(1,"VDMA pixel mismatch index=%0d got=%h expected=%h",pixel_index,dut.w_port__VDMA_0__m_axis_mm2s_tdata,expected_pixel);
        if(dut.w_port__VDMA_0__m_axis_mm2s_tlast !== (pixel_index%1024==1023))
            $fatal(1,"VDMA EOL mismatch index=%0d",pixel_index);
        if(dut.w_port__VDMA_0__m_axis_mm2s_tuser !== (pixel_index==0))
            $fatal(1,"VDMA SOF mismatch index=%0d",pixel_index);
        pixel_index++; pixels_checked++;
    end
end
always @(posedge clk) if(`PS.f2p_irq[0]) irq_seen=1;
always @(posedge dut.w_port__HDMI_VTG_0__vtg_pclk) begin
    if(dut.axi_system_AXI4_Stream_to_Video_Out_0_Inst.vid_active_video) native_count++;
    if(dut.axi_system_HDMI_VTG_0_Inst.vtg_active_video) vtg_count++;
end
endmodule
