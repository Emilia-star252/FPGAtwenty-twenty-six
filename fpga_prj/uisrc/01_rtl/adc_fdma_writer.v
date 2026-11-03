// Fixed acquisition FDMA: 32-bit stream -> staged 64-bit INCR bursts -> DDR.
// Software supplies a DMA-owned ring. Never overwrite an unconsumed block.
// One burst outstanding; block publication follows the last successful B.
module adc_fdma_writer (
    input wire s_axi_lite_aclk,
    input wire axi_resetn,
    input wire [9:0] s_axi_lite_awaddr,
    input wire s_axi_lite_awvalid,
    output wire s_axi_lite_awready,
    input wire [31:0] s_axi_lite_wdata,
    input wire [3:0] s_axi_lite_wstrb,
    input wire s_axi_lite_wvalid,
    output wire s_axi_lite_wready,
    output reg [1:0] s_axi_lite_bresp,
    output reg s_axi_lite_bvalid,
    input wire s_axi_lite_bready,
    input wire [9:0] s_axi_lite_araddr,
    input wire s_axi_lite_arvalid,
    output wire s_axi_lite_arready,
    output reg [31:0] s_axi_lite_rdata,
    output reg [1:0] s_axi_lite_rresp,
    output reg s_axi_lite_rvalid,
    input wire s_axi_lite_rready,
    input wire [31:0] s_axis_s2mm_tdata,
    input wire [3:0] s_axis_s2mm_tkeep,
    input wire s_axis_s2mm_tlast,
    input wire s_axis_s2mm_tvalid,
    output wire s_axis_s2mm_tready,
    output wire [4:0] m_axi_s2mm_awid,
    output reg [32:0] m_axi_s2mm_awaddr,
    output wire [7:0] m_axi_s2mm_awlen,
    output wire [2:0] m_axi_s2mm_awsize,
    output wire [1:0] m_axi_s2mm_awburst,
    output wire m_axi_s2mm_awlock,
    output wire [3:0] m_axi_s2mm_awcache,
    output wire [2:0] m_axi_s2mm_awprot,
    output wire [3:0] m_axi_s2mm_awqos,
    output wire m_axi_s2mm_awvalid,
    input wire m_axi_s2mm_awready,
    output wire [63:0] m_axi_s2mm_wdata,
    output wire [7:0] m_axi_s2mm_wstrb,
    output wire m_axi_s2mm_wlast,
    output wire m_axi_s2mm_wvalid,
    input wire m_axi_s2mm_wready,
    input wire [4:0] m_axi_s2mm_bid,
    input wire [1:0] m_axi_s2mm_bresp,
    input wire m_axi_s2mm_bvalid,
    output wire m_axi_s2mm_bready
);
    localparam IDLE=0, FILL=1, ADDR=2, DATA=3, RESP=4;
    reg [2:0] state;
    reg run_enable, reset_pending;
    reg [32:0] ring_base;
    reg [31:0] ring_slots, producer, consumer;
    reg [31:0] errors;
    reg [10:0] packet_words;
    reg [5:0] fill_words;
    reg [4:0] burst_beats, write_index;
    reg [63:0] staging [0:15];
    reg [31:0] low_word;
    reg aw_pending, w_pending;
    reg [9:0] write_addr;
    reg [31:0] write_data;
    reg [3:0] write_strb;
    wire [31:0] occupied = producer - consumer;
    wire full = (occupied >= ring_slots);
    wire [32:0] ring_span = {1'b0,ring_slots[19:0],12'b0};
    wire [33:0] ring_end = {1'b0,ring_base} + {1'b0,ring_span};
    wire config_valid = (ring_slots >= 2) && (ring_slots <= 65536) &&
        ((ring_slots & (ring_slots-1'b1)) == 0) && (ring_base[2:0] == 0) &&
        !ring_end[33];
    wire [32:0] slot_offset = {1'b0,((producer[19:0]) & (ring_slots[19:0]-1'b1)),12'b0};
    wire [9:0] boundary_beats = 10'd512 - {1'b0,m_axi_s2mm_awaddr[11:3]};
    wire [9:0] remaining_beats = 10'd512 - {1'b0,packet_words[10:1]};
    wire [9:0] next_beats = (boundary_beats < 16) ? boundary_beats :
        ((remaining_beats < 16) ? remaining_beats : 10'd16);
    wire [10:0] accepted_word = packet_words + {5'd0,fill_words};
    wire stream_bad = (s_axis_s2mm_tkeep != 4'hf) ||
        (s_axis_s2mm_tlast != (accepted_word == 1023));

    assign s_axis_s2mm_tready = (state == FILL) && run_enable &&
        !reset_pending && (errors == 0) && (fill_words < {burst_beats,1'b0});
    assign m_axi_s2mm_awid = 0;
    assign m_axi_s2mm_awlen = {3'd0,burst_beats} - 1'b1;
    assign m_axi_s2mm_awsize = 3;
    assign m_axi_s2mm_awburst = 1;
    assign m_axi_s2mm_awlock = 0;
    assign m_axi_s2mm_awcache = 4'b0010;
    assign m_axi_s2mm_awprot = 0;
    assign m_axi_s2mm_awqos = 0;
    assign m_axi_s2mm_awvalid = (state == ADDR);
    assign m_axi_s2mm_wdata = staging[write_index[3:0]];
    assign m_axi_s2mm_wstrb = 8'hff;
    assign m_axi_s2mm_wlast = (write_index == burst_beats-1'b1);
    assign m_axi_s2mm_wvalid = (state == DATA);
    assign m_axi_s2mm_bready = (state == RESP);
    assign s_axi_lite_awready = !aw_pending && !s_axi_lite_bvalid;
    assign s_axi_lite_wready = !w_pending && !s_axi_lite_bvalid;
    assign s_axi_lite_arready = !s_axi_lite_rvalid || s_axi_lite_rready;

    always @(posedge s_axi_lite_aclk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            state<=IDLE; run_enable<=0; reset_pending<=0;
            ring_base<=0; ring_slots<=0; producer<=0; consumer<=0; errors<=0;
            packet_words<=0; fill_words<=0; burst_beats<=0; write_index<=0;
            low_word<=0; m_axi_s2mm_awaddr<=0;
            aw_pending<=0; w_pending<=0; write_addr<=0; write_data<=0; write_strb<=0;
            s_axi_lite_bvalid<=0; s_axi_lite_bresp<=0;
            s_axi_lite_rvalid<=0; s_axi_lite_rdata<=0; s_axi_lite_rresp<=0;
        end else begin
            case (state)
                IDLE: if (run_enable && !reset_pending && errors==0 && !full) begin
                    m_axi_s2mm_awaddr <= ring_base + slot_offset;
                    packet_words<=0; fill_words<=0; burst_beats<=0; state<=FILL;
                end
                FILL: begin
                    if (!run_enable || reset_pending || errors!=0) begin
                        // A partial packet may already occupy this unpublished slot.
                        state<=IDLE;
                        if (!reset_pending) errors[4]<=1;
                    end else if (burst_beats==0) begin
                        burst_beats<=next_beats[4:0];
                    end else if (s_axis_s2mm_tvalid && s_axis_s2mm_tready) begin
                        if (stream_bad) begin errors[2]<=1; run_enable<=0; state<=IDLE; end
                        else begin
                            if (!fill_words[0]) low_word<=s_axis_s2mm_tdata;
                            else staging[fill_words[4:1]]<={s_axis_s2mm_tdata,low_word};
                            fill_words<=fill_words+1'b1;
                            if (fill_words == {burst_beats,1'b0}-1'b1) begin
                                write_index<=0; state<=ADDR;
                            end
                        end
                    end
                end
                ADDR: if (m_axi_s2mm_awready) state<=DATA;
                DATA: if (m_axi_s2mm_wready) begin
                    if (m_axi_s2mm_wlast) state<=RESP;
                    else write_index<=write_index+1'b1;
                end
                RESP: if (m_axi_s2mm_bvalid) begin
                    if (m_axi_s2mm_bresp!=0 || m_axi_s2mm_bid!=0) begin
                        errors[1]<=1; run_enable<=0; state<=IDLE;
                    end else if (packet_words+{5'd0,burst_beats,1'b0} == 1024) begin
                        producer<=producer+1'b1; packet_words<=0; state<=IDLE;
                    end else begin
                        m_axi_s2mm_awaddr<=m_axi_s2mm_awaddr+{25'd0,burst_beats,3'd0};
                        packet_words<=packet_words+{5'd0,burst_beats,1'b0};
                        burst_beats<=0; fill_words<=0; state<=FILL;
                    end
                end
                default: state<=IDLE;
            endcase
            // A reset request drains any already-issued AXI burst/response first.
            // It never withdraws AWVALID/WVALID while the slave is stalled.
            if (reset_pending && state==IDLE) begin
                reset_pending<=0; producer<=0; consumer<=0; errors<=0;
                packet_words<=0; fill_words<=0; burst_beats<=0;
            end
            if (s_axi_lite_awvalid && s_axi_lite_awready) begin
                aw_pending<=1; write_addr<=s_axi_lite_awaddr;
            end
            if (s_axi_lite_wvalid && s_axi_lite_wready) begin
                w_pending<=1; write_data<=s_axi_lite_wdata; write_strb<=s_axi_lite_wstrb;
            end
            if (s_axi_lite_bvalid && s_axi_lite_bready) s_axi_lite_bvalid<=0;
            if (aw_pending && w_pending && !s_axi_lite_bvalid) begin
                aw_pending<=0; w_pending<=0; s_axi_lite_bvalid<=1; s_axi_lite_bresp<=0;
                if (write_addr[1:0]!=0 || write_strb!=4'hf || reset_pending)
                    s_axi_lite_bresp<=2;
                else case (write_addr)
                    10'h004: begin
                        if (write_data==2) begin run_enable<=0; reset_pending<=1; end
                        else if (write_data==0) run_enable<=0;
                        else if (write_data==1 && config_valid && errors==0) run_enable<=1;
                        else s_axi_lite_bresp<=2;
                    end
                    10'h010: if (!run_enable && state==IDLE && producer==consumer) ring_base[31:0]<=write_data;
                        else s_axi_lite_bresp<=2;
                    10'h014: if (!run_enable && state==IDLE && producer==consumer && write_data<=1) ring_base[32]<=write_data[0];
                        else s_axi_lite_bresp<=2;
                    10'h018: if (!run_enable && state==IDLE && producer==consumer) ring_slots<=write_data;
                        else s_axi_lite_bresp<=2;
                    10'h020: if ((write_data-consumer)<=occupied) consumer<=write_data;
                        else s_axi_lite_bresp<=2;
                    default: s_axi_lite_bresp<=2;
                endcase
            end
            if (s_axi_lite_rvalid && s_axi_lite_rready) s_axi_lite_rvalid<=0;
            if (s_axi_lite_arvalid && s_axi_lite_arready) begin
                s_axi_lite_rvalid<=1; s_axi_lite_rresp<=0;
                if (s_axi_lite_araddr[1:0]!=0) begin s_axi_lite_rresp<=2; s_axi_lite_rdata<=0; end
                else case (s_axi_lite_araddr)
                    10'h000: s_axi_lite_rdata<=32'h46444d31; // FDM1
                    10'h004: s_axi_lite_rdata<={30'd0,reset_pending,run_enable};
                    10'h008: s_axi_lite_rdata<={27'd0,config_valid,(errors!=0),full,(state!=IDLE),run_enable};
                    10'h00c: s_axi_lite_rdata<=errors;
                    10'h010: s_axi_lite_rdata<=ring_base[31:0];
                    10'h014: s_axi_lite_rdata<={31'd0,ring_base[32]};
                    10'h018: s_axi_lite_rdata<=ring_slots;
                    10'h01c: s_axi_lite_rdata<=producer;
                    10'h020: s_axi_lite_rdata<=consumer;
                    10'h024: s_axi_lite_rdata<=4096;
                    10'h028: s_axi_lite_rdata<=32'h50343831; // P481: 48/48/32
                    default: begin s_axi_lite_rdata<=0; s_axi_lite_rresp<=2; end
                endcase
            end
        end
    end
endmodule
