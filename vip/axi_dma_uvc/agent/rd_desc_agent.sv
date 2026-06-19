// Milestone 5: rd_desc_agent
//
// Engineering goal:
// Build a real UVC-style agent for the AXI DMA read descriptor input channel.
// This agent is the container for the components that belong to this protocol
// role.  In active mode it owns both sequencer and driver.
//
// Current component hierarchy target after this milestone:
//
//   uvm_test_top
//     env
//       rd_agent
//         sequencer
//         driver
//
// Later hierarchy will also add:
//         monitor   // optional for descriptor handshakes
//
// What belongs in this agent:
// - Creation of rd_desc_sequencer.
// - Creation of rd_desc_driver.
// - Later creation of descriptor monitor, if we decide it adds value.
// - connect_phase wiring between sequencer and driver.
// - active/passive configuration, matching real reusable UVC style.
//
// What does NOT belong in this agent:
// - Descriptor field generation policy.  That belongs in sequences.
// - Pin-level valid/ready driving.  That belongs in driver.
// - DUT output checking.  That belongs in monitor/scoreboard.

// Real-project style note:
// This agent should support active/passive mode from the beginning.
//
// - UVM_ACTIVE:
//   The agent creates sequencer + driver.  It can actively send read
//   descriptors into the DUT.
//
// - UVM_PASSIVE:
//   The agent must not create a driver or sequencer.  It only observes through
//   monitor components.  We do not have the monitor yet, so passive mode will
//   temporarily create no children, but the structure is still useful because
//   it teaches the reusable-agent flow used in real projects.

// UVM package and macro support:
// - uvm_agent and uvm_component are in uvm_pkg.
// - `uvm_component_utils and `uvm_info are macro definitions.
import uvm_pkg::*;
`include "uvm_macros.svh"

// Compile-order dependency:
//
// This agent declares:
//
//   rd_desc_sequencer sequencer;
//   rd_desc_driver    driver;
//
// Therefore flist.f must compile:
//
//   dma_rd_desc_item.sv
//   rd_desc_sequencer.sv
//   rd_desc_driver.sv
//   rd_desc_agent.sv
//
// in that order.


// This is a long-lived UVM component that groups the read descriptor channel's
// sequencer/driver/monitor pieces.
class rd_desc_agent extends uvm_agent;

    // Factory registration lets the env create this agent through type_id and
    // keeps the door open for factory overrides in later tests.
    `uvm_component_utils(rd_desc_agent)

    // Reusable-agent mode control.
    // Default is active for block-level DMA read tests.  Tests or envs can
    // override this through uvm_config_db when this agent should only observe.
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Child component handles are class members because build_phase creates
    // them and connect_phase later needs the same handles for TLM wiring.
    rd_desc_sequencer sequencer;
    rd_desc_driver driver;

    // Standard UVM component constructor.  parent is supplied by axi_dma_env
    // when it creates rd_agent, which places this agent in the UVM hierarchy.
    function new(string name = "rd_desc_agent", uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("RD_DESC_AGENT", "build_phase entered", UVM_LOW)

        // is_active is optional config.  If no test sets it, the member keeps
        // its default UVM_ACTIVE value.  void'(...) documents that ignoring the
        // get() return value is intentional.
        void'(uvm_config_db#(uvm_active_passive_enum)::get(this,"","is_active",is_active));

        // Active agents create sequencer + driver and can drive DUT inputs.
        // Passive agents must not create these active components.  A monitor
        // will be created unconditionally later, after we add that component.
        if(is_active == UVM_ACTIVE)begin
            sequencer = rd_desc_sequencer::type_id::create("sequencer",this);
            driver = rd_desc_driver::type_id::create("driver",this);
        end
    endfunction

    // Connect the driver's built-in TLM pull port to the sequencer's export.
    // This is a transaction-level connection; the physical signal connection
    // remains rd_desc_driver -> axi_dma_if.rd_desc_drv_mp.
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(is_active == UVM_ACTIVE)begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass //rd_desc_agent extends uvm_agent

// TODO LATER: optional descriptor monitor.
//
// A descriptor monitor can observe actual accepted descriptors and publish
// them to the scoreboard.  We may add it later if it helps debug or checking.


// Local acceptance criteria:
// - rd_desc_agent extends uvm_agent.
// - It uses `uvm_component_utils(rd_desc_agent).
// - It declares uvm_active_passive_enum is_active = UVM_ACTIVE.
// - It gets optional "is_active" config from uvm_config_db.
// - It declares rd_desc_sequencer sequencer.
// - It declares rd_desc_driver driver.
// - It creates sequencer and driver in build_phase only when active.
// - It connects driver.seq_item_port to sequencer.seq_item_export in
//   connect_phase only when active.
// - It has no valid/ready or DUT signal driving code.
