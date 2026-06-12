interface axi_dma_if #(
    parameter AXI_DATA_WIDTH  = 32,
    parameter AXI_ADDR_WIDTH  = 16,
    parameter AXI_STRB_WIDTH  = AXI_DATA_WIDTH / 8,
    parameter AXI_ID_WIDTH    = 8,
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8,
    parameter AXIS_ID_WIDTH   = 8,
    parameter AXIS_DEST_WIDTH = 8,
    parameter AXIS_USER_WIDTH = 1,
    parameter LEN_WIDTH       = 20,
    parameter TAG_WIDTH       = 8
) (
    input clk,
    input rst
);
  // this interface connect DUT "axi_dma" to the whole verification component
  // axi read descriptor input 
  logic [AXI_ADDR_WIDTH-1:0] s_axis_read_desc_addr;
  logic [LEN_WIDTH-1:0] s_axis_read_desc_len;
  logic [TAG_WIDTH-1:0] s_axis_read_desc_tag;
  logic [AXIS_ID_WIDTH-1:0] s_axis_read_desc_id;
  logic [AXIS_DEST_WIDTH-1:0] s_axis_read_desc_dest;
  logic [AXIS_USER_WIDTH-1:0] s_axis_read_desc_user;
  logic s_axis_read_desc_valid;
  logic s_axis_read_desc_ready;

  // axi read descriptor status output 
  logic [TAG_WIDTH-1:0] m_axis_read_desc_status_tag;
  logic [3:0] m_axis_read_desc_status_error;
  logic m_axis_read_desc_status_valid;

  // axi stream read data ouput 
  logic [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata;
  logic [AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep;
  logic m_axis_read_data_tvalid;
  logic m_axis_read_data_tready;
  logic m_axis_read_data_tlast;
  logic [AXIS_ID_WIDTH-1:0] m_axis_read_data_tid;
  logic [AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest;
  logic [AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser;

  // axi write descriptor input 
  logic [AXI_ADDR_WIDTH-1:0] s_axis_write_desc_addr;
  logic [LEN_WIDTH-1:0] s_axis_write_desc_len;
  logic [TAG_WIDTH-1:0] s_axis_write_desc_tag;
  logic s_axis_write_desc_valid;
  logic s_axis_write_desc_ready;

  // axi write descriptor status output 
  logic [LEN_WIDTH-1:0] m_axis_write_desc_status_len;
  logic [TAG_WIDTH-1:0] m_axis_write_desc_status_tag;
  logic [AXIS_ID_WIDTH-1:0] m_axis_write_desc_status_id;
  logic [AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest;
  logic [AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user;
  logic [3:0] m_axis_write_desc_status_error;
  logic m_axis_write_desc_status_valid;

  // axi stream write data input
  logic [AXIS_DATA_WIDTH-1:0] s_axis_write_data_tdata;
  logic [AXIS_KEEP_WIDTH-1:0] s_axis_write_data_tkeep;
  logic s_axis_write_data_tvalid;
  logic s_axis_write_data_tready;
  logic s_axis_write_data_tlast;
  logic [AXIS_ID_WIDTH-1:0] s_axis_write_data_tid;
  logic [AXIS_DEST_WIDTH-1:0] s_axis_write_data_tdest;
  logic [AXIS_USER_WIDTH-1:0] s_axis_write_data_tuser;

  // axi master interface
  // axi master address write channel
  logic [AXI_ID_WIDTH-1:0] m_axi_awid;
  logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
  logic [7:0] m_axi_awlen;
  logic [2:0] m_axi_awsize;
  logic [1:0] m_axi_awburst;  // determine the style of burst 
  logic m_axi_awlock;
  logic [3:0] m_axi_awcache;
  logic [2:0] m_axi_awprot;
  logic m_axi_awvalid;
  logic m_axi_awready;

  // axi master data write channel
  logic [AXI_DATA_WIDTH-1:0] m_axi_wdata;
  logic [AXI_STRB_WIDTH-1:0] m_axi_wstrb;
  logic m_axi_wlast;
  logic m_axi_wvalid;
  logic m_axi_wready;

  // axi master response write channel
  logic [AXI_ID_WIDTH-1:0] m_axi_bid;
  logic [1:0] m_axi_bresp;
  logic m_axi_bvalid;
  logic m_axi_bready;

  // axi master address read channel
  logic [AXI_ID_WIDTH-1:0] m_axi_arid;
  logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
  logic [7:0] m_axi_arlen;
  logic [2:0] m_axi_arsize;
  logic [1:0] m_axi_arburst;
  logic m_axi_arlock;
  logic [3:0] m_axi_arcache;
  logic [2:0] m_axi_arprot;  // protection
  logic m_axi_arvalid;
  logic m_axi_arready;

  // axi master data read channel
  logic [AXI_ID_WIDTH-1:0] m_axi_rid;
  logic [AXI_DATA_WIDTH-1:0] m_axi_rdata;
  logic [1:0] m_axi_rresp;
  logic m_axi_rlast;
  logic m_axi_rvalid;
  logic m_axi_rready;

  // config
  logic read_enable;
  logic write_enable;
  logic write_abort;


  // modport for DUT
  //use it when initialize axi_dma
  modport dut_mp(
      input clk,
      input rst,

      input s_axis_read_desc_addr,
      input s_axis_read_desc_len,
      input s_axis_read_desc_tag,
      input s_axis_read_desc_id,
      input s_axis_read_desc_dest,
      input s_axis_read_desc_user,
      input s_axis_read_desc_valid,
      output s_axis_read_desc_ready,

      output m_axis_read_desc_status_tag,
      output m_axis_read_desc_status_error,
      output m_axis_read_desc_status_valid,

      output m_axis_read_data_tdata,
      output m_axis_read_data_tkeep,
      output m_axis_read_data_tvalid,
      input m_axis_read_data_tready,
      output m_axis_read_data_tlast,
      output m_axis_read_data_tid,
      output m_axis_read_data_tdest,
      output m_axis_read_data_tuser,

      input s_axis_write_desc_addr,
      input s_axis_write_desc_len,
      input s_axis_write_desc_tag,
      input s_axis_write_desc_valid,
      output s_axis_write_desc_ready,

      output m_axis_write_desc_status_len,
      output m_axis_write_desc_status_tag,
      output m_axis_write_desc_status_id,
      output m_axis_write_desc_status_dest,
      output m_axis_write_desc_status_user,
      output m_axis_write_desc_status_error,
      output m_axis_write_desc_status_valid,

      input s_axis_write_data_tdata,
      input s_axis_write_data_tkeep,
      input s_axis_write_data_tvalid,
      output s_axis_write_data_tready,
      input s_axis_write_data_tlast,
      input s_axis_write_data_tid,
      input s_axis_write_data_tdest,
      input s_axis_write_data_tuser,

      output m_axi_awid,
      output m_axi_awaddr,
      output m_axi_awlen,
      output m_axi_awsize,
      output m_axi_awburst,
      output m_axi_awlock,
      output m_axi_awcache,
      output m_axi_awprot,
      output m_axi_awvalid,
      input m_axi_awready,

      output m_axi_wdata,
      output m_axi_wstrb,
      output m_axi_wlast,
      output m_axi_wvalid,
      input m_axi_wready,

      input m_axi_bid,
      input m_axi_bresp,
      input m_axi_bvalid,
      output m_axi_bready,

      output m_axi_arid,
      output m_axi_araddr,
      output m_axi_arlen,
      output m_axi_arsize,
      output m_axi_arburst,
      output m_axi_arlock,
      output m_axi_arcache,
      output m_axi_arprot,
      output m_axi_arvalid,
      input m_axi_arready,

      input m_axi_rid,
      input m_axi_rdata,
      input m_axi_rresp,
      input m_axi_rlast,
      input m_axi_rvalid,
      output m_axi_rready,

      input read_enable,
      input write_enable,
      input write_abort
  );

  // read descriptor driver modport
  modport rd_desc_drv_mp(
      input clk,
      input rst,

      output s_axis_read_desc_addr,
      output s_axis_read_desc_len,
      output s_axis_read_desc_tag,
      output s_axis_read_desc_id,
      output s_axis_read_desc_dest,
      output s_axis_read_desc_user,
      output s_axis_read_desc_valid,
      input s_axis_read_desc_ready,

      output read_enable
  );

  // write descriptor driver modport
  modport wr_desc_drv_mp(
      input clk,
      input rst,

      output s_axis_write_desc_addr,
      output s_axis_write_desc_len,
      output s_axis_write_desc_tag,
      output s_axis_write_desc_valid,
      input s_axis_write_desc_ready,

      output write_enable,
      output write_abort
  );

  // axis write data driver modport
  modport axis_wr_data_drv_mp(
      input clk,
      input rst,

      output s_axis_write_data_tdata,
      output s_axis_write_data_tkeep,
      output s_axis_write_data_tvalid,
      input s_axis_write_data_tready,
      output s_axis_write_data_tlast,
      output s_axis_write_data_tid,
      output s_axis_write_data_tdest,
      output s_axis_write_data_tuser
  );

  // axis read data monitor modport
  modport axis_rd_data_mon_mp(
      input clk,
      input rst,

      input m_axis_read_data_tdata,
      input m_axis_read_data_tkeep,
      input m_axis_read_data_tvalid,
      input m_axis_read_data_tready,
      input m_axis_read_data_tlast,
      input m_axis_read_data_tid,
      input m_axis_read_data_tdest,
      input m_axis_read_data_tuser
  );

  // read status monitor modport
  modport rd_status_mon_mp(
      input clk,
      input rst,

      input m_axis_read_desc_status_tag,
      input m_axis_read_desc_status_error,
      input m_axis_read_desc_status_valid
  );

  // write status monitor modport
  modport wr_status_mon_mp(
      input clk,
      input rst,

      input m_axis_write_desc_status_len,
      input m_axis_write_desc_status_tag,
      input m_axis_write_desc_status_id,
      input m_axis_write_desc_status_dest,
      input m_axis_write_desc_status_user,
      input m_axis_write_desc_status_error,
      input m_axis_write_desc_status_valid
  );

  // axi memory responder modport
  // for memory model
  modport axi_mem_rsp_mp(
      input clk,
      input rst,

      input m_axi_awid,
      input m_axi_awaddr,
      input m_axi_awlen,
      input m_axi_awsize,
      input m_axi_awburst,
      input m_axi_awlock,
      input m_axi_awcache,
      input m_axi_awprot,
      input m_axi_awvalid,
      output m_axi_awready,

      input m_axi_wdata,
      input m_axi_wstrb,
      input m_axi_wlast,
      input m_axi_wvalid,
      output m_axi_wready,

      output m_axi_bid,
      output m_axi_bresp,
      output m_axi_bvalid,
      input m_axi_bready,

      input m_axi_arid,
      input m_axi_araddr,
      input m_axi_arlen,
      input m_axi_arsize,
      input m_axi_arburst,
      input m_axi_arlock,
      input m_axi_arcache,
      input m_axi_arprot,
      input m_axi_arvalid,
      output m_axi_arready,

      output m_axi_rid,
      output m_axi_rdata,
      output m_axi_rresp,
      output m_axi_rlast,
      output m_axi_rvalid,
      input m_axi_rready

  );


endinterface  //axi_dma_if

