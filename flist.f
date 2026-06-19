// --- 包含路径 (Include Directories) ---
+incdir+./rtl
+incdir+./vip/axi_dma_uvc
+incdir+./tb
+incdir+./tests

// --- 接口文件 (Interface) ---
./vip/axi_dma_uvc/axi_dma_if.sv

// --- 设计文件 (RTL) ---
./rtl/axi_dma_rd.v
./rtl/axi_dma_wr.v
./rtl/axi_dma.v
./verilog-axi/rtl/axi_ram.v

// --- 验证环境与顶层 (Testbench) ---
./vip/axi_dma_uvc/seq_item/dma_rd_desc_item.sv
// NEXT: after you finish these monitor transaction items, uncomment/add them
// before the monitor files that will use them.
// ./vip/axi_dma_uvc/seq_item/axis_rd_data_item.sv
// ./vip/axi_dma_uvc/seq_item/rd_status_item.sv
./vip/axi_dma_uvc/sequencer/rd_desc_sequencer.sv
./vip/axi_dma_uvc/driver/rd_desc_driver.sv
./vip/axi_dma_uvc/agent/rd_desc_agent.sv
./vip/axi_dma_uvc/env/axi_dma_env.sv
./tests/base_test.sv
./tb/top_tb.sv
