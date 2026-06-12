import uvm_pkg::*;
`include "uvm_macros.svh"

class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    virtual axi_dma_if vif;

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);  // super means the build phase in the parent class will be also executed
        `uvm_info("BASE_TEST", "build_phase entered", UVM_LOW)

        if (!uvm_config_db#(virtual axi_dma_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("BASE_TEST", "Failed to get virtual axi_dma_if from uvm_config_db")
        end

        `uvm_info("BASE_TEST", "Got virtual axi_dma_if from uvm_config_db", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("BASE_TEST","run_phase entered",UVM_LOW);
        #100ns;
        phase.drop_objection(this);
    endtask
endclass
