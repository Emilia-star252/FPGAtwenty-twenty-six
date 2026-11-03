// ADC capture branch. All ports use clk; never back-pressure the control loop.
// P481 frame: signed voltage_product[47:0], signed current_product[47:0],
// applied duty Q16[31:0], little endian, exactly 16 bytes. No status payload.
module adc_axis_source #(
    parameter PACKET_SAMPLES = 256,
    parameter RESET_HOLD_CYCLES = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        capture_enable,
    input  wire        fifo_clear,
    input  wire        adc_sample_valid,
    input  wire [47:0] voltage_product_in,
    input  wire [47:0] current_product_in,
    input  wire [31:0] duty_q16_in,

    output wire [31:0] m_axis_tdata,
    output wire [3:0]  m_axis_tkeep,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,

    output reg  [31:0] drop_count,
    // Observe both FIFO output handshake pins, even after changing the sink
    // from AXI-Lite to DMA. No dependency on optional vendor count outputs.
    input  wire        fifo_out_tvalid,
    input  wire        fifo_out_tready,
    output reg  [31:0] fifo_level,
    // Connect to FIFO us_aresetn and the register adapter fifo_ready_in.
    // This resets only the acquisition FIFO, not ADC, PI/PWM or AXI-Lite.
    output wire        fifo_reset_n
);
    localparam PACKET_BITS = (PACKET_SAMPLES > 1) ? $clog2(PACKET_SAMPLES) : 1;
    localparam RESET_BITS = (RESET_HOLD_CYCLES > 1) ? $clog2(RESET_HOLD_CYCLES + 1) : 1;
    reg [PACKET_BITS-1:0] packet_index;
    reg [RESET_BITS-1:0] reset_count;
    reg [127:0] frame_hold;
    reg [2:0] words_pending;
    reg last_hold;

    assign fifo_reset_n = rst_n && (reset_count == 0) && !fifo_clear;
    assign m_axis_tdata = frame_hold[31:0];
    assign m_axis_tkeep = 4'hf;
    assign m_axis_tlast = last_hold && (words_pending == 1);
    assign m_axis_tvalid = (words_pending != 0) && fifo_reset_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reset_count <= RESET_HOLD_CYCLES;
        else if (fifo_clear)
            reset_count <= RESET_HOLD_CYCLES;
        else if (reset_count != 0)
            reset_count <= reset_count - 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_level <= 0;
        else if (fifo_clear || (reset_count != 0))
            fifo_level <= 0;
        else begin
            case ({m_axis_tvalid && m_axis_tready,
                   fifo_out_tvalid && fifo_out_tready})
                2'b10: fifo_level <= fifo_level + 1'b1;
                2'b01: fifo_level <= fifo_level - 1'b1;
                default: ;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_index <= 0;
            frame_hold <= 0;
            words_pending <= 0;
            last_hold <= 0;
            drop_count <= 0;
        end else if (fifo_clear || (reset_count != 0)) begin
            packet_index <= 0;
            frame_hold <= 0;
            words_pending <= 0;
            last_hold <= 0;
            drop_count <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                words_pending <= words_pending - 1'b1;
                frame_hold <= {32'd0,frame_hold[127:32]};
            end

            if (adc_sample_valid && capture_enable) begin
                // Replace a frame only when empty or its final word is consumed.
                // If blocked within a frame, discard the whole new frame.
                if ((words_pending == 0) || ((words_pending == 1) && m_axis_tready)) begin
                    frame_hold <= {duty_q16_in,current_product_in,voltage_product_in};
                    words_pending <= 4;
                    last_hold <= (packet_index == PACKET_SAMPLES - 1);
                    if (packet_index == PACKET_SAMPLES - 1)
                        packet_index <= 0;
                    else
                        packet_index <= packet_index + 1'b1;
                end else if (drop_count != 32'hffffffff) begin
                    // Keep the stalled beat stable; discard only the new sample.
                    drop_count <= drop_count + 1'b1;
                end
            end
        end
    end
endmodule
