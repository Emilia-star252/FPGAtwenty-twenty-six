`timescale 1ns/1ps
module tb_rs485_pl;
    localparam integer BIT_TICKS=10, GAP_TICKS=1750;
    reg clk=0, rst_n=0, ps_rst_n=0, rx=1;
    always #500 clk=!clk;
    wire tx,de,remote,remote_enable,serial_clear,ps_clear;
    wire [31:0] remote_vref, ps_vref;
    wire ps_enable, ps_fault_clear;
    wire enabled = remote ? remote_enable : ps_enable;
    wire [31:0] vref = remote ? remote_vref : ps_vref;
    reg protection_stop=0;
    reg [31:0] faults=0;
    wire [31:0] status = faults | (remote ? 32'h200:0) | (enabled ? 3:0) | 32'h14;
    reg sample_valid=0;
    reg [31:0] voltage=32'h1234abcd, current=32'hffff8000, duty=32768;
    reg [7:0] awaddr=0;
    reg [31:0] wdata=0;
    reg awvalid=0,wvalid=0,bready=0;
    wire awready,wready,bvalid;
    wire [1:0] bresp;
    reg test_passed=0;
    rs485_dcdc_control #(.CLOCK_HZ(1000000),.BAUD(100000)) dut (
        .clk(clk),.rst_n(rst_n),.rx(rx),.tx(tx),.de(de),
        .sample_valid(sample_valid),.protection_stop(protection_stop),
        .voltage_q16(voltage),.current_q16(current),.duty_q16(duty),
        .control_status(status),.effective_vref_q16(vref),.active_vref_q16(vref),
        .effective_enable(enabled),.remote_mode(remote),.remote_enable(remote_enable),
        .remote_vref_q16(remote_vref),.fault_clear(serial_clear),.ps_command_clear(ps_clear));
    axi4lite_slave_v11 registers (
        .clk(clk),.rst_n(rst_n && ps_rst_n),.protection_stop(protection_stop || ps_clear),
        .fault_clear_cmd(ps_fault_clear),.output_enable_cmd(ps_enable),.vref_cmd_q16(ps_vref),
        .adc_sample_valid(sample_valid),.adc_status_in(0),.control_status_in(status),
        .vref_active_q16_in(vref),.s_axis_tdata(0),.s_axis_tkeep(4'hf),
        .s_axis_tlast(1'b0),.s_axis_tvalid(1'b0),.s_axis_tready(),
        .fifo_level_in(0),.fifo_drop_count_in(0),.fifo_ready_in(1'b1),
        .capture_enable(),.fifo_clear(),
        .s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
        .s_axi_wdata(wdata),.s_axi_wstrb(4'hf),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
        .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
        .s_axi_araddr(8'd0),.s_axi_arvalid(1'b0),.s_axi_arready(),
        .s_axi_rdata(),.s_axi_rresp(),.s_axi_rvalid(),.s_axi_rready(1'b0));

    task automatic ticks(input integer n); repeat(n) @(negedge clk); endtask
    task automatic ps_write(input [7:0] address,input [31:0] data,input [1:0] expected=0);
        @(negedge clk);awaddr=address;wdata=data;awvalid=1;wvalid=1;
        @(posedge clk); if (!awready || !wready) $fatal(1,"AXI not ready");
        @(negedge clk);awvalid=0;wvalid=0;
        wait(bvalid);#1;if(bresp!==expected)$fatal(1,"GP0 resp addr=%h got=%h want=%h",address,bresp,expected);
        @(negedge clk);bready=1;@(negedge clk);bready=0;
    endtask
    // Independent wire-level UART BFM, not another copy of the DUT receiver.
    byte received[0:8191];
    integer received_count=0, clear_count=0;
    always @(posedge clk) if(serial_clear)clear_count<=clear_count+1;
    always begin
        @(negedge tx);
        if(de)begin : monitor_byte
            reg [7:0] value;
            ticks(BIT_TICKS+BIT_TICKS/2);
            for(integer bit_number=0;bit_number<8;bit_number++)begin
                value[bit_number]=tx;ticks(BIT_TICKS);
            end
            if(tx!==1 || de!==1)$fatal(1,"TX stop bit/DE invalid");
            received[received_count]=value;received_count++;
            ticks(BIT_TICKS/2-1);
            if(!de)$fatal(1,"DE released before full stop bit");
        end
    end
    function automatic [15:0] crc_byte(input [15:0] c,input [7:0] b);
        reg [15:0] v;v=c^b;
        for(integer bit_number=0;bit_number<8;bit_number++)
            v=v[0]?((v>>1)^16'ha001):(v>>1);
        return v;
    endfunction
    byte request[0:7];
    integer response_start;
    bit mutate_snapshot=0;
    task automatic send_byte(input [7:0] b,input bit bad_stop=0);
        rx=0;ticks(BIT_TICKS);
        for(integer bit_number=0;bit_number<8;bit_number++)begin rx=b[bit_number];ticks(BIT_TICKS);end
        rx=!bad_stop;ticks(BIT_TICKS);rx=1;
    endtask
    task automatic make_request(input [7:0] station,input [7:0] fn,
                                input [15:0] address,input [15:0] data);
        reg [15:0] crc;
        request[0]=station;request[1]=fn;request[2]=address[15:8];request[3]=address[7:0];
        request[4]=data[15:8];request[5]=data[7:0];crc=16'hffff;
        for(integer n=0;n<6;n++)crc=crc_byte(crc,request[n]);
        request[6]=crc[7:0];request[7]=crc[15:8];
    endtask
    task automatic send_request(input bit corrupt=0,input bit split_frame=0);
        ticks(GAP_TICKS+20);response_start=received_count;
        for(integer n=0;n<8;n++)begin
            send_byte(request[n] ^ ((corrupt && n==7)?8'h80:0));
            if(split_frame && n==3)ticks(800);
        end
    endtask
    task automatic get_response(input integer length);
        reg [15:0] crc;integer timeout_cycles;
        timeout_cycles=0;
        while(!de && timeout_cycles<3000)begin ticks(1);timeout_cycles++;end
        if(!de)$fatal(1,"Missing response fn=%h addr=%h%h",request[1],request[2],request[3]);
        if(mutate_snapshot)begin
            voltage=32'h56781234;current=32'h01020304;duty=65535;
            sample_valid=1;ticks(1);sample_valid=0;mutate_snapshot=0;
        end
        timeout_cycles=0;
        while(de && timeout_cycles<6000)begin ticks(1);timeout_cycles++;end
        ticks(2);
        if(de || received_count-response_start!=length)
            $fatal(1,"Response length %0d want %0d",received_count-response_start,length);
        crc=16'hffff;for(integer n=0;n<length;n++)crc=crc_byte(crc,received[response_start+n]);
        if(crc!=0)$fatal(1,"Reply CRC invalid");
        if(received[response_start]!=1)$fatal(1,"Wrong reply station");
    endtask
    task automatic no_response;
        ticks(GAP_TICKS+2000);
        if(de || received_count!=response_start)$fatal(1,"Unexpected response");
    endtask
    task automatic write_word(input [15:0] address,input [15:0] data,input [7:0] exception=0);
        make_request(1,6,address,data);send_request();get_response(exception==0?8:5);
        if(exception!=0)begin
            if(received[response_start+1]!=8'h86 || received[response_start+2]!=exception)
                $fatal(1,"Wrong exception at %h",address);
        end else for(integer n=0;n<6;n++)
            if(received[response_start+n]!=request[n])$fatal(1,"FC06 echo mismatch");
    endtask
    function automatic [15:0] response_word(input integer n);
        return {received[response_start+3+2*n],received[response_start+4+2*n]};
    endfunction
    initial begin
        ticks(6);rst_n=1;ps_rst_n=1;ticks(6);
        if(remote || enabled || de || tx!==1)$fatal(1,"Unsafe reset defaults");
        sample_valid=1;ticks(1);sample_valid=0;
        ps_write('h44,12*65536);ps_write('h40,1);
        if(!enabled || vref!=12*65536)$fatal(1,"Legacy GP0 behavior changed");
        write_word('h100,1,6); // cannot transfer ownership while running
        write_word('h102,0);ticks(3);
        if(enabled || ps_vref!=0)$fatal(1,"Serial STOP failed in GP0 mode");
        write_word('h100,1);
        ps_write('h44,24*65536,2);ps_write('h40,1,2);ps_write('h60,1,2);
        ps_write('h2c,1); // capture controls are independent of command ownership
        write_word('h102,1,6);write_word('h101,'h4001,3);write_word('h999,1,2);
        write_word('h101,'h1800);write_word('h102,1);
        if(!remote || !enabled || vref!=24*65536)$fatal(1,"PL remote start failed");
        // PS can stay in reset while serial reads and control keep working.
        ps_rst_n=0;ticks(10);
        make_request(1,4,0,16);send_request();mutate_snapshot=1;get_response(37);
        if(response_word(0)!=='h5253 || response_word(1)!=1 || response_word(4)!=='h1800 ||
           {response_word(6),response_word(7)}!==32'h1234abcd ||
           {response_word(8),response_word(9)}!==32'hffff8000 ||
           {response_word(10),response_word(11)}!==32768)
            $fatal(1,"Snapshot contents/endian mismatch");
        if(!enabled)$fatal(1,"PS reset stopped pure PL control");ps_rst_n=1;
        write_word('h100,0,6);
        make_request(1,6,'h101,'h0c00);send_request(1);no_response();
        if(vref!=24*65536 || dut.crc_errors!=1)$fatal(1,"CRC rejection failed");
        make_request(2,6,'h101,'h0c00);send_request();no_response();
        if(vref!=24*65536)$fatal(1,"Foreign station modified controls");
        make_request(1,6,'h101,'h0c00);send_request(0,1);no_response();
        if(vref!=24*65536 || dut.frame_errors==0)$fatal(1,"t1.5 rejection failed");
        make_request(0,6,'h101,'h0c00);send_request();no_response();
        if(vref!=12*65536)$fatal(1,"Broadcast write failed");
        make_request(0,3,0,1);send_request();no_response();
        make_request(1,'h10,0,1);send_request();get_response(5);
        if(received[response_start+1]!=8'h90 || received[response_start+2]!=1)$fatal(1,"Unsupported FC");
        make_request(1,3,0,0);send_request();get_response(5);
        if(received[response_start+2]!=3)$fatal(1,"Quantity zero accepted");
        make_request(1,3,15,2);send_request();get_response(5);
        if(received[response_start+2]!=2)$fatal(1,"Invalid read address accepted");
        // Oversized and UART-framing-error frames are discarded without writes.
        ticks(GAP_TICKS+20);response_start=received_count;
        for(integer n=0;n<258;n++)send_byte(n[7:0]);no_response();
        ticks(GAP_TICKS+20);response_start=received_count;send_byte(8'h55,1);no_response();
        protection_stop=1;faults='h80;ticks(3);
        if(enabled || vref!=0)$fatal(1,"Trip did not invalidate serial command");
        protection_stop=0;write_word('h101,'h0c00);write_word('h102,1,6);
        write_word('h103,1);
        if(clear_count!=1 || enabled || vref!=0)$fatal(1,"Clear must not restart");
        faults=0;write_word('h102,1,6);write_word('h101,'h4000);write_word('h102,1);
        if(!enabled || vref!=64*65536)$fatal(1,"64 V boundary failed");
        write_word('h102,0);write_word('h100,0);ticks(3);
        if(remote || enabled || ps_vref!=0)$fatal(1,"Old GP0 command revived");
        ps_write('h40,1,2);ps_write('h44,6*65536);ps_write('h40,1);
        if(!enabled || vref!=6*65536)$fatal(1,"GP0 handback failed");
        write_word('h102,0);write_word('h100,1);write_word('h101,'h0c00);write_word('h102,1);
        rst_n=0;ticks(2);
        if(enabled || remote || de || tx!==1)$fatal(1,"Reset failed to stop serial controls");
        rst_n=1;ticks(20);if(enabled)$fatal(1,"Reset restored stale serial command");
        test_passed=1;
        $display("RS485_PL_TEST_PASS: wire UART/DE/CRC/t1.5/t3.5, FC03/04/06, broadcast, bad frames, coherent values, GP0 ownership, trip/clear/reset, PS held reset");
        $finish;
    end
    initial begin #1000000000;$fatal(1,"RS485 test timeout");end
endmodule
