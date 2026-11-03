`timescale 1ns/1ps
module uart_format_case #(parameter PARITY=1, STOP_BITS=1)(output reg done=0);
    reg clk=0,rst_n=0,rx=1,tx_enable=0,tx_valid=0;
    reg [7:0] tx_data=8'ha6;
    wire tx,de,ready,tx_busy,rx_valid,rx_error,rx_busy;
    wire [7:0] rx_data;
    localparam BIT_TICKS=10;
    always #500 clk=!clk;
    rs485_uart #(.CLOCK_HZ(1000000),.BAUD(100000),.PARITY(PARITY),.STOP_BITS(STOP_BITS)) dut(
        .clk(clk),.rst_n(rst_n),.rx(rx),.tx(tx),.de(de),.tx_enable(tx_enable),
        .tx_valid(tx_valid),.tx_data(tx_data),.tx_ready(ready),.tx_busy(tx_busy),
        .rx_valid(rx_valid),.rx_error(rx_error),.rx_data(rx_data),.rx_busy(rx_busy));
    task automatic ticks(input integer n);repeat(n)@(negedge clk);endtask
    integer valid_count=0,error_count=0;
    always @(posedge clk)begin
        if(rx_valid)begin if(rx_data!==8'ha6)$fatal(1,"UART format RX data");valid_count++;end
        if(rx_error)error_count++;
    end
    task automatic receive_character(input bit corrupt_parity);
        rx=0;ticks(BIT_TICKS);
        for(integer b=0;b<8;b++)begin rx=tx_data[b];ticks(BIT_TICKS);end
        if(PARITY!=0)begin rx=(^tx_data)^(PARITY==2)^corrupt_parity;ticks(BIT_TICKS);end
        rx=1;ticks(BIT_TICKS*STOP_BITS+20);
    endtask
    initial begin
        ticks(4);rst_n=1;ticks(4);receive_character(0);
        if(valid_count!=1 || error_count!=0)$fatal(1,"UART format receive failed");
        if(PARITY!=0)begin
            receive_character(1);
            if(valid_count!=1 || error_count!=1)$fatal(1,"Parity error accepted");
        end
        tx_enable=1;tx_valid=1;@(negedge clk);tx_valid=0;
        if(tx!==0 || !de)$fatal(1,"TX did not start");
        ticks(BIT_TICKS+BIT_TICKS/2);
        for(integer b=0;b<8;b++)begin
            if(tx!==tx_data[b])$fatal(1,"UART format TX data");ticks(BIT_TICKS);
        end
        if(PARITY!=0)begin
            if(tx!==((^tx_data)^(PARITY==2)))$fatal(1,"TX parity");ticks(BIT_TICKS);
        end
        repeat(STOP_BITS)begin if(tx!==1)$fatal(1,"TX stop bits");ticks(BIT_TICKS);end
        wait(!tx_busy);tx_enable=0;ticks(2);done=1;
    end
endmodule
module tb_rs485_uart_formats;
    wire even_done,odd_done,two_stop_done;
    reg test_passed=0;
    uart_format_case #(.PARITY(1)) even_test(even_done);
    uart_format_case #(.PARITY(2)) odd_test(odd_done);
    uart_format_case #(.PARITY(0),.STOP_BITS(2)) two_stop_test(two_stop_done);
    initial begin
        wait(even_done && odd_done && two_stop_done);test_passed=1;
        $display("RS485_UART_FORMATS_PASS: 8E1, 8O1, 8N2, parity errors");$finish;
    end
    initial begin #2000000;$fatal(1,"UART format timeout");end
endmodule
