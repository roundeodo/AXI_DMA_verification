// Milestone 10C: rd_smoke_test TODO scaffold
//
// Engineering goal:
// Create the first real test that starts a sequence.
//
// base_test builds the reusable environment:
//
//   top_tb -> run_test -> base_test -> env -> agent/driver/monitors/ref/scoreboard
//
// rd_smoke_test adds one specific scenario:
//
//   start rd_desc_smoke_sequence on env.rd_agent.sequencer
//
// Why derived test:
// Keep base_test reusable and boring.  Real verification projects usually put
// common environment construction/configuration in base_test, while each
// concrete test extends it and starts scenario-specific sequences.

// TODO 1: import UVM and include macros.
//
// Write:
//
import uvm_pkg::*;
`include "uvm_macros.svh"


// TODO 2: understand compile-order dependencies.
//
// This test uses:
// - base_test
// - rd_desc_smoke_sequence
//
// Therefore flist.f must compile:
//
//   rd_desc_smoke_sequence.sv
//   base_test.sv
//   rd_smoke_test.sv
//
// before top_tb.sv.


// TODO 3: write the class header.
//
// Suggested header:
//
//   class rd_smoke_test extends base_test;
//
// Meaning:
// This test inherits the env construction and configuration from base_test.
// It only changes the run behavior by starting a smoke sequence.
class rd_smoke_test extends base_test;
    `uvm_component_utils(rd_smoke_test)

    function new(string name = "rd_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    virtual task run_phase(uvm_phase phase);
        rd_desc_smoke_sequence seq;
        phase.raise_objection(this);
        `uvm_info("RD_SMOKE_TEST", "run_phase entered", UVM_LOW)

        seq = rd_desc_smoke_sequence::type_id::create("seq");

        seq.start(env.rd_agent.sequencer);

        #500ns;

        phase.drop_objection(this);
        
    endtask //
endclass //rd_smoke_test extends base_test


// TODO 4: register with the factory.
//
// Put inside the class:
//
//   `uvm_component_utils(rd_smoke_test)
//
// Why:
// UVM needs factory registration so +UVM_TESTNAME=rd_smoke_test can create this
// class by name.


// TODO 5: add the standard component constructor.
//
// Suggested code:
//
//   function new(string name = "rd_smoke_test",
//                uvm_component parent = null);
//       super.new(name, parent);
//   endfunction


// TODO 6: write run_phase.
//
// Suggested code shape:
//
//   virtual task run_phase(uvm_phase phase);
//       rd_desc_smoke_sequence seq;
//
//       phase.raise_objection(this);
//
//       `uvm_info("RD_SMOKE_TEST", "run_phase entered", UVM_LOW)
//
//       seq = rd_desc_smoke_sequence::type_id::create("seq");
//
//       seq.start(env.rd_agent.sequencer);
//
//       #500ns;
//
//       phase.drop_objection(this);
//   endtask
//
// Why no super.run_phase(phase):
// base_test.run_phase currently raises an objection and waits for 100ns as a
// skeleton placeholder.  This derived test replaces that behavior with the real
// smoke sequence.  Calling super.run_phase() would run the placeholder wait too.
//
// Why start on env.rd_agent.sequencer:
// rd_desc_smoke_sequence produces dma_rd_desc_item transactions.  The matching
// sequencer is inside the active read descriptor agent.
//
// Why wait after sequence:
// seq.start() returns after the driver has accepted the sequence item, but the
// DMA still needs time to issue AXI reads, return AXIS data, and emit status.
// The first version uses a fixed wait; later the scoreboard can decide when the
// test is done.


// TODO 7: update flist.f after this file is complete.
//
// Add:
//
//   ./tests/rd_smoke_test.sv
//
// after base_test.sv and before top_tb.sv.


// TODO 8: choose the test from the simulator command line.
//
// Recommended change:
// In top_tb.sv, use:
//
//   run_test();
//
// instead of:
//
//   run_test("base_test");
//
// Then run:
//
//   vsim -c -do uvm_start.do +UVM_TESTNAME=rd_smoke_test
//
// Why:
// This lets you switch tests without editing top_tb every time.
