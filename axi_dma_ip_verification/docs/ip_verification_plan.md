# AXI4 Multi-Descriptor DMA Subsystem IP Verification Plan

**Document type:** Verification plan  
**Version:** Draft 1.0  
**Scope:** IP-level RTL verification  
**Methodology:** SystemVerilog, UVM 1.2, UVM RAL, SVA, VCS/URG  
**Purpose:** Define what must be verified for one AXI4 memory-to-memory DMA subsystem IP before it is used as a verified building block in a larger subsystem.

## 1. Executive Summary

This plan defines an IP-level verification strategy for an AXI4 multi-descriptor memory-to-memory DMA subsystem. The IP is programmed through AXI4-Lite, accepts and validates descriptors, moves bytes through an internal AXI4-Stream path, accesses external memory through AXI4, records completion information, and optionally raises an interrupt.

The plan is intentionally **IP-centric**. It verifies the correctness of one DMA subsystem instance and its direct control/memory interfaces. It does not attempt to verify multi-DMA routing, multiple external AXI masters, shared-memory Crossbar arbitration, or multi-memory system address mapping; those belong to the system-level verification plan.

The final outcome expected from this plan is an evidence-backed IP verification baseline: reusable tests, a transaction-accurate scoreboard, assertions, functional coverage, a regression flow, and documented scope exclusions.

## 2. Design Scope

### 2.1 Functional architecture

```text
AXI4-Lite software control
  → descriptor staging registers
  → SUBMIT command
  → descriptor validation + request FIFO
  → descriptor manager
  → AXI DMA read engine
  → internal AXI4-Stream FIFO
  → AXI DMA write engine
  → AXI4 external memory
  → completion FIFO / status / IRQ
```

The descriptor manager is expected to execute accepted requests in order. Each accepted transfer reads a source byte range and writes the same byte stream to a non-overlapping destination range. Completion information is made visible through the control plane after both read-side and write-side status are available.

### 2.2 Interfaces under verification

| Interface | Direction | Verification responsibility |
| --- | --- | --- |
| `clk`, `rst` | Input | Synchronous reset behavior, state cleanup, and post-reset recovery. |
| `s_axil_*` | AXI4-Lite slave | Register access, command semantics, response behavior, and protocol stability. |
| `m_axi_*` | AXI4 master | Read/write burst generation, AXI protocol behavior, data integrity, and response handling. |
| `irq` | Output | Completion-driven, level-sensitive interrupt behavior. |

### 2.3 Target configuration

This plan targets the following checked-in configuration. Any parameter change requires a verification-impact review.

| Item | Target configuration |
| --- | --- |
| AXI4-Lite address / data width | 8 / 32 bits |
| AXI4 address / data / ID width | 16 / 32 / 8 bits |
| Maximum AXI burst length | 16 beats |
| Descriptor length / tag width | 20 / 8 bits |
| AXI4-Stream data width | 32 bits |
| AXI4-Stream FIFO depth | 16 entries |
| Request FIFO / completion FIFO depth | 4 / 4 entries |
| Verification memory size | 64 KiB |
| `ENABLE_UNALIGNED` | `0` |
| `ENABLE_SG` | `0` |
| Clock | 100 MHz |

## 3. Requirements to be Verified

### 3.1 Control-plane requirements

The verification environment shall demonstrate that:

- Software can program source address, destination address, length, tag, and interrupt enable through AXI4-Lite.
- `SUBMIT`, `COMP_POP`, and sticky-status clear operations have write-one command semantics.
- Descriptor staging registers respect byte strobes.
- Read-only registers are protected from writes.
- Unsupported or reserved accesses produce the specified benign/default behavior.
- Empty completion-head registers return the specified empty values.
- Status, queue level, submitted count, and completed count are readable and internally consistent.

### 3.2 Descriptor-admission requirements

The plan shall verify that descriptor acceptance is controlled by the configured policy:

- A valid descriptor is accepted only when the request FIFO can accept it.
- Zero-length requests are rejected.
- Source and destination alignment is enforced when unaligned transfers are disabled.
- Address, length, and tag fields outside their configured widths are rejected.
- Source and destination byte ranges must remain within the configured AXI address space.
- Source and destination ranges must not overlap; adjacent non-overlapping ranges remain legal.
- Full-FIFO rejection and invalid-descriptor rejection are separately visible through the defined status mechanism.

### 3.3 Data-movement requirements

For every accepted descriptor, verification shall establish that:

- The DMA reads exactly the requested source byte range.
- The DMA writes exactly the requested destination byte range.
- Destination bytes equal the source bytes captured at descriptor start.
- AXI burst length, beat size, address increment, `WLAST`, byte strobes, and 4 KiB boundary behavior are legal.
- Partial final beats preserve correct byte enables and do not corrupt neighboring bytes.
- Descriptor execution and completion records remain in the required order.
- Completion tag, actual length, read error, write error, and mismatch fields encode the outcome correctly.

### 3.4 Resilience requirements

The IP shall maintain protocol correctness and either complete or report the specified error outcome when subjected to:

- Independent AW, W, B, AR, and R channel stalls.
- Internal AXI4-Stream FIFO backpressure.
- Multiple accepted but incomplete AXI bursts.
- Address-matched AXI read/write `SLVERR` and `DECERR` responses.
- Reset while idle, while a descriptor is active, and while AXI transactions are active.

### 3.5 Completion and interrupt requirements

The plan shall verify that:

- A completion is recorded only after the transfer reaches its defined terminal state.
- Completion FIFO head fields represent the oldest unpopped completion.
- `COMP_POP` removes one completion and does not corrupt remaining entries.
- IRQ remains low when disabled.
- With IRQ enabled, IRQ is high while at least one completion remains pending.
- IRQ deasserts after the last completion is popped.

## 4. Verification Environment Architecture

The UVM environment shall be built around independent stimulus, observation, and prediction.

| Component | Planned responsibility |
| --- | --- |
| Active AXI-Lite UVM agent | Drive and monitor register accesses, byte strobes, command writes, and response behavior. |
| UVM RAL model | Provide frontdoor access to all control/status registers through an adapter and monitor-driven predictor. |
| Descriptor/manager monitor | Observe descriptor acceptance, rejection, queue level, active state, and completion records. |
| AXI memory proxy | Sit between DUT and memory; independently control AW/W/B/AR/R stalls, delayed responses, outstanding requests, and address-matched error injection. |
| AXI RAM model | Hold deterministic initial source data and accept the DUT's real AXI transactions. |
| Reference memory model | Maintain a byte-addressable expected-memory image independent of the RTL implementation. |
| Scoreboard | Compare AXI behavior, destination bytes, completion metadata, counters, status, and IRQ against the expected model. |
| Coverage collector | Sample functional events and crosses defined in Section 7. |
| SVA checker set | Check protocol stability, burst rules, FIFO bounds, state/count consistency, IRQ semantics, and reset behavior. |
| Regression launcher | Compile, run, seed, collect logs, and merge coverage data reproducibly. |

### 4.1 Reference-model and scoreboard policy

The reference model must not duplicate the descriptor-manager state machine, FIFO pointers, or RTL burst-splitting implementation. Instead it shall:

1. Initialize to the same deterministic memory image as the AXI RAM.
2. Snapshot expected source bytes when a descriptor begins.
3. Construct expected destination bytes and expected completion fields from the descriptor and injected memory behavior.
4. Update expected memory only for accepted writes.
5. Compare observed AXI write data and destination memory against this independent model.
6. Fail the test if a burst remains unfinished or a descriptor is unexpectedly active at test end.

## 5. Test Strategy

The test plan uses directed tests for specific requirements, constrained-random tests for combinations, assertion-driven stress for protocol behavior, and coverage-closure tests for hard-to-reach legal states.

### P0 — Build, reset, and basic connectivity

| Scenario | Expected check |
| --- | --- |
| Elaboration smoke | DUT, AXI-Lite agent, memory proxy, RAM, RAL, scoreboard, and assertions connect and initialize. |
| Idle reset | All FIFOs, counters, active state, completion state, sticky status, and IRQ reset to defined values. |
| Basic programmed transfer | One aligned, non-overlapping transfer completes with correct destination data and completion record. |

### P1 — AXI-Lite and register-access behavior

| Scenario | Expected check |
| --- | --- |
| RAL frontdoor programming | Program source, destination, length, tag, control, submit, and completion pop through RAL. |
| Register readback | Check writable fields, status fields, queue levels, submitted/completed counts, and empty-completion values. |
| WSTRB matrix | Exercise all single-byte, multi-byte, and full-byte write-strobe patterns relevant to staging registers. |
| Access policy | Attempt reads of write-only locations, writes to read-only locations, and accesses to unsupported addresses. |
| Command no-op | Confirm zero-data/zero-strobe command writes do not create submit, pop, or clear pulses. |

### P2 — Descriptor validity, boundaries, and queues

| Scenario | Expected check |
| --- | --- |
| Length sweep | Cover sub-beat, one-beat, multi-beat, long, and maximum-supported transfer lengths. |
| Tag sweep | Cover zero, normal, and maximum configured tag values. |
| Alignment matrix | Verify aligned descriptors; reject all prohibited source/destination offsets. |
| Address range | Verify legal low/high addresses and reject width overflow, range overflow, and wraparound. |
| Overlap matrix | Cover non-overlap, adjacency, source-before-destination overlap, destination-before-source overlap, and identical ranges. |
| 4 KiB matrix | Cover neither/source/destination/both-side crossing and required burst splitting. |
| Request FIFO saturation | Fill the request FIFO, observe the full condition/rejection behavior, then drain it. |
| Completion FIFO behavior | Build pending completions, observe full/empty behavior, pop entries, and confirm ordering. |

### P3 — AXI transfer, backpressure, and outstanding traffic

| Scenario | Expected check |
| --- | --- |
| AW stall | Hold `AWREADY` low and check stable write-address signals and later progress. |
| W stall | Hold `WREADY` low and check stable write data/strb/last signals and later progress. |
| B stall | Delay B responses and check write completion/status handling. |
| AR stall | Hold `ARREADY` low and check stable read-address signals and later progress. |
| R stall | Delay read data and check stable behavior, internal backpressure, and recovery. |
| AXIS FIFO pressure | Fill or stall the stream path and check that backpressure propagates without data loss. |
| Multiple outstanding bursts | Permit multiple incomplete reads/writes, delay responses, and check IDs, ordering, and completion correctness. |
| Partial final beat | Use non-word-multiple lengths; check `WSTRB`, source/destination bytes, and final `WLAST`. |

### P4 — Error, completion, IRQ, and reset

| Scenario | Expected check |
| --- | --- |
| Read `SLVERR` | Inject a source-side `SLVERR`; check completion read-error encoding and software-visible status. |
| Read `DECERR` | Inject a source-side `DECERR`; check completion read-error encoding and software-visible status. |
| Write `SLVERR` | Inject a destination-side `SLVERR`; check completion write-error encoding and software-visible status. |
| Write `DECERR` | Inject a destination-side `DECERR`; check completion write-error encoding and software-visible status. |
| IRQ disabled/enabled | Verify level-sensitive IRQ behavior in both modes. |
| Empty completion pop | Verify sticky empty-pop status and its clear behavior. |
| Reset recovery | Apply reset at legal idle/active/AXI-active points; check cleanup, IRQ low, and a subsequent successful transfer. |

### P5 — Constrained-random and closure testing

| Scenario | Expected check |
| --- | --- |
| Legal constrained-random descriptors | Randomize source/destination, lengths, tags, queue timing, and memory latency while scoreboard checks every transfer. |
| Negative constrained-random descriptors | Randomize invalid fields and check rejection/status instead of data movement. |
| Mixed queue traffic | Randomize submissions, completion pops, IRQ enable state, and status reads around active traffic. |
| Coverage-directed tests | Target uncovered legal combinations, rare FSM transitions, backpressure arcs, and assertion cover properties. |
| Long-running stress | Repeatedly execute legal transfers with random stalls/errors to detect state leakage or transaction loss. |

## 6. Assertion Plan

Assertions are required to catch errors close to their origin rather than relying only on end-of-test data mismatch.

| Assertion family | Required properties |
| --- | --- |
| AXI4-Lite protocol | AW/W/AR/B/R payload stability while valid is held under stall; legal response handshakes. |
| AXI4 master protocol | AW/W/AR/R/B stability under stall, legal INCR bursts, beat-size rules, 4 KiB legality, known payloads, and valid `WLAST`. |
| Descriptor path | Descriptor payload stability during acceptance stalls; no descriptor execution without valid acceptance. |
| AXIS FIFO | Stable stream payload/sidebands under `TVALID && !TREADY`; FIFO bounds and correct backpressure propagation. |
| Queue and counters | Request/completion FIFO bounds, count consistency, legal push/pop behavior, and in-order completion state. |
| IRQ and reset | IRQ equation, IRQ deassertion after final pop, reset state cleanup, and no illegal post-reset activation. |

Assertion cover properties shall be defined for important legal stress conditions so that a regression proves they were actually activated.

## 7. Functional Coverage Plan

Functional coverage is a measurement plan, not a substitute for scoreboard or assertion checking. The following covergroups and crosses are required.

| Coverage area | Planned samples |
| --- | --- |
| AXI-Lite access | Read/write direction, register category, WSTRB class and lanes, response, operation/address cross. |
| RAL access | Frontdoor configuration writes, commands, status reads, and predictor-consistent accesses. |
| Descriptor properties | Legal/invalid result, length class, alignment, tag class, range boundary, high-bit validity, overlap relation, and source/destination 4 KiB crossings. |
| Queue/status | Request/completion occupancy, push/pop, submit outcome, active state, sticky status, and clear sequence. |
| AXI transfer | Burst size/length, residual burst, 4 KiB split, partial final beat, and `WLAST`. |
| Backpressure | AW/W/B/AR/R stall and recovery, AXIS stall/recovery, and FIFO-full propagation. |
| Errors | Read/write `OKAY`, `SLVERR`, `DECERR`, and completion/error-status cross. |
| Outstanding traffic | Read/write outstanding depth and delayed response combinations. |
| Completion/IRQ/reset | Completion presence, tag/length/status class, IRQ enable/level, pop behavior, reset point, and recovery result. |

Required crosses include at minimum:

- source/destination boundary condition × transfer-length class;
- descriptor validity × submit outcome;
- queue level × completion presence;
- memory response type × completion error status;
- channel-stall type × recovery outcome;
- IRQ enable × completion FIFO state;
- reset point × post-reset recovery result.

Coverage closure requires every planned functional bin to be hit or formally waived with a documented reason. Any waiver must identify whether the bin is impossible by construction, disabled by the target parameter configuration, or intentionally out of scope.

## 8. Regression and Reporting Requirements

The regression flow shall:

- Run directed P0-P4 tests before broad constrained-random tests.
- Record test name, random seed, simulator version, RTL revision, timeout, and result.
- Preserve UVM logs, assertion failures, scoreboard diagnostics, and coverage database information.
- Run a smoke subset for fast change detection and a full regression for closure.
- Distinguish black-box functional tests from white-box coverage-activation tests.
- Publish a report that lists pass/fail status, coverage state, reviewed exclusions, open issues, and scope changes.

No verification result may be claimed solely from code coverage. A passing closure requires coherent evidence from tests, scoreboard checks, assertions, and functional coverage.

## 9. Entry and Exit Criteria

### Entry criteria

- DUT interfaces, register map, descriptor format, and parameter configuration are stable enough to create predictions.
- AXI-Lite agent, RAL model, memory proxy, RAM, reference model, scoreboard, assertions, and regression launcher compile together.
- Memory initialization and error/backpressure controls are deterministic and reset between tests.
- Each planned test has an expected positive or negative outcome.

### Test pass criteria

- Test completes before its defined timeout.
- No unexpected UVM error or fatal occurs.
- No assertion failure or unexpected protocol violation occurs.
- Scoreboard data, burst, completion, status, counter, and IRQ checks match the expected outcome.
- Negative tests demonstrate the specified rejection/error result rather than silently completing as normal transfers.

### Verification closure criteria

- All planned P0-P4 requirements have passing, traceable tests.
- P5 random/stress testing has exercised the planned combinations and revealed no unresolved correctness issue.
- Functional coverage targets are reached or remaining bins are review-approved waivers.
- Assertion properties have no failures and their cover properties have been activated by targeted tests.
- Code coverage is reviewed for meaningful unexecuted logic; exclusions are documented.
- All open issues, unsupported parameters, and intentionally excluded features are recorded in the final verification report.

## 10. Scope Exclusions and Escalation Rules

The following are excluded from this plan unless the design configuration changes:

- Unaligned transfer shifting when `ENABLE_UNALIGNED=1`.
- Scatter-gather linked-list descriptor fetch when `ENABLE_SG=1`.
- Multi-engine/multi-channel scheduling within the IP.
- Out-of-order descriptor completion behavior.
- Any write-abort behavior not explicitly defined in the IP specification.

Enabling an excluded feature, changing an interface width, changing FIFO depth, changing maximum burst length, or changing the register/descriptor specification shall trigger:

1. Requirement-impact review.
2. Reference-model and scoreboard update review.
3. Assertion and coverage-plan update.
4. Targeted regression followed by full-regression re-execution.

## 11. Handoff to System-Level Verification

Once this plan reaches closure, the IP verification baseline can be reused by the larger AXI DMA subsystem effort. The system-level plan should rely on the IP baseline for:

- Single-instance descriptor acceptance, queues, completion, IRQ, reset, and byte-accurate data movement.
- AXI burst, backpressure, error-response, and outstanding-transaction behavior.
- AXI-Lite register and command semantics.

The system-level plan must independently verify what this IP-level plan excludes:

- Multiple DMA channels and their simultaneous operation.
- AXI-Lite Crossbar decoding to channel and IRQ/status blocks.
- AXI-Stream routing between DMA channel readers and writers.
- AXI Crossbar sharing among DMA and external masters.
- Multiple memory windows, memory VIP behavior, and same-RAM arbitration.

This separation keeps the IP verification focused and gives the system-level environment a clear, non-duplicated foundation.

