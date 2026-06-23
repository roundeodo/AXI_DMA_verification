// Milestone 13A: rd_len_random_sequence TODO scaffold
//
// Engineering goal:
// Add the first constrained-random stimulus for RD-FEAT-002 and RD-FEAT-003:
//
//   RD-FEAT-002 Byte length and beat count
//   RD-FEAT-003 tkeep generation
//
// This sequence sends many read descriptors with randomized length while keeping
// address behavior simple and aligned.
//
// Why only randomize length first:
// We are strengthening the length/tkeep/tlast verification target.  If we also
// randomize address offset now, failures could come from unaligned-address logic
// instead of length logic.  That would mix RD-FEAT-002/003 with RD-FEAT-004.
//
// Real verification habit:
// Constrained random should be introduced after directed tests and checkers are
// trusted.  rd_len_sweep_test already proved the checker path and exact corner
// lengths.  This random sequence now asks: "does the same logic survive many
// legal lengths, not only the hand-picked ones?"
//
// Data flow:
//
//   rd_len_random_test
//       configures num_desc/min_len/max_len/base_addr
//       |
//       v
//   rd_len_random_sequence
//       creates randomized dma_rd_desc_item objects
//       |
//       v
//   rd_desc_driver
//       drives descriptor pins
//       |
//       v
//   DUT/ref_model/scoreboard/coverage

// TODO RAND-LEN-1: import UVM and include macros.
//
// Write:
import uvm_pkg::*;
`include "uvm_macros.svh"


// TODO RAND-LEN-2: create the class.
//
// Suggested header:
//
//   class rd_len_random_sequence extends uvm_sequence #(dma_rd_desc_item#());
//       `uvm_object_utils(rd_len_random_sequence)
//
// Why sequence:
// Random transaction generation is scenario behavior.  The test should select
// and configure this scenario, but the transaction loop belongs in the sequence.

class rd_len_random_sequence extends uvm_sequence #(dma_rd_desc_item#());


// TODO RAND-LEN-3: add sequence configuration knobs.
//
// Suggested members:
//
  int unsigned num_desc    = 50;
  bit [15:0]   base_addr   = 16'h2000;
  int unsigned addr_stride = 16'h0100;
  bit [19:0]  min_len     = 20'd1;
  bit [19:0]  max_len     = 20'd128;
  bit [7:0]   base_tag    = 8'h40;
  bit [7:0]   cfg_id      = 8'h00;
  bit [7:0]   cfg_dest    = 8'h00;
  bit         cfg_user    = 1'b0;
//
// Why these defaults:
// - num_desc=50 gives more confidence than a tiny directed list, but remains
//   quick to simulate.
// - base_addr=0x2000 separates random-test traffic from smoke/sweep logs.
// - addr_stride=0x100 keeps each descriptor in a different aligned region.
// - max_len=128 is large enough to create multi-beat frames, but still fast.
// - id/dest stay zero because current DUT parameters do not propagate them.
//
// Important:
// addr is intentionally deterministic and aligned in this first random test.
// Address-offset randomization belongs to RD-FEAT-004.




// TODO RAND-LEN-4: add constructor.
//
// Suggested code:
//
  function new(string name = "rd_len_random_sequence");
      super.new(name);
  endfunction


// TODO RAND-LEN-5: add a configuration check helper.
//
// Suggested function:
//
//   function void check_config();
//       int unsigned last_byte;
//
//       if (num_desc == 0) begin
//           `uvm_fatal("RD_LEN_RANDOM_SEQ", "num_desc must be > 0")
//       end
//
//       if (min_len == 0 || max_len < min_len) begin
//           `uvm_fatal("RD_LEN_RANDOM_SEQ",
//               $sformatf("bad length range min_len=%0d max_len=%0d",
//                         min_len, max_len))
//       end
//
//       last_byte = base_addr + (num_desc-1)*addr_stride + max_len - 1;
//
//       if (last_byte >= 65536) begin
//           `uvm_fatal("RD_LEN_RANDOM_SEQ",
//               $sformatf("random sequence exceeds 64KB memory: last_byte=0x%0h",
//                         last_byte))
//       end
//
//       if (base_addr[1:0] != 0 || addr_stride[1:0] != 0) begin
//           `uvm_fatal("RD_LEN_RANDOM_SEQ",
//               "phase-1 length random test requires aligned addresses")
//       end
//   endfunction
//
// Why this check matters:
// Random tests fail in less obvious ways than directed tests.  A small config
// guard prevents us from debugging a bogus memory-range or alignment mistake.
    function void check_config();
        int unsigned last_byte;

        if(num_desc == 0)begin
            `uvm_fatal("RD_LEN_RANDOM_SEQ", "num_desc must be > 0")
        end

        if(min_len == 0 || max_len < min_len) begin
            `uvm_fatal("RD_LEN_RANDOM_SEQ", $sformatf("bad length range min_len = %0d max_len=%0d",min_len,max_len))
        end

        last_byte = base_addr + (num_desc - 1) * addr_stride + max_len - 1;

        if(last_byte >= 65536) begin
            `uvm_fatal("RD_LEN_RANDOM_SEQ", $sformatf("random sequence exceeds 64KB memory: last_byte=0x%0h",last_byte))    
        end
        
        if(base_addr[1:0] != 0 || addr_stride[1:0] != 0)begin
            `uvm_fatal("RD_LEN_RANDOM_SEQ", "phase-1 length random test required aligned addresses")
        end
    endfunction



// TODO RAND-LEN-6: write helper task send_one_random_desc().
//
// Suggested task:
//
//   task send_one_random_desc(input int unsigned desc_index);
//       dma_rd_desc_item#() req;
//       bit [15:0] addr_value;
//       bit [7:0]  tag_value;
//
//       addr_value = base_addr + desc_index * addr_stride;
//       tag_value  = base_tag + desc_index;
//
//       req = dma_rd_desc_item#()::type_id::create(
//           $sformatf("req_rand_%0d", desc_index)
//       );
//
//       start_item(req);
//
//       if (!req.randomize() with {
//           addr == addr_value;
//           len inside {[min_len:max_len]};
//           tag == tag_value;
//           id == cfg_id;
//           dest == cfg_dest;
//           user == cfg_user;
//       }) begin
//           `uvm_fatal("RD_LEN_RANDOM_SEQ",
//               $sformatf("randomize failed for desc_index=%0d", desc_index))
//       end
//
//       finish_item(req);
//
//       `uvm_info("RD_LEN_RANDOM_SEQ",
//           $sformatf("sent random descriptor[%0d] addr=0x%0h len=%0d tag=0x%0h",
//                     desc_index, req.addr, req.len, req.tag),
//           UVM_LOW)
//   endtask
//
// Why start_item before randomize:
// In a full UVM flow, start_item arbitrates for the sequencer and gives UVM a
// chance to run sequence hooks before the item is finalized.  For our simple
// sequence, randomizing before start_item would also work, but this order matches
// common UVM sequence style and scales better.
//
// Why inline constraints:
// The base item stays reusable and mostly unconstrained.  This sequence adds the
// constraints that are specific to this scenario: aligned deterministic address,
// random legal length, deterministic tag.
    task send_one_random_desc(input int unsigned desc_index);
        dma_rd_desc_item#() req;
        bit[15:0] addr_value;
        bit [7:0] tag_value;

        addr_value = base_addr + desc_index * addr_stride;
        tag_value = base_tag + desc_index;

        req = dma_rd_desc_item#()::type_id::create($sformatf("req_rand_%0d", desc_index));

        start_item(req);

        if(!req.randomize() with {
            addr == addr_value;
            len inside {[min_len:max_len]};
            tag == tag_value;
            id == cfg_id;
            dest == cfg_dest;
            user == cfg_user;
        })begin
            `uvm_fatal("RD_LEN_RANDOM_SEQ", $sformatf("randomize failed for desc_index=%0d, desc_index"))
        end

        finish_item(req);

        `uvm_info("RD_LEN_RANDOM_SEQ",$sformatf("sent random descriptor[%0d] addr=0x%0h len=%0d tag=%0h",
        desc_index, req.addr, req.len, req.tag), UVM_LOW)
    endtask //


// TODO RAND-LEN-7: write body().
//
// Suggested body:
//
//   virtual task body();
//       `uvm_info("RD_LEN_RANDOM_SEQ", "body started", UVM_LOW)
//
//       check_config();
//
//       for (int unsigned i = 0; i < num_desc; i++) begin
//           send_one_random_desc(i);
//       end
//   endtask
//
// What this test should stress:
// - many descriptor lengths
// - many frame beat counts
// - many final tkeep patterns
// - repeated descriptor/status/data matching
//
// What this test intentionally does not stress yet:
// - unaligned addresses
// - AXIS backpressure
// - AXI SLVERR/DECERR
// - reset during transfer
// Those are separate verification-plan entries with their own infrastructure.
virtual task body();
    `uvm_info("RD_LEN_RANDOM_SEQ", "body started", UVM_LOW)

    check_config();

    for(int unsigned i = 0; i < num_desc; i++)begin
        send_one_desc(i);
    end 
endtask //

// TODO RAND-LEN-LATER: make knobs configurable from plusargs or config objects.
//
// Later options:
// - +NUM_DESC=...
// - +MIN_LEN=...
// - +MAX_LEN=...
// - a formal rd_sequence_cfg object in uvm_config_db
//
// For now, rd_len_random_test will set the sequence fields directly.

endclass