// Milestone 7B: rd_status_item TODO scaffold
//
// Engineering goal:
// Define the transaction type that rd_status_monitor will publish when it
// observes DMA read descriptor completion status.
//
// The read status channel in axi_dma_rd is simpler than AXIS data:
//
//   m_axis_read_desc_status_tag
//   m_axis_read_desc_status_error
//   m_axis_read_desc_status_valid
//
// There is no ready signal on this status interface.  A status event exists
// when status_valid is sampled high.  The monitor converts that signal-level
// event into one rd_status_item and publishes it to the scoreboard.
//
// Why this item matters:
// The descriptor has a tag.  The status returns a tag.  The scoreboard will use
// the returned tag to check that the DUT completed the correct descriptor and
// reported the expected error code.

// TODO 1: import UVM and include UVM macros.
//
// Follow the same pattern as dma_rd_desc_item.sv:
//
//   import uvm_pkg::*;
//   `include "uvm_macros.svh"


// TODO 2: create a parameterized class.
//
// Suggested class header:
//
//   class rd_status_item #(
//       parameter int TAG_WIDTH = 8
//   ) extends uvm_sequence_item;
//
// Why parameterized:
// TAG_WIDTH mirrors the DUT/interface tag width.  The status item should follow
// that width instead of hard-coding 8 everywhere.


// TODO 3: add observed status fields inside the class.
//
// Suggested fields:
//
//   bit [TAG_WIDTH-1:0] tag;
//   bit [3:0]           error;
//
// Why these fields are not rand:
// This item represents actual DUT output sampled by a monitor.  The monitor
// should copy signal values into the item.  It should not randomize them.


// TODO 4: optionally add debug metadata.
//
// Suggested optional field:
//
//   time sample_time;
//
// This is useful in logs when comparing "when did the data frame end?" against
// "when did the status appear?"  If you later use object compare, sample_time
// should usually be no-compare/debug-only.


// TODO 5: register the object with UVM factory and field automation.
//
// Because this class is parameterized, use:
//
//   `uvm_object_param_utils_begin(rd_status_item)
//       `uvm_field_int(tag,   UVM_ALL_ON)
//       `uvm_field_int(error, UVM_ALL_ON)
//       ...
//   `uvm_object_utils_end
//
// This makes print/copy/compare available in the same style as
// dma_rd_desc_item.


// TODO 6: add the constructor.
//
// This is a uvm_object, not a component, so constructor has no parent:
//
//   function new(string name = "rd_status_item");
//       super.new(name);
//   endfunction


// TODO LATER: define readable error names.
//
// The RTL uses 4-bit error codes.  For the first smoke test, checking
// error == 0 is enough.  Later we can add constants or convert2string() output
// so logs print names like DMA_ERROR_NONE, SLVERR, or DECERR.
