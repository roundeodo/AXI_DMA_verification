// Milestone 10B: axi_dma_rd_ref_model
//
// Engineering goal:
// Split prediction out of the scoreboard.
//
// The reference model predicts what axi_dma_rd should output after it accepts a
// read descriptor.  The scoreboard compares:
//
//   expected transactions from reference model
//   actual transactions from monitors
//
// Why split reference model from scoreboard:
// - The reference model answers: "what should happen?"
// - The scoreboard answers: "did actual match expected?"
// - This keeps checking code easier to debug and closer to real project style.
//
// Future data flow:
//
//   rd_desc_driver.accepted_desc_ap
//       |
//       v
//   axi_dma_rd_ref_model
//       |
//       +--> expected AXIS read-data items
//       |
//       +--> expected read-status items
//
//   axis_rd_data_monitor
//       |
//       v
//   actual AXIS read-data items
//
//   rd_status_monitor
//       |
//       v
//   actual read-status items
//
//   scoreboard compares expected vs actual
//
// Important:
// This reference model should receive descriptors only after the driver has
// completed the descriptor valid/ready handshake.  A descriptor that was merely
// created by a sequence is not yet guaranteed to have reached the DUT.

import uvm_pkg::*;
`include "uvm_macros.svh"


// This model needs to receive accepted read descriptors.
// This creates an analysis imp type that will call:
//
//   write_accepted_rd_desc(dma_rd_desc_item#() item)
//
// when the driver publishes an accepted descriptor.
`uvm_analysis_imp_decl(_accepted_rd_desc)

// Compile-order dependencies:
// This model uses:
// - dma_rd_desc_item#()
// - axis_rd_data_item#()
// - rd_status_item#()
//
// Therefore flist.f must compile:
//
//   dma_rd_desc_item.sv
//   axis_rd_data_item.sv
//   rd_status_item.sv
//   axi_dma_rd_ref_model.sv
//
// before axi_dma_env.sv.


// Why uvm_component:
// The reference model is a long-lived verification component owned by env.  It
// receives descriptors, predicts expected output, and publishes expected items.
class axi_dma_rd_ref_model extends uvm_component;
    `uvm_component_utils(axi_dma_rd_ref_model)

    uvm_analysis_imp_accepted_rd_desc #(dma_rd_desc_item#(), axi_dma_rd_ref_model)
        accepted_desc_export;
    
    uvm_analysis_port #(axis_rd_data_item#())
        expected_data_ap;
    
    uvm_analysis_port #(rd_status_item#())  
        expected_status_ap;
    
    localparam int MEM_SIZE_BYTES = 65536;
    bit [7:0] mem [MEM_SIZE_BYTES];

    // This must match top_tb.smoke_mem_pattern exactly.  If the two patterns
    // differ, the scoreboard will report data mismatches even if the DUT is
    // correct.
    function automatic bit[7:0] smoke_mem_pattern(input int unsigned byte_addr);
        smoke_mem_pattern = byte_addr[7:0] ^ 8'hA5;
    endfunction

    // axi_ram contains the actual data the DUT reads.  ref_model.mem contains
    // the expected data the checker uses.  They must be initialized with the
    // same pattern.
    function void init_mem();
        for( int unsigned addr = 0; addr < MEM_SIZE_BYTES; addr++)begin
            mem[addr] = smoke_mem_pattern(addr);
        end
    endfunction

    function new(string name = "axi_dma_ref_model", uvm_component parent = null);
        super.new(name, parent);
        accepted_desc_export = new("accepted_desc_export", this);
        expected_data_ap = new("expected_data_ap", this);
        expected_status_ap = new("expected_status_ap", this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        init_mem();

        `uvm_info("AXI_DMA_REF", "build_phase entered", UVM_LOW)
    endfunction

    virtual function void write_accepted_rd_desc(dma_rd_desc_item#() item);
        rd_status_item#() exp_status;

        `uvm_info("AXI_DMA_REF",
          $sformatf("accepted descriptor addr=0x%0h len=%0d tag=0x%0h",
                    item.addr, item.len, item.tag),
          UVM_LOW)

        // First real prediction: a successful smoke descriptor should return
        // the descriptor tag and error code 0.  This prediction does not depend
        // on memory contents, so it is the safest first checker to add.
        exp_status = rd_status_item#()::type_id::create("exp_status");
        exp_status.tag = item.tag;
        exp_status.error = 4'h0;
        exp_status.sample_time = $time;

        expected_status_ap.write(exp_status);
        `uvm_info("AXI_DMA_REF",
            $sformatf("expected status tag=0x%0h error=0x%0h",
                      exp_status.tag, exp_status.error),
            UVM_LOW)

        // Generate expected AXIS data beats for the current directed smoke
        // descriptor.  The first version supports AXIS_DATA_WIDTH=32 and
        // aligned reads; later directed tests will expand this model.
        publish_expected_read_data(item);
    endfunction

    // Publish expected AXIS read-data beats for one descriptor.
    // Current scope:
    // - AXIS_DATA_WIDTH = 32, so bytes_per_beat = 4
    // - aligned address smoke path
    // - AXIS_ID_ENABLE=0 and AXIS_DEST_ENABLE=0 in the DUT instance
    function void publish_expected_read_data(dma_rd_desc_item#() desc);
        axis_rd_data_item#() exp;
        int unsigned bytes_per_beat;
        int unsigned remaining;
        int unsigned byte_addr;
        int unsigned beat_index;
        int unsigned lane;
        int unsigned valid_bytes;

        bytes_per_beat = 4;
        remaining = desc.len;
        byte_addr = desc.addr;
        beat_index = 0;

        while(remaining > 0) begin
            exp = axis_rd_data_item#()::type_id::create("exp_data");
            exp.data = 'd0;
            exp.keep = 'd0;
            exp.beat_index = beat_index;
            exp.sample_time = $time;

            valid_bytes = (remaining >= bytes_per_beat) ? bytes_per_beat : remaining;

            for(lane = 0; lane < valid_bytes; lane++) begin
                exp.data[8*lane +: 8] = mem[byte_addr + lane];
                exp.keep[lane] = 1'b1;
            end 

            exp.last = (remaining <= bytes_per_beat);

            // current DUT parameters in top_tb use AXIS_ID_ENABLE=0 and 
            // AXIS_DEST_ENABLE=0, so expected id/dest are 0 in the smoke test
            exp.id = 'd0;
            exp.dest = 'd0;
            exp.user = desc.user;

            expected_data_ap.write(exp);

            remaining -= valid_bytes;
            byte_addr += valid_bytes;
            beat_index++;
        end        
    endfunction

endclass //axi_dma_rd_ref_model extends uvm_component

// Expected status is implemented for the successful smoke path.  Later, extend
// this for error-response tests when AXI read SLVERR/DECERR injection exists.

// TODO LATER: improve expected AXIS read-data model.
//
// Later improvements:
// - handle unaligned addresses carefully
// - parameterize bytes_per_beat
// - model AXIS_ID_ENABLE / AXIS_DEST_ENABLE / AXIS_USER_ENABLE config
// - add error response prediction


// TODO LATER 3: decide FIFO vs direct analysis connection.
//
// Option A, direct push:
//
//   ref_model.expected_data_ap.connect(scoreboard.expected_data_export);
//
// Option B, TLM FIFO:
//
//   ref_model.expected_data_ap -> expected FIFO -> scoreboard blocking get
//
// Direct push is simpler.  FIFO is useful when scoreboard wants to actively
// pair expected and actual items in run_phase.  We will choose after the first
// descriptor reaches the reference model.
