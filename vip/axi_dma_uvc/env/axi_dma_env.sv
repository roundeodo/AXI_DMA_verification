// Milestone 3B: axi_dma_env owns the read descriptor agent.
//
// What we are learning in this step:
// 1. env is the top-level container of the reusable verification platform.
// 2. base_test should not directly create every low-level component forever.
// 3. The env creates child agents so base_test does not manage low-level
//    verification components directly.
//
// Target hierarchy for this milestone:
//
//   uvm_test_top
//     env
//       rd_agent
//         sequencer
//         driver
//
// Later hierarchy will grow into:
//
//   uvm_test_top
//     env
//       rd_agent
//         sequencer
//         driver
//       axis_read_data_monitor
//       rd_status_monitor
//       scoreboard
//
// Note:
// The AXI memory slave is currently the RTL module axi_ram instantiated in
// top_tb.  It is not a UVM component inside env, so env will observe DMA
// outputs through monitors and check them in scoreboard.

// UVM package and macro support:
// - uvm_env is defined in uvm_pkg.
// - `uvm_component_utils and `uvm_info are defined in uvm_macros.svh.
import uvm_pkg::*;
`include "uvm_macros.svh"

// Compile-order dependency:
//
// axi_dma_env will declare:
//
//   rd_desc_agent rd_agent;
//
// Therefore flist.f must compile:
//
//   dma_rd_desc_item.sv
//   rd_desc_sequencer.sv
//   rd_desc_driver.sv
//   rd_desc_agent.sv
//   axi_dma_env.sv
//
// in that order.

// axi_dma_env is a uvm_env because it is the reusable container for agents,
// models, monitors, scoreboard, and coverage.
//
// axi_dma_env is a long-lived component in the UVM hierarchy.  Its job is to
// contain lower-level verification components for this DMA IP.
class axi_dma_env extends uvm_env;
    // rd_agent owns the active descriptor side of the read-DMA testbench:
    // sequence item flow -> sequencer -> driver -> DUT descriptor input.
    rd_desc_agent rd_agent;

    // Factory registration lets base_test create env through:
    //
    //   axi_dma_env::type_id::create("env", this);
    `uvm_component_utils(axi_dma_env)

    // Why env owns the agent:
    // base_test should describe the test intent, while env owns the reusable
    // verification structure.  Creating rd_agent here gives the hierarchy:
    //
    //   uvm_test_top.env.rd_agent
    //
    // This path matters for uvm_config_db settings such as:
    //
    //   uvm_config_db#(uvm_active_passive_enum)::set(
    //       this, "env.rd_agent", "is_active", UVM_ACTIVE
    //   );

    // Standard UVM component constructor.  base_test passes parent = this, so
    // the env appears in the hierarchy as uvm_test_top.env.
    function new(string name = "axi_dma_env", uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("AXI_DMA_ENV", "build_phase_entered", UVM_LOW)

        // Why parent = this:
        // The agent is a child of env, so config paths, reports, and phase
        // traversal all see it as:
        //
        //   uvm_test_top.env.rd_agent
        //
        // Why create in env, not base_test:
        // In real UVC structure, env is the reusable verification container.
        // Tests configure the env and start sequences; they should not
        // manually construct every low-level agent.
        rd_agent = rd_desc_agent::type_id::create("rd_agent",this);
    endfunction

// TODO NEXT: add monitor and checking components.
//
// After the descriptor driver path is stable, add:
// - AXIS read data monitor
// - read status monitor
// - scoreboard


// TODO NEXT: add connect_phase.
//
// The env does not need connect_phase while it only contains rd_agent.  It will
// need connect_phase when there are TLM analysis ports to connect, for example:
// - monitor analysis ports -> scoreboard exports
// - driver accepted-descriptor analysis port -> scoreboard export


// Local acceptance criteria after you complete this file:
// - axi_dma_env extends uvm_env.
// - It uses `uvm_component_utils(axi_dma_env).
// - It has new(name, parent) and calls super.new(name, parent).
// - build_phase calls super.build_phase(phase).
// - build_phase prints one UVM info message.
// - It declares rd_desc_agent rd_agent.
// - It creates rd_agent in build_phase with parent = this.



endclass //axi_dma_env extends uvm_env
