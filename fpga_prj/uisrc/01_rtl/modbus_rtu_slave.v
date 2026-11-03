`timescale 1ns/1ps
// Bounded RTU server: FC03/04 (1..16 words) and FC06, broadcast FC06 included.
// Register requests/responses use a one-cycle pulse, all in the UART clock domain.
module modbus_rtu_slave #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200,
    parameter integer PARITY = 0,
    parameter integer STOP_BITS = 1,
    parameter [7:0] STATION = 1
)(
    input wire clk, rst_n, rx,
    output wire tx, de,
    output reg frame_start, req_valid, req_write,
    output reg [15:0] req_address, req_data,
    input wire rsp_valid,
    input wire [15:0] rsp_data,
    input wire [7:0] rsp_exception,
    output reg [31:0] good_frames, crc_errors, frame_errors
);
    localparam integer BIT_CYCLES = (CLOCK_HZ+BAUD/2)/BAUD;
    localparam integer CHAR_BITS = 9+STOP_BITS+(PARITY != 0);
    localparam integer T15 = (BAUD > 19200) ? (64'd1*CLOCK_HZ*750+999999)/1000000
                                           : (BIT_CYCLES*CHAR_BITS*3+1)/2;
    localparam integer T35 = (BAUD > 19200) ? (64'd1*CLOCK_HZ*1750+999999)/1000000
                                           : (BIT_CYCLES*CHAR_BITS*7+1)/2;
    // UART reports a byte at the centre of its last stop bit. Include the
    // remaining half stop bit when measuring silence after that byte.
    localparam integer IDLE15 = T15 + BIT_CYCLES/2;
    localparam integer IDLE35 = T35 + BIT_CYCLES/2;
    localparam RX=0, CHECK=1, READ_REQ=2, READ_WAIT=3, WRITE_REQ=4,
               WRITE_WAIT=5, CRC=6, LEAD=7, SEND=8, WAIT_BYTE=9, TAIL=10;
    reg [3:0] state;
    reg [7:0] rx_buf[0:255], tx_buf[0:36];
    reg [8:0] rx_length;
    reg [5:0] payload_length, tx_length, tx_index, crc_index;
    reg [4:0] word_count, word_index;
    reg [15:0] base_address, rx_crc, tx_crc;
    reg [31:0] silence, guard_count;
    reg invalid_frame, old_rx_busy, broadcast;
    wire [7:0] byte_rx;
    wire byte_valid, byte_error, rx_busy, tx_ready, tx_busy;
    // Register frame DE ownership: decoding a binary FSM could glitch at 7->8.
    reg tx_enable;
    rs485_uart #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD), .PARITY(PARITY),
                 .STOP_BITS(STOP_BITS)) uart (
        .clk(clk), .rst_n(rst_n), .rx(rx), .tx(tx), .de(de),
        .tx_enable(tx_enable), .tx_valid(state == SEND), .tx_data(tx_buf[tx_index]),
        .tx_ready(tx_ready), .tx_busy(tx_busy), .rx_data(byte_rx),
        .rx_valid(byte_valid), .rx_error(byte_error), .rx_busy(rx_busy));

    function [15:0] crc16;
        input [15:0] old_crc; input [7:0] data;
        reg [15:0] value; integer k;
        begin
            value = old_crc ^ {8'd0, data};
            for (k=0; k<8; k=k+1)
                value = value[0] ? ((value >> 1) ^ 16'ha001) : (value >> 1);
            crc16 = value;
        end
    endfunction
    wire [15:0] crc_next = crc16(tx_crc, tx_buf[crc_index]);
    task exception_reply;
        input [7:0] code;
        begin
            tx_buf[0] <= STATION; tx_buf[1] <= rx_buf[1] | 8'h80;
            tx_buf[2] <= code; payload_length <= 3;
            crc_index <= 0; tx_crc <= 16'hffff; state <= CRC;
        end
    endtask
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RX; tx_enable <= 0; rx_length <= 0; rx_crc <= 16'hffff;
            silence <= 0; invalid_frame <= 0; old_rx_busy <= 0;
            broadcast <= 0; good_frames <= 0; crc_errors <= 0; frame_errors <= 0;
            frame_start <= 0; req_valid <= 0; req_write <= 0;
            req_address <= 0; req_data <= 0;
            payload_length <= 0; tx_length <= 0; tx_index <= 0; crc_index <= 0;
            tx_crc <= 16'hffff; word_count <= 0; word_index <= 0;
            base_address <= 0; guard_count <= 0;
        end else begin
            frame_start <= 0; req_valid <= 0; old_rx_busy <= rx_busy;
            if (state == RX) begin
                if (rx_busy || byte_valid || byte_error) silence <= 0;
                else if (silence < IDLE35) silence <= silence+1'b1;
                // A late next character invalidates a frame; normal end-of-frame
                // silence must NOT be treated as an inter-character error.
                if (rx_busy && !old_rx_busy && rx_length != 0 && silence >= IDLE15)
                    invalid_frame <= 1;
                if (byte_error) invalid_frame <= 1;
                if (byte_valid) begin
                    if (rx_length < 256) begin
                        rx_buf[rx_length[7:0]] <= byte_rx;
                        rx_length <= rx_length+1'b1;
                        rx_crc <= crc16(rx_crc, byte_rx);
                    end else invalid_frame <= 1;
                end else if (!rx_busy && silence == IDLE35 &&
                             (rx_length != 0 || invalid_frame)) begin
                    if (invalid_frame || rx_length < 4) begin
                        frame_errors <= frame_errors+1'b1;
                        rx_length <= 0; invalid_frame <= 0; rx_crc <= 16'hffff;
                    end else if (rx_crc != 0) begin
                        crc_errors <= crc_errors+1'b1;
                        rx_length <= 0; rx_crc <= 16'hffff;
                    end else if (rx_buf[0] != STATION && rx_buf[0] != 0) begin
                        rx_length <= 0; rx_crc <= 16'hffff;
                    end else begin
                        broadcast <= (rx_buf[0] == 0);
                        good_frames <= good_frames+1'b1; frame_start <= 1;
                        state <= CHECK;
                    end
                end
            end else case (state)
                CHECK: begin
                    base_address <= {rx_buf[2],rx_buf[3]}; word_index <= 0;
                    if (broadcast && rx_buf[1] != 6) begin
                        state <= RX; rx_length <= 0; rx_crc <= 16'hffff;
                    end else if (rx_buf[1] != 3 && rx_buf[1] != 4 && rx_buf[1] != 6)
                        exception_reply(1);
                    else if (rx_length != 8) begin
                        if (broadcast) begin state <= RX; rx_length <= 0; rx_crc <= 16'hffff; end
                        else exception_reply(3);
                    end else if (rx_buf[1] == 6) state <= WRITE_REQ;
                    else if ({rx_buf[4],rx_buf[5]} == 0 || {rx_buf[4],rx_buf[5]} > 16 ||
                             ({1'b0,rx_buf[2],rx_buf[3]} + {1'b0,rx_buf[4],rx_buf[5]}) > 17'h10000)
                        exception_reply(3);
                    else begin
                        word_count <= rx_buf[5][4:0];
                        tx_buf[0] <= STATION; tx_buf[1] <= rx_buf[1];
                        tx_buf[2] <= rx_buf[5] << 1;
                        payload_length <= 3+(rx_buf[5] << 1); state <= READ_REQ;
                    end
                end
                READ_REQ: begin
                    req_valid <= 1; req_write <= 0;
                    req_address <= base_address + word_index; state <= READ_WAIT;
                end
                READ_WAIT: if (rsp_valid) begin
                    if (rsp_exception != 0) exception_reply(rsp_exception);
                    else begin
                        tx_buf[3+(word_index<<1)] <= rsp_data[15:8];
                        tx_buf[4+(word_index<<1)] <= rsp_data[7:0];
                        if (word_index+1 == word_count) begin
                            crc_index <= 0; tx_crc <= 16'hffff; state <= CRC;
                        end else begin word_index <= word_index+1'b1; state <= READ_REQ; end
                    end
                end
                WRITE_REQ: begin
                    req_valid <= 1; req_write <= 1; req_address <= base_address;
                    req_data <= {rx_buf[4],rx_buf[5]}; state <= WRITE_WAIT;
                end
                WRITE_WAIT: if (rsp_valid) begin
                    if (broadcast) begin state <= RX; rx_length <= 0; rx_crc <= 16'hffff; end
                    else if (rsp_exception != 0) exception_reply(rsp_exception);
                    else begin
                        for (k=0; k<6; k=k+1) tx_buf[k] <= rx_buf[k];
                        payload_length <= 6; crc_index <= 0; tx_crc <= 16'hffff; state <= CRC;
                    end
                end
                CRC: begin
                    tx_crc <= crc_next;
                    if (crc_index+1 == payload_length) begin
                        tx_buf[payload_length] <= crc_next[7:0];
                        tx_buf[payload_length+1] <= crc_next[15:8];
                        tx_length <= payload_length+2; tx_index <= 0;
                        guard_count <= BIT_CYCLES-1; tx_enable <= 1; state <= LEAD;
                    end else crc_index <= crc_index+1'b1;
                end
                LEAD: if (guard_count != 0) guard_count <= guard_count-1'b1;
                      else state <= SEND;
                SEND: if (tx_ready) state <= WAIT_BYTE;
                WAIT_BYTE: if (!tx_busy) begin
                    if (tx_index+1 == tx_length) begin
                        guard_count <= BIT_CYCLES-1; state <= TAIL;
                    end else begin tx_index <= tx_index+1'b1; state <= SEND; end
                end
                TAIL: if (guard_count != 0) guard_count <= guard_count-1'b1;
                else begin
                    state <= RX; tx_enable <= 0; rx_length <= 0; invalid_frame <= 0;
                    rx_crc <= 16'hffff; silence <= 0;
                end
                default: begin state <= RX; tx_enable <= 0; end
            endcase
        end
    end
endmodule
