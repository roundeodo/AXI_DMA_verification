// Milestone 11B: rd_len_sweep_test TODO scaffold
//
// Engineering goal:
// Select and run the read length-sweep scenario.
//
// Correct UVM layering:
//
//   rd_len_sweep_test
//       chooses the scenario and starts the sequence
//       |
//       v
//   rd_len_sweep_sequence
//       generates the ordered descriptor transaction stream
//       |
//       v
//   rd_desc_driver
//       drives descriptor pins
//
// The test should not manually generate each descriptor.  That belongs in the
// sequence.  This keeps tests high-level and lets sequences be reused.

// TODO LEN-9: import UVM and include macros.
//
// Write:
//
  import uvm_pkg::*;
  `include "uvm_macros.svh"


// TODO LEN-10: write the class header.
//
// Suggested header:
//
  class rd_len_sweep_test extends base_test;
//
// Register with:
//
  `uvm_component_utils(rd_len_sweep_test)


// TODO LEN-11: add constructor.
//
// Suggested code:
//
  function new(string name = "rd_len_sweep_test",
               uvm_component parent = null);
      super.new(name, parent);
  endfunction


// TODO LEN-12: write run_phase.
//
// Suggested code:
//
  virtual task run_phase(uvm_phase phase);
      rd_len_sweep_sequence seq;

      phase.raise_objection(this);

      `uvm_info("RD_LEN_SWEEP_TEST", "run_phase entered", UVM_LOW)

      seq = rd_len_sweep_sequence::type_id::create("seq");

      // Optional high-level scenario configuration:
      seq.base_addr = 16'h1000;
      seq.base_tag  = 8'h01;

      seq.start(env.rd_agent.sequencer);

      #1500ns;

      phase.drop_objection(this);
  endtask
//
// Why wait after sequence:
// seq.start() returns after all descriptors have been handed to the driver, but
// the DMA still needs time to complete AXI reads and status/data output.  Later
// we will replace fixed waits with scoreboard-driven end-of-test logic.
endclass

// TODO LEN-13: update flist.f.
//
// Add both files before top_tb:
//
//   ./vip/axi_dma_uvc/sequence/rd_len_sweep_sequence.sv
//   ./tests/rd_len_sweep_test.sv
//
// rd_len_sweep_sequence.sv must compile before rd_len_sweep_test.sv.


// TODO LEN-14: run the test.
//
// Use:
//
//   vsim -c -do "set TESTNAME rd_len_sweep_test; do uvm_start.do"
//
// Expected final report:
//
// - status matches = 8
// - data matches = total expected beats:
//   len 1  -> 1
//   len 2  -> 1
//   len 3  -> 1
//   len 4  -> 1
//   len 5  -> 2
//   len 15 -> 4
//   len 16 -> 4
//   len 17 -> 5
//   total  -> 19
// - mismatches = 0
