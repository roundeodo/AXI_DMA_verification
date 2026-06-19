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

  // axi stream read data output 
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

  // Clocking block: read descriptor driver timing view
  //
  // The read descriptor driver is a testbench component.  It should drive and
  // sample this synchronous interface at well-defined clocking points, instead
  // of changing signals at arbitrary simulation times.  This clocking block is
  // the timing view used by rd_desc_driver:
  //
  //   @(rd_desc_drv_cb);
  //   rd_desc_drv_cb.s_axis_read_desc_valid <= 1'b1;
  //
  // This is cleaner than scattering:
  //
  //   @(posedge clk);
  //   s_axis_read_desc_valid <= 1'b1;
  //
  // throughout the driver.
  //
  // What input/output means in a clocking block:
  // - output: signals driven by the testbench driver.
  // - input : signals sampled by the testbench driver.
  //
  // For rd_desc_drv_cb:
  // - output payload/valid/read_enable because the driver drives them.
  // - input ready/rst because the driver only observes them.
  //
  // - input #1step samples stable values just before the clocking event.
  // - output #1ns drives after the clock edge, reducing TB/DUT race risk.
  clocking rd_desc_drv_cb @(posedge clk);
    default input #1step output #1ns;
    
    output s_axis_read_desc_addr;
    output s_axis_read_desc_len;
    output s_axis_read_desc_tag;
    output s_axis_read_desc_id;
    output s_axis_read_desc_dest;
    output s_axis_read_desc_user;
    output s_axis_read_desc_valid;

    output read_enable;
    input s_axis_read_desc_ready;
    input rst;
  endclocking

  // The driver should access descriptor signals through:
  //
  //   rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_addr
  //
  // instead of directly:
  //
  //   rd_desc_vif.s_axis_read_desc_addr
  // read descriptor driver modport
  modport rd_desc_drv_mp(
      clocking rd_desc_drv_cb,
      input clk,
      input rst
  );

  // cb  
  clocking wr_desc_drv_cb @(posedge clk);
    default input #1step output #1ns;
    input rst;

    output s_axis_write_desc_addr;
    output s_axis_write_desc_len;
    output s_axis_write_desc_tag;
    output s_axis_write_desc_valid;
    input s_axis_write_desc_ready;

    output write_enable;
    output write_abort;
  endclocking
  // write descriptor driver modport
  modport wr_desc_drv_mp(
    clocking wr_desc_drv_cb,
    input clk,
    input rst
  );


  // cb
  clocking axis_wr_data_drv_cb @(posedge clk);
    default input #1step output #1ns;
    input rst;

    output s_axis_write_data_tdata;
    output s_axis_write_data_tkeep;
    output s_axis_write_data_tvalid;
    input s_axis_write_data_tready;
    output s_axis_write_data_tlast;
    output s_axis_write_data_tid;
    output s_axis_write_data_tdest;
    output s_axis_write_data_tuser;
  endclocking

  // axis write data driver modport
  modport axis_wr_data_drv_mp(
    clocking axis_wr_data_drv_cb,
    input clk,
    input rst
  );

  // cb
  clocking axis_rd_data_mon_cb @(posedge clk);
    default input #1step output #1ns;
    input rst;

    input m_axis_read_data_tdata;
    input m_axis_read_data_tkeep;
    input m_axis_read_data_tvalid;
    input m_axis_read_data_tready;
    input m_axis_read_data_tlast;
    input m_axis_read_data_tid;
    input m_axis_read_data_tdest;
    input m_axis_read_data_tuser;
  endclocking 

  // axis read data monitor modport
  modport axis_rd_data_mon_mp(
    clocking axis_rd_data_mon_cb,
    input clk,
    input rst
  );

  // cb
  clocking rd_status_mon_cb @(posedge clk);
    default input #1step output #1ns;
    input rst;

    input m_axis_read_desc_status_tag;
    input m_axis_read_desc_status_error;
    input m_axis_read_desc_status_valid;
  endclocking

  // read status monitor modport
  modport rd_status_mon_mp(
    clocking rd_status_mon_cb,
    input clk,
    input rst
  );

  // cb
  clocking wr_status_mon_cb @(posedge clk);
    default input #1step output #1ns;
    input rst;

    input m_axis_write_desc_status_len;
    input m_axis_write_desc_status_tag;
    input m_axis_write_desc_status_id;
    input m_axis_write_desc_status_dest;
    input m_axis_write_desc_status_user;
    input m_axis_write_desc_status_error;
    input m_axis_write_desc_status_valid;
  endclocking

  // write status monitor modport
  modport wr_status_mon_mp(
    clocking wr_status_mon_cb,
    input clk,
    input rst
  );


  // AXI memory note:
  //
  // We originally planned a UVM AXI memory responder that would drive
  // m_axi_arready and m_axi_r* through a clocking block.  The current testbench
  // instead instantiates the library RTL axi_ram directly in top_tb.  Because
  // clocking block outputs are also drivers, keeping an unused responder
  // clocking block here would create multiple drivers on the same signals.
  //
  // If we later replace axi_ram with a UVM AXI slave responder, add a dedicated
  // responder modport back and remove the RTL axi_ram connection at the same
  // time.  Only one component may drive the AXI slave response signals.


endinterface  //axi_dma_if
