# axi_dma_rd Verification Plan

Version: 0.1

Status: living document.  This file records what we intend to verify for
`axi_dma_rd`, why each item matters, and what evidence will be used to claim it
has been verified.

This is different from `axi_dma_uvm_verification_plan.md`:

- `axi_dma_uvm_verification_plan.md` is the learning and implementation roadmap.
- This file is the functional verification plan for the read DMA RTL.

## 1. DUT Scope

The current verification target is:

```text
rtl/axi_dma_rd.v
```

The block accepts read descriptors and produces AXI Stream read data:

```text
descriptor input
    addr, len, tag, id, dest, user
        |
        v
axi_dma_rd
        |
        +--> AXI read master: AR/R channel reads memory
        |
        +--> AXIS read data output: tdata/tkeep/tlast/tid/tdest/tuser
        |
        +--> descriptor status output: tag/error/valid
```

The current memory slave is:

```text
verilog-axi/rtl/axi_ram.v
```

The current reference model keeps a byte-level mirror of memory in SystemVerilog
class code and predicts AXIS output data from accepted descriptors.

## 2. Current DUT Configuration

The current testbench uses a 32-bit AXI/AXIS datapath:

```text
AXI_DATA_WIDTH  = 32
AXIS_DATA_WIDTH = 32
AXIS_KEEP_WIDTH = 4
```

Important RTL parameters that affect the verification plan:

```text
AXI_MAX_BURST_LEN
AXIS_KEEP_ENABLE
AXIS_LAST_ENABLE
AXIS_ID_ENABLE
AXIS_DEST_ENABLE
AXIS_USER_ENABLE
LEN_WIDTH
TAG_WIDTH
ENABLE_UNALIGNED
```

These parameters matter because they change observable behavior:

- `AXIS_KEEP_ENABLE` controls whether partial final beats are visible through
  `tkeep`.
- `AXIS_LAST_ENABLE` controls frame termination behavior.
- `AXIS_ID_ENABLE`, `AXIS_DEST_ENABLE`, and `AXIS_USER_ENABLE` control whether
  descriptor sideband fields are propagated.
- `ENABLE_UNALIGNED` controls whether byte-unaligned read addresses are
  supported.
- `AXI_MAX_BURST_LEN` affects AR burst splitting and boundary behavior.

## 3. Verification Strategy

We will verify this block in layers.

1. Build a checking baseline with directed tests.
2. Add functional coverage that maps to this plan.
3. Add constrained-random tests only after the directed checker path is trusted.
4. Add regression and code coverage review.
5. Record remaining risk and closure status.

Current status:

```text
RD-DIR-001 smoke read              done
RD-DIR-002 read length sweep       done
Functional coverage                not started
Constrained random                 not started
Backpressure tests                 not started
Unaligned address tests            not started
AXI error response tests           not started
Code coverage review               not started
```

## 4. Reference Model And Scoreboard Requirements

The checker must not only count transactions.  It must prove that the DMA output
matches the descriptor and memory contents.

Reference model responsibilities:

- Receive a descriptor only after the descriptor valid/ready handshake has
  completed.
- Use descriptor `addr` and `len` to read expected bytes from the reference
  memory mirror.
- Pack expected bytes into AXIS beats.
- Predict `tkeep` for the final beat.
- Predict `tlast`.
- Predict status `tag` and `error`.
- Respect enabled sideband behavior for `id`, `dest`, and `user`.

Scoreboard responsibilities:

- Compare expected and actual AXIS beats in order.
- Compare only valid byte lanes indicated by `tkeep`; invalid byte lanes are
  don't-care.
- Compare `tkeep`, `tlast`, `id`, `dest`, and `user`.
- Compare status `tag` and `error`.
- Report pending expected or actual transactions at end of test.

Current checker limitation:

- The current model assumes a simple initialized memory pattern.
- The current model does not yet handle all parameter combinations.
- The current tests use fixed waits instead of scoreboard-driven end-of-test.

## 5. Feature-Based Verification Items

### RD-FEAT-001 Descriptor Handshake

What to verify:

- A descriptor is accepted only when descriptor `valid && ready` occurs.
- The driver publishes a descriptor to the reference model only after acceptance.
- One accepted descriptor produces exactly one status completion.

Why:

- If the testbench predicts from descriptors that were not actually accepted,
  the scoreboard can report false failures.
- If the DUT drops or duplicates descriptors, DMA software would see missing or
  repeated completions.

Evidence:

- Driver accepted-descriptor analysis port.
- Status monitor.
- Scoreboard status count and tag matching.

Planned tests:

```text
RD-DIR-001 smoke read
RD-DIR-002 length sweep
RD-RAND-001 rd_len_random_test
```

Planned coverage:

```text
descriptor accepted count
descriptor spacing
multiple descriptors in one test
```

### RD-FEAT-002 Byte Length And Beat Count

What to verify:

- Descriptor `len` controls the exact number of output bytes.
- Number of AXIS beats is correct.
- `tlast` appears on the final beat only.

Why:

- DMA length bugs cause data truncation, over-read, or frame corruption.
- Off-by-one errors are common around `len=1`, full-beat lengths, and
  full-beat-plus-one lengths.

Evidence:

- Reference model predicts expected byte stream and beat count.
- Scoreboard compares every beat.

Directed tests:

```text
RD-DIR-002 length sweep:
    len = 1, 2, 3, 4, 5, 15, 16, 17
```

Planned coverage:

```text
len_one
len_less_than_one_beat
len_exactly_one_beat
len_one_beat_plus_one
len_multi_beat
len_exact_multiple_of_beat
```

### RD-FEAT-003 tkeep Generation

What to verify:

- Full beats have `tkeep = 4'b1111` for 32-bit AXIS data.
- Partial final beats have the correct `tkeep`.
- Invalid byte lanes are not treated as meaningful data by the scoreboard.

Why:

- AXIS receivers use `tkeep` to know which bytes are valid.
- It is legal for invalid `tdata` lanes to contain don't-care values, so the
  checker must not over-constrain them.

Evidence:

- Scoreboard masks `tdata` comparison using `tkeep`.
- Length sweep covers all final-beat `tkeep` values for 32-bit data.

Directed tests:

```text
RD-DIR-002 length sweep
```

Planned coverage:

```text
tkeep = 0001
tkeep = 0011
tkeep = 0111
tkeep = 1111
```

### RD-FEAT-004 Address Alignment

What to verify:

- Aligned reads start at the correct byte address.
- If `ENABLE_UNALIGNED=1`, unaligned reads start at the exact descriptor byte
  address.
- Output byte order is correct for `addr[1:0] = 0, 1, 2, 3`.

Why:

- Address offset bugs often shift the whole output stream by one or more bytes.
- Unaligned support changes internal offset, first beat handling, and last beat
  handling.

Evidence:

- Reference model predicts bytes from exact descriptor address.
- Scoreboard compares byte-level output.

Planned directed tests:

```text
RD-DIR-003 address offset sweep:
    addr[1:0] = 0, 1, 2, 3
    len = 1, 2, 3, 4, 5, 8, 15, 16, 17
```

Planned coverage:

```text
addr_offset bins: 0, 1, 2, 3
cross addr_offset x len_class
cross addr_offset x final_tkeep
```

### RD-FEAT-005 AXI Read Burst Generation

What to verify:

- AR channel uses legal burst parameters.
- Long descriptors are split into legal AXI bursts.
- `arlen`, `arsize`, `arburst`, and `araddr` match the requested transfer.
- Burst splitting respects `AXI_MAX_BURST_LEN`.

Why:

- The DMA output may look correct for small reads while AR burst generation is
  wrong for longer reads.
- AXI slaves and interconnects rely on legal burst shape.

Evidence:

- Add AXI read address monitor.
- Check AR request legality.
- Cross-check total returned bytes against descriptors.

Planned tests:

```text
RD-DIR-004 max burst length cases
RD-DIR-005 long descriptor split cases
```

Planned coverage:

```text
arlen bins: single, small, max_minus_1, max
number_of_bursts_per_descriptor
```

### RD-FEAT-006 4KB Boundary Handling

What to verify:

- AXI bursts do not cross a 4KB address boundary.
- Descriptors near a 4KB boundary are split correctly.
- Output data remains continuous across the split.

Why:

- AXI requires bursts not to cross 4KB boundaries.
- Boundary logic is a classic source of corner-case bugs.

Evidence:

- AXI AR monitor checks burst boundary legality.
- Scoreboard checks output byte stream continuity.

Planned tests:

```text
RD-DIR-006 4KB boundary:
    addr = 0x0ffc len = 4
    addr = 0x0ffd len = 8
    addr = 0x0ff0 len = 32
```

Planned coverage:

```text
crosses_4kb_boundary
ends_at_4kb_boundary
starts_after_4kb_boundary
```

### RD-FEAT-007 AXIS Backpressure

What to verify:

- When `m_axis_read_data_tready` is low, the DUT holds valid data stable.
- No beats are lost or duplicated under backpressure.
- `tlast` and `tkeep` remain aligned with the correct data beat.

Why:

- Real downstream blocks can stall.
- FIFO and output handshake bugs often appear only under backpressure.

Evidence:

- AXIS monitor samples only `tvalid && tready`.
- Add protocol checker for stable data while stalled.
- Scoreboard verifies no missing or duplicated beats.

Planned tests:

```text
RD-DIR-007 deterministic backpressure
RD-RAND-002 random backpressure
```

Planned coverage:

```text
stall_cycles: 0, 1, 2-5, >5
stall_on_first_beat
stall_on_middle_beat
stall_on_last_beat
```

### RD-FEAT-008 Status Tag And Error

What to verify:

- Status `tag` matches descriptor `tag`.
- Status `error` is zero for successful AXI reads.
- AXI `SLVERR` and `DECERR` responses are mapped to the expected DMA error
  status.

Why:

- Software relies on status tags to match completions to descriptors.
- Error reporting is required for robust DMA operation.

Evidence:

- Status monitor.
- Reference model expected status.
- Error-response memory model or AXI responder for negative tests.

Current tests:

```text
RD-DIR-001 smoke read
RD-DIR-002 length sweep
```

Planned tests:

```text
RD-DIR-008 AXI SLVERR response
RD-DIR-009 AXI DECERR response
```

Planned coverage:

```text
status_error = none
status_error = axi_read_slverr
status_error = axi_read_decerr
tag bins and tag uniqueness
```

### RD-FEAT-009 Sideband Fields

What to verify:

- If sideband propagation is enabled, descriptor `id`, `dest`, and `user` appear
  correctly on AXIS output.
- If a sideband is disabled by parameter, output follows RTL-defined disabled
  behavior.

Why:

- Sideband fields are often used for routing, stream identification, or metadata.
- Parameterized sideband behavior can hide bugs if only default parameters are
  tested.

Evidence:

- Reference model predicts sideband values according to parameter configuration.
- Scoreboard compares actual sideband fields.

Planned tests:

```text
RD-DIR-010 sideband propagation enabled
RD-DIR-011 sideband disabled behavior
```

Planned coverage:

```text
id values
dest values
user values
sideband enable/disable configurations
```

### RD-FEAT-010 Reset And Enable Behavior

What to verify:

- During reset, outputs are inactive.
- After reset release, the block accepts descriptors normally.
- When `enable` is low, descriptor acceptance and read behavior match the RTL
  specification.
- Reset during or between descriptors does not leave stale completions.

Why:

- Reset and enable bugs can corrupt the first transaction after reset or leave
  stale status/data in FIFOs.

Evidence:

- Reset tests.
- Monitors confirm no unexpected data/status during reset.
- Scoreboard is reset-aware or flushes expectations when reset aborts a
  transaction.

Planned tests:

```text
RD-DIR-012 reset before descriptor
RD-DIR-013 reset during active read
RD-DIR-014 enable low/high behavior
```

Planned coverage:

```text
reset_before_transfer
reset_during_descriptor
reset_during_data
enable_low_descriptor_attempt
```

## 6. Test Plan

| Test ID | Test Name | Purpose | Current Status |
|---|---|---|---|
| RD-DIR-001 | `rd_smoke_test` | One aligned descriptor, basic data/status check | Done |
| RD-DIR-002 | `rd_len_sweep_test` | Length, `tkeep`, `tlast`, beat count | Done |
| RD-DIR-003 | `rd_addr_offset_test` | Address offset and unaligned byte ordering | Planned |
| RD-DIR-004 | `rd_max_burst_test` | Max burst and burst splitting | Planned |
| RD-DIR-005 | `rd_long_desc_test` | Multi-burst descriptors | Planned |
| RD-DIR-006 | `rd_4kb_boundary_test` | AXI 4KB boundary splitting | Planned |
| RD-DIR-007 | `rd_backpressure_test` | AXIS output stalls | Planned |
| RD-DIR-008 | `rd_slverr_test` | AXI read SLVERR mapping | Planned |
| RD-DIR-009 | `rd_decerr_test` | AXI read DECERR mapping | Planned |
| RD-DIR-010 | `rd_sideband_test` | ID/dest/user propagation | Planned |
| RD-DIR-012 | `rd_reset_test` | Reset and enable behavior | Planned |
| RD-RAND-001 | `rd_len_random_test` | Random aligned descriptor lengths for RD-FEAT-002/003 | Planned |
| RD-RAND-002 | `rd_random_backpressure_test` | Random descriptor plus random stalls | Planned |

## 7. Verification Closure Tracker

This table is the long-term tracking point for the verification plan.  A feature
entry should not be marked closed only because a test exists.  Closure requires
stimulus, checking, coverage, and regression evidence.

Status meanings:

```text
Planned      entry is identified, but implementation has not started
In Progress  some tests/checkers exist, but closure evidence is incomplete
Blocked      progress needs a missing model, VIP feature, RTL decision, or tool setup
Closed       tests pass, checkers exist, coverage target is met, regression is stable
Waived       intentionally not verified, with a written reason
```

| Feature ID | Feature | Tests | Checker Evidence | Coverage Evidence | Regression Evidence | Status | Notes |
|---|---|---|---|---|---|---|---|
| RD-FEAT-001 | Descriptor handshake | `rd_smoke_test`, `rd_len_sweep_test` | Driver publishes only accepted descriptors; status tag compared | Not implemented | Manual runs only | In Progress | Need descriptor coverage and regression script |
| RD-FEAT-002 | Byte length and beat count | `rd_smoke_test`, `rd_len_sweep_test` | Data beat count, `tlast`, and byte data checked | Not implemented | Manual runs only | In Progress | Good candidate for first closure after coverage |
| RD-FEAT-003 | `tkeep` generation | `rd_len_sweep_test` | `tkeep` checked; invalid `tdata` lanes masked | Not implemented | Manual runs only | In Progress | Good candidate for first closure after coverage |
| RD-FEAT-004 | Address alignment | Planned `rd_addr_offset_test` | Byte-level scoreboard should support this | Not implemented | None | Planned | Requires `ENABLE_UNALIGNED=1` tests |
| RD-FEAT-005 | AXI read burst generation | Planned `rd_max_burst_test`, `rd_long_desc_test` | No AR monitor/checker yet | Not implemented | None | Planned | Needs AXI read address monitor |
| RD-FEAT-006 | 4KB boundary handling | Planned `rd_4kb_boundary_test` | No AR boundary checker yet | Not implemented | None | Planned | Needs AR monitor plus data continuity check |
| RD-FEAT-007 | AXIS backpressure | Planned `rd_backpressure_test` | No stall-stability checker yet | Not implemented | None | Planned | Needs controllable `tready` driver |
| RD-FEAT-008 | Status tag and error | `rd_smoke_test`, `rd_len_sweep_test`; error tests planned | Status tag/error compared for success path | Not implemented | Manual runs only | In Progress | Error status needs SLVERR/DECERR stimulus |
| RD-FEAT-009 | Sideband fields | Planned `rd_sideband_test` | Scoreboard compares sidebands, but default config disables id/dest | Not implemented | None | Planned | Needs parameter/config variants |
| RD-FEAT-010 | Reset and enable behavior | Planned `rd_reset_test` | No reset-aware checker yet | Not implemented | None | Planned | Needs expectation flush/abort policy |

First closure target:

```text
RD-FEAT-002 Byte length and beat count
RD-FEAT-003 tkeep generation
```

Why these first:

- Directed stimulus already exists.
- Scoreboard checking already exists.
- Only functional coverage and regression evidence are missing.
- Closing these entries will teach the full loop:
  plan entry -> stimulus -> checker -> coverage -> regression -> closure status.

## 8. Functional Coverage Plan

Coverage should be sampled from accepted descriptors and observed output, not
from random variables before handshake.

Coverage design rule:

```text
RTL/spec feature
    -> verification plan entry
        -> coverage intent
            -> coverpoint / bins / cross
                -> sample point
```

Do not start by randomly adding coverpoints to whatever signals are convenient.
Start from a feature or risk in this plan, decide what scenario must be proven to
have occurred, then choose the transaction field or protocol event that best
represents that scenario.

Examples:

```text
RD-FEAT-002 Byte length and beat count
    coverage intent:
        prove important descriptor length classes occurred
    sample point:
        accepted descriptor from rd_desc_driver.accepted_desc_ap
    fields:
        desc.len

RD-FEAT-003 tkeep generation
    coverage intent:
        prove final-beat keep patterns occurred
    sample point:
        observed AXIS read data from axis_rd_data_monitor.ap
    fields:
        tkeep, tlast

RD-FEAT-004 Address alignment
    coverage intent:
        prove every byte offset was tested
    sample point:
        accepted descriptor
    fields:
        desc.addr[1:0]
```

Coverage is not a correctness check.  Coverage tells us that a planned scenario
happened.  The scoreboard or protocol checker must still prove that the DUT
behaved correctly in that scenario.

The complete evidence chain for a feature entry is:

```text
stimulus creates the scenario
coverage proves the scenario occurred
checker proves the observed result was correct
regression proves the result is repeatable
closure tracker records the evidence
```

### Coverage Categories

Feature coverage:

- Measures whether planned functional scenarios occurred.
- Examples: length class, address offset, final `tkeep`, status error.

Cross coverage:

- Measures whether important combinations occurred.
- Examples: `addr_offset x length_class`, `final_tkeep x tlast`,
  `status_error x length_class`.

Protocol coverage:

- Measures bus/protocol behavior.
- Examples: AXI `arlen`, burst split count, RRESP value, 4KB boundary behavior.
- If a commercial AXI VIP is used later, some protocol coverage may come from
  that VIP instead of our own coverage collector.

Error and negative coverage:

- Measures whether error scenarios were intentionally triggered.
- Examples: AXI `SLVERR`, AXI `DECERR`, reset during active transfer, descriptor
  attempt while disabled.

Configuration coverage:

- Measures parameter/configuration combinations across regression runs.
- Examples: `ENABLE_UNALIGNED`, `AXIS_ID_ENABLE`, `AXIS_DEST_ENABLE`,
  `AXI_DATA_WIDTH`.
- This is often tracked with a regression matrix, not only a single covergroup.

Code coverage:

- Measures which RTL lines, branches, toggles, or states executed.
- It is reviewed separately in the code coverage section.
- It does not replace functional coverage because it does not prove the intended
  behavior was checked.

Payload data coverage policy:

- Do not cover raw `tdata` values by default.
- The scoreboard checks payload data correctness.
- Coverage should only include data values when the data pattern itself is a
  feature or risk, for example packet opcodes, headers, CRC/ECC patterns, all
  zero/all one stress patterns, or data-dependent processing.
- For this DMA read path, the memory pattern is used to make byte-order and
  alignment bugs visible to the checker, not to achieve raw data-value coverage.

### Current Framework Support Matrix

This matrix records whether the current UVM framework can actually verify each
feature entry.  A coverpoint alone is not enough.  Each entry needs stimulus,
observability, checking, and a coverage sample point.

| Feature ID | Current Framework Support | What Already Exists | Missing Before Closure |
|---|---|---|---|
| RD-FEAT-001 Descriptor handshake | Partial | Descriptor driver publishes accepted descriptors after valid/ready; status monitor and scoreboard compare completions | Independent descriptor input monitor is optional but useful; descriptor spacing/back-to-back coverage; regression evidence |
| RD-FEAT-002 Byte length and beat count | Mostly supported | Length sequences, AXIS data monitor, byte-level reference model, scoreboard data/tlast check | Functional coverage implementation; frame beat-count coverage; regression evidence |
| RD-FEAT-003 `tkeep` generation | Mostly supported | Length sweep hits partial final beats; scoreboard compares `tkeep` and masks invalid `tdata` lanes | Functional coverage implementation for final `tkeep`; regression evidence |
| RD-FEAT-004 Address alignment | Partially supported | Descriptor item can carry unaligned addresses; reference model predicts byte stream from exact byte address; scoreboard can compare byte-level output | DUT must be instantiated with `ENABLE_UNALIGNED=1`; address-offset sequence/test; coverage bins must be hit |
| RD-FEAT-005 AXI read burst generation | Not supported yet | AXI AR/R signals exist in `axi_dma_if` and are connected to `axi_ram` | AXI read address monitor; AXI read data/response monitor if needed; burst legality checker; AR coverage |
| RD-FEAT-006 4KB boundary handling | Partially supported for data, not AXI legality | Existing scoreboard can check output byte continuity if a boundary descriptor is sent | AXI AR monitor/checker to prove bursts do not cross 4KB; boundary coverage |
| RD-FEAT-007 AXIS backpressure | Not supported yet | AXIS monitor observes `tready` | `m_axis_read_data_tready` is currently tied high in `top_tb`; need AXIS sink/backpressure driver; stall-stability checker; backpressure coverage |
| RD-FEAT-008 Status tag and error | Success path only | Status monitor and scoreboard check `tag/error=0` for successful reads | Error injection source for AXI `SLVERR/DECERR`; reference model error prediction; error coverage |
| RD-FEAT-009 Sideband fields | Partial | Descriptor item has `id/dest/user`; scoreboard compares output sidebands; current model expects `id=0`, `dest=0`, `user=desc.user` | Parameter/config variants for `AXIS_ID_ENABLE` and `AXIS_DEST_ENABLE`; sideband sequences; sideband coverage |
| RD-FEAT-010 Reset and enable behavior | Not supported yet | Initial reset exists in `top_tb`; driver drives `read_enable=1` | Reset/enable controller; reset-aware ref model and scoreboard flush policy; reset/enable tests and coverage |

Conclusion:

```text
The current framework can close the first small feature group:
    RD-FEAT-002 Byte length and beat count
    RD-FEAT-003 tkeep generation

The current framework cannot close the full axi_dma_rd plan yet.
Additional infrastructure is required before the remaining entries can be
meaningfully covered and checked.
```

### Coverage Implementation Phases

Phase 1: high-level read output coverage.

```text
Component:
    axi_dma_rd_coverage

Sources:
    accepted descriptors
    observed AXIS read data
    observed read status

Targets:
    RD-FEAT-001 success-path descriptor completion evidence
    RD-FEAT-002 length and beat-count classes
    RD-FEAT-003 final tkeep patterns
    RD-FEAT-008 success-path status error = 0
```

Phase 1 random-strengthening test:

```text
Add:
    rd_len_random_sequence
    rd_len_random_test

Purpose:
    Randomize aligned descriptor lengths after directed length sweep passes.
    This strengthens RD-FEAT-002 and RD-FEAT-003 without mixing in unaligned
    address behavior from RD-FEAT-004.

Initial constraints:
    addr aligned
    len inside [1:128]
    num_desc = 50
    deterministic tags
```

Phase 2: address alignment coverage.

```text
Add:
    rd_addr_offset_sequence
    rd_addr_offset_test
    ENABLE_UNALIGNED=1 configuration

Targets:
    RD-FEAT-004 addr[1:0] = 0, 1, 2, 3
    addr_offset x length_class
    addr_offset x final_tkeep
```

Phase 3: AXI read protocol coverage.

```text
Add:
    axi_read_addr_item
    axi_read_addr_monitor
    AXI AR legality checker

Targets:
    RD-FEAT-005 burst generation
    RD-FEAT-006 4KB boundary behavior
```

Phase 4: AXIS backpressure coverage.

```text
Add:
    axis_rd_sink_driver or axis_rd_ready_driver
    configurable tready pattern
    stable-while-stalled checker

Targets:
    RD-FEAT-007 backpressure
```

Phase 5: AXI error-response coverage.

```text
Add one of:
    UVM AXI read responder with error injection
    modified/error-capable AXI RAM wrapper
    commercial/open-source AXI VIP with RRESP control

Targets:
    RD-FEAT-008 SLVERR and DECERR status mapping
```

Phase 6: configuration, sideband, reset, and enable coverage.

```text
Add:
    parameter/config regression matrix
    sideband tests
    reset/enable controller
    reset-aware scoreboard policy

Targets:
    RD-FEAT-009 sideband fields
    RD-FEAT-010 reset and enable behavior
```

Recommended coverage collectors:

```text
rd_desc_cov
    samples accepted descriptors

axis_rd_data_cov
    samples output AXIS beats

rd_status_cov
    samples descriptor completions

axi_read_addr_cov
    samples AR channel behavior after an AXI monitor exists
```

Initial covergroups:

```text
descriptor length class
descriptor address offset
descriptor tag values
final tkeep pattern
beats per descriptor
status error
AXIS backpressure
AXI burst length
4KB boundary crossing
```

Important crosses:

```text
length_class x final_tkeep
addr_offset x length_class
addr_offset x final_tkeep
burst_length x crosses_4kb_boundary
backpressure_position x tlast
status_error x descriptor_len_class
```

Functional coverage is not implemented yet.

## 9. Code Coverage Plan

After directed tests are stable, run simulator code coverage and inspect:

- Uncovered state-machine branches.
- Uncovered `ENABLE_UNALIGNED` paths.
- Uncovered AXI error handling.
- Uncovered boundary split logic.
- Uncovered sideband enable/disable branches.
- Uncovered reset/enable branches.

Code coverage does not replace functional coverage.  It tells us which RTL code
was executed, not whether the behavior was checked correctly.

## 10. Closure Criteria For axi_dma_rd

The read DMA block is not considered verified until:

- All planned directed tests pass.
- Constrained-random tests pass with repeatable seeds.
- Scoreboard reports zero mismatches and zero pending transactions.
- Functional coverage reaches the target bins defined in this plan, or uncovered
  bins are waived with a reason.
- Code coverage is reviewed and major uncovered RTL branches are explained.
- Known limitations are documented.

Current closure status:

```text
Not closed.
The project currently has a working directed checking baseline, but coverage and
many feature tests are still missing.
```
