`timescale 1ns/1ps
// Uses the AXI/ADC/PLL/CWC models from tb_protection; the tested DCDC/UART/RTU,
// PI/PWM, ADC serial driver and command-register bank are all production RTL.
module tb_rs485_top;
    localparam integer BIT_TICKS=100, GAP_TICKS=175000;
    reg clk=0,rst_n=0,rx=1;
    always #5 clk=!clk;
    reg signed [15:0] voltage_raw=1966,current_raw=3277;
    wire busy,da,db,cs,sclk,adc_reset,convst,h1,l1,h2,l2,tx,de;
    integer samples=0;
    reg test_passed=0;
    DCDC_top #(.ADC_RESET_CYCLES(8),.V_SOFT_START_MS(1),
               .V_KP_Q16(0),.V_KI_Q16(0),.I_KP_Q16(0),.I_KI_Q16(0),
               .RS485_BAUD(1000000)) dut(
        .clk_in(clk),.rst_n(rst_n),.ad_busy(busy),.ad_dout_a(da),.ad_dout_b(db),
        .ad_cs(cs),.ad_sclk(sclk),.ad_rst(adc_reset),.ad_convsta(convst),
        .ad_convstb(),.ad_range(),.card_power_en(),.O_hdmi_tx_p(),.O_hdmi_clk_p(),
        .pwm1_h(h1),.pwm1_l(l1),.pwm2_h(h2),.pwm2_l(l2),
        .I_rs485_rx(rx),.O_rs485_tx(tx),.O_rs485_de(de));
    protection_adc_model adc(convst,cs,sclk,adc_reset,voltage_raw,current_raw,busy,da,db);
    always @(posedge dut.adc_valid)samples++;
    always @(posedge clk)begin
        #1;
        if(!dut.pwm_output_enable && {h1,l1,h2,l2}!==0)$fatal(1,"RS485 top: gates not off");
        if(dut.pwm_output_enable && (h1===l1 || {h1,l1}!=={h2,l2}))$fatal(1,"RS485 top: PWM mapping");
    end
    task automatic ticks(input integer n);repeat(n)@(negedge clk);endtask
    byte received[0:255];integer count=0,start_count;
    always begin
        @(negedge tx);
        if(de)begin
            reg [7:0] b;ticks(BIT_TICKS+BIT_TICKS/2);
            for(integer n=0;n<8;n++)begin b[n]=tx;ticks(BIT_TICKS);end
            if(!tx || !de)$fatal(1,"RS485 top TX framing");
            received[count]=b;count++;
        end
    end
    function automatic [15:0] crc_byte(input [15:0] c,input [7:0] b);
        reg [15:0] v;v=c^b;
        for(integer n=0;n<8;n++)v=v[0]?((v>>1)^16'ha001):(v>>1);
        return v;
    endfunction
    task automatic send_byte(input [7:0] b);
        rx=0;ticks(BIT_TICKS);
        for(integer n=0;n<8;n++)begin rx=b[n];ticks(BIT_TICKS);end
        rx=1;ticks(BIT_TICKS);
    endtask
    task automatic request(input [7:0] fn,input [15:0] address,input [15:0] value,
                           input [7:0] exception=0);
        byte bytes[0:7];reg [15:0] crc;integer timeout_cycles,expected_length;
        ticks(GAP_TICKS+20);start_count=count;
        bytes[0]=1;bytes[1]=fn;bytes[2]=address[15:8];bytes[3]=address[7:0];
        bytes[4]=value[15:8];bytes[5]=value[7:0];crc=16'hffff;
        for(integer n=0;n<6;n++)crc=crc_byte(crc,bytes[n]);
        bytes[6]=crc[7:0];bytes[7]=crc[15:8];
        for(integer n=0;n<8;n++)send_byte(bytes[n]);
        timeout_cycles=0;
        while(!de && timeout_cycles<200000)begin ticks(1);timeout_cycles++;end
        if(!de)$fatal(1,"RS485 top missing response");
        timeout_cycles=0;
        while(de && timeout_cycles<50000)begin ticks(1);timeout_cycles++;end
        ticks(2);expected_length=(exception!=0)?5:((fn==6)?8:(5+2*value));
        if(de || count-start_count!=expected_length)$fatal(1,"RS485 top response length");
        crc=16'hffff;for(integer n=start_count;n<count;n++)crc=crc_byte(crc,received[n]);
        if(crc!=0)$fatal(1,"RS485 top reply CRC");
        if(exception!=0 && (received[start_count+1]!=(fn|8'h80) || received[start_count+2]!=exception))
            $fatal(1,"RS485 top exception mismatch");
        if(exception==0 && received[start_count+1]!=fn)
            $fatal(1,"Unexpected RTU exception fn=%h code=%h",received[start_count+1],received[start_count+2]);
    endtask
    integer before_stop;
    initial begin
        force dut.axi_reset_n=0; // No PS/AXI command service for the serial tests.
        ticks(5);rst_n=1;repeat(5)@(posedge dut.adc_valid);ticks(5);
        if(dut.pwm_output_enable)$fatal(1,"RS485 top reset output ON");
        request(6,'h100,1);request(6,'h101,'h0c00);request(6,'h102,1);
        repeat(20)@(posedge dut.adc_valid);ticks(5);
        if(!dut.pwm_output_enable || dut.vref_cmd_q16!=12*65536 || dut.pwm_active_counts!=1333)
            $fatal(1,"RS485 top pure-PL 12 V/PWM start failed");
        // Trip the real production protection while a serial read is replying.
        fork
            request(4,0,16);
            begin wait(de);current_raw=20000;repeat(3)@(posedge dut.adc_valid);end
        join
        if(!dut.overcurrent_fault || dut.pwm_output_enable || dut.output_enable_cmd || dut.vref_cmd_q16!=0)
            $fatal(1,"RS485 traffic delayed protection");
        request(6,'h103,1);
        if(!dut.overcurrent_fault)$fatal(1,"Unsafe sample cleared fault");
        current_raw=3277;repeat(3)@(posedge dut.adc_valid);request(6,'h103,1);
        if(dut.overcurrent_fault || dut.pwm_output_enable)$fatal(1,"Safe clear/restart interlock");
        request(6,'h102,1,6);request(6,'h101,'h1800);request(6,'h102,1);
        repeat(20)@(posedge dut.adc_valid);ticks(5);
        if(!dut.pwm_output_enable || dut.pwm_active_counts!=2000)$fatal(1,"RS485 top 24 V/PWM restart");
        request(6,'h101,'h4001,3);
        before_stop=samples;request(6,'h102,0);
        if(dut.pwm_output_enable || {h1,l1,h2,l2}!==0 || samples<=before_stop)
            $fatal(1,"Serial STOP stopped sampling or left gates on");
        request(6,'h100,0);release dut.axi_reset_n;ticks(10);
        if(dut.output_enable_cmd || dut.vref_cmd_q16!=0)$fatal(1,"Old PS command revived");
        dut.u_axi_system.write_command('h44,12*65536);
        dut.u_axi_system.write_command('h40,1);repeat(20)@(posedge dut.adc_valid);ticks(5);
        if(!dut.pwm_output_enable)$fatal(1,"GP0 handback failed at full top");
        rst_n=0;ticks(4);if({h1,l1,h2,l2}!==0 || de)$fatal(1,"Reset failed at full top");
        test_passed=1;
        $display("RS485_TOP_TEST_PASS: PS reset held, actual ADC/PI/PWM start/stop, overcurrent during serial TX, safe fault clear, fresh restart, GP0 handback");
        $finish;
    end
    initial begin #100000000;$fatal(1,"RS485 top timeout");end
endmodule
