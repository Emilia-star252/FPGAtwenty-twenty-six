`timescale 1ns/1ps
// Half-duplex UART. DE is owned by the RTU frame engine, not by individual bytes.
module rs485_uart #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200,
    parameter integer PARITY = 0, // 0=none, 1=even, 2=odd
    parameter integer STOP_BITS = 1
)(
    input wire clk, rst_n, rx,
    input wire tx_enable, tx_valid,
    input wire [7:0] tx_data,
    output wire tx, de, tx_ready,
    output reg tx_busy,
    output reg [7:0] rx_data,
    output reg rx_valid, rx_error, rx_busy
);
    localparam integer BIT_CYCLES = (CLOCK_HZ + BAUD/2) / BAUD;
    localparam integer CHAR_BITS = 9 + STOP_BITS + (PARITY != 0);
    // Only the pad -> rx_meta path is asynchronous; rx_meta -> rx_sync is timed.
    (* ASYNC_REG = "TRUE" *) reg rx_meta, rx_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin rx_meta <= 1; rx_sync <= 1; end
        else begin rx_meta <= rx; rx_sync <= rx_meta; end

    reg [11:0] tx_shift;
    reg [3:0] tx_left;
    reg [31:0] tx_count;
    wire parity_bit = (^tx_data) ^ (PARITY == 2);
    assign de = rst_n && tx_enable;
    assign tx = (rst_n && tx_busy) ? tx_shift[0] : 1'b1;
    assign tx_ready = tx_enable && !tx_busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_busy <= 0; tx_shift <= 12'hfff; tx_left <= 0; tx_count <= 0;
        end else if (!tx_busy) begin
            if (tx_valid && tx_enable) begin
                tx_shift <= (PARITY == 0) ? {3'b111, tx_data, 1'b0}
                                         : {2'b11, parity_bit, tx_data, 1'b0};
                tx_busy <= 1; tx_left <= CHAR_BITS; tx_count <= BIT_CYCLES-1;
            end
        end else if (tx_count != 0) tx_count <= tx_count - 1'b1;
        else begin
            tx_count <= BIT_CYCLES-1;
            tx_shift <= {1'b1, tx_shift[11:1]};
            tx_left <= tx_left - 1'b1;
            if (tx_left == 1) tx_busy <= 0;
        end
    end

    localparam RX_IDLE=0, RX_START=1, RX_DATA=2, RX_PARITY=3, RX_STOP=4;
    reg [2:0] rx_state, rx_bit;
    reg [7:0] rx_shift;
    reg [31:0] rx_count;
    reg bad_frame, second_stop;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE; rx_bit <= 0; rx_shift <= 0; rx_count <= 0;
            bad_frame <= 0; second_stop <= 0;
            rx_data <= 0; rx_valid <= 0; rx_error <= 0; rx_busy <= 0;
        end else begin
            rx_valid <= 0; rx_error <= 0;
            if (tx_enable) begin rx_state <= RX_IDLE; rx_busy <= 0; end
            else case (rx_state)
                RX_IDLE: if (!rx_sync) begin
                    rx_busy <= 1; rx_state <= RX_START;
                    rx_count <= BIT_CYCLES/2-1; bad_frame <= 0;
                end
                RX_START: if (rx_count != 0) rx_count <= rx_count-1'b1;
                else if (rx_sync) begin rx_state <= RX_IDLE; rx_busy <= 0; end
                else begin rx_state <= RX_DATA; rx_bit <= 0; rx_count <= BIT_CYCLES-1; end
                RX_DATA: if (rx_count != 0) rx_count <= rx_count-1'b1;
                else begin
                    rx_shift[rx_bit] <= rx_sync; rx_count <= BIT_CYCLES-1;
                    if (rx_bit == 7) begin
                        rx_state <= (PARITY == 0) ? RX_STOP : RX_PARITY;
                        second_stop <= 0;
                    end else rx_bit <= rx_bit+1'b1;
                end
                RX_PARITY: if (rx_count != 0) rx_count <= rx_count-1'b1;
                else begin
                    bad_frame <= (rx_sync != ((^rx_shift) ^ (PARITY == 2)));
                    rx_state <= RX_STOP; rx_count <= BIT_CYCLES-1;
                end
                RX_STOP: if (rx_count != 0) rx_count <= rx_count-1'b1;
                else if (STOP_BITS == 2 && !second_stop) begin
                    bad_frame <= bad_frame || !rx_sync;
                    second_stop <= 1; rx_count <= BIT_CYCLES-1;
                end else begin
                    rx_busy <= 0; rx_state <= RX_IDLE; rx_data <= rx_shift;
                    rx_valid <= !bad_frame && rx_sync;
                    rx_error <= bad_frame || !rx_sync;
                end
                default: begin rx_state <= RX_IDLE; rx_busy <= 0; end
            endcase
        end
    end
endmodule
