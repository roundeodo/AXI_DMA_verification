// Milestone 7A: axis_rd_data_item TODO scaffold
//
// Engineering goal:
// Define the transaction type that axis_rd_data_monitor will publish when it
// observes DMA read data on m_axis_read_data_*.
//
// Important learning point:
// This is still a uvm_sequence_item even though it is not created by a sequence.
// In UVM, "sequence_item" often means "transaction object".  It can be used on
// either side of the testbench:
//
//   sequence -> sequencer -> driver       uses dma_rd_desc_item
//   monitor  -> analysis port -> scoreboard uses axis_rd_data_item
//
// First design choice:
// This item represents one accepted AXIS beat, not a whole frame.
//
// Why one beat first:
// - The monitor can publish one item every time tvalid && tready is sampled.
// - The scoreboard can later reconstruct a frame by collecting beats until
//   tlast == 1.
// - This keeps the first monitor simple and waveform-friendly.
//
// The monitor will fill this item from these DUT output signals:
//
//   m_axis_read_data_tdata
//   m_axis_read_data_tkeep
//   m_axis_read_data_tlast
//   m_axis_read_data_tid
//   m_axis_read_data_tdest
//   m_axis_read_data_tuser
//
// It should not contain tvalid or tready as normal payload fields.
// Reason:
// valid/ready are handshake conditions used by the monitor to decide when a
// beat exists.  Once a beat is accepted, the transaction should describe the
// accepted data, not the cycle-level handshake itself.

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
//   class axis_rd_data_item #(
//       parameter int AXIS_DATA_WIDTH = 32,
//       parameter int AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
//       parameter int AXIS_ID_WIDTH   = 8,
//       parameter int AXIS_DEST_WIDTH = 8,
//       parameter int AXIS_USER_WIDTH = 1
//   ) extends uvm_sequence_item;
//
// Why parameterized:
// These widths mirror axi_dma_if/DUT parameters.  Keeping the item
// parameterized makes the UVC less fragile when widths change.


// TODO 3: add observed data fields inside the class.
//
// Suggested fields:
//
//   bit [AXIS_DATA_WIDTH-1:0] data;
//   bit [AXIS_KEEP_WIDTH-1:0] keep;
//   bit                       last;
//   bit [AXIS_ID_WIDTH-1:0]   id;
//   bit [AXIS_DEST_WIDTH-1:0] dest;
//   bit [AXIS_USER_WIDTH-1:0] user;
//
// Why these fields are not rand:
// This item represents actual DUT output sampled by a monitor.  The monitor
// should copy signal values into the item.  Randomization belongs to sequences,
// not to observed actual-result transactions.


// TODO 4: optionally add debug metadata.
//
// Suggested optional fields:
//
//   int unsigned beat_index;
//   time         sample_time;
//
// beat_index:
// The monitor can count beats within the current frame.  This is not a DUT
// signal, but it makes logs and scoreboard failures much easier to read.
//
// sample_time:
// Useful for debugging.  If you register it with field macros later, consider
// UVM_NOCOMPARE so object compare does not fail only because sample times differ.


// TODO 5: register the object with UVM factory and field automation.
//
// Because this class is parameterized, use:
//
//   `uvm_object_param_utils_begin(axis_rd_data_item)
//       `uvm_field_int(data, UVM_ALL_ON)
//       ...
//   `uvm_object_utils_end
//
// Register all required payload fields.  If you add sample_time, mark it as
// debug-only or no-compare later.


// TODO 6: add the constructor.
//
// This is a uvm_object, not a component, so constructor has no parent:
//
//   function new(string name = "axis_rd_data_item");
//       super.new(name);
//   endfunction


// TODO LATER: add a helper to count valid bytes from keep.
//
// A useful function later:
//
//   function int unsigned valid_byte_count();
//
// It should count the number of 1 bits in keep.  The scoreboard will use this
// when converting AXIS beats back into a byte stream.
