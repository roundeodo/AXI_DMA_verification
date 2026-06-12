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

    initial begin
        dma_if.s_axis_read_desc_addr  = '0;
        dma_if.s_axis_read_desc_len   = '0;
        dma_if.s_axis_read_desc_tag   = '0;
        dma_if.s_axis_read_desc_id    = '0;
        dma_if.s_axis_read_desc_dest  = '0;
        dma_if.s_axis_read_desc_user  = '0;
        dma_if.s_axis_read_desc_valid = 1'b0;

        dma_if.m_axis_read_data_tready = 1'b1;

        dma_if.m_axi_arready = 1'b0;
        dma_if.m_axi_rid     = '0;
        dma_if.m_axi_rdata   = '0;
        dma_if.m_axi_rresp   = 2'b00;
        dma_if.m_axi_rlast   = 1'b0;
        dma_if.m_axi_rvalid  = 1'b0;

        dma_if.read_enable = 1'b0;

        uvm_config_db#(virtual axi_dma_if)::set(null, "uvm_test_top", "vif", dma_if);
        run_test("base_test");
    end

endmodule
