`timescale 1ns/1ps
// Adapt the vendor NPU's 6-bit transaction IDs and AXI3-sized burst fields
// to the 5-bit AXI4 upstream port of the shared HP1 matrix.
// There is one outstanding read and one outstanding write. Original IDs are
// saved independently and restored on every response; no ID is truncated.
// Matrix US1 uses ID zero; the matrix adds its master-routing bit for HP1.
module npu_hp1_axi_adapter (
    input wire aclk,
    input wire aresetn,
    input wire [5:0] s_axi_awid,
    input wire [32:0] s_axi_awaddr,
    input wire [3:0] s_axi_awlen,
    input wire [1:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst,
    input wire s_axi_awlock,
    input wire [3:0] s_axi_awcache,
    input wire [2:0] s_axi_awprot,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    input wire [63:0] s_axi_wdata,
    input wire [7:0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    output wire [5:0] s_axi_bid,
    output wire [1:0] s_axi_bresp,
    output wire s_axi_bvalid,
    input wire s_axi_bready,
    input wire [5:0] s_axi_arid,
    input wire [32:0] s_axi_araddr,
    input wire [3:0] s_axi_arlen,
    input wire [1:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst,
    input wire s_axi_arlock,
    input wire [3:0] s_axi_arcache,
    input wire [2:0] s_axi_arprot,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    output wire [5:0] s_axi_rid,
    output wire [63:0] s_axi_rdata,
    output wire [1:0] s_axi_rresp,
    output wire s_axi_rlast,
    output wire s_axi_rvalid,
    input wire s_axi_rready,
    output wire [4:0] m_axi_awid,
    output wire [32:0] m_axi_awaddr,
    output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst,
    output wire m_axi_awlock,
    output wire [3:0] m_axi_awcache,
    output wire [2:0] m_axi_awprot,
    output wire [3:0] m_axi_awqos,
    output wire m_axi_awvalid,
    input wire m_axi_awready,
    output wire [63:0] m_axi_wdata,
    output wire [7:0] m_axi_wstrb,
    output wire m_axi_wlast,
    output wire m_axi_wvalid,
    input wire m_axi_wready,
    input wire [4:0] m_axi_bid,
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready,
    output wire [4:0] m_axi_arid,
    output wire [32:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arlock,
    output wire [3:0] m_axi_arcache,
    output wire [2:0] m_axi_arprot,
    output wire [3:0] m_axi_arqos,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire [4:0] m_axi_rid,
    input wire [63:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output wire m_axi_rready
);
    reg write_active;
    reg read_active;
    reg [5:0] write_id;
    reg [5:0] read_id;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_active <= 1'b0;
            read_active <= 1'b0;
            write_id <= 6'd0;
            read_id <= 6'd0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                write_active <= 1'b1;
                write_id <= s_axi_awid;
            end
            if (s_axi_bvalid && s_axi_bready)
                write_active <= 1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                read_active <= 1'b1;
                read_id <= s_axi_arid;
            end
            if (s_axi_rvalid && s_axi_rready && s_axi_rlast)
                read_active <= 1'b0;
        end
    end

    assign m_axi_awid = 5'd0;
    assign m_axi_awaddr = s_axi_awaddr;
    assign m_axi_awlen = {4'd0, s_axi_awlen};
    assign m_axi_awsize = {1'b0, s_axi_awsize};
    assign m_axi_awburst = s_axi_awburst;
    assign m_axi_awlock = s_axi_awlock;
    assign m_axi_awcache = s_axi_awcache;
    assign m_axi_awprot = s_axi_awprot;
    assign m_axi_awqos = 4'd0;
    assign m_axi_awvalid = aresetn && !write_active && s_axi_awvalid;
    assign s_axi_awready = aresetn && !write_active && m_axi_awready;
    assign m_axi_wdata = s_axi_wdata;
    assign m_axi_wstrb = s_axi_wstrb;
    assign m_axi_wlast = s_axi_wlast;
    assign m_axi_wvalid = aresetn && write_active && s_axi_wvalid;
    assign s_axi_wready = aresetn && write_active && m_axi_wready;
    assign s_axi_bid = write_id;
    assign s_axi_bresp = m_axi_bresp;
    assign s_axi_bvalid = aresetn && write_active && m_axi_bvalid;
    assign m_axi_bready = aresetn && write_active && s_axi_bready;

    assign m_axi_arid = 5'd0;
    assign m_axi_araddr = s_axi_araddr;
    assign m_axi_arlen = {4'd0, s_axi_arlen};
    assign m_axi_arsize = {1'b0, s_axi_arsize};
    assign m_axi_arburst = s_axi_arburst;
    assign m_axi_arlock = s_axi_arlock;
    assign m_axi_arcache = s_axi_arcache;
    assign m_axi_arprot = s_axi_arprot;
    assign m_axi_arqos = 4'd0;
    assign m_axi_arvalid = aresetn && !read_active && s_axi_arvalid;
    assign s_axi_arready = aresetn && !read_active && m_axi_arready;
    assign s_axi_rid = read_id;
    assign s_axi_rdata = m_axi_rdata;
    assign s_axi_rresp = m_axi_rresp;
    assign s_axi_rlast = m_axi_rlast;
    assign s_axi_rvalid = aresetn && read_active && m_axi_rvalid;
    assign m_axi_rready = aresetn && read_active && s_axi_rready;
endmodule
