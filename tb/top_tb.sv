`timescale 1ns/1ps

// 引入 UVM package 和 macro
import uvm_pkg::*;
`include "uvm_macros.svh"

module top_tb;
    logic clk;
    logic rst;

    initial begin
        clk = 0;
        forever begin
            #5 clk = ~clk;
        end
    end

    initial begin
        rst = 1;
        #20;
        rst = 0;
    end

    axi_dma_if dma_if (
        .clk(clk),
        .rst(rst)
    );

    axi_dma_rd dut (
        .clk(clk),
        .rst(rst),

        .s_axis_read_desc_addr(dma_if.s_axis_read_desc_addr),
        .s_axis_read_desc_len(dma_if.s_axis_read_desc_len),
        .s_axis_read_desc_tag(dma_if.s_axis_read_desc_tag),
        .s_axis_read_desc_id(dma_if.s_axis_read_desc_id),
        .s_axis_read_desc_dest(dma_if.s_axis_read_desc_dest),
        .s_axis_read_desc_user(dma_if.s_axis_read_desc_user),
        .s_axis_read_desc_valid(dma_if.s_axis_read_desc_valid),
        .s_axis_read_desc_ready(dma_if.s_axis_read_desc_ready),

        .m_axis_read_desc_status_tag(dma_if.m_axis_read_desc_status_tag),
        .m_axis_read_desc_status_error(dma_if.m_axis_read_desc_status_error),
        .m_axis_read_desc_status_valid(dma_if.m_axis_read_desc_status_valid),

        .m_axis_read_data_tdata(dma_if.m_axis_read_data_tdata),
        .m_axis_read_data_tkeep(dma_if.m_axis_read_data_tkeep),
        .m_axis_read_data_tvalid(dma_if.m_axis_read_data_tvalid),
        .m_axis_read_data_tready(dma_if.m_axis_read_data_tready),
        .m_axis_read_data_tlast(dma_if.m_axis_read_data_tlast),
        .m_axis_read_data_tid(dma_if.m_axis_read_data_tid),
        .m_axis_read_data_tdest(dma_if.m_axis_read_data_tdest),
        .m_axis_read_data_tuser(dma_if.m_axis_read_data_tuser),

        .m_axi_arid(dma_if.m_axi_arid),
        .m_axi_araddr(dma_if.m_axi_araddr),
        .m_axi_arlen(dma_if.m_axi_arlen),
        .m_axi_arsize(dma_if.m_axi_arsize),
        .m_axi_arburst(dma_if.m_axi_arburst),
        .m_axi_arlock(dma_if.m_axi_arlock),
        .m_axi_arcache(dma_if.m_axi_arcache),
        .m_axi_arprot(dma_if.m_axi_arprot),
        .m_axi_arvalid(dma_if.m_axi_arvalid),
        .m_axi_arready(dma_if.m_axi_arready),
        .m_axi_rid(dma_if.m_axi_rid),
        .m_axi_rdata(dma_if.m_axi_rdata),
        .m_axi_rresp(dma_if.m_axi_rresp),
        .m_axi_rlast(dma_if.m_axi_rlast),
        .m_axi_rvalid(dma_if.m_axi_rvalid),
        .m_axi_rready(dma_if.m_axi_rready),

        .enable(dma_if.read_enable)
    );

    // AXI RAM model from the same verilog-axi library as the DMA RTL.
    //
    // In the read-DMA milestone, axi_dma_rd is the AXI master and axi_ram is
    // the AXI slave memory.  The DMA issues AR requests through dma_if.m_axi_*,
    // and axi_ram returns R data beats.  The write channels are tied off for
    // now because axi_dma_rd does not use them.
    axi_ram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(16),
        .STRB_WIDTH(4),
        .ID_WIDTH(8),
        .PIPELINE_OUTPUT(0)
    ) axi_ram_inst (
        .clk(clk),
        .rst(rst),

        .s_axi_awid('0),
        .s_axi_awaddr('0),
        .s_axi_awlen('0),
        .s_axi_awsize('0),
        .s_axi_awburst(2'b01),
        .s_axi_awlock(1'b0),
        .s_axi_awcache('0),
        .s_axi_awprot('0),
        .s_axi_awvalid(1'b0),
        .s_axi_awready(),

        .s_axi_wdata('0),
        .s_axi_wstrb('0),
        .s_axi_wlast(1'b0),
        .s_axi_wvalid(1'b0),
        .s_axi_wready(),

        .s_axi_bid(),
        .s_axi_bresp(),
        .s_axi_bvalid(),
        .s_axi_bready(1'b1),

        .s_axi_arid(dma_if.m_axi_arid),
        .s_axi_araddr(dma_if.m_axi_araddr),
        .s_axi_arlen(dma_if.m_axi_arlen),
        .s_axi_arsize(dma_if.m_axi_arsize),
        .s_axi_arburst(dma_if.m_axi_arburst),
        .s_axi_arlock(dma_if.m_axi_arlock),
        .s_axi_arcache(dma_if.m_axi_arcache),
        .s_axi_arprot(dma_if.m_axi_arprot),
        .s_axi_arvalid(dma_if.m_axi_arvalid),
        .s_axi_arready(dma_if.m_axi_arready),

        .s_axi_rid(dma_if.m_axi_rid),
        .s_axi_rdata(dma_if.m_axi_rdata),
        .s_axi_rresp(dma_if.m_axi_rresp),
        .s_axi_rlast(dma_if.m_axi_rlast),
        .s_axi_rvalid(dma_if.m_axi_rvalid),
        .s_axi_rready(dma_if.m_axi_rready)
    );

    // The RTL axi_ram stores 32-bit words, but DMA descriptors use byte
    // addresses.  We need a deterministic byte pattern so the reference model
    // can predict exactly what the DMA should output.
    function automatic [7:0] smoke_mem_pattern(input int unsigned byte_addr);
        smoke_mem_pattern = byte_addr[7:0] ^ 8'hA5;
    endfunction

    // Why this pattern:
    // - non-zero, so bugs do not hide behind all-zero memory
    // - easy to reproduce in ref_model
    // - changes with address, so wrong address/byte order is visible

    // axi_ram has:
    //
    //   reg [DATA_WIDTH-1:0] mem[(2**VALID_ADDR_WIDTH)-1:0];
    //
    // With DATA_WIDTH=32, each mem[word_index] contains 4 byte lanes:
    //
    //   mem[word_index][7:0]    -> byte address word_index*4 + 0
    //   mem[word_index][15:8]   -> byte address word_index*4 + 1
    //   mem[word_index][23:16]  -> byte address word_index*4 + 2
    //   mem[word_index][31:24]  -> byte address word_index*4 + 3
    //
    // Important:
    // This is a testbench preload using hierarchical access.  It is acceptable
    // for this learning testbench, but it is not synthesizable RTL style.
    initial begin
        // Let axi_ram's own time-0 memory clear finish first, then overwrite it
        // with the smoke-test pattern before reset is released.
        #1ns;
        for(int word = 0; word < 2**axi_ram_inst.VALID_ADDR_WIDTH; word++)begin
            for(int lane = 0; lane < 4; lane++)begin
                axi_ram_inst.mem[word][8*lane +: 8] = smoke_mem_pattern(word*4 + lane);
            end
        end
    end

    initial begin
        dma_if.s_axis_read_desc_addr  = '0;
        dma_if.s_axis_read_desc_len   = '0;
        dma_if.s_axis_read_desc_tag   = '0;
        dma_if.s_axis_read_desc_id    = '0;
        dma_if.s_axis_read_desc_dest  = '0;
        dma_if.s_axis_read_desc_user  = '0;
        dma_if.s_axis_read_desc_valid = 1'b0;

        dma_if.m_axis_read_data_tready = 1'b1;

        dma_if.read_enable = 1'b0;

        uvm_config_db#(virtual axi_dma_if)::set(null, "uvm_test_top", "vif", dma_if);

        // Pass the read-descriptor driver view separately from the full
        // interface handle above.  The driver gets "rd_desc_vif" as a
        // modport-typed virtual interface, so it can only access the
        // descriptor signals it owns.
        uvm_config_db#(virtual axi_dma_if.rd_desc_drv_mp)::set(
            null,
            "uvm_test_top.*",
            "rd_desc_vif",
            dma_if.rd_desc_drv_mp
            );

        // TODO MON-1: pass monitor modport views into UVM.
        //
        // After axis_rd_data_monitor and rd_status_monitor are added to env,
        // set their virtual interface handles here.
        //
        // Add:
        //
        // uvm_config_db#(virtual axi_dma_if.axis_rd_data_mon_mp)::set(
        //     null,
        //     "uvm_test_top.*",
        //     "axis_rd_data_vif",
        //     dma_if.axis_rd_data_mon_mp
        // );
        //
        // uvm_config_db#(virtual axi_dma_if.rd_status_mon_mp)::set(
        //     null,
        //     "uvm_test_top.*",
        //     "rd_status_vif",
        //     dma_if.rd_status_mon_mp
        // );
        //
        // Why top_tb does this:
        // top_tb owns the real static interface instance.  UVM classes only get
        // virtual handles to selected modport views through uvm_config_db.
        uvm_config_db#(virtual axi_dma_if.axis_rd_data_mon_mp)::set(
            null,
            "uvm_test_top.*",
            "axis_rd_data_vif",
            dma_if.axis_rd_data_mon_mp
        );

        uvm_config_db#(virtual axi_dma_if.rd_status_mon_mp)::set(
            null,
            "uvm_test_top.*",
            "rd_status_vif",
            dma_if.rd_status_mon_mp
        );
        
        // TODO TEST-1: when rd_smoke_test is ready, switch this to run_test().
        //
        // Current form always runs base_test:
        //
        //   run_test("base_test");
        //
        // Better long-term form:
        //
        //   run_test();
        //
        // Then select tests from the simulator command line:
        //
        //   +UVM_TESTNAME=base_test
        //   +UVM_TESTNAME=rd_smoke_test
        //
        // This avoids editing top_tb each time you want to run a different
        // test scenario.
        run_test();
    end

endmodule
