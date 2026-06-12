/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 DMA
 */
module axi_dma_wr #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // Use AXI stream tkeep signal
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8),
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    // Use AXI stream tlast signal
    parameter AXIS_LAST_ENABLE = 1,
    // Propagate AXI stream tid signal
    parameter AXIS_ID_ENABLE = 0,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // Propagate AXI stream tdest signal
    parameter AXIS_DEST_ENABLE = 0,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // Propagate AXI stream tuser signal
    parameter AXIS_USER_ENABLE = 1,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,
    // Width of length field
    parameter LEN_WIDTH = 20,
    // Width of tag field
    parameter TAG_WIDTH = 8,
    // Enable support for scatter/gather DMA
    // (multiple descriptors per AXI stream frame)
    parameter ENABLE_SG = 0,
    // Enable support for unaligned transfers
    parameter ENABLE_UNALIGNED = 0
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * AXI write descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_write_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_write_desc_tag,
    input  wire                       s_axis_write_desc_valid,
    output wire                       s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [LEN_WIDTH-1:0]       m_axis_write_desc_status_len,
    output wire [TAG_WIDTH-1:0]       m_axis_write_desc_status_tag,
    output wire [AXIS_ID_WIDTH-1:0]   m_axis_write_desc_status_id,
    output wire [AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest,
    output wire [AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user,
    output wire [3:0]                 m_axis_write_desc_status_error,
    output wire                       m_axis_write_desc_status_valid,

    /*
     * AXI stream write data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0] s_axis_write_data_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0] s_axis_write_data_tkeep,
    input  wire                       s_axis_write_data_tvalid,
    output wire                       s_axis_write_data_tready,
    input  wire                       s_axis_write_data_tlast,
    input  wire [AXIS_ID_WIDTH-1:0]   s_axis_write_data_tid,
    input  wire [AXIS_DEST_WIDTH-1:0] s_axis_write_data_tdest,
    input  wire [AXIS_USER_WIDTH-1:0] s_axis_write_data_tuser,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,

    /*
     * Configuration
     */
    input  wire                       enable,
    input  wire                       abort
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH); // 一个beat中包含的字节数
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE; // 单次transaction能够搬运的最大总字节数

parameter AXIS_KEEP_WIDTH_INT = AXIS_KEEP_ENABLE ? AXIS_KEEP_WIDTH : 1;
parameter AXIS_WORD_WIDTH = AXIS_KEEP_WIDTH_INT;
parameter AXIS_WORD_SIZE = AXIS_DATA_WIDTH/AXIS_WORD_WIDTH;

parameter OFFSET_WIDTH = AXI_STRB_WIDTH > 1 ? $clog2(AXI_STRB_WIDTH) : 1;
parameter OFFSET_MASK = AXI_STRB_WIDTH > 1 ? {OFFSET_WIDTH{1'b1}} : 0;
parameter ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);
parameter CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;

parameter STATUS_FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (AXI_WORD_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble (instance %m)");
        $finish;
    end

    if (AXIS_WORD_SIZE * AXIS_KEEP_WIDTH_INT != AXIS_DATA_WIDTH) begin
        $error("Error: AXI stream data width not evenly divisble (instance %m)");
        $finish;
    end

    if (AXI_WORD_SIZE != AXIS_WORD_SIZE) begin
        $error("Error: word size mismatch (instance %m)");
        $finish;
    end

    if (2**$clog2(AXI_WORD_WIDTH) != AXI_WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two (instance %m)");
        $finish;
    end

    if (AXI_DATA_WIDTH != AXIS_DATA_WIDTH) begin
        $error("Error: AXI interface width must match AXI stream interface width (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
        $finish;
    end

    if (ENABLE_SG) begin
        $error("Error: scatter/gather is not yet implemented (instance %m)");
        $finish;
    end
end

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

localparam [3:0]
    DMA_ERROR_NONE = 4'd0,
    DMA_ERROR_TIMEOUT = 4'd1,
    DMA_ERROR_PARITY = 4'd2,
    DMA_ERROR_AXI_RD_SLVERR = 4'd4,
    DMA_ERROR_AXI_RD_DECERR = 4'd5,
    DMA_ERROR_AXI_WR_SLVERR = 4'd6,
    DMA_ERROR_AXI_WR_DECERR = 4'd7,
    DMA_ERROR_PCIE_FLR = 4'd8,
    DMA_ERROR_PCIE_CPL_POISONED = 4'd9,
    DMA_ERROR_PCIE_CPL_STATUS_UR = 4'd10,
    DMA_ERROR_PCIE_CPL_STATUS_CA = 4'd11;

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_START = 3'd1,
    STATE_WRITE = 3'd2,
    STATE_FINISH_BURST = 3'd3,
    STATE_DROP_DATA = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg transfer_in_save; // 因为可能要align  所以必须
reg flush_save;
reg status_fifo_we;

integer i;
reg [OFFSET_WIDTH:0] cycle_size;

reg [AXI_ADDR_WIDTH-1:0] addr_reg = {AXI_ADDR_WIDTH{1'b0}}, addr_next;
reg [LEN_WIDTH-1:0] op_word_count_reg = {LEN_WIDTH{1'b0}}, op_word_count_next;
reg [LEN_WIDTH-1:0] tr_word_count_reg = {LEN_WIDTH{1'b0}}, tr_word_count_next;

reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [AXI_STRB_WIDTH-1:0] strb_offset_mask_reg = {AXI_STRB_WIDTH{1'b1}}, strb_offset_mask_next;
reg zero_offset_reg = 1'b1, zero_offset_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
reg [LEN_WIDTH-1:0] length_reg = {LEN_WIDTH{1'b0}}, length_next;
reg [CYCLE_COUNT_WIDTH-1:0] input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, input_cycle_count_next;
reg [CYCLE_COUNT_WIDTH-1:0] output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, output_cycle_count_next;
reg input_active_reg = 1'b0, input_active_next;
reg first_cycle_reg = 1'b0, first_cycle_next;
reg input_last_cycle_reg = 1'b0, input_last_cycle_next;
reg output_last_cycle_reg = 1'b0, output_last_cycle_next;
reg last_transfer_reg = 1'b0, last_transfer_next;
reg [1:0] bresp_reg = AXI_RESP_OKAY, bresp_next;

reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;
reg [AXIS_ID_WIDTH-1:0] axis_id_reg = {AXIS_ID_WIDTH{1'b0}}, axis_id_next;
reg [AXIS_DEST_WIDTH-1:0] axis_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, axis_dest_next;
reg [AXIS_USER_WIDTH-1:0] axis_user_reg = {AXIS_USER_WIDTH{1'b0}}, axis_user_next;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_wr_ptr_reg = 0;
reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_rd_ptr_reg = 0, status_fifo_rd_ptr_next;
reg [LEN_WIDTH-1:0] status_fifo_len[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [TAG_WIDTH-1:0] status_fifo_tag[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [AXIS_ID_WIDTH-1:0] status_fifo_id[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [AXIS_DEST_WIDTH-1:0] status_fifo_dest[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [AXIS_USER_WIDTH-1:0] status_fifo_user[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg status_fifo_last[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [LEN_WIDTH-1:0] status_fifo_wr_len;
reg [TAG_WIDTH-1:0] status_fifo_wr_tag;
reg [AXIS_ID_WIDTH-1:0] status_fifo_wr_id;
reg [AXIS_DEST_WIDTH-1:0] status_fifo_wr_dest;
reg [AXIS_USER_WIDTH-1:0] status_fifo_wr_user;
reg status_fifo_wr_last;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] active_count_reg = 0;
reg active_count_av_reg = 1'b1;
reg inc_active;
reg dec_active;

reg s_axis_write_desc_ready_reg = 1'b0, s_axis_write_desc_ready_next;

reg [LEN_WIDTH-1:0] m_axis_write_desc_status_len_reg = {LEN_WIDTH{1'b0}}, m_axis_write_desc_status_len_next;
reg [TAG_WIDTH-1:0] m_axis_write_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_write_desc_status_tag_next;
reg [AXIS_ID_WIDTH-1:0] m_axis_write_desc_status_id_reg = {AXIS_ID_WIDTH{1'b0}}, m_axis_write_desc_status_id_next;
reg [AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, m_axis_write_desc_status_dest_next;
reg [AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user_reg = {AXIS_USER_WIDTH{1'b0}}, m_axis_write_desc_status_user_next;
reg [3:0] m_axis_write_desc_status_error_reg = 4'd0, m_axis_write_desc_status_error_next;
reg m_axis_write_desc_status_valid_reg = 1'b0, m_axis_write_desc_status_valid_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;
reg m_axi_bready_reg = 1'b0, m_axi_bready_next;

reg s_axis_write_data_tready_reg = 1'b0, s_axis_write_data_tready_next;

reg [AXIS_DATA_WIDTH-1:0] save_axis_tdata_reg = {AXIS_DATA_WIDTH{1'b0}};
reg [AXIS_KEEP_WIDTH_INT-1:0] save_axis_tkeep_reg = {AXIS_KEEP_WIDTH_INT{1'b0}};
reg save_axis_tlast_reg = 1'b0;

reg [AXIS_DATA_WIDTH-1:0] shift_axis_tdata;
reg [AXIS_KEEP_WIDTH_INT-1:0] shift_axis_tkeep;
reg shift_axis_tvalid;
reg shift_axis_tlast;
reg shift_axis_input_tready;
reg shift_axis_extra_cycle_reg = 1'b0;

// internal datapath
reg  [AXI_DATA_WIDTH-1:0] m_axi_wdata_int;
reg  [AXI_STRB_WIDTH-1:0] m_axi_wstrb_int;
reg                       m_axi_wlast_int;
reg                       m_axi_wvalid_int;
wire                      m_axi_wready_int;

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_len = m_axis_write_desc_status_len_reg;
assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_id = m_axis_write_desc_status_id_reg;
assign m_axis_write_desc_status_dest = m_axis_write_desc_status_dest_reg;
assign m_axis_write_desc_status_user = m_axis_write_desc_status_user_reg;
assign m_axis_write_desc_status_error = m_axis_write_desc_status_error_reg;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign s_axis_write_data_tready = s_axis_write_data_tready_reg;

assign m_axi_awid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_awaddr = m_axi_awaddr_reg;
assign m_axi_awlen = m_axi_awlen_reg;
assign m_axi_awsize = AXI_BURST_SIZE;
assign m_axi_awburst = 2'b01;
assign m_axi_awlock = 1'b0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot = 3'b010;
assign m_axi_awvalid = m_axi_awvalid_reg;
assign m_axi_bready = m_axi_bready_reg;

always @* begin
    if (!ENABLE_UNALIGNED || zero_offset_reg) begin
        // passthrough if no overlap
        shift_axis_tdata = s_axis_write_data_tdata;
        shift_axis_tkeep = s_axis_write_data_tkeep;
        shift_axis_tvalid = s_axis_write_data_tvalid;
        shift_axis_tlast = AXIS_LAST_ENABLE && s_axis_write_data_tlast;
        shift_axis_input_tready = 1'b1;
    end else if (!AXIS_LAST_ENABLE) begin // 先拼接  再移位
        shift_axis_tdata = {s_axis_write_data_tdata, save_axis_tdata_reg} >> ((AXIS_KEEP_WIDTH_INT-offset_reg)*AXIS_WORD_SIZE);
        shift_axis_tkeep = {s_axis_write_data_tkeep, save_axis_tkeep_reg} >> (AXIS_KEEP_WIDTH_INT-offset_reg);
        shift_axis_tvalid = s_axis_write_data_tvalid;
        shift_axis_tlast = 1'b0;
        shift_axis_input_tready = 1'b1;
    end else if (shift_axis_extra_cycle_reg) begin // 处理最后一拍  此时没有输入了 
        shift_axis_tdata = {s_axis_write_data_tdata, save_axis_tdata_reg} >> ((AXIS_KEEP_WIDTH_INT-offset_reg)*AXIS_WORD_SIZE);
        shift_axis_tkeep = {{AXIS_KEEP_WIDTH_INT{1'b0}}, save_axis_tkeep_reg} >> (AXIS_KEEP_WIDTH_INT-offset_reg);
        shift_axis_tvalid = 1'b1;
        shift_axis_tlast = save_axis_tlast_reg;
        shift_axis_input_tready = flush_save;
    end else begin
        shift_axis_tdata = {s_axis_write_data_tdata, save_axis_tdata_reg} >> ((AXIS_KEEP_WIDTH_INT-offset_reg)*AXIS_WORD_SIZE);
        shift_axis_tkeep = {s_axis_write_data_tkeep, save_axis_tkeep_reg} >> (AXIS_KEEP_WIDTH_INT-offset_reg);
        shift_axis_tvalid = s_axis_write_data_tvalid;
        shift_axis_tlast = (s_axis_write_data_tlast && ((s_axis_write_data_tkeep & ({AXIS_KEEP_WIDTH_INT{1'b1}} << (AXIS_KEEP_WIDTH_INT-offset_reg))) == 0));
        shift_axis_input_tready = !(s_axis_write_data_tlast && s_axis_write_data_tready && s_axis_write_data_tvalid);
    end
end

always @* begin
    state_next = STATE_IDLE;

    s_axis_write_desc_ready_next = 1'b0;

    m_axis_write_desc_status_len_next = m_axis_write_desc_status_len_reg;
    m_axis_write_desc_status_tag_next = m_axis_write_desc_status_tag_reg;
    m_axis_write_desc_status_id_next = m_axis_write_desc_status_id_reg;
    m_axis_write_desc_status_dest_next = m_axis_write_desc_status_dest_reg;
    m_axis_write_desc_status_user_next = m_axis_write_desc_status_user_reg;
    m_axis_write_desc_status_error_next = m_axis_write_desc_status_error_reg;
    m_axis_write_desc_status_valid_next = 1'b0;

    s_axis_write_data_tready_next = 1'b0;

    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;
    m_axi_wdata_int = shift_axis_tdata;
    m_axi_wstrb_int = shift_axis_tkeep;
    m_axi_wlast_int = 1'b0;
    m_axi_wvalid_int = 1'b0;
    m_axi_bready_next = 1'b0;

    transfer_in_save = 1'b0;
    flush_save = 1'b0;
    status_fifo_we = 1'b0;

    cycle_size = AXIS_KEEP_WIDTH_INT;

    addr_next = addr_reg;
    offset_next = offset_reg;
    strb_offset_mask_next = strb_offset_mask_reg;
    zero_offset_next = zero_offset_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    length_next = length_reg;
    op_word_count_next = op_word_count_reg;
    tr_word_count_next = tr_word_count_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    first_cycle_next = first_cycle_reg;
    input_last_cycle_next = input_last_cycle_reg;
    output_last_cycle_next = output_last_cycle_reg;
    last_transfer_next = last_transfer_reg;

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    inc_active = 1'b0;
    dec_active = 1'b0;

    tag_next = tag_reg;
    axis_id_next = axis_id_reg;
    axis_dest_next = axis_dest_reg;
    axis_user_next = axis_user_reg;

    status_fifo_wr_len = length_reg;
    status_fifo_wr_tag = tag_reg;
    status_fifo_wr_id = axis_id_reg;
    status_fifo_wr_dest = axis_dest_reg;
    status_fifo_wr_user = axis_user_reg;
    status_fifo_wr_last = 1'b0;

    if (m_axi_bready && m_axi_bvalid && (m_axi_bresp == AXI_RESP_SLVERR || m_axi_bresp == AXI_RESP_DECERR)) begin
        bresp_next = m_axi_bresp;
    end else begin
        bresp_next = bresp_reg;
    end

    case (state_reg)
        STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            flush_save = 1'b1;
            s_axis_write_desc_ready_next = enable && active_count_av_reg; // 用于追踪outstanding？

            if (ENABLE_UNALIGNED) begin // 支持非对齐的地址  但是else状态就完全不管对不对齐？默认就是对齐的？
                addr_next = s_axis_write_desc_addr;
                offset_next = s_axis_write_desc_addr & OFFSET_MASK;
                strb_offset_mask_next = {AXI_STRB_WIDTH{1'b1}} << (s_axis_write_desc_addr & OFFSET_MASK);
                zero_offset_next = (s_axis_write_desc_addr & OFFSET_MASK) == 0;
                last_cycle_offset_next = offset_next + (s_axis_write_desc_len & OFFSET_MASK);
            end else begin
                addr_next = s_axis_write_desc_addr & ADDR_MASK;
                offset_next = 0;
                strb_offset_mask_next = {AXI_STRB_WIDTH{1'b1}};
                zero_offset_next = 1'b1;
                last_cycle_offset_next = offset_next + (s_axis_write_desc_len & OFFSET_MASK);
            end
            tag_next = s_axis_write_desc_tag; //锁存CPU发过来的这个descriptor的ID
            op_word_count_next = s_axis_write_desc_len; //所存word 长度
            first_cycle_next = 1'b1; //
            length_next = 0;

            if (s_axis_write_desc_ready && s_axis_write_desc_valid) begin
                s_axis_write_desc_ready_next = 1'b0; //握手成功，然后就要来处理现在接收进来的这个descriptor
                state_next = STATE_START;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_START: begin
            // start state - initiate new AXI transfer
            if (op_word_count_reg <= AXI_MAX_BURST_SIZE - (addr_reg & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                // packet smaller than max burst size
                if (((addr_reg & 12'hfff) + (op_word_count_reg & 12'hfff)) >> 12 != 0 || op_word_count_reg >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_word_count_next = 13'h1000 - (addr_reg & 12'hfff);
                end else begin
                    // does not cross 4k boundary
                    tr_word_count_next = op_word_count_reg;
                end
            end else begin
                // packet larger than max burst size
                if (((addr_reg & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_word_count_next = 13'h1000 - (addr_reg & 12'hfff);
                end else begin
                    // does not cross 4k boundary
                    tr_word_count_next = AXI_MAX_BURST_SIZE - (addr_reg & OFFSET_MASK);
                end
            end

            input_cycle_count_next = (tr_word_count_next - 1) >> $clog2(AXIS_KEEP_WIDTH_INT);
            input_last_cycle_next = input_cycle_count_next == 0;
            if (ENABLE_UNALIGNED) begin
                output_cycle_count_next = (tr_word_count_next + (addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
            end else begin
                output_cycle_count_next = (tr_word_count_next - 1) >> AXI_BURST_SIZE;
            end
            output_last_cycle_next = output_cycle_count_next == 0;
            last_transfer_next = tr_word_count_next == op_word_count_reg;
            input_active_next = 1'b1;

            if (ENABLE_UNALIGNED) begin
                if (!first_cycle_reg && last_transfer_next) begin
                    if (offset_reg >= last_cycle_offset_reg && last_cycle_offset_reg > 0) begin
                        // last cycle will be served by stored partial cycle
                        input_active_next = input_cycle_count_next > 0;
                        input_cycle_count_next = input_cycle_count_next - 1;
                    end
                end
            end

            if (!m_axi_awvalid_reg && active_count_av_reg) begin // 只有在上一次请求被完成了之后 AW通道是空闲的 才能进一步做后续操作
                m_axi_awaddr_next = addr_reg;
                m_axi_awlen_next = output_cycle_count_next;
                m_axi_awvalid_next = s_axis_write_data_tvalid || !first_cycle_reg;
                // AXI 允许先发AW 再发W 但是有可能发了AW  W还不来 这样就会抢占通道
                // 所以如果你不是第一个，就允许你先发AW  因为如果是stream，那么数据就已经源源不断地来，不需要等
                if (m_axi_awvalid_next) begin
                    addr_next = addr_reg + tr_word_count_next;
                    op_word_count_next = op_word_count_reg - tr_word_count_next;

                    s_axis_write_data_tready_next = m_axi_wready_int && input_active_next;

                    inc_active = 1'b1; // 用于控制outstanding的计数器？

                    state_next = STATE_WRITE;
                end else begin
                    state_next = STATE_START;
                end
            end else begin
                state_next = STATE_START;
            end
        end
        STATE_WRITE: begin
            s_axis_write_data_tready_next = m_axi_wready_int && (last_transfer_reg || input_active_reg) && shift_axis_input_tready;
            // last transfer reg用于指示当前处于有效输入接收器
            // shift axis input tready再处理气泡周期的时候会被拉低
            if ((s_axis_write_data_tready && shift_axis_tvalid) || (!input_active_reg && !last_transfer_reg) || !shift_axis_input_tready) begin
                // 上面对应3种情况  进了block再分别处理   但是核心就是必须要更新状态和内部计数器
                // 上游发生了数据握手
                // 输入已经结束（再处理收尾数据）
                // 移位器在处理上一个周期的残留数据
                if (s_axis_write_data_tready && s_axis_write_data_tvalid) begin
                    transfer_in_save = 1'b1; // 用于指示移位寄存器保存当前的input数据

                    axis_id_next = s_axis_write_data_tid;
                    axis_dest_next = s_axis_write_data_tdest;
                    axis_user_next = s_axis_write_data_tuser;
                end

                // update counters //用于指示要写入的数据长度  
                if (first_cycle_reg) begin // length用于记录总写入的数据长度？
                    length_next = length_reg + (AXIS_KEEP_WIDTH_INT - offset_reg);
                end else begin
                    length_next = length_reg + AXIS_KEEP_WIDTH_INT;
                end
                if (input_active_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
                end
                input_last_cycle_next = input_cycle_count_next == 0; // 用于判断是否要结束了
                output_cycle_count_next = output_cycle_count_reg - 1; 
                output_last_cycle_next = output_cycle_count_next == 0;// 如果数据计数器要耗尽了，就要触发总线的WLAST  告诉下游DMA要完成当前descriptor了？
                first_cycle_next = 1'b0;
                strb_offset_mask_next = {AXI_STRB_WIDTH{1'b1}};

                m_axi_wdata_int = shift_axis_tdata;  // 驱动 W 通道
                m_axi_wstrb_int = strb_offset_mask_reg;
                m_axi_wvalid_int = 1'b1;

                if (AXIS_LAST_ENABLE && s_axis_write_data_tlast) begin // 输入源提前拉高TLAST，终止了传输？
                    // end of input frame
                    input_active_next = 1'b0;
                    s_axis_write_data_tready_next = 1'b0;
                end

                if (AXIS_LAST_ENABLE && shift_axis_tlast) begin // 移位器判断是否到了最后一拍  shift会计算残余数据是否在这一拍能够全部输出？ 表示移位寄存器中的最后一拍数据也没了
                    // 也会被s_axis_write_data_tlast触发
                    // end of data packet

                    if (AXIS_KEEP_ENABLE) begin
                        cycle_size = AXIS_KEEP_WIDTH_INT;
                        for (i = AXIS_KEEP_WIDTH_INT-1; i >= 0; i = i - 1) begin
                            if (~shift_axis_tkeep & strb_offset_mask_reg & (1 << i)) begin
                                // shift axis tkeep是当前输出数据地有效字节mask
                                // strb offset是地址不对齐时产生的基准mask   这里是在计算当前beat地有效word数？
                                // 既要考虑地址对齐  又要考虑输入mask
                                // 在找这一个cycle中最低的有效lane 
                                cycle_size = i; // 这是上游实际提供的字节长度？  基于shift axis tkeep算出来的
                            end
                        end
                    end else begin
                        cycle_size = AXIS_KEEP_WIDTH_INT; // 如果没有keep信号，则不需要阶段  直接是满载的字数
                    end

                    if (output_last_cycle_reg) begin // 意味着这是当前transaction的最后一个beat ？  但是不一定是最后一个transaction
                        m_axi_wlast_int = 1'b1;
                        // 一个descriptor拆分成不同的transaction，有的transaction是能完全跑满的，但是有些可能就没对齐？
                        // no more data to transfer, finish operation
                        if (last_transfer_reg && last_cycle_offset_reg > 0) begin  // 是最后一个beat 而且还有offset 意味着没有完美对齐总线
                        // last transfer reg意味着这是当前descriptor任务的最后一个transaction   
                            if (AXIS_KEEP_ENABLE && !(shift_axis_tkeep & ~({AXI_STRB_WIDTH{1'b1}} >> (AXI_STRB_WIDTH - last_cycle_offset_reg)))) begin
                                m_axi_wstrb_int = strb_offset_mask_reg & shift_axis_tkeep; // 这是descriptor中指定的mask，它和当前本地计算出来的安全边界相同
                                if (first_cycle_reg) begin // 也是第一个beat，意味着这是个single beat transfer
                                    length_next = length_reg + (cycle_size - offset_reg);
                                end else begin
                                    length_next = length_reg + cycle_size;
                                end
                            end else begin
                                m_axi_wstrb_int = strb_offset_mask_reg & {AXI_STRB_WIDTH{1'b1}} >> (AXI_STRB_WIDTH - last_cycle_offset_reg); // 和上面的区别是什么？
                                // 当descriptor算出来的安全边界和本地算出来的不同，以本地的为准
                                if (first_cycle_reg) begin
                                    length_next = length_reg + (last_cycle_offset_reg - offset_reg);
                                end else begin
                                    length_next = length_reg + last_cycle_offset_reg; // DMA内部的计数值？
                                end
                            end
                        end else begin // 要么意味着最后这一个beat是满载的（transaction还没有结束，但是这是当前这个transaction的最后一个beat） 要么就是说这里也对齐了 
                            if (AXIS_KEEP_ENABLE) begin
                                m_axi_wstrb_int = strb_offset_mask_reg & shift_axis_tkeep;
                                if (first_cycle_reg) begin
                                    length_next = length_reg + (cycle_size - offset_reg);
                                end else begin
                                    length_next = length_reg + cycle_size;
                                end
                            end
                        end

                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b1;

                        s_axis_write_data_tready_next = 1'b0;
                        s_axis_write_desc_ready_next = enable && active_count_av_reg;
                        state_next = STATE_IDLE; //刚好还是最后一个transaction，所以可以直接去到IDLE状态
                    end else begin //说明output_last_cycle_reg == 0  这不是当前transaction的最后一个beat？
                        // more cycles left in burst, finish burst
                        if (AXIS_KEEP_ENABLE) begin
                            m_axi_wstrb_int = strb_offset_mask_reg & shift_axis_tkeep;
                            if (first_cycle_reg) begin
                                length_next = length_reg + (cycle_size - offset_reg);
                            end else begin
                                length_next = length_reg + cycle_size;
                            end
                        end

                        // enqueue status FIFO entry for write completion   // 记录当前这个transaction的完成情况
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b1;

                        s_axis_write_data_tready_next = 1'b0;
                        state_next = STATE_FINISH_BURST; // 还不是最后一个transaction  所以还需要去补空包？ 要到下一个状态
                    end

                end else if (output_last_cycle_reg) begin // 记录的是当前这个transaction的长度  意味着当前的transaction正常结束
                    m_axi_wlast_int = 1'b1;

                    if (op_word_count_reg > 0) begin // 说明当前的transaction并不是最后一个transaction
                        // current AXI transfer complete, but there is more data to transfer
                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b0;  //未完结就不要吧总任务的wr last拉高

                        s_axis_write_data_tready_next = 1'b0;
                        state_next = STATE_START;
                    end else begin
                        // no more data to transfer, finish operation
                        if (last_cycle_offset_reg > 0) begin
                            m_axi_wstrb_int = strb_offset_mask_reg & {AXI_STRB_WIDTH{1'b1}} >> (AXI_STRB_WIDTH - last_cycle_offset_reg);
                            if (first_cycle_reg) begin
                                length_next = length_reg + (last_cycle_offset_reg - offset_reg);
                            end else begin
                                length_next = length_reg + last_cycle_offset_reg;
                            end
                        end

                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b1; //拉高说明这个descriptor已完成

                        if (AXIS_LAST_ENABLE) begin
                            // not at the end of packet; drop remainder
                            s_axis_write_data_tready_next = shift_axis_input_tready;
                            state_next = STATE_DROP_DATA;
                        end else begin
                            // no framing; return to idle
                            s_axis_write_data_tready_next = 1'b0;
                            s_axis_write_desc_ready_next = enable && active_count_av_reg;
                            state_next = STATE_IDLE;
                        end
                    end
                end else begin // 正常的中间beat传输  还不是最后一个transaction  也不是transaction的最后一拍
                    s_axis_write_data_tready_next = m_axi_wready_int && (last_transfer_reg || input_active_next) && shift_axis_input_tready;
                    state_next = STATE_WRITE;
                end
            end else begin
                state_next = STATE_WRITE;
            end
        end
        STATE_FINISH_BURST: begin //一旦AW 握手成功  W通道必须给足够的数据
            // finish current AXI burst

            if (m_axi_wready_int) begin
                // update counters
                if (input_active_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
                end
                input_last_cycle_next = input_cycle_count_next == 0;
                output_cycle_count_next = output_cycle_count_reg - 1;
                output_last_cycle_next = output_cycle_count_next == 0;

                m_axi_wdata_int = {AXI_DATA_WIDTH{1'b0}};
                m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b0}};
                m_axi_wvalid_int = 1'b1;

                if (output_last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    m_axi_wlast_int = 1'b1;

                    s_axis_write_data_tready_next = 1'b0;
                    s_axis_write_desc_ready_next = enable && active_count_av_reg;
                    state_next = STATE_IDLE;
                end else begin
                    // more cycles in AXI transfer
                    state_next = STATE_FINISH_BURST;
                end
            end else begin
                state_next = STATE_FINISH_BURST;
            end
        end
        STATE_DROP_DATA: begin //处理overrun 即上游设备超发的数据（可能会在一开始设定好的size之上超发一些数据） （不能直接拒绝接收，因为可能会让上游IP的fifo堵死，导致数据丢失？）
            // drop excess AXI stream data
            s_axis_write_data_tready_next = shift_axis_input_tready;

            if (shift_axis_tvalid) begin
                if (s_axis_write_data_tready && s_axis_write_data_tvalid) begin
                    transfer_in_save = 1'b1; //数据只在shift reg中流转，不会通过AXI到达下游   只要m_axi_wvalid_int没有被拉高  数据就不会往后走
                end

                if (shift_axis_tlast) begin //上游的overrun结束了
                    s_axis_write_data_tready_next = 1'b0;
                    s_axis_write_desc_ready_next = enable && active_count_av_reg; // 允许接收来自cpu的新descriptor
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DROP_DATA;
                end
            end else begin
                state_next = STATE_DROP_DATA;
            end
        end
    endcase

    if (status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin //把status中的状态反馈给CPU？
        // status FIFO not empty
        if (m_axi_bready && m_axi_bvalid) begin
            // got write completion, pop and return status
            m_axis_write_desc_status_len_next = status_fifo_len[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            m_axis_write_desc_status_tag_next = status_fifo_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            m_axis_write_desc_status_id_next = status_fifo_id[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            m_axis_write_desc_status_dest_next = status_fifo_dest[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            m_axis_write_desc_status_user_next = status_fifo_user[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            if (bresp_next == AXI_RESP_SLVERR) begin
                m_axis_write_desc_status_error_next = DMA_ERROR_AXI_WR_SLVERR;
            end else if (bresp_next == AXI_RESP_DECERR) begin
                m_axis_write_desc_status_error_next = DMA_ERROR_AXI_WR_DECERR;
            end else begin
                m_axis_write_desc_status_error_next = DMA_ERROR_NONE;
            end
            m_axis_write_desc_status_valid_next = status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]]; // 释放descriptor资源  可以去处理下一个descriptor了？
            status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;
            m_axi_bready_next = 1'b0;

            if (status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]]) begin
                bresp_next = AXI_RESP_OKAY;
            end

            dec_active = 1'b1;
        end else begin
            // wait for write completion
            m_axi_bready_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axis_write_desc_ready_reg <= s_axis_write_desc_ready_next;

    m_axis_write_desc_status_len_reg <= m_axis_write_desc_status_len_next;
    m_axis_write_desc_status_tag_reg <= m_axis_write_desc_status_tag_next;
    m_axis_write_desc_status_id_reg <= m_axis_write_desc_status_id_next;
    m_axis_write_desc_status_dest_reg <= m_axis_write_desc_status_dest_next;
    m_axis_write_desc_status_user_reg <= m_axis_write_desc_status_user_next;
    m_axis_write_desc_status_error_reg <= m_axis_write_desc_status_error_next;
    m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;

    s_axis_write_data_tready_reg <= s_axis_write_data_tready_next;

    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;
    m_axi_bready_reg <= m_axi_bready_next;

    addr_reg <= addr_next;
    offset_reg <= offset_next;
    strb_offset_mask_reg <= strb_offset_mask_next;
    zero_offset_reg <= zero_offset_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    length_reg <= length_next;
    op_word_count_reg <= op_word_count_next;
    tr_word_count_reg <= tr_word_count_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    first_cycle_reg <= first_cycle_next;
    input_last_cycle_reg <= input_last_cycle_next;
    output_last_cycle_reg <= output_last_cycle_next;
    last_transfer_reg <= last_transfer_next;
    bresp_reg <= bresp_next;

    tag_reg <= tag_next;
    axis_id_reg <= axis_id_next;
    axis_dest_reg <= axis_dest_next;
    axis_user_reg <= axis_user_next;

    // datapath
    if (flush_save) begin
        save_axis_tkeep_reg <= {AXIS_KEEP_WIDTH_INT{1'b0}};
        save_axis_tlast_reg <= 1'b0;
        shift_axis_extra_cycle_reg <= 1'b0;
    end else if (transfer_in_save) begin
        save_axis_tdata_reg <= s_axis_write_data_tdata;
        save_axis_tkeep_reg <= AXIS_KEEP_ENABLE ? s_axis_write_data_tkeep : {AXIS_KEEP_WIDTH_INT{1'b1}};
        save_axis_tlast_reg <= s_axis_write_data_tlast;
        shift_axis_extra_cycle_reg <= s_axis_write_data_tlast & ((s_axis_write_data_tkeep >> (AXIS_KEEP_WIDTH_INT-offset_reg)) != 0); // 为了解决非对齐时间差  最后需要额外一拍来处理shift reg中的残留数据
    end

    if (status_fifo_we) begin
        status_fifo_len[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_len; //吧当前transaction的数据压入RAM
        status_fifo_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_tag;
        status_fifo_id[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_id;
        status_fifo_dest[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_dest;
        status_fifo_user[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_user;
        status_fifo_last[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_last;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    if (active_count_reg < 2**STATUS_FIFO_ADDR_WIDTH && inc_active && !dec_active) begin  //记录的是transaction！  可以有多个在途descriptor  也可以有多个在途transaction
        active_count_reg <= active_count_reg + 1;
        active_count_av_reg <= active_count_reg < (2**STATUS_FIFO_ADDR_WIDTH-1);
    end else if (active_count_reg > 0 && !inc_active && dec_active) begin
        active_count_reg <= active_count_reg - 1;
        active_count_av_reg <= 1'b1;
    end else begin
        active_count_av_reg <= active_count_reg < 2**STATUS_FIFO_ADDR_WIDTH;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axis_write_desc_ready_reg <= 1'b0;
        m_axis_write_desc_status_valid_reg <= 1'b0;

        s_axis_write_data_tready_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;

        bresp_reg <= AXI_RESP_OKAY;

        save_axis_tlast_reg <= 1'b0;
        shift_axis_extra_cycle_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= 0;
        status_fifo_rd_ptr_reg <= 0;

        active_count_reg <= 0;
        active_count_av_reg <= 1'b1;
    end
end

// output datapath logic
reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg  = {AXI_DATA_WIDTH{1'b0}};
reg [AXI_STRB_WIDTH-1:0] m_axi_wstrb_reg  = {AXI_STRB_WIDTH{1'b0}};
reg                      m_axi_wlast_reg  = 1'b0;
reg                      m_axi_wvalid_reg = 1'b0;

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}}); //异步fifo？
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_DATA_WIDTH-1:0] out_fifo_wdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_STRB_WIDTH-1:0] out_fifo_wstrb[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg                      out_fifo_wlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axi_wready_int = !out_fifo_half_full_reg; // 不用full 反压  因为有可能有在途的  用half full 反压比较安全

assign m_axi_wdata  = m_axi_wdata_reg; //这是DMA对下游暴露出来的真正接口
assign m_axi_wstrb  = m_axi_wstrb_reg;
assign m_axi_wvalid = m_axi_wvalid_reg;
assign m_axi_wlast  = m_axi_wlast_reg;

always @(posedge clk) begin
    m_axi_wvalid_reg <= m_axi_wvalid_reg && !m_axi_wready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axi_wvalid_int) begin // DMA往AXI的输出有效
        out_fifo_wdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wdata_int; // 数据存入fifo
        out_fifo_wstrb[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wstrb_int;
        out_fifo_wlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wlast_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axi_wvalid_reg || m_axi_wready)) begin
        m_axi_wdata_reg <= out_fifo_wdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]]; // 左边是暴露给下游的接口  这样数据就从fifo中去到下游
        m_axi_wstrb_reg <= out_fifo_wstrb[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wlast_reg <= out_fifo_wlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wvalid_reg <= 1'b1;
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axi_wvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
