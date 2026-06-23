# AXI DMA UVM Verification Learning Plan

## 0. Goal

This project is not only about making one simulation pass or writing a UVM
testbench that "looks right". The real goal is to learn a realistic IP
verification workflow end to end, using an AXI-based DMA as the training target.

The feature-level verification plan for the read DMA is kept in:

```text
docs/axi_dma_rd_verification_plan.md
```

Use that document to answer "what are we trying to verify and why?"  Use this
document to answer "what implementation step should we do next?"

By the end of this project, the verification environment should be able to show,
with logs, checks, tests, and coverage metrics, what has been verified and what
has not been verified yet.

The target mindset is verification closure:

- Start from a written verification plan.
- Translate design behavior into concrete verification goals.
- Build reusable UVM components that can drive, observe, predict, and check DUT
  behavior.
- Write directed tests first to prove the environment and important scenarios.
- Add constrained-random tests only after the directed path is trustworthy.
- Define functional coverage that maps back to the verification plan.
- Run regressions and use pass/fail results, functional coverage, code coverage,
  and open issues to judge verification completeness.
- Keep a traceable connection between:
  - RTL feature or risk
  - test scenario
  - checker/reference model behavior
  - coverage point
  - regression result

The final learning outcome is not simply "the test passes". The final outcome is
understanding how a verification engineer argues that an IP block has reached a
planned verification quality level, and what evidence is used to support that
claim.

For this DMA project, that evidence should eventually include:

- Passing directed and constrained-random regressions.
- Scoreboard checks for read data, write data, descriptor status, tags, lengths,
  sideband fields, and memory contents.
- Functional coverage for descriptor length, address alignment, burst shape,
  `tkeep` patterns, backpressure, tags, error/status cases, and read/write/top
  integration scenarios.
- Code coverage review to find unexercised RTL branches or states.
- A short verification closure summary explaining what is covered, what remains
  unverified, and why.

The learning style is:

1. Explain the purpose of the current verification step.
2. Add a small, realistic TODO scaffold.
3. Let you write the code.
4. Review the code and explain bugs, timing, logs, and waveforms.
5. Only then move to the next step.

The verification order is:

1. Verify `axi_dma_rd`.
2. Verify `axi_dma_wr`.
3. Verify top-level `axi_dma`.

## 1. Current Architecture Decision

For the first complete flow, we will use:

- DUT: `rtl/axi_dma_rd.v`
- AXI memory model: `verilog-axi/rtl/axi_ram.v`
- UVM side:
  - read descriptor sequence item
  - read descriptor sequencer
  - read descriptor driver
  - read descriptor agent
  - environment
  - AXIS read data monitor
  - read status monitor
  - scoreboard/reference model
  - directed smoke sequence

We are not using Questa QVIP as the first path. QVIP is useful in real projects,
but it introduces a large amount of vendor-specific UVMF/VIP structure before we
have finished the core verification flow. We can add a later QVIP study step
after the basic UVM flow is complete.

We are also not using a custom UVM AXI memory responder as the first path. An RTL
AXI RAM gives us a known-good AXI slave quickly, so we can focus on verifying the
DMA behavior instead of debugging a home-made AXI slave.

## 2. Step 1: Clean And Stabilize The Current Baseline

Purpose:

- Remove stale TODOs that no longer match the chosen architecture.
- Remove the abandoned UVM memory responder direction.
- Keep the current minimum environment build working:
  - `base_test`
  - `axi_dma_env`
  - `rd_desc_agent`
  - `rd_desc_sequencer`
  - `rd_desc_driver`
  - `axi_dma_rd`
  - `axi_ram`

Acceptance criteria:

- The code still compiles.
- UVM enters `base_test`, `axi_dma_env`, `rd_desc_agent`, `rd_desc_driver`, and
  `rd_desc_sequencer`.
- The driver gets `rd_desc_vif`.
- No descriptor sequence is required yet.

## 3. Step 2: Stabilize The AXI RAM Memory Environment

Purpose:

- Make sure the DMA read master port is connected to a real AXI slave.
- Decide how memory will be initialized for directed tests.

What we need to learn:

- The DUT is the AXI master.
- `axi_ram` is the AXI slave.
- UVM does not directly drive AXI read response signals in this path.
- Monitors may observe memory-side AXI signals, but they must not drive them.

TODOs to add later:

- Add a clean memory preload mechanism.
- Add a small directed memory pattern for smoke testing.
- Confirm read data returned by `axi_ram` appears on DMA AXIS output.

## 4. Step 3: Write The AXIS Read Data Monitor

Purpose:

- Observe what the DMA actually outputs on `m_axis_read_data_*`.
- Convert signal-level AXIS beats into transaction-level data for the scoreboard.

What this monitor owns:

- It samples `tvalid/tready/tdata/tkeep/tlast/tid/tdest/tuser`.
- It does not drive anything.
- It publishes observed beats or frames through an analysis port.

Acceptance criteria:

- Monitor can be instantiated.
- Monitor can see valid AXIS handshakes.
- Monitor sends observed data to a simple subscriber or scoreboard.

## 5. Step 4: Write The Read Status Monitor

Purpose:

- Observe `m_axis_read_desc_status_*`.
- Check whether the DMA reports descriptor completion correctly.

What this monitor owns:

- It samples status valid handshakes.
- It publishes status transactions through an analysis port.

Acceptance criteria:

- Status monitor captures `tag`, `error`, and related status fields.
- Scoreboard can receive status events.

## 6. Step 5: Build The Scoreboard And Reference Model

Purpose:

- Compare expected DMA behavior against actual observed behavior.

First reference model:

- When a descriptor is accepted, remember:
  - source memory address
  - byte length
  - tag/id/dest/user
- Use the known memory preload pattern to predict expected AXIS output bytes.
- Compare expected AXIS frames against monitor output.
- Compare expected status against status monitor output.

Important idea:

The reference model is not another implementation of the full DMA. At first it is
only a small model of the behavior we expect for one directed read descriptor.

## 7. Step 6: Publish Accepted Descriptors From The Driver

Purpose:

- The scoreboard needs to know which descriptors were actually sent.
- The best time to publish a descriptor is after the descriptor valid/ready
  handshake completes.

Implementation direction:

- Add an analysis port to `rd_desc_driver`.
- After `drive_one_desc()` sees handshake completion, write a copy of the item to
  that analysis port.
- Connect the driver analysis port to the scoreboard in the environment.

## 8. Step 7: Add A Smoke Sequence And Start It From The Test

Purpose:

- Start with one deterministic descriptor.
- Do not jump to random testing too early.

Smoke sequence behavior:

- Create one `dma_rd_desc_item`.
- Use a simple address and length.
- Start it on `rd_desc_sequencer`.

Acceptance criteria:

- Driver receives the item.
- Descriptor handshake happens.
- DMA reads from `axi_ram`.
- AXIS output monitor sees expected bytes.
- Status monitor sees completion.
- Scoreboard passes.

## 9. Step 8: Directed Test Expansion

Add directed tests for:

- Small lengths.
- One full AXI beat.
- Unaligned addresses.
- Multiple beats.
- `tkeep` edge cases.
- Boundary-adjacent reads.
- Different tags.
- Backpressure on AXIS output.

Current next directed expansion:

- `rd_len_sweep_test`
- Start `rd_len_sweep_sequence`
- Keep descriptor stream generation inside the sequence, not inside the test
- Sweep lengths: 1, 2, 3, 4, 5, 15, 16, 17
- Check expected `data/keep/last/id/dest/user` and status `tag/error`
- Expected status matches: 8
- Expected data beat matches: 19

Current status:

- `rd_smoke_test` is complete.
- `rd_len_sweep_test` is complete.
- The scoreboard now masks invalid `tdata` byte lanes according to `tkeep`.

Next learning step:

- Add a minimal functional coverage collector for the read path.
- Use the already passing smoke and length-sweep tests to see real coverage
  numbers.
- Then continue directed expansion from the feature verification plan:
  - address offset / unaligned reads
  - AXIS backpressure
  - AXI burst and 4KB boundary behavior

Purpose:

- Each test should target one real verification risk.
- Directed tests build confidence before constrained random.

## 10. Step 9: Coverage And Randomization

Purpose:

- Translate verification goals into measurable coverage.

Coverage examples:

- Descriptor length bins.
- Address offset bins.
- Burst length bins.
- `tkeep` patterns.
- Backpressure patterns.
- Status/error cases.

Randomization examples:

- Constrain legal lengths first.
- Then add address offsets.
- Then add backpressure.
- Then add multiple descriptors.

## 11. Step 10: Extend To `axi_dma_wr`

New pieces:

- Write descriptor item.
- AXIS input frame item.
- AXIS input driver.
- Write status monitor.
- Memory content checker.

New checks:

- AW/W/B behavior through `axi_ram`.
- `wstrb` correctness.
- `wlast` correctness.
- Memory guard bytes.
- Status tag/length/error fields.

## 12. Step 11: Verify Top-Level `axi_dma`

Purpose:

- Integrate read and write paths.
- Check that top-level parameters and wiring behave correctly.

Tests:

- Read-only.
- Write-only.
- Read and write in the same simulation.
- Descriptor backpressure.
- Data backpressure.
- Multiple descriptors.

## 13. Deferred Study: Questa QVIP

After the basic UVM flow is complete, we can investigate Questa QVIP:

- Where the installed examples live.
- How QVIP separates HDL signal interface and HVL UVM classes.
- How a commercial AXI VIP replaces our hand-written bus components.
- What parts of the testbench still remain ours:
  - env configuration
  - tests/sequences
  - scoreboard
  - coverage
  - DMA-specific reference model

This is useful later, but it is not the first path.
