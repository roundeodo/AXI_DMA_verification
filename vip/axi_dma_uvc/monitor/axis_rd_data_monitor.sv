// Milestone 8A: axis_rd_data_monitor TODO scaffold
//
// Engineering goal:
// Build the first real observation component for the read DMA path.
//
// This monitor watches the DUT output channel:
//
//   m_axis_read_data_*
//
// and converts accepted AXIS beats into axis_rd_data_item transactions.
//
// Data flow:
//
//   axi_dma_rd.m_axis_read_data_*
//       |
//       v
//   axi_dma_if.axis_rd_data_mon_mp
//       |
//       v
//   axis_rd_data_monitor
//       |
//       v
//   analysis_port #(axis_rd_data_item#())
//       |
//       v
//   scoreboard
//
// What belongs in this monitor:
// - Sample DUT output signals.
// - Detect accepted AXIS beats with tvalid && tready.
// - Create one axis_rd_data_item per accepted beat.
// - Fill item fields from sampled interface signals.
// - Publish the item through an analysis port.
//
// What does NOT belong in this monitor:
// - Driving tready.  tready belongs to the downstream sink/backpressure model.
// - Checking whether the data is correct.  That belongs in the scoreboard.
// - Predicting memory contents.  That belongs in the reference model/scoreboard.
// - Creating descriptors.  That belongs in sequences.

// TODO 1: import UVM and include macros.
//
// Write:
//
import uvm_pkg::*;
`include "uvm_macros.svh"
//
// Why:
// - uvm_monitor and uvm_analysis_port are in uvm_pkg.
// - `uvm_component_utils, `uvm_info, and `uvm_fatal are macros.


// TODO 2: understand compile-order dependencies.
//
// This monitor uses:
// - axi_dma_if.axis_rd_data_mon_mp
// - axis_rd_data_item#()
//
// Therefore flist.f must compile in this order:
//
//   axi_dma_if.sv
//   axis_rd_data_item.sv
//   axis_rd_data_monitor.sv
//
// Do not `include those files here.  The filelist owns compile order.


// TODO 3: write the class header.
//
// Suggested header:
//
//   class axis_rd_data_monitor extends uvm_monitor;
//
// Why uvm_monitor:
// A monitor is a passive UVM component.  It observes signal activity and
// publishes transactions.  It should not drive DUT pins.
class axis_rd_data_monitor extends uvm_monitor;
    `uvm_component_utils(axis_rd_data_monitor)

    virtual axi_dma_if.axis_rd_data_mon_mp axis_rd_data_vif;

    uvm_analysis_port #(axis_rd_data_item#()) ap;

    int unsigned beat_index;



    function new(string name = "axis_rd_data_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap",this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_dma_if.axis_rd_data_mon_mp)::get(
            this,"","axis_rd_data_vif",axis_rd_data_vif
        ))begin
            `uvm_fatal("AXIS_RD_MON","Failed to get axis_rd_data_vif")
        end
        `uvm_info("AXIS_RD_MON", "Got axis_rd_data_vif", UVM_LOW)
    endfunction

    task sample_one_beat();
        axis_rd_data_item#() item;
        item = axis_rd_data_item#()::type_id::create("item");

        // copy data from physical interface
        item.data = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tdata;
        item.keep = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tkeep;
        item.last = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tlast;
        item.id = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tid;
        item.dest = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tdest;
        item.user = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tuser;
        
        // fill debug metadata
        item.beat_index = beat_index;
        item.sample_time = $time;

        // publish the item through port
        ap.write(item);

        // update beat_index
        if(item.last) 
            beat_index = 0;
        else
            beat_index++;
    endtask 

    virtual task run_phase(uvm_phase phase);
        beat_index = 0;

        wait(axis_rd_data_vif.rst == 1'b0);

        forever begin
            @(axis_rd_data_vif.axis_rd_data_mon_cb);

            if(axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tvalid &&
               axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tready)begin
                sample_one_beat();
               end
        end
    endtask //
endclass //axis_rd_data_monitor extends uvm_monitor

// TODO 4: register the monitor with the factory.
//
// Put inside the class:
//
//   `uvm_component_utils(axis_rd_data_monitor)
//
// Why:
// The env will create this monitor using type_id::create().


// TODO 5: declare the virtual interface handle.
//
// Use the read-data monitor modport:
//
//   virtual axi_dma_if.axis_rd_data_mon_mp axis_rd_data_vif;
//
// Why modport-typed:
// - The monitor only sees the AXIS read-data signals it is allowed to observe.
// - It prevents accidental access to descriptor or AXI memory signals.
// - It makes the component boundary explicit.
//
// Field name:
// Use "axis_rd_data_vif" in uvm_config_db.  Do not use generic "vif", because
// this UVC will have several interface views.


// TODO 6: declare the analysis port.
//
// Put inside the class:
//
//   uvm_analysis_port #(axis_rd_data_item#()) ap;
//
// What this means:
// The monitor broadcasts observed transactions.  It does not know who receives
// them.  Later env.connect_phase will connect:
//
//   axis_rd_mon.ap.connect(scoreboard.axis_rd_data_export);
//
// Why analysis port:
// Monitors usually use analysis ports because observation is one-to-many and
// non-blocking.  A scoreboard, coverage collector, and logger could all
// subscribe to the same monitor.


// TODO 7: add local debug state.
//
// Suggested class member:
//
//   int unsigned beat_index;
//
// Purpose:
// Count beats within the current AXIS frame.  When tlast is observed, reset it
// to 0 for the next frame.  This makes scoreboard logs much easier to read.


// TODO 8: add the component constructor.
//
// Suggested code:
//
//   function new(string name = "axis_rd_data_monitor",
//                uvm_component parent = null);
//       super.new(name, parent);
//       ap = new("ap", this);
//   endfunction
//
// Why create ap in new:
// UVM ports are class objects.  They should be constructed before connect_phase,
// and the constructor is the normal place to create them.


// TODO 9: get the virtual interface in build_phase.
//
// Suggested code shape:
//
//   virtual function void build_phase(uvm_phase phase);
//       super.build_phase(phase);
//
//       if (!uvm_config_db#(virtual axi_dma_if.axis_rd_data_mon_mp)::get(
//               this, "", "axis_rd_data_vif", axis_rd_data_vif
//       )) begin
//           `uvm_fatal("AXIS_RD_MON", "Failed to get axis_rd_data_vif")
//       end
//
//       `uvm_info("AXIS_RD_MON", "Got axis_rd_data_vif", UVM_LOW)
//   endfunction
//
// Required top_tb support later:
//
//   uvm_config_db#(virtual axi_dma_if.axis_rd_data_mon_mp)::set(
//       null,
//       "uvm_test_top.*",
//       "axis_rd_data_vif",
//       dma_if.axis_rd_data_mon_mp
//   );


// TODO 10: write a helper task to sample one accepted beat.
//
// Suggested task name:
//
//   task sample_one_beat();
//
// Inside the task:
// 1. Create an item:
//
//      axis_rd_data_item#() item;
//      item = axis_rd_data_item#()::type_id::create("item");
//
// 2. Copy sampled values from the clocking block:
//
//      item.data = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tdata;
//      item.keep = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tkeep;
//      item.last = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tlast;
//      item.id   = axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tid;
//      ...
//
// 3. Fill debug metadata:
//
//      item.beat_index  = beat_index;
//      item.sample_time = $time;
//
// 4. Publish it:
//
//      ap.write(item);
//
// 5. Update beat_index:
//
//      if (item.last) beat_index = 0;
//      else           beat_index++;
//
// Why a helper task:
// It keeps run_phase focused on "when do I sample?" and the helper focused on
// "what fields do I copy?".


// TODO 11: write run_phase.
//
// Suggested code shape:
//
//   virtual task run_phase(uvm_phase phase);
//       beat_index = 0;
//
//       wait (axis_rd_data_vif.rst == 1'b0);
//
//       forever begin
//           @(axis_rd_data_vif.axis_rd_data_mon_cb);
//
//           if (axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tvalid &&
//               axis_rd_data_vif.axis_rd_data_mon_cb.m_axis_read_data_tready) begin
//               sample_one_beat();
//           end
//       end
//   endtask
//
// Why tvalid && tready:
// AXIS data is transferred only when both sides agree on the same clock edge.
// If tvalid is 1 but tready is 0, the beat is being held, not accepted.


// TODO 12: add env/top integration later, not now.
//
// After this monitor compiles standalone:
// - add it to flist.f after axis_rd_data_item.sv
// - add the virtual interface set() call in top_tb
// - declare axis_rd_data_monitor axis_rd_mon in axi_dma_env
// - create it in axi_dma_env.build_phase
//
// Do not connect to scoreboard yet.  We will create the scoreboard after both
// read-data and status monitors exist.
