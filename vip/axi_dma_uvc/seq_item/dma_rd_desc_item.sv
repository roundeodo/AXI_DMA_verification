// Milestone 2: dma_rd_desc_item
//
// What we are learning in this step:
// 1. A UVM transaction/sequence item describes one abstract operation.
// 2. It should contain the information payload of the operation.
// 3. It should not contain pin-level handshake details such as valid/ready.
// 4. It should be easy to create, print, copy, and later randomize.
//
// Verification flow around this item:
//
//   sequence creates dma_rd_desc_item
//       |
//       v
//   sequencer passes item to driver
//       |
//       v
//   driver converts item fields into s_axis_read_desc_* pin activity
//       |
//       v
//   DUT issues AXI read requests and returns AXIS read data/status
//
// Current status:
// - DONE: define the read descriptor payload fields.
// - DONE: register the item with the UVM factory.
// - DONE: create and print one item from base_test.
// - LATER: add constraints after the first directed smoke path is stable.
// - LATER: use this item from a sequence instead of manually in base_test.

// uvm_pkg contains uvm_sequence_item and other UVM object base classes.
import uvm_pkg::*;

// uvm_macros.svh defines `uvm_object_param_utils_begin, `uvm_field_int,
// and `uvm_object_utils_end.  Importing uvm_pkg does not import macros.
`include "uvm_macros.svh"

// dma_rd_desc_item models one read descriptor sent into axi_dma_rd.
//
// The RTL descriptor input channel has these payload signals:
//
//   s_axis_read_desc_addr
//   s_axis_read_desc_len
//   s_axis_read_desc_tag
//   s_axis_read_desc_id
//   s_axis_read_desc_dest
//   s_axis_read_desc_user
//
// The corresponding transaction fields are:
//
//   addr, len, tag, id, dest, user
//
// Do not add s_axis_read_desc_valid or s_axis_read_desc_ready here.
// Reason:
// valid/ready describe cycle-level handshake behavior.  The driver owns that
// behavior.  The sequence item only answers: "what read operation do I want?"
class dma_rd_desc_item #(
    // These parameters mirror the current default widths in axi_dma_if.
    // We parameterize the item now so the UVC can later follow DUT/interface
    // width changes without rewriting field declarations.
    parameter int AXI_ADDR_WIDTH  = 16,
    parameter int LEN_WIDTH       = 20,
    parameter int TAG_WIDTH       = 8,
    parameter int AXIS_ID_WIDTH   = 8,
    parameter int AXIS_DEST_WIDTH = 8,
    parameter int AXIS_USER_WIDTH = 1
) extends uvm_sequence_item;

    // addr: byte address in AXI memory where the DMA read should start.
    // This is the main "where do I read from?" part of the descriptor.
    rand bit [AXI_ADDR_WIDTH-1:0] addr;

    // len: number of bytes requested by this descriptor.
    // We leave it unconstrained for now; later we will add len > 0.
    rand bit [LEN_WIDTH-1:0] len;

    // tag: transaction identifier returned on read descriptor status.
    // The scoreboard will use this to match a completed status to the request.
    rand bit [TAG_WIDTH-1:0] tag;

    // id/dest/user: AXIS sideband metadata that the read path may propagate
    // onto m_axis_read_data_tid/tdest/tuser depending on DUT parameters.
    rand bit [AXIS_ID_WIDTH-1:0]   id;
    rand bit [AXIS_DEST_WIDTH-1:0] dest;
    rand bit [AXIS_USER_WIDTH-1:0] user;

    // Register this transaction class with the UVM factory.
    //
    // Why object_param_utils:
    // This is a parameterized uvm_object/uvm_sequence_item, not a component.
    // Components use `uvm_component_utils; objects use object utils.
    //
    // Why field macros:
    // These fields then participate in built-in print/copy/compare/record
    // behavior.  The rd_desc.print() output you saw came from this block.
    `uvm_object_param_utils_begin(dma_rd_desc_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(len,  UVM_ALL_ON)
        `uvm_field_int(tag,  UVM_ALL_ON)
        `uvm_field_int(id,   UVM_ALL_ON)
        `uvm_field_int(dest, UVM_ALL_ON)
        `uvm_field_int(user, UVM_ALL_ON)
    `uvm_object_utils_end

    // uvm_sequence_item is a uvm_object, not a uvm_component.
    // Therefore the constructor takes only a name and has no parent argument.
    //
    // Compare with base_test:
    // - base_test extends uvm_test/uvm_component and needs parent.
    // - dma_rd_desc_item is a short-lived data object and has no hierarchy.
    function new(string name = "dma_rd_desc_item");
        super.new(name);
    endfunction

    // TODO LATER 1: add basic constraints after smoke testing is stable.
    //
    // We intentionally do not add constraints in the first version.  The first
    // directed test should be easy to debug with manually assigned values.
    //
    // Candidate future constraints:
    // - len > 0
    // - addr inside the memory model address range
    // - addr aligned to AXI beat size when ENABLE_UNALIGNED == 0
    // - targeted values for burst and 4KB boundary scenarios

    // TODO LATER 2: consider a custom convert2string().
    //
    // rd_desc.print() is already useful because of the field macros.  A custom
    // convert2string() can later make concise one-line debug messages such as:
    // "RD_DESC addr=0x1000 len=16 tag=1 id=1".

    // TODO LATER 3: decide where timing-control knobs belong.
    //
    // We may eventually want pre_valid_delay or idle-cycle control.  Do not
    // add it yet.  First write the driver, then decide whether such knobs
    // belong in this item, in a sequence config object, or in the driver config.

endclass
