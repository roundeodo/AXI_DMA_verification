// Milestone 10A: rd_desc_smoke_sequence TODO scaffold
//
// Engineering goal:
// Create the first real stimulus sequence for axi_dma_rd.
//
// This sequence sends exactly one directed read descriptor into rd_desc_driver
// through rd_desc_sequencer.
//
// Data flow:
//
//   rd_desc_smoke_sequence
//       |
//       v
//   rd_desc_sequencer
//       |
//       v
//   rd_desc_driver
//       |
//       v
//   axi_dma_rd.s_axis_read_desc_*
//
// Why a sequence now:
// Until now the driver exists, but it is blocked in get_next_item().  A sequence
// is the UVM object that creates a transaction and hands it to the sequencer.
// Once this sequence starts, the descriptor input path becomes active.
//
// Why directed, not random:
// The first smoke test should be deterministic and easy to debug in waves.
// Randomization comes after we have memory preload, monitors, and scoreboard
// checks working for one known descriptor.

// TODO 1: import UVM and include macros.
//
// Write:
//
  import uvm_pkg::*;
  `include "uvm_macros.svh"
//
// Why:
// - uvm_sequence is in uvm_pkg.
// - `uvm_object_utils and `uvm_info are macros.


// TODO 2: understand compile-order dependencies.
//
// This sequence uses:
// - dma_rd_desc_item#()
//
// Therefore flist.f must compile:
//
//   dma_rd_desc_item.sv
//   rd_desc_smoke_sequence.sv
//
// before any test file that creates this sequence.


// TODO 3: write the class header.
//
// Suggested header:
//
//   class rd_desc_smoke_sequence extends uvm_sequence #(dma_rd_desc_item#());
//
// Meaning:
// This sequence produces dma_rd_desc_item transactions.  The sequencer it runs
// on must be compatible with dma_rd_desc_item#(), which rd_desc_sequencer is.
class rd_desc_smoke_sequence extends uvm_sequence #(dma_rd_desc_item#());
    `uvm_object_utils(rd_desc_smoke_sequence)

    // TODO LEN-1: add configurable descriptor fields.
    //
    // The first smoke sequence hard-coded addr/len/tag/id/dest/user.  For
    // directed expansion, keep this sequence as a reusable "send one read
    // descriptor" sequence and let tests configure the values before start().
    //
    // Add class members:
    //
    bit [15:0] cfg_addr = 16'h1000;
    bit [19:0] cfg_len  = 20'd16;
    bit [7:0]  cfg_tag  = 8'h01;
    bit [7:0]  cfg_id   = 8'h01;
    bit [7:0]  cfg_dest = 8'h00;
    bit        cfg_user = 1'b0;
    //
    // Why cfg_ prefix:
    // These are sequence configuration knobs, not fields sampled from the DUT.
    // The sequence will copy them into the dma_rd_desc_item payload.

    function new(string name = "rd_desc_smoke_sequence");
        super.new(name);
    endfunction //new()

    virtual task body();
        dma_rd_desc_item#() req;

        `uvm_info("RD_DESC_SMOKE_SEQ", "body started", UVM_LOW)

        req = dma_rd_desc_item#()::type_id::create("req");

        start_item(req);

        // TODO LEN-2: replace hard-coded values with cfg_* members.
        //
        // Change these assignments to:
        //
        req.addr = cfg_addr;
        req.len  = cfg_len;
        req.tag  = cfg_tag;
        req.id   = cfg_id;
        req.dest = cfg_dest;
        req.user = cfg_user;
        //
        // This lets rd_smoke_test keep the old defaults, while
        // rd_len_sweep_test can run the same sequence with len=1,2,3,...

        finish_item(req);

        `uvm_info("RD_DESC_SMOKE_SEQ",
            $sformatf("sent descriptor addr=0x%0h len=%0d tag=0x%0h",
                      req.addr, req.len, req.tag),
            UVM_LOW)

        
    endtask //
endclass //rd_desc_smoke_sequence extends uvm_sequence #(dma_rd_desc_item#())

// TODO 4: register with the factory.
//
// Put inside the class:
//
//   `uvm_object_utils(rd_desc_smoke_sequence)
//
// Why object utils, not component utils:
// A sequence is a uvm_object, not a uvm_component.  It has no parent hierarchy
// and no build/connect/run phases.


// TODO 5: add the constructor.
//
// Suggested code:
//
//   function new(string name = "rd_desc_smoke_sequence");
//       super.new(name);
//   endfunction
//
// Why no parent:
// Sequences are objects.  They are started on sequencers, but they are not
// permanent UVM hierarchy components.


// TODO 6: write body().
//
// Suggested code shape:
//
//   virtual task body();
//       dma_rd_desc_item#() req;
//
//       `uvm_info("RD_DESC_SMOKE_SEQ", "body started", UVM_LOW)
//
//       req = dma_rd_desc_item#()::type_id::create("req");
//
//       start_item(req);
//
//       req.addr = 16'h1000;
//       req.len  = 20'd16;
//       req.tag  = 8'h01;
//       req.id   = 8'h01;
//       req.dest = 8'h00;
//       req.user = 1'b0;
//
//       finish_item(req);
//
//       `uvm_info("RD_DESC_SMOKE_SEQ",
//           $sformatf("sent descriptor addr=0x%0h len=%0d tag=0x%0h",
//                     req.addr, req.len, req.tag),
//           UVM_LOW)
//   endtask
//
// What start_item/finish_item mean:
// - start_item(req) asks the sequencer/driver pipeline for permission to send.
// - You fill the item fields before finish_item().
// - finish_item(req) hands the completed item to the sequencer so the driver
//   can receive it through get_next_item().
//
// Common mistake:
// Do not call driver methods directly from the sequence.  The sequence talks to
// the sequencer; the driver talks to pins.


// TODO LATER: replace direct assignments with randomization.
//
// Later, after the smoke path works, we can write:
//
//   assert(req.randomize() with {
//       addr == 16'h1000;
//       len  == 20'd16;
//       tag  == 8'h01;
//   });
//
// For the first test, direct assignment is clearer.
