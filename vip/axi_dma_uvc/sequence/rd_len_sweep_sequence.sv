// Milestone 11A: rd_len_sweep_sequence TODO scaffold
//
// Engineering goal:
// Describe a directed read-length transaction flow in a sequence, not in the
// test.  This matches real UVM project structure more closely:
//
//   test:
//     selects and starts a scenario
//
//   sequence:
//     defines the ordered transaction stream for that scenario
//
// This sequence generates multiple DMA read descriptors with different lengths
// to check tkeep, tlast, and beat-count behavior.
//
// Verification intent:
//
//   len = 1   -> one beat, keep=0001, last=1
//   len = 2   -> one beat, keep=0011, last=1
//   len = 3   -> one beat, keep=0111, last=1
//   len = 4   -> one beat, keep=1111, last=1
//   len = 5   -> two beats, keep=1111 then 0001
//   len = 15  -> four beats, last keep=0111
//   len = 16  -> four beats, all keep=1111
//   len = 17  -> five beats, last keep=0001

// TODO LEN-3: import UVM and include macros.
//
// Write:
//
import uvm_pkg::*;
`include "uvm_macros.svh"


// TODO LEN-4: write the class header.
//
// Suggested header:
//
//   class rd_len_sweep_sequence extends uvm_sequence #(dma_rd_desc_item#());
//
// Register with:
//
//   `uvm_object_utils(rd_len_sweep_sequence)
//
// Why sequence, not test:
// The ordered descriptor stream is stimulus behavior.  Tests choose scenarios;
// sequences describe transaction flow.

class rd_len_sweep_sequence extends uvm_sequence #(dma_rd_desc_item#());
    `uvm_object_utils(rd_len_sweep_sequence)

  bit [15:0] base_addr = 16'h1000;
  bit [7:0]  base_tag  = 8'h01;
  bit [7:0]  cfg_id    = 8'h00;
  bit [7:0]  cfg_dest  = 8'h00;
  bit        cfg_user  = 1'b0;

  function new(string name = "rd_len_sweep_sequence");
      super.new(name);
  endfunction

  task send_one_desc(
      input bit [15:0] addr,
      input bit [19:0] len,
      input bit [7:0]  tag
  );
      dma_rd_desc_item#() req;

      req = dma_rd_desc_item#()::type_id::create(
          $sformatf("req_len_%0d", len)
      );

      start_item(req);

      req.addr = addr;
      req.len  = len;
      req.tag  = tag;
      req.id   = cfg_id;
      req.dest = cfg_dest;
      req.user = cfg_user;

      finish_item(req);

      `uvm_info("RD_LEN_SWEEP_SEQ",
          $sformatf("sent descriptor addr=0x%0h len=%0d tag=0x%0h",
                    addr, len, tag),
          UVM_LOW)
  endtask

    virtual task body();
        bit[19:0] lengths[$];

        `uvm_info("RD_LEN_SWEEP_SEQ", "body started", UVM_LOW)
        lengths = '{20'd1, 20'd2, 20'd3, 20'd4, 20'd5, 20'd15, 20'd16, 20'd17};
        foreach(lengths[i]) begin
            send_one_desc(base_addr + i*16'h0100, lengths[i], base_tag + i);
        end
        
    endtask //

endclass //rd_len_sweep_sequence extends uvm_sequence

// TODO LEN-5: add configurable sequence-level knobs.
//
// Suggested members:
//

// Why:
// The test can later configure the scenario without changing the sequence code.


// TODO LEN-6: add constructor.
//
// Suggested code:
//
//   function new(string name = "rd_len_sweep_sequence");
//       super.new(name);
//   endfunction


// TODO LEN-7: add helper task send_one_desc().
//
// Suggested helper:
//
//
// Why helper task:
// It keeps body() readable and makes the descriptor-generation pattern clear.


// TODO LEN-8: write body().
//
// Suggested body:
//
//   virtual task body();
//       bit [19:0] lengths[$];
//
//       `uvm_info("RD_LEN_SWEEP_SEQ", "body started", UVM_LOW)
//
//       lengths = '{20'd1, 20'd2, 20'd3, 20'd4,
//                   20'd5, 20'd15, 20'd16, 20'd17};
//
//       foreach (lengths[i]) begin
//           send_one_desc(base_addr + i*16'h0100,
//                         lengths[i],
//                         base_tag + i);
//       end
//   endtask
//
// Why different addresses:
// Each descriptor reads a different memory region.  This makes logs/waves
// easier and avoids hiding accidental descriptor reuse.
//
// Why different tags:
// The status checker proves each completion returned the expected tag.


// TODO LATER: turn fixed length list into configurable scenario data.
//
// Later options:
// - make the length list configurable
// - add address-offset scenarios
// - add descriptor spacing
// - add constrained-random length generation after directed cases pass
