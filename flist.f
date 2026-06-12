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

// --- 验证环境与顶层 (Testbench) ---
./tests/base_test.sv
./tb/top_tb.sv
