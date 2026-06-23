// uvm_pkg contains the UVM base classes
import uvm_pkg::*;

// uvm_macros.svh defines helper macros such as `uvm_component_utils,
// `uvm_info, and `uvm_fatal.  The macros are not classes, so importing
// uvm_pkg alone is not enough.
`include "uvm_macros.svh"

// base_test is the first UVM component created by run_test("base_test").
// It is the top-level class-side entry point of the verification environment.
// Later, this class will create env/agent/sequence objects in its phases.
class base_test extends uvm_test;

    // Register this class with the UVM factory.
    // Purpose:
    // 1. Let run_test("base_test") create this class by name.
    // 2. Enable factory override later, which is how UVM swaps tests or
    //    components without editing the original construction code.
    `uvm_component_utils(base_test)

    // virtual interface is a class-side handle that points to a real
    // SystemVerilog interface instance in top_tb.
    //
    // Why virtual:
    // UVM classes are dynamic objects and cannot directly instantiate or
    // connect to hardware signals.  top_tb owns the real axi_dma_if instance;
    // base_test only stores a handle to it.
    virtual axi_dma_if vif;

    // env is the top-level reusable verification container for this DMA UVC.
    // Keep it as a class member because it is part of the component hierarchy.
    axi_dma_env env;

    // UVM components use a standard constructor signature:
    // - name: instance name in the UVM component hierarchy.
    // - parent: parent component, null for the root test.
    //
    // When parent is not null:
    // Child components created inside another component should pass that
    // component as parent, for example:
    // env = axi_dma_env::type_id::create("env", this);
    // This makes the hierarchy uvm_test_top.env and lets config/reporting/
    // phase traversal work through the component tree.
    //
    // The default name should match the class name for readable reports.
    function new(string name = "base_test", uvm_component parent = null);
        // 
        // Always call the parent constructor so uvm_test/uvm_component can
        // register this instance into the UVM hierarchy correctly.
        super.new(name, parent);
    endfunction //new()


    // build_phase is for constructing and configuring the testbench hierarchy.
    // The test decides the high-level configuration, then creates env.  The env
    // creates reusable verification components such as agents and monitors.
    virtual function void build_phase(uvm_phase phase);
        // Let the parent class do its own build work first. super means call
        // the same function in the parent class.
        // This is a good UVM habit and avoids breaking inherited behavior.
        super.build_phase(phase);

        // UVM report message.  UVM_LOW means the message is normally visible.
        // This confirms that UVM successfully created the test and entered
        // build_phase.
        `uvm_info("BASE_TEST", "build_phase entered", UVM_LOW)

        // Get the virtual interface that top_tb placed in uvm_config_db with:
        // uvm_config_db#(virtual axi_dma_if)::set(null, "uvm_test_top", "vif", dma_if);
        //
        // Arguments:
        // - this: start searching from this component.
        // - "": use this component's exact scope, no child instance path.
        // - "vif": field name/key; must match the set() call in top_tb.
        // - vif: destination variable that receives the handle.
        if (!uvm_config_db#(virtual axi_dma_if)::get(this, "", "vif", vif)) begin
            // Fatal error stops simulation immediately.
            // Without a valid vif, any future driver/monitor would either fail
            // or drive nothing, so continuing would only create confusing bugs.
            `uvm_fatal("BASE_TEST", "Failed to get virtual axi_dma_if from uvm_config_db")
        end

        // If we reach here, the static world (top_tb/interface/DUT) and the
        // dynamic UVM world (base_test) are connected correctly.
        `uvm_info("BASE_TEST", "Got virtual axi_dma_if from uvm_config_db", UVM_LOW)
        
        uvm_config_db#(uvm_active_passive_enum)::set(
            this,
            "env.rd_agent",
            "is_active",
            UVM_ACTIVE
        );

        // Create the reusable environment after placing its configuration.
        // This lets env.rd_agent read "is_active" during its own build_phase.
        env = axi_dma_env::type_id::create("env",this);
    endfunction

    // run_phase is a task phase, so it can consume simulation time.
    // Stimulus, sequences, waits, and end-of-test timing usually live here
    // or inside sequences/components started from here.
    virtual task run_phase(uvm_phase phase);
        // Raise an objection to tell UVM: "the test is still running."
        // If nobody raises an objection, UVM may end run_phase immediately.
        phase.raise_objection(this);

        // This log proves that the simulation reached time-consuming UVM code.
        `uvm_info("BASE_TEST", "run_phase entered", UVM_LOW);

        // Temporary wait used only for the first skeleton test.
        // Later this will be replaced by starting a sequence, waiting for the
        // scoreboard to finish, or waiting for a specific DUT event.
        //
        // Real-project style:
        // Do not start rd_desc_smoke_sequence directly from base_test.  Keep
        // base_test reusable and create a derived test, such as rd_smoke_test,
        // to express this specific scenario.
        #100ns;

        // Drop the objection to tell UVM: "this test has finished."
        // When all objections are dropped, UVM can cleanly end run_phase.
        phase.drop_objection(this);
    endtask //

endclass //base_test extends uvm_test
