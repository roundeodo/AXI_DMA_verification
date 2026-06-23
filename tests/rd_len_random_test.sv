// Milestone 13B: rd_len_random_test TODO scaffold
//
// Engineering goal:
// Run the first constrained-random read-length scenario.
//
// Correct UVM layering:
//
//   rd_len_random_test
//       selects/configures the random length scenario
//       |
//       v
//   rd_len_random_sequence
//       randomizes and sends many descriptors
//       |
//       v
//   existing env/checker/coverage
//       proves data/status correctness and coverage
//
// This test does not manually create every descriptor.  It configures and starts
// a sequence, because the descriptor stream is stimulus behavior.

// TODO RAND-LEN-8: import UVM and include macros.
//
// Write:
//
//   import uvm_pkg::*;
//   `include "uvm_macros.svh"


// TODO RAND-LEN-9: create the test class.
//
// Suggested header:
//
//   class rd_len_random_test extends base_test;
//       `uvm_component_utils(rd_len_random_test)
//
// Why extend base_test:
// base_test builds and configures the reusable environment.  This derived test
// only changes run_phase by starting the random-length sequence.


// TODO RAND-LEN-10: add constructor.
//
// Suggested code:
//
//   function new(string name = "rd_len_random_test",
//                uvm_component parent = null);
//       super.new(name, parent);
//   endfunction


// TODO RAND-LEN-11: write run_phase.
//
// Suggested code:
//
//   virtual task run_phase(uvm_phase phase);
//       rd_len_random_sequence seq;
//
//       phase.raise_objection(this);
//
//       `uvm_info("RD_LEN_RANDOM_TEST", "run_phase entered", UVM_LOW)
//
//       seq = rd_len_random_sequence::type_id::create("seq");
//
//       seq.num_desc    = 50;
//       seq.base_addr   = 16'h2000;
//       seq.addr_stride = 16'h0100;
//       seq.min_len     = 20'd1;
//       seq.max_len     = 20'd128;
//       seq.base_tag    = 8'h40;
//
//       seq.start(env.rd_agent.sequencer);
//
//       #100us;
//
//       phase.drop_objection(this);
//   endtask
//
// Why #100us:
// This is a temporary end-of-test guard that gives the DMA time to complete many
// descriptors.  A real closure-quality environment should eventually end based
// on scoreboard/ref_model drain state instead of a fixed delay.


// TODO RAND-LEN-12: update flist.f after both classes are complete.
//
// Add the sequence before tests:
//
//   ./vip/axi_dma_uvc/sequence/rd_len_random_sequence.sv
//
// Add the test before top_tb:
//
//   ./tests/rd_len_random_test.sv
//
// Compile order matters because rd_len_random_test references
// rd_len_random_sequence.


// TODO RAND-LEN-13: run the random test.
//
// First run:
//
//   vsim -c -do "set TESTNAME rd_len_random_test; do uvm_start.do"
//
// Expected:
// - scoreboard mismatches = 0
// - no pending expected/actual data/status
// - coverage remains high for length/tkeep/frame bins
//
// Seed note:
// Questa controls SystemVerilog randomization through the simulation seed.  Our
// uvm_start.do does not yet expose a SEED variable.  After this test works once,
// the next real engineering step is to modify uvm_start.do or write a regression
// script so we can run this same test with multiple seeds.


// TODO RAND-LEN-LATER: replace fixed wait with scoreboard-aware end-of-test.
//
// The current tests use fixed waits after seq.start().  That is acceptable while
// learning, but it is not a closure-quality end condition.  Later the scoreboard
// or env should expose "all expected transactions drained" status so tests can
// finish as soon as checking is complete.

