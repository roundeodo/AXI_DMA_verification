// Milestone 9: axi_dma_scoreboard
//
// Engineering goal:
// Build the first checking component for the read DMA path.
//
// First version scope:
// - Receive actual AXIS read-data beats from axis_rd_data_monitor.
// - Receive actual read status events from rd_status_monitor.
// - Print what it receives so we can prove the monitor -> scoreboard TLM path.
//
// Later version scope:
// - Receive accepted read descriptors from rd_desc_driver.
// - Build expected read-data bytes from descriptor + memory preload pattern.
// - Compare expected vs actual read data.
// - Compare expected vs actual status tag/error.
//
// Data flow after env.connect_phase:
//
//   axis_rd_data_monitor.ap
//       |
//       v
//   scoreboard.axis_rd_data_export
//
//   rd_status_monitor.ap
//       |
//       v
//   scoreboard.rd_status_export
//
// Why scoreboard is separate from monitor:
// The monitor only reports what happened.  The scoreboard decides whether what
// happened is correct.  Keeping those roles separate makes the UVC reusable.

import uvm_pkg::*;
`include "uvm_macros.svh"

// UVM package and macro support:
// - uvm_scoreboard and uvm_analysis_imp are in uvm_pkg.
// - `uvm_component_utils and `uvm_info are macros.


// A normal uvm_analysis_imp calls a method named write().
// But this scoreboard must receive two different transaction types:
//
// - axis_rd_data_item#()
// - rd_status_item#()
//
// One class cannot have two write() functions with different argument types in
// a clean UVM style.  UVM solves this with `uvm_analysis_imp_decl.
`uvm_analysis_imp_decl(_axis_rd_data)
`uvm_analysis_imp_decl(_rd_status)
// Expected status uses a separate analysis imp so the scoreboard can receive
// expected status from the reference model through write_expected_rd_status().
`uvm_analysis_imp_decl(_expected_rd_status)
// Expected read data uses a separate analysis imp so the scoreboard can receive
// expected AXIS beats from the reference model through
// write_expected_axis_rd_data().
`uvm_analysis_imp_decl(_expected_axis_rd_data)
//
// These macros create specialized imp classes that call:
//
//   write_axis_rd_data(axis_rd_data_item#() item)
//   write_rd_status(rd_status_item#() item)
//   write_expected_rd_status(rd_status_item#() item)
//
// respectively.

// Compile-order dependencies:
// This scoreboard uses:
// - axis_rd_data_item#()
// - rd_status_item#()
//
// Therefore flist.f must compile:
//
//   axis_rd_data_item.sv
//   rd_status_item.sv
//   axi_dma_scoreboard.sv
//
// before axi_dma_env.sv, because env will declare the scoreboard handle.


// Why uvm_scoreboard:
// It is a UVM component intended for checking.  It participates in phases and
// can be created by env through the factory.
class axi_dma_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_dma_scoreboard)

    uvm_analysis_imp_axis_rd_data #(axis_rd_data_item#(), axi_dma_scoreboard) axis_rd_data_export;
    uvm_analysis_imp_rd_status #(rd_status_item#(), axi_dma_scoreboard) rd_status_export;

    // Receive expected status transactions from the reference model.
    uvm_analysis_imp_expected_rd_status #(rd_status_item#(), axi_dma_scoreboard)
        expected_status_export;

    // Receive expected AXIS read-data beats from the reference model.
    uvm_analysis_imp_expected_axis_rd_data #(axis_rd_data_item#(), axi_dma_scoreboard)
        expected_data_export;

    int unsigned actual_data_beat_count;
    int unsigned actual_status_count;

    // Expected and actual status may not arrive at the same simulation time.
    // Queues let the scoreboard compare them when both sides are available.
    rd_status_item#() expected_status_q[$];
    rd_status_item#() actual_status_q[$];
    int unsigned expected_status_count;
    int unsigned status_match_count;
    int unsigned status_mismatch_count;

    // Expected data is generated when the descriptor is accepted.  Actual data
    // arrives later after AXI reads complete.  Queues let the scoreboard match
    // expected and actual beats in order.
    axis_rd_data_item#() expected_data_q[$];
    axis_rd_data_item#() actual_data_q[$];
    int unsigned expected_data_beat_count;
    int unsigned data_match_count;
    int unsigned data_mismatch_count;

    function new(string name = "axi_dma_scoreboard", uvm_component parent = null);
        super.new(name,parent);
        axis_rd_data_export = new("axis_rd_data_export", this);
        rd_status_export = new("rd_status_export", this);
        expected_status_export = new("expected_status_export", this);

        expected_data_export = new("expected_data_export", this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        actual_data_beat_count = 0;
        actual_status_count = 0;
        expected_status_count = 0;
        status_match_count = 0;
        status_mismatch_count = 0;

        expected_data_beat_count = 0;
        data_match_count = 0;
        data_mismatch_count = 0;
        `uvm_info("AXI_DMA_SB", "build_phase entered", UVM_LOW)
    endfunction

    function void write_axis_rd_data(axis_rd_data_item#() item);
        actual_data_beat_count++;
        `uvm_info("AXI_DMA_SB", $sformatf("RX data beat[%0d]: data=0x%0h keep=0x%0h last=%0b id=0x%0h dest=0x%0h user=0x%0h",
                     item.beat_index, item.data, item.keep, item.last,
                     item.id, item.dest, item.user), UVM_LOW)

        actual_data_q.push_back(item);
        compare_data_if_ready();
    endfunction

    function void write_expected_axis_rd_data(axis_rd_data_item#() item);
        expected_data_beat_count++;
        `uvm_info("AXI_DMA_SB",
            $sformatf("EXP data beat[%0d]: data=0x%0h keep=0x%0h last=%0b id=0x%0h dest=0x%0h user=0x%0h",
                      item.beat_index, item.data, item.keep, item.last,
                      item.id, item.dest, item.user),
            UVM_LOW)

        expected_data_q.push_back(item);
        compare_data_if_ready();    
    endfunction

    function void write_rd_status(rd_status_item#() item);
        actual_status_count++;
        `uvm_info("AXI_DMA_SB", $sformatf("RX status[%0d]: tag=0x%0h error=0x%0h",
                         actual_status_count, item.tag, item.error),UVM_LOW)

        actual_status_q.push_back(item);
        compare_status_if_ready();
    endfunction

    function void write_expected_rd_status(rd_status_item#() item);
        expected_status_count++;
        `uvm_info("AXI_DMA_SB",
            $sformatf("EXP status[%0d]: tag=0x%0h error=0x%0h",
                      expected_status_count, item.tag, item.error),
            UVM_LOW)

        expected_status_q.push_back(item);
        compare_status_if_ready();
    endfunction
    
    // Compare all expected/actual status pairs that are currently available.
    // The while loop handles the case where one side queues several items
    // before the other side catches up.
    function void compare_status_if_ready();
        rd_status_item#() exp;
        rd_status_item#() act;

        while(expected_status_q.size() > 0 && actual_status_q.size() > 0)begin
            exp = expected_status_q.pop_front();
            act = actual_status_q.pop_front();

            if(exp.tag !== act.tag || exp.error !== act.error)begin
                status_mismatch_count++;
                `uvm_error("AXI_DMA_SB",
                    $sformatf("STATUS mismatch: exp tag=0x%0h error=0x%0h, act tag=0x%0h error=0x%0h",
                              exp.tag, exp.error, act.tag, act.error))
            end else begin
                status_match_count++;
                `uvm_info("AXI_DMA_SB",
                    $sformatf("STATUS match[%0d]: tag=0x%0h error=0x%0h",
                              status_match_count, act.tag, act.error),
                    UVM_LOW)
            end
        end
        
    endfunction

    // Compare all expected/actual data beats that are currently available.
    function void compare_data_if_ready();
        axis_rd_data_item#() exp;
        axis_rd_data_item#() act;
        bit [31:0] data_mask;


        while (expected_data_q.size() > 0 && actual_data_q.size() > 0) begin
            exp = expected_data_q.pop_front();
            act = actual_data_q.pop_front();

            data_mask = keep_to_data_mask(exp.keep);

            if (((exp.data ^ act.data) & data_mask)!== '0 ||
                exp.keep !== act.keep ||
                exp.last !== act.last ||
                exp.id   !== act.id   ||
                exp.dest !== act.dest ||
                exp.user !== act.user) begin
                data_mismatch_count++;
                `uvm_error("AXI_DMA_SB",
                    $sformatf("DATA mismatch beat exp_idx=%0d act_idx=%0d exp_data=0x%0h act_data=0x%0h exp_keep=0x%0h act_keep=0x%0h exp_last=%0b act_last=%0b",
                              exp.beat_index, act.beat_index,
                              exp.data, act.data,
                              exp.keep, act.keep,
                              exp.last, act.last))
            end else begin
                data_match_count++;
                `uvm_info("AXI_DMA_SB",
                    $sformatf("DATA match[%0d]: beat=%0d data=0x%0h keep=0x%0h last=%0b",
                              data_match_count, act.beat_index,
                              act.data, act.keep, act.last),
                    UVM_LOW)
            end
        end
    endfunction

    function bit [31:0] keep_to_data_mask(bit [3:0] keep);
        bit[31:0] mask;
        mask = '0;

        foreach(keep[i])begin
            if(keep[i])begin
                mask[i*8 +: 8] = 8'hff;
            end
        end
        return mask;
    endfunction

    virtual function void report_phase(uvm_phase phase);    
        super.report_phase(phase);
        `uvm_info("AXI_DMA_SB",
           $sformatf("Observed %0d read-data beats and %0d read-status events",
                     actual_data_beat_count, actual_status_count),
           UVM_LOW)

        `uvm_info("AXI_DMA_SB",
            $sformatf("Status matches=%0d mismatches=%0d pending_exp=%0d pending_act=%0d",
                        status_match_count, status_mismatch_count,
                        expected_status_q.size(), actual_status_q.size()),
            UVM_LOW)
        
        if (expected_status_q.size() != 0 || actual_status_q.size() != 0) begin
            `uvm_error("AXI_DMA_SB", "Unmatched status transactions remain")
        end

        `uvm_info("AXI_DMA_SB",
            $sformatf("Data matches=%0d mismatches=%0d pending_exp=%0d pending_act=%0d",
                      data_match_count, data_mismatch_count,
                      expected_data_q.size(), actual_data_q.size()),
            UVM_LOW)

        if (expected_data_q.size() != 0 || actual_data_q.size() != 0) begin
            `uvm_error("AXI_DMA_SB", "Unmatched data transactions remain")
        end
        
    endfunction
endclass //axi_dma_scoreboard extends uvm_scoreboard
