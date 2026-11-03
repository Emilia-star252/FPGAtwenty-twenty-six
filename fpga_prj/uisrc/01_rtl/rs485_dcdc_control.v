`timescale 1ns/1ps
// Pure-PL RS485 control. No dependency on the PS reset, software, DDR or HP ports.
module rs485_dcdc_control #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200,
    parameter integer PARITY = 0,
    parameter integer STOP_BITS = 1,
    parameter [7:0] STATION = 1
)(
    input wire clk, rst_n, rx,
    output wire tx, de,
    input wire sample_valid, protection_stop,
    input wire signed [31:0] voltage_q16, current_q16,
    input wire [31:0] duty_q16, control_status, effective_vref_q16, active_vref_q16,
    input wire effective_enable,
    output reg remote_mode, remote_enable,
    output reg [31:0] remote_vref_q16,
    output reg fault_clear,
    output wire ps_command_clear
);
    wire frame_start, req_valid, req_write, rsp_valid;
    wire [15:0] req_address, req_data;
    reg [15:0] rsp_data;
    reg [7:0] rsp_exception;
    reg response_valid, discard_ps;
    wire [31:0] good_frames, crc_errors, frame_errors;
    assign rsp_valid = response_valid;
    assign ps_command_clear = remote_mode || discard_ps;
    modbus_rtu_slave #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD), .PARITY(PARITY),
        .STOP_BITS(STOP_BITS), .STATION(STATION)) rtu (
        .clk(clk), .rst_n(rst_n), .rx(rx), .tx(tx), .de(de),
        .frame_start(frame_start), .req_valid(req_valid), .req_write(req_write),
        .req_address(req_address), .req_data(req_data), .rsp_valid(rsp_valid),
        .rsp_data(rsp_data), .rsp_exception(rsp_exception), .good_frames(good_frames),
        .crc_errors(crc_errors), .frame_errors(frame_errors));

    reg signed [31:0] last_voltage, last_current;
    reg [31:0] last_duty, sample_count;
    reg [15:0] snapshot[0:15];
    wire blocked = protection_stop || ((control_status & 32'h00000188) != 0);
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_voltage <= 0; last_current <= 0; last_duty <= 0; sample_count <= 0;
            remote_mode <= 0; remote_enable <= 0; remote_vref_q16 <= 0;
            fault_clear <= 0; discard_ps <= 0; response_valid <= 0;
            rsp_data <= 0; rsp_exception <= 0;
            for (k=0; k<16; k=k+1) snapshot[k] <= 0;
        end else begin
            fault_clear <= 0; discard_ps <= 0; response_valid <= 0;
            if (sample_valid) begin
                last_voltage <= voltage_q16; last_current <= current_q16;
                last_duty <= duty_q16; sample_count <= sample_count+1'b1;
            end
            // All FC03/04 words come from the same completed-sample snapshot.
            if (frame_start) begin
                snapshot[0] <= 16'h5253; snapshot[1] <= {15'd0,remote_mode};
                snapshot[2] <= control_status[15:0]; snapshot[3] <= control_status[31:16];
                snapshot[4] <= effective_vref_q16[23:8];
                snapshot[5] <= active_vref_q16[23:8];
                snapshot[6] <= last_voltage[31:16]; snapshot[7] <= last_voltage[15:0];
                snapshot[8] <= last_current[31:16]; snapshot[9] <= last_current[15:0];
                snapshot[10] <= last_duty[31:16]; snapshot[11] <= last_duty[15:0];
                snapshot[12] <= sample_count[31:16]; snapshot[13] <= sample_count[15:0];
                snapshot[14] <= crc_errors[15:0]; snapshot[15] <= frame_errors[15:0];
            end
            if (req_valid) begin
                response_valid <= 1; rsp_exception <= 0; rsp_data <= 0;
                if (!req_write) begin
                    if (req_address < 16) rsp_data <= snapshot[req_address[3:0]];
                    else case (req_address)
                        16'h0100: rsp_data <= {15'd0,remote_mode};
                        16'h0101: rsp_data <= remote_vref_q16[23:8];
                        16'h0102: rsp_data <= {15'd0,effective_enable};
                        16'h0103: rsp_data <= 0;
                        default: rsp_exception <= 2;
                    endcase
                end else case (req_address)
                    16'h0100: begin
                        if (req_data > 1) rsp_exception <= 3;
                        else if (req_data[0] != remote_mode) begin
                            if (effective_enable || control_status[1]) rsp_exception <= 6;
                            else begin
                                remote_mode <= req_data[0]; remote_enable <= 0;
                                remote_vref_q16 <= 0; discard_ps <= 1;
                            end
                        end
                    end
                    16'h0101: begin
                        if (req_data > 16'h4000) rsp_exception <= 3;
                        else if (!remote_mode || protection_stop || control_status[3]) rsp_exception <= 6;
                        else begin
                            remote_vref_q16 <= {8'd0,req_data,8'd0};
                            if (req_data == 0) remote_enable <= 0;
                        end
                    end
                    16'h0102: begin
                        if (req_data > 1) rsp_exception <= 3;
                        else if (req_data == 0) begin
                            // STOP works in either ownership mode and invalidates old commands.
                            remote_enable <= 0; remote_vref_q16 <= 0; discard_ps <= 1;
                        end else if (!remote_mode || remote_vref_q16 == 0 || blocked)
                            rsp_exception <= 6;
                        else remote_enable <= 1;
                    end
                    16'h0103: begin
                        if (req_data != 1) rsp_exception <= 3;
                        else if (!remote_mode) rsp_exception <= 6;
                        else begin
                            remote_enable <= 0; remote_vref_q16 <= 0;
                            discard_ps <= 1; fault_clear <= 1;
                        end
                    end
                    default: rsp_exception <= 2;
                endcase
            end
            // An actual trip wins over any serial write accepted on the same edge.
            if (protection_stop || control_status[3]) begin
                remote_enable <= 0; remote_vref_q16 <= 0;
            end
        end
    end
endmodule
