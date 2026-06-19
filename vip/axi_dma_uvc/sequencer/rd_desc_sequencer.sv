// Milestone 4: rd_desc_sequencer
//
// Engineering goal:
// Build a real UVC-style sequencer for the AXI DMA read descriptor channel.
// This first version is intentionally small, but it is not a toy: in a
// production UVM environment, a simple per-interface sequencer often starts
// exactly like this and grows only when a real need appears.
//
// Role in the final verification environment:
//
//   rd_desc_sequence
//       creates dma_rd_desc_item
//       |
//       v
//   rd_desc_sequencer
//       arbitrates and provides items
//       |
//       v
//   rd_desc_driver
//       converts item into s_axis_read_desc_* handshakes
//       |
//       v
//   axi_dma_rd DUT
//
// What belongs in a sequencer:
// - The transaction type binding: uvm_sequencer #(dma_rd_desc_item#()).
// - Factory registration.
// - Component constructor.
// - Optional debug/build logs while the environment is growing.
// - Later, optional response routing or extra arbitration policy if needed.
//
// What does NOT belong in a sequencer:
// - DUT/interface signal access.
// - valid/ready timing.
// - descriptor field assignment policy.
// - scoreboard checks.
//
// Those belong to driver, sequence, or scoreboard respectively.

// UVM package and macro support:
// - uvm_sequencer and uvm_component are in uvm_pkg.
// - `uvm_component_utils and `uvm_info are macros from uvm_macros.svh.
//
// Common mistakes to remember:
// - Do not write "#import"; SystemVerilog uses "import".
// - Do not omit the macro include if you use `uvm_component_utils.
import uvm_pkg::*;
`include "uvm_macros.svh"

// Compile-order dependency:
// rd_desc_sequencer will reference dma_rd_desc_item#().
// Therefore flist.f must compile:
//
//   ./vip/axi_dma_uvc/seq_item/dma_rd_desc_item.sv
//   ./vip/axi_dma_uvc/sequencer/rd_desc_sequencer.sv
//
class rd_desc_sequencer extends uvm_sequencer#(dma_rd_desc_item#());
    `uvm_component_utils(rd_desc_sequencer)

    function new(string name = "rd_desc_sequencer",uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase); 
        super.build_phase(phase);
        `uvm_info("RD_DESC_SEQUENCER","build_phase entered", UVM_LOW)
    endfunction
endclass //rd_desc_sequencer extends uvm_sequencer

// TODO LATER 1: sequence response policy.
//
// Most simple drivers only call item_done() with no response.
// If later tests need descriptor-level responses, we can add response support
// using put_response()/get_response() or response fields.  Do not add that
// until a real test requires it.


// TODO LATER 2: arbitration and virtual sequences.
//
// If multiple sequences try to use this sequencer at once, UVM sequencer
// arbitration becomes relevant.  For early directed tests, one sequence at a
// time is enough.  Later virtual sequences may coordinate:
// - read descriptor sequence
// - AXI memory behavior
// - AXIS backpressure sequence
//
// The sequencer can remain simple unless those scenarios demand more.


// Local acceptance criteria:
// - No DUT/interface signals are mentioned in executable code.
// - No valid/ready logic is written here.
// - The class extends uvm_sequencer #(dma_rd_desc_item#()).
// - The class uses `uvm_component_utils(rd_desc_sequencer).
// - The constructor has both name and parent and calls super.new(name, parent).
// - The file compiles when placed after dma_rd_desc_item.sv in flist.f.
