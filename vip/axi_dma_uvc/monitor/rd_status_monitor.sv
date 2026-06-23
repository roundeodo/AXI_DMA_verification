// Milestone 8B: rd_status_monitor TODO scaffold
//
// Engineering goal:
// Build the monitor for the read descriptor completion status channel.
//
// This monitor watches:
//
//   m_axis_read_desc_status_*
//
// and converts each status_valid event into one rd_status_item transaction.
//
// Data flow:
//
//   axi_dma_rd.m_axis_read_desc_status_*
//       |
//       v
//   axi_dma_if.rd_status_mon_mp
//       |
//       v
//   rd_status_monitor
//       |
//       v
//   analysis_port #(rd_status_item#())
//       |
//       v
//   scoreboard
//
// Important difference from AXIS read data:
// The read status channel has valid, but no ready.  Therefore the monitor
// samples a status item when status_valid is high on a clock edge.
//
// For AXIS read data:
//
//   sample when tvalid && tready
//
// For read descriptor status:
//
//   sample when status_valid
//
// What belongs in this monitor:
// - Sample status_valid/tag/error.
// - Create one rd_status_item per valid status event.
// - Publish the item through an analysis port.
//
// What does NOT belong in this monitor:
// - Checking whether error is correct.  That belongs in scoreboard.
// - Matching tag to descriptor.  That belongs in scoreboard/reference model.
// - Driving any signal.  This monitor is passive.

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
// - axi_dma_if.rd_status_mon_mp
// - rd_status_item#()
//
// Therefore flist.f must compile in this order:
//
//   axi_dma_if.sv
//   rd_status_item.sv
//   rd_status_monitor.sv
//
// Do not `include those files here.  The filelist owns compile order.


// TODO 3: write the class header.
//
// Suggested header:
//
//   class rd_status_monitor extends uvm_monitor;
//
// Why uvm_monitor:
// This component observes DUT status output and publishes transactions.  It is
// passive and should not drive any DUT pins.
class rd_status_monitor extends uvm_monitor;
    `uvm_component_utils(rd_status_monitor)

    virtual axi_dma_if.rd_status_mon_mp rd_status_vif;

    uvm_analysis_port #(rd_status_item#()) ap;


    function new(string name = "rd_status_monitor", uvm_component parent = null);
        super.new(name,parent);
        ap = new("ap",this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_dma_if.rd_status_mon_mp)::get(
            this, "", "rd_status_vif", rd_status_vif
        )) begin
            `uvm_fatal("RD_STATUS_MON", "Failed to get rd_status_vif")
        end

        `uvm_info("RD_STATUS_MON", "Got rd_status_vif", UVM_LOW)
    endfunction

    task sample_one_status();
        rd_status_item#() item;
        item = rd_status_item#()::type_id::create("item");

        item.tag   = rd_status_vif.rd_status_mon_cb.m_axis_read_desc_status_tag;
        item.error = rd_status_vif.rd_status_mon_cb.m_axis_read_desc_status_error;

        item.sample_time = $time;

        ap.write(item);
    endtask //

    virtual task run_phase(uvm_phase phase);
        wait(rd_status_vif.rst == 1'b0);

        forever begin
            @(rd_status_vif.rd_status_mon_cb);

            if(rd_status_vif.rd_status_mon_cb.m_axis_read_desc_status_valid) begin
                sample_one_status();
            end
        end
    endtask //automatic
endclass //rd_status_monitor extends uvm_monitor

// TODO 4: register with the factory.
//
// Put inside the class:
//
//   `uvm_component_utils(rd_status_monitor)
//
// Why:
// The env will create this monitor using type_id::create().


// TODO 5: declare the virtual interface handle.
//
// Use the read-status monitor modport:
//
//   virtual axi_dma_if.rd_status_mon_mp rd_status_vif;
//
// Why modport-typed:
// - The monitor only sees the read status signals it is allowed to observe.
// - It prevents accidental access to unrelated descriptor/data/AXI signals.
// - It makes the monitor boundary explicit.
//
// Field name:
// Use "rd_status_vif" in uvm_config_db.


// TODO 6: declare the analysis port.
//
// Put inside the class:
//
//   uvm_analysis_port #(rd_status_item#()) ap;
//
// What this means:
// The monitor broadcasts observed status transactions.  Later env.connect_phase
// will connect:
//
//   rd_status_mon.ap.connect(scoreboard.rd_status_export);


// TODO 7: add the component constructor.
//
// Suggested code:
//
//   function new(string name = "rd_status_monitor",
//                uvm_component parent = null);
//       super.new(name, parent);
//       ap = new("ap", this);
//   endfunction
//
// Why create ap in new:
// UVM TLM ports are class objects, not components.  They are normally created
// directly with new().


// TODO 8: get the virtual interface in build_phase.
//
// Suggested code shape:
//
//   virtual function void build_phase(uvm_phase phase);
//       super.build_phase(phase);
//
//       if (!uvm_config_db#(virtual axi_dma_if.rd_status_mon_mp)::get(
//               this, "", "rd_status_vif", rd_status_vif
//       )) begin
//           `uvm_fatal("RD_STATUS_MON", "Failed to get rd_status_vif")
//       end
//
//       `uvm_info("RD_STATUS_MON", "Got rd_status_vif", UVM_LOW)
//   endfunction
//
// Required top_tb support later:
//
//   uvm_config_db#(virtual axi_dma_if.rd_status_mon_mp)::set(
//       null,
//       "uvm_test_top.*",
//       "rd_status_vif",
//       dma_if.rd_status_mon_mp
//   );


// TODO 9: write a helper task to sample one status event.
//
// Suggested task name:
//
//   task sample_one_status();
//
// Inside the task:
// 1. Create an item:
//
//      rd_status_item#() item;
//      item = rd_status_item#()::type_id::create("item");
//
// 2. Copy sampled values from the clocking block:
//
//      item.tag   = rd_status_vif.rd_status_mon_cb.m_axis_read_desc_status_tag;
//      item.error = rd_status_vif.rd_status_mon_cb.m_axis_read_desc_status_error;
//
// 3. Fill debug metadata:
//
//      item.sample_time = $time;
//
// 4. Publish it:
//
//      ap.write(item);
//
// Optional debug:
// Add a `uvm_info print that includes tag/error.  Keep verbosity UVM_LOW or
// UVM_MEDIUM so it is visible while we are still learning.


// TODO 10: write run_phase.
//
// Suggested code shape:
//
//   virtual task run_phase(uvm_phase phase);
//       wait (rd_status_vif.rst == 1'b0);
//
//       forever begin
//           @(rd_status_vif.rd_status_mon_cb);
//
//           if (rd_status_vif.rd_status_mon_cb.m_axis_read_desc_status_valid) begin
//               sample_one_status();
//           end
//       end
//   endtask
//
// Why only status_valid:
// This status channel has no ready signal.  A valid pulse is the event.


// TODO 11: add env/top integration later, not now.
//
// After this monitor compiles standalone:
// - add it to flist.f after rd_status_item.sv
// - add the virtual interface set() call in top_tb
// - declare rd_status_monitor rd_status_mon in axi_dma_env
// - create it in axi_dma_env.build_phase
//
// Do not connect to scoreboard yet.  We will create the scoreboard after both
// monitors exist.
