// Milestone 12: axi_dma_rd_coverage
//
// Engineering goal:
// Add the first functional coverage component for axi_dma_rd.
//
// Why coverage is a separate component:
// - The scoreboard answers "is the observed behavior correct?"
// - Coverage answers "which planned scenarios actually happened?"
// - Keeping coverage separate avoids mixing pass/fail checking with measurement.
//
// First closure target from docs/axi_dma_rd_verification_plan.md:
//
//   RD-FEAT-002 Byte length and beat count
//   RD-FEAT-003 tkeep generation
//
// This component is Phase 1 coverage only.  It does not cover the full read-DMA
// verification plan by itself.  Later features need extra infrastructure:
//
// - AXI burst and 4KB coverage need an AXI AR monitor.
// - Backpressure coverage needs a tready/backpressure driver.
// - SLVERR/DECERR coverage needs an error-injecting AXI slave/responder.
// - Reset/enable coverage needs a reset/enable controller and reset-aware
//   scoreboard policy.
//
// First coverage sources:
//
//   rd_agent.driver.accepted_desc_ap
//       -> sample accepted descriptor length/address/tag
//
//   axis_rd_mon.ap
//       -> sample observed tkeep/tlast/beat position
//
//   rd_status_mon.ap
//       -> sample observed status tag/error
//
// Important rule:
// Sample accepted/observed transactions, not sequence random variables before
// handshake.  Coverage should describe what really happened in the simulation.

// TODO COV-1: import UVM and include macros.
//
// Write:

import uvm_pkg::*;
`include "uvm_macros.svh"


// TODO COV-2: declare unique analysis imp suffixes.
//
// Scoreboard already uses several `uvm_analysis_imp_decl suffixes.  Do not reuse
// the same suffix names here.
//
// Write:
//
`uvm_analysis_imp_decl(_cov_rd_desc)
`uvm_analysis_imp_decl(_cov_axis_rd_data)
`uvm_analysis_imp_decl(_cov_rd_status)
//
// Why:
// Each imp suffix creates an implementation port class that calls a matching
// write_* function in this component.



// TODO COV-3: create the component class.
//
// Suggested header:
//
//   class axi_dma_rd_coverage extends uvm_component;
//       `uvm_component_utils(axi_dma_rd_coverage)
//
// Why uvm_component:
// This component has multiple analysis inputs with different transaction types.
// A plain uvm_subscriber is best for one transaction type; here uvm_component is
// cleaner.
class axi_dma_rd_coverage extends uvm_component;
    `uvm_component_utils(axi_dma_rd_coverage)

// TODO COV-4: declare analysis implementation ports inside the class.
//
// Suggested declarations:
//
//   uvm_analysis_imp_cov_rd_desc #(dma_rd_desc_item#(), axi_dma_rd_coverage)
//       accepted_desc_export;
//
//   uvm_analysis_imp_cov_axis_rd_data #(axis_rd_data_item#(), axi_dma_rd_coverage)
//       axis_rd_data_export;
//
//   uvm_analysis_imp_cov_rd_status #(rd_status_item#(), axi_dma_rd_coverage)
//       rd_status_export;
//
// Naming rule:
// Use "export" here because other components connect their analysis ports to
// this component's analysis implementations.
    uvm_analysis_imp_cov_rd_desc #(dma_rd_desc_item#(), axi_dma_rd_coverage)
        accepted_desc_export;
    
    uvm_analysis_imp_cov_axis_rd_data #(axis_rd_data_item#(), axi_dma_rd_coverage)
        axis_rd_data_export;

    uvm_analysis_imp_cov_rd_status #(rd_status_item#(), axi_dma_rd_coverage)
        rd_status_export;


// TODO COV-5: add sampled variables for descriptor coverage.
//
// Covergroups usually sample simple local variables.  The write_* function
// copies item fields into these variables, then calls covergroup.sample().
//
// Suggested variables:
//
//   bit [19:0] cov_desc_len;
//   bit [15:0] cov_desc_addr;
//   bit [7:0]  cov_desc_tag;
//
// Why not sample the object handle directly:
// Sampling local variables keeps the covergroup simple and avoids object handle
// lifetime surprises.
    bit [19:0] cov_desc_len;
    bit [15:0] cov_desc_addr;
    bit [7:0]  cov_desc_tag;


// TODO COV-6: add sampled variables for AXIS read data coverage.
//
// Suggested variables:
//
//   bit [3:0] cov_tkeep;
//   bit       cov_tlast;
//   int unsigned cov_beat_index;
//   int unsigned cov_frame_beat_count;
//   int unsigned current_frame_beat_count;
//
// First goal:
// Prove that rd_len_sweep_test hits final tkeep patterns 0001, 0011, 0111,
// and 1111.
    bit [3:0] cov_tkeep;
    bit       cov_tlast;
    int unsigned cov_beat_index;
    int unsigned cov_frame_beat_count;
    int unsigned current_frame_beat_count;


// TODO COV-7: add sampled variables for read status coverage.
//
// Suggested variables:
//
//   bit [7:0] cov_status_tag;
//   bit [3:0] cov_status_error;
//
// First goal:
// Prove that the success-path status error value is observed.
    bit [7:0] cov_status_tag;
    bit [3:0] cov_status_error;


// Descriptor coverage group.
//
// Covergroup idea:
// A covergroup is a sampling object.  It does not sample continuously by itself;
// it samples only when we call:
//
//   rd_desc_cg.sample();
//
// In this component, that call happens in write_cov_rd_desc(), after the driver
// publishes an accepted descriptor.  That means the coverage point records
// descriptors that really completed the valid/ready handshake, not descriptors
// that a sequence merely intended to send.
//
// option.per_instance = 1:
// Each instance of axi_dma_rd_coverage keeps its own coverage numbers.  This is
// the normal choice for UVM components because each env instance should report
// its own coverage instead of merging with every other instance of the same type.
//
// cp_len_class:
// This coverpoint maps RD-FEAT-002 into bins.  We do not make one bin for every
// possible len value.  Instead, we group values by behavior:
// - len=1 exercises the minimum transfer.
// - len=2/3 exercises partial final beats.
// - len=4 is exactly one 32-bit beat.
// - len=5 is one full beat plus one byte.
// - len=6..15 is multi-beat with a partial final beat.
// - len=16 is an exact multi-beat transfer.
// - len=17 is exact multi-beat plus one byte.
//
// cp_addr_offset:
// This is included now only to document the sampling point.  Phase 1 is not
// closing RD-FEAT-004 address alignment, so unaligned offsets are ignore_bins for
// now.  When we start rd_addr_offset_test, convert off1/off2/off3 from
// ignore_bins into real bins.
    covergroup rd_desc_cg;
        option.per_instance = 1;

        cp_len_class: coverpoint cov_desc_len {
            bins len_1              = {1};
            bins len_less_than_beat = {[2:3]};
            bins len_one_beat       = {4};
            bins len_one_plus       = {5};
            bins len_multi_beat     = {[6:15]};
            bins len_exact_multi    = {16};
            bins len_multi_plus     = {17};
        }

        cp_addr_offset: coverpoint cov_desc_addr[1:0] {
            bins aligned = {0};
            ignore_bins unaligned_not_phase1 = {1, 2, 3};
        }
    endgroup


// AXIS read-data beat coverage group.
//
// This group samples one accepted AXIS beat every time axis_rd_data_monitor
// publishes an item.  The monitor only publishes on tvalid && tready, so these
// coverage bins describe beats that really left the DUT.
//
// cp_tkeep:
// Records all observed keep patterns.  For 32-bit AXIS, keep has four bits, one
// per byte lane.  In phase 1, legal/interesting values are:
// - 0001: one valid byte
// - 0011: two valid bytes
// - 0111: three valid bytes
// - 1111: four valid bytes
//
// cp_final_tkeep:
// This is the closure-critical coverpoint for RD-FEAT-003.  The "iff" clause is
// a sample filter: bins are sampled only when cov_tlast is 1.  This means it
// records final-beat keep patterns, not keep patterns from every beat.
//
// cp_tlast:
// Records whether the test saw both non-final and final beats.
//
// cross_tkeep_tlast:
// Cross coverage records combinations of two coverpoints.  Here it answers:
// "Which keep patterns appeared on final vs non-final beats?"
//
// Some combinations are not part of the phase-1 target.  For this DMA read path,
// non-final beats should be full-width keep=1111.  Partial keep on a non-final
// beat is not expected in this phase, so those cross bins are ignored instead of
// lowering the phase-1 coverage percentage.
    covergroup axis_rd_data_cg;
        option.per_instance = 1;

        cp_tkeep: coverpoint cov_tkeep {
            bins keep_0001 = {4'b0001};
            bins keep_0011 = {4'b0011};
            bins keep_0111 = {4'b0111};
            bins keep_1111 = {4'b1111};
        }

        cp_final_tkeep: coverpoint cov_tkeep iff (cov_tlast) {
            bins final_keep_0001 = {4'b0001};
            bins final_keep_0011 = {4'b0011};
            bins final_keep_0111 = {4'b0111};
            bins final_keep_1111 = {4'b1111};
        }

        cp_tlast: coverpoint cov_tlast {
            bins not_last = {0};
            bins last     = {1};
        }

        cross_tkeep_tlast: cross cp_tkeep, cp_tlast {
            ignore_bins partial_nonfinal =
                binsof(cp_tlast.not_last) &&
                (binsof(cp_tkeep.keep_0001) ||
                 binsof(cp_tkeep.keep_0011) ||
                 binsof(cp_tkeep.keep_0111));
        }
    endgroup

// AXIS frame shape coverage group.
//
// axis_rd_data_cg samples every beat.  This group samples once per AXIS frame,
// when tlast is observed.  current_frame_beat_count increments for every accepted
// beat and is copied into cov_frame_beat_count on the final beat.
//
// Why separate group:
// RD-FEAT-002 is not only about descriptor length values.  It also cares that
// the DUT produces one-beat and multi-beat frames.  The scoreboard proves the
// exact count is correct; this covergroup proves those frame shapes occurred.
//
// The phase-1 length sweep is expected to hit 1, 2, 4, and 5 beat frames.  Other
// frame sizes are future directed/random coverage targets.  We simply do not
// create bins for them yet, so they do not affect phase-1 closure coverage.
    covergroup axis_frame_cg;
        option.per_instance = 1;
        
        cp_frame_beats: coverpoint cov_frame_beat_count {
            bins one_beat  = {1};
            bins two_beats = {2};
            bins four_beats = {4};
            bins five_beats = {5};
        }
    endgroup

// Read status coverage group.
//
// Phase 1 only covers successful reads, so the only coverage target here is
// error=0.  Non-zero errors require error injection on the AXI memory side, which
// the current axi_ram setup does not provide.  Later, when we add SLVERR/DECERR
// stimulus, convert error_not_phase1 from ignore_bins into real bins.
    covergroup rd_status_cg;
        option.per_instance = 1;

        cp_error: coverpoint cov_status_error {
            bins none = {4'd0};
            ignore_bins error_not_phase1 = {[1:15]};
        }
    endgroup


// TODO COV-11: add constructor and create analysis exports and covergroups.
//
// Suggested code shape:
//
//   function new(string name = "axi_dma_rd_coverage",
//                uvm_component parent = null);
//       super.new(name, parent);
//
//       accepted_desc_export = new("accepted_desc_export", this);
//       axis_rd_data_export  = new("axis_rd_data_export", this);
//       rd_status_export     = new("rd_status_export", this);
//
//       rd_desc_cg      = new();
//       axis_rd_data_cg = new();
//       axis_frame_cg   = new();
//       rd_status_cg    = new();
//   endfunction

    function new(string name = "axi_dma_rd_coverage", uvm_component parent = null);
        super.new(name, parent);
        
        accepted_desc_export = new("accepted_desc_export", this);
        axis_rd_data_export  = new("axis_rd_data_export", this);
        rd_status_export     = new("rd_status_export", this);

        rd_desc_cg      = new();
        axis_rd_data_cg = new();
        axis_frame_cg   = new();            
        rd_status_cg    = new();

        current_frame_beat_count = 0;
    endfunction


// TODO COV-12: implement write functions.
//
// Suggested code shape:
//
//   function void write_cov_rd_desc(dma_rd_desc_item#() item);
//       cov_desc_len  = item.len;
//       cov_desc_addr = item.addr;
//       cov_desc_tag  = item.tag;
//       rd_desc_cg.sample();
//   endfunction
//
//   function void write_cov_axis_rd_data(axis_rd_data_item#() item);
//       cov_tkeep      = item.keep;
//       cov_tlast      = item.last;
//       cov_beat_index = item.beat_index;
//       axis_rd_data_cg.sample();
//
//       current_frame_beat_count++;
//
//       if (item.last) begin
//           cov_frame_beat_count = current_frame_beat_count;
//           axis_frame_cg.sample();
//           current_frame_beat_count = 0;
//       end
//   endfunction
//
//   function void write_cov_rd_status(rd_status_item#() item);
//       cov_status_tag   = item.tag;
//       cov_status_error = item.error;
//       rd_status_cg.sample();
//   endfunction
//
// Why these names:
// They must match the suffixes from TODO COV-2:
// - _cov_rd_desc       -> write_cov_rd_desc
// - _cov_axis_rd_data  -> write_cov_axis_rd_data
// - _cov_rd_status     -> write_cov_rd_status
    function void write_cov_rd_desc(dma_rd_desc_item#() item);
        cov_desc_len  = item.len;
        cov_desc_addr = item.addr;
        cov_desc_tag  = item.tag;
        rd_desc_cg.sample(); 
    endfunction

    function void write_cov_axis_rd_data(axis_rd_data_item#() item);
        cov_tkeep      = item.keep;
        cov_tlast      = item.last;
        cov_beat_index = item.beat_index;
        axis_rd_data_cg.sample();

        current_frame_beat_count++;

        if(item.last)begin
            cov_frame_beat_count = current_frame_beat_count;
            axis_frame_cg.sample();
            current_frame_beat_count = 0;
        end
    endfunction

    function void write_cov_rd_status(rd_status_item#() item);
        cov_status_tag   = item.tag;
        cov_status_error = item.error;
        rd_status_cg.sample(); 
    endfunction

// TODO COV-13: add report_phase summary.
//
// Suggested code:
//
//   virtual function void report_phase(uvm_phase phase);
//       super.report_phase(phase);
//
//       `uvm_info("AXI_DMA_RD_COV",
//           $sformatf("rd_desc_cg coverage = %.2f%%", rd_desc_cg.get_coverage()),
//           UVM_LOW)
//
//       `uvm_info("AXI_DMA_RD_COV",
//           $sformatf("axis_rd_data_cg coverage = %.2f%%",
//                     axis_rd_data_cg.get_coverage()),
//           UVM_LOW)
//
//       `uvm_info("AXI_DMA_RD_COV",
//           $sformatf("axis_frame_cg coverage = %.2f%%",
//                     axis_frame_cg.get_coverage()),
//           UVM_LOW)
//
//       `uvm_info("AXI_DMA_RD_COV",
//           $sformatf("rd_status_cg coverage = %.2f%%",
//                     rd_status_cg.get_coverage()),
//           UVM_LOW)
//   endfunction
//
// Note:
// Coverage percentage can be misleading early on because planned-but-not-yet-run
// scenarios lower the percentage.  Always interpret it together with the
// verification closure tracker.
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("AXI_DMA_RD_COV", $sformatf("rd_desc_cg coverage = %.2f%%", rd_desc_cg.get_coverage()),UVM_LOW)
        `uvm_info("AXI_DMA_RD_COV", $sformatf("axis_rd_data_cg coverage = %.2f%%", axis_rd_data_cg.get_coverage()),UVM_LOW)
        `uvm_info("AXI_DMA_RD_COV", $sformatf("axis_frame_cg coverage = %.2f%%", axis_frame_cg.get_coverage()),UVM_LOW)
        `uvm_info("AXI_DMA_RD_COV", $sformatf("rd_status_cg coverage = %.2f%%", rd_status_cg.get_coverage()),UVM_LOW)
    endfunction


// TODO COV-14: after this class is complete, update env and flist.
//
// flist.f:
//
//   Add this file before axi_dma_env.sv:
//     ./vip/axi_dma_uvc/coverage/axi_dma_rd_coverage.sv
//
// axi_dma_env.sv:
//
//   Declare:
//     axi_dma_rd_coverage rd_cov;
//
//   Create in build_phase:
//     rd_cov = axi_dma_rd_coverage::type_id::create("rd_cov", this);
//
//   Connect in connect_phase:
//     rd_agent.driver.accepted_desc_ap.connect(rd_cov.accepted_desc_export);
//     axis_rd_mon.ap.connect(rd_cov.axis_rd_data_export);
//     rd_status_mon.ap.connect(rd_cov.rd_status_export);
endclass
