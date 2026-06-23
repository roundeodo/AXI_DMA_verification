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

    // TODO MON-2: declare monitor handles as env members.
    //
    // Add these after rd_agent:
    //
    //   axis_rd_data_monitor axis_rd_mon;
    //   rd_status_monitor    rd_status_mon;
    //
    // Why env owns these monitors:
    // Monitors are reusable verification components, just like agents.  The
    // test should configure the env, but the env should own the reusable
    // structure that observes DUT behavior.

    // Factory registration lets base_test create env through:
    //
    //   axi_dma_env::type_id::create("env", this);
    axis_rd_data_monitor axis_rd_mon;
    rd_status_monitor rd_status_mon;

    axi_dma_scoreboard scoreboard;

    // ref_model receives accepted descriptors and predicts expected DMA
    // outputs.  The scoreboard compares those expected transactions with the
    // actual transactions observed by monitors.
    axi_dma_rd_ref_model ref_model;

    // TODO COV-15: after axi_dma_rd_coverage.sv is complete, declare the
    // coverage collector here:
    //
    //   axi_dma_rd_coverage rd_cov;
    //
    // Why env owns coverage:
    // Coverage is part of the reusable verification environment.  Tests choose
    // scenarios; coverage measures what scenarios actually happened.
    axi_dma_rd_coverage rd_cov;

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

        // TODO MON-3: create the read-data and status monitors.
        //
        // Add after rd_agent creation:
        //
        //   axis_rd_mon  = axis_rd_data_monitor::type_id::create("axis_rd_mon", this);
        //   rd_status_mon = rd_status_monitor::type_id::create("rd_status_mon", this);
        //
        // Why create them unconditionally:
        // These monitors are passive observers.  They should exist whether the
        // descriptor agent is active or passive, because checking and coverage
        // still need to observe DUT outputs.
        axis_rd_mon = axis_rd_data_monitor::type_id::create("axis_rd_mon", this);
        rd_status_mon = rd_status_monitor::type_id::create("rd_status_mon", this);
        scoreboard = axi_dma_scoreboard::type_id::create("scoreboard", this);

        // Create the reference model unconditionally because checking should
        // exist regardless of whether the descriptor agent is active/passive.
        ref_model = axi_dma_rd_ref_model::type_id::create("ref_model", this);

        // TODO COV-16: after declaring rd_cov, create it here:
        //
        //   rd_cov = axi_dma_rd_coverage::type_id::create("rd_cov", this);
        //
        // Create coverage unconditionally.  Even a passive environment can
        // measure observed DUT behavior.
        rd_cov = axi_dma_rd_coverage::type_id::create("rd_cov", this);
        
    endfunction

// TODO MON-4: no scoreboard connection yet.
//
// After both monitors build and get their virtual interfaces, the next module
// will be scoreboard.  Only then will env.connect_phase connect:
//
//   axis_rd_mon.ap.connect(scoreboard.axis_rd_data_export);
//   rd_status_mon.ap.connect(scoreboard.rd_status_export);
//
// Do not write those connections until the scoreboard exists.
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        axis_rd_mon.ap.connect(scoreboard.axis_rd_data_export);
        rd_status_mon.ap.connect(scoreboard.rd_status_export);

        // The ref model starts prediction only after the descriptor driver has
        // completed the descriptor valid/ready handshake and published a stable
        // descriptor copy.
        rd_agent.driver.accepted_desc_ap.connect(ref_model.accepted_desc_export);

        // First real checking path:
        //
        //   descriptor accepted -> ref_model expected status
        //   DUT status monitor  -> actual status
        //   scoreboard compares expected vs actual
        ref_model.expected_status_ap.connect(scoreboard.expected_status_export);

        // TODO DATA-17: connect expected data to scoreboard.
        //
        // After scoreboard adds expected_data_export and ref_model publishes
        // expected_data_ap, connect:
        //
        //   ref_model.expected_data_ap.connect(scoreboard.expected_data_export);
        //
        // This completes the read-data checking path:
        //
        //   descriptor accepted -> ref_model expected data beats
        //   DUT AXIS monitor    -> actual data beats
        //   scoreboard compares expected vs actual
        ref_model.expected_data_ap.connect(scoreboard.expected_data_export);

        // TODO COV-17: after rd_cov exists, connect real observed/accepted
        // transactions to coverage:
        //
        //   rd_agent.driver.accepted_desc_ap.connect(rd_cov.accepted_desc_export);
        //   axis_rd_mon.ap.connect(rd_cov.axis_rd_data_export);
        //   rd_status_mon.ap.connect(rd_cov.rd_status_export);
        //
        // Why accepted/observed transactions:
        // Coverage should describe what actually happened, not what a sequence
        // intended to send before handshake.
        rd_agent.driver.accepted_desc_ap.connect(rd_cov.accepted_desc_export);
        axis_rd_mon.ap.connect(rd_cov.axis_rd_data_export);
        rd_status_mon.ap.connect(rd_cov.rd_status_export);
        
    endfunction

// TODO NEXT: add checking components.
//
// After monitor integration is stable, add:
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
