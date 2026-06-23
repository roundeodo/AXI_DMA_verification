// Milestone 6: rd_desc_driver
//
// Engineering goal:
// Build the first real pin-driving component in the read descriptor UVC.
// The driver consumes dma_rd_desc_item transactions from rd_desc_sequencer and
// drives the DUT's s_axis_read_desc_* input channel.
//
// Final data path:
//
//   rd_desc_sequence
//       creates dma_rd_desc_item
//       |
//       v
//   rd_desc_sequencer
//       |
//       v
//   rd_desc_driver
//       |
//       v
//   axi_dma_if.rd_desc_drv_mp
//       |
//       v
//   axi_dma_rd.s_axis_read_desc_*
//
// What belongs in this driver:
// - Get dma_rd_desc_item from seq_item_port.
// - Drive addr/len/tag/id/dest/user onto interface signals.
// - Assert s_axis_read_desc_valid.
// - Wait until s_axis_read_desc_ready is high on a clock edge.
// - Deassert valid and call item_done().
// - Drive safe idle values during reset/idle.
//
// What does NOT belong in this driver:
// - Generating descriptor contents.  That belongs in sequences.
// - Checking read data/status.  That belongs in monitors/scoreboard.
// - Modeling AXI memory responses.  In the current baseline, axi_ram in top_tb
//   owns the AXI slave response side.

// UVM package and macro support:
// - uvm_driver and uvm_component are in uvm_pkg.
// - `uvm_component_utils, `uvm_info, and `uvm_fatal are macros.
import uvm_pkg::*;
`include "uvm_macros.svh"

// Compile-order dependencies:
// This driver uses:
// - dma_rd_desc_item#()
// - axi_dma_if
//
// Therefore, when we later add this file to flist.f, order must include:
//
//   axi_dma_if.sv
//   dma_rd_desc_item.sv
//   rd_desc_driver.sv
//
// We do not `include those files here.  The filelist owns compile order.


// Meaning:
// - This driver consumes dma_rd_desc_item transactions.
// - The built-in seq_item_port type will match dma_rd_desc_item#().
class rd_desc_driver extends uvm_driver#(dma_rd_desc_item#());

    // Factory registration lets rd_desc_agent create this driver by type_id.
    `uvm_component_utils(rd_desc_driver)

    // The driver uses a modport-typed virtual interface handle.
    //
    // Why modport-typed:
    // - It limits this driver to the read descriptor signals it owns.
    // - It prevents accidental access to unrelated AXI/AXIS/status signals.
    // - It makes the driver boundary explicit in the type system.
    //
    // Why the field name is "rd_desc_vif":
    // Later the env will have multiple interface views: descriptor, AXIS read
    // data, status, and possibly memory observation views.  A specific name is
    // easier to configure and debug than a generic "vif".
    virtual axi_dma_if.rd_desc_drv_mp rd_desc_vif;

    // Publish a descriptor snapshot after the descriptor valid/ready handshake
    // completes.  The reference model will use this as its input, because only
    // accepted descriptors should produce expected DMA output.
    uvm_analysis_port #(dma_rd_desc_item#()) accepted_desc_ap;


    // Standard UVM component constructor.
    function new(string name = "rd_desc_driver", uvm_component parent = null);
        super.new(name,parent);
        accepted_desc_ap = new("accepted_desc_ap", this);
    endfunction //new()

    // build_phase gets the modport view placed in uvm_config_db by top_tb.
    // A driver without a valid interface would silently drive nothing or crash
    // later, so a missing rd_desc_vif is a fatal configuration error.
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_dma_if.rd_desc_drv_mp)::get(this,"","rd_desc_vif",rd_desc_vif)) begin
            `uvm_fatal("RD_DESC_DRIVER","Failed to get rd_desc_vif")
        end

        `uvm_info("RD_DESC_DRIVER","Got rd_desc_vif", UVM_LOW);

    endfunction

    function void publish_accepted_desc(dma_rd_desc_item#() item);
        dma_rd_desc_item#() accepted;

        accepted = dma_rd_desc_item#()::type_id::create("accepted");
        accepted.copy(item);
        accepted_desc_ap.write(accepted);

        `uvm_info("RD_DESC_DRIVER",
            $sformatf("Published accepted descriptor addr=0x%0h len=%0d tag=0x%0h",
                      accepted.addr, accepted.len, accepted.tag),
            UVM_LOW)
    endfunction

    // Drive a safe idle state on descriptor inputs.
    //
    // Why read_enable = 1:
    // For the first directed read test, we want the DMA read path enabled.
    // Later we can make this configurable.
    //
    // Important:
    // Only drive signals that belong to rd_desc_drv_mp:
    // - read descriptor payload
    // - read descriptor valid
    // - read_enable
    task drive_idle();
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_addr <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_len <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_tag <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_id <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_dest <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_user <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_valid <= 'd0;
        rd_desc_vif.rd_desc_drv_cb.read_enable <= 1'b1;
        // ready is a DUT output.  The driver observes it during handshake; it
        // must never drive ready.
    endtask 

    // Drive one descriptor transaction onto the DUT input channel.
    //
    // Why this shape:
    // - payload is stable while valid is asserted.
    // - handshake completes when valid && ready are sampled on a clock edge.
    // - after handshake, valid returns to idle.
    // - the clocking block controls when ready is sampled and when
    //   valid/payload are driven, reducing race risk between testbench and DUT.
    //
    // Later refinement:
    // We may add optional pre-valid delay or inter-transfer gap after the basic
    // smoke test works.
    task drive_one_desc(dma_rd_desc_item#() item);
        @(rd_desc_vif.rd_desc_drv_cb);
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_addr <= item.addr;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_len <= item.len;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_tag <= item.tag;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_id <= item.id;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_dest <= item.dest;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_user <= item.user;
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_valid <= 1'b1;

        do begin
            @(rd_desc_vif.rd_desc_drv_cb);
        end while(!rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_ready);

        // pull down valid after successful handshake
        rd_desc_vif.rd_desc_drv_cb.s_axis_read_desc_valid <= 1'b0;
    endtask 


    // run_phase consumes sequence items forever.
    //
    // Why no objections here:
    // The test or sequence should control end-of-test objections.  Drivers
    // usually run forever and react to available items.
    //
    // Why req declaration goes at the top:
    // SystemVerilog requires declarations before procedural statements in many
    // tool modes.
    virtual task run_phase(uvm_phase phase);
        dma_rd_desc_item#() req;

        drive_idle();

        wait(rd_desc_vif.rst == 1'b0);
        @(rd_desc_vif.rd_desc_drv_cb);

        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("RD_DESC_DRIVER", "Driving read descriptor", UVM_LOW)
            drive_one_desc(req);
            publish_accepted_desc(req);
            seq_item_port.item_done();
        end
    endtask 


    // TODO NEXT: publish accepted descriptors to the scoreboard.
    //
    // Next, add an analysis port to this driver:
    //
    //   uvm_analysis_port #(dma_rd_desc_item#()) accepted_desc_ap;
    //
    // Create it in new():
    //
    //   accepted_desc_ap = new("accepted_desc_ap", this);
    //
    // After drive_one_desc() completes the valid/ready handshake, send a copy
    // of the accepted item:
    //
    //   dma_rd_desc_item#() accepted;
    //   accepted = dma_rd_desc_item#()::type_id::create("accepted");
    //   accepted.copy(req);
    //   accepted_desc_ap.write(accepted);
    //
    // Why after handshake:
    // The reference model should predict only descriptors the DUT actually
    // accepted, not descriptors that a sequence merely tried to send.
    //
    // Why copy:
    // Analysis subscribers should receive a stable transaction snapshot.  If
    // the original req handle is reused or modified later, the reference model
    // should not see its historical descriptor change.

endclass //rd_desc_driver extends uvm_driver#(dma_rd_desc_item#())


// TODO LATER 1: reset robustness.
//
// First version waits for reset to deassert once.  Later, if the DUT can reset
// during traffic, enhance the driver to abort current handshakes and return to
// idle on reset assertion.


// TODO LATER 2: driver configuration.
//
// Later config knobs may include:
// - enable read path default
// - pre_valid_delay
// - inter_descriptor_gap
// - verbosity/debug toggles
//
// Do not add these until the simple directed path works.


// Local acceptance criteria:
// - rd_desc_driver extends uvm_driver #(dma_rd_desc_item#()).
// - It uses `uvm_component_utils(rd_desc_driver).
// - It gets virtual axi_dma_if from uvm_config_db.
// - It has drive_idle(), drive_one_desc(), and run_phase().
// - It calls get_next_item() and item_done().
// - It only drives read descriptor input signals and read_enable.
// - It does not check DUT outputs.
