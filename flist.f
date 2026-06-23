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
./vip/axi_dma_uvc/seq_item/axis_rd_data_item.sv
./vip/axi_dma_uvc/seq_item/rd_status_item.sv
// TODO MON-5: after env declares monitor types, uncomment these two monitor
// files so their classes are compiled before axi_dma_env.sv.
./vip/axi_dma_uvc/monitor/axis_rd_data_monitor.sv
./vip/axi_dma_uvc/monitor/rd_status_monitor.sv
// NEXT: after axi_dma_scoreboard.sv is completed, add it here before env.
./vip/axi_dma_uvc/scoreboard/axi_dma_scoreboard.sv
// TODO REF-4: after env declares axi_dma_rd_ref_model, uncomment this file so
// the class is compiled before axi_dma_env.sv.
./vip/axi_dma_uvc/model/axi_dma_rd_ref_model.sv
// TODO COV: complete axi_dma_rd_coverage.sv, then add it before axi_dma_env.sv.
./vip/axi_dma_uvc/coverage/axi_dma_rd_coverage.sv
// NEXT: after rd_desc_smoke_sequence.sv is completed, add it before tests.
./vip/axi_dma_uvc/sequence/rd_desc_smoke_sequence.sv
// TODO LEN: this file currently contains the teaching scaffold.  Complete the
// sequence class before running rd_len_sweep_test.
./vip/axi_dma_uvc/sequence/rd_len_sweep_sequence.sv
// TODO RAND-LEN: after rd_len_random_sequence.sv is complete, uncomment it.
// ./vip/axi_dma_uvc/sequence/rd_len_random_sequence.sv
./vip/axi_dma_uvc/sequencer/rd_desc_sequencer.sv
./vip/axi_dma_uvc/driver/rd_desc_driver.sv
./vip/axi_dma_uvc/agent/rd_desc_agent.sv
./vip/axi_dma_uvc/env/axi_dma_env.sv
./tests/base_test.sv
// NEXT: after rd_smoke_test.sv is completed, add it here before top_tb.
./tests/rd_smoke_test.sv
// TODO LEN: this file currently contains the teaching scaffold.  Complete the
// test class before running rd_len_sweep_test.
./tests/rd_len_sweep_test.sv
// TODO RAND-LEN: after rd_len_random_test.sv is complete, uncomment it.
// ./tests/rd_len_random_test.sv
./tb/top_tb.sv
