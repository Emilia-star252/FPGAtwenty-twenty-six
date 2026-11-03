`timescale 1ns/1ps
module tb_adc_dma;
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0, valid=0;
    reg [31:0] voltage=0,current=0,duty=0,status=0;
    wire axi_reset_n,output_enable_cmd,fault_clear_cmd;
    wire [31:0] vref_cmd_q16;
    reg test_passed=0;
    axi_system dut(.axi_clk(clk),.pll_locked(1'b1),.ext_reset_n(reset_n),
        .adc_sample_valid(valid),.voltage_raw_in(16'd0),.current_raw_in(16'd0),
        .adc_status_in(32'd0),.voltage_q16_in(voltage),.current_q16_in(current),
        .duty_q16_in(duty),.control_status_in(status),.vref_active_q16_in(32'd0),
        .protection_stop(1'b0),.axi_reset_n(axi_reset_n),
        .output_enable_cmd(output_enable_cmd),.vref_cmd_q16(vref_cmd_q16),.fault_clear_cmd(fault_clear_cmd));
    `define PS dut.axi_system_ARM_Processor_System_0_Inst
    reg [31:0] data;
    reg [1:0] resp;
    integer n,k;
    task automatic check_read(input [32:0] addr,input [31:0] expected);
        begin
            `PS.read32(addr,data,resp);
            if(resp!=0 || data!==expected) $fatal(1,"read %h got %h resp %b expected %h",addr,data,resp,expected);
        end
    endtask
    task automatic wait_dma(input bit error_expected);
        begin
            for(integer poll=0;poll<4000;poll++) begin
                `PS.read32(33'h80010034,data,resp);
                if(resp!=0) $fatal(1,"DMA status read failed");
                if(error_expected && (data & 32'h70)!=0) return;
                if(!error_expected && (data & 32'h70)!=0) $fatal(1,"DMA error status=%h",data);
                if(!error_expected && data[1] && data[12]) return;
            end
            $fatal(1,"DMA completion timeout status=%h",data);
        end
    endtask
    task automatic packet(input integer packet_id,input [31:0] destination);
        integer offset;
        reg [31:0] expected,actual;
        begin
            `PS.write32(33'h80010034,32'h1000);
            `PS.write32(33'h80010048,destination);
            `PS.write32(33'h8001004c,0);
            `PS.write32(33'h80010058,4096);
            `PS.write32(33'h8000002c,1);
            for(integer frame=0;frame<256;frame++) begin
                @(negedge clk); valid=1;
                voltage=32'h00110000+frame+packet_id*256;
                current=32'hffff0000-frame-packet_id*256;
                duty=32'h00008000+frame;
                status=32'ha5000000+frame;
                @(negedge clk); valid=0;
                repeat (11) @(negedge clk);
            end
            `PS.write32(33'h8000002c,0);
            wait_dma(0);
            for(integer word_index=0;word_index<1024;word_index++) begin
                case(word_index%4)
                    0: expected=32'h00110000+word_index/4+packet_id*256;
                    1: expected=32'hffff0000-word_index/4-packet_id*256;
                    2: expected=32'h00008000+word_index/4;
                    3: expected=32'ha5000000+word_index/4;
                endcase
                offset=destination-32'h10000000+word_index*4;
                actual={`PS.memory[offset+3],`PS.memory[offset+2],`PS.memory[offset+1],`PS.memory[offset]};
                if(actual!==expected) $fatal(1,"DDR mismatch packet=%0d word=%0d actual=%h expected=%h",packet_id,word_index,actual,expected);
            end
            check_read(33'h80000030,0);
            check_read(33'h80000024,0);
            $display("DMA_PACKET_PASS packet=%0d destination=%h",packet_id,destination);
        end
    endtask
    initial begin
        #100; reset_n=1;
        wait(axi_reset_n); repeat(50) @(posedge clk);
        check_read(33'h80000000,32'h41444331);
        check_read(33'h80000054,32'h43545231);
        check_read(33'h80000064,32'h464c5431);
        `PS.write32(33'h8000002c,2); repeat(60) @(posedge clk);
        `PS.write32(33'h80010030,4);
        for(n=0;n<100;n++) begin
            `PS.read32(33'h80010030,data,resp);
            if(!data[2]) break;
        end
        if(data[2]) $fatal(1,"DMA reset timeout");
        `PS.write32(33'h80010030,1);
        packet(0,32'h10000fc0);
        packet(1,32'h10002000);
        if(`PS.write_bytes!=8192) $fatal(1,"wrong byte count %d",`PS.write_bytes);
        `PS.read32(33'h80000028,data,resp);
        if(resp!=2) $fatal(1,"legacy destructive FIFO read must fail");
        if(output_enable_cmd!==0 || vref_cmd_q16!==0 || fault_clear_cmd!==0)
            $fatal(1,"DMA altered DCDC output defaults");
        // An unmapped GP0 access must terminate with DECERR.
        `PS.read32(33'h80020000,data,resp);
        if(resp!=3) $fatal(1,"expected unmapped DECERR got %b",resp);
        // Propagate an HP0 SLVERR into DMA status, then reset both the DMA
        // and acquisition FIFO before restarting at a fresh packet boundary.
        `PS.inject_error=1;
        `PS.write32(33'h80010034,32'h7000);
        `PS.write32(33'h80010048,32'h10004000);
        `PS.write32(33'h80010058,4096);
        `PS.write32(33'h8000002c,1);
        for(k=0;k<256;k++) begin
            @(negedge clk); valid=1; voltage=k; current=k; duty=0; status=0;
            @(negedge clk); valid=0;
            repeat(11) @(negedge clk);
        end
        `PS.write32(33'h8000002c,0);
        wait_dma(1);
        $display("DMA_SLVERR_PROPAGATION_PASS status=%h",data);
        `PS.write32(33'h80010030,4);
        for(n=0;n<100;n++) begin
            `PS.read32(33'h80010030,data,resp);
            if(!data[2]) break;
        end
        if(data[2]) $fatal(1,"DMA recovery reset timeout");
        `PS.write32(33'h8000002c,2);
        repeat(60) @(posedge clk);
        `PS.inject_error=0;
        `PS.write32(33'h80010030,1);
        packet(2,32'h10006000);
        $display("DMA_ERROR_RECOVERY_PASS");
        $display("ADC_DMA_ALL_TESTS_PASS bytes=%0d bursts=%0d",`PS.write_bytes,`PS.burst_count);
        test_passed=1; $finish;
    end
    initial begin #2000000; $fatal(1,"global timeout"); end
endmodule
