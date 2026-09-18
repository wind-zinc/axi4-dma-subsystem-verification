# AXI4 Multi-Descriptor DMA Subsystem IP Verification Plan

**Document type:** Verification plan

**Version:** 1.0

**Lifecycle phase:** Pre-regression planning

**Scope:** IP-level RTL verification

**Methodology:** SystemVerilog, UVM 1.2, UVM RAL, SVA, and VCS/URG

## 1. Purpose

This document defines the verification objectives, environment, stimulus, checking, coverage, and completion criteria for one AXI4 multi-descriptor memory-to-memory DMA subsystem IP.

The DMA is programmed through AXI4-Lite. It validates and queues descriptors, transfers data through an internal AXI4-Stream path, accesses external memory through AXI4, records completion information, and optionally raises an interrupt.

## 2. DUT Overview

```text
AXI4-Lite software control
  -> descriptor staging registers
  -> SUBMIT command
  -> descriptor validation and request FIFO
  -> descriptor manager
  -> AXI DMA read engine
  -> internal AXI4-Stream FIFO
  -> AXI DMA write engine
  -> AXI4 external memory
  -> completion FIFO, status, and IRQ
```

Accepted descriptors are expected to execute in order. Each descriptor identifies a source byte range, a non-overlapping destination byte range, a transfer length, a tag, and interrupt control. Completion information becomes visible after the read-side and write-side terminal status is available.

### 2.1 Interfaces

| Interface | Direction | Planned verification focus |
| --- | --- | --- |
| `clk`, `rst` | Input | Reset behavior, state cleanup, and recovery. |
| `s_axil_*` | AXI4-Lite slave | Register access, command semantics, response behavior, and protocol stability. |
| `m_axi_*` | AXI4 master | Burst generation, protocol behavior, data integrity, backpressure, and error responses. |
| `irq` | Output | Completion-driven, level-sensitive interrupt behavior. |

### 2.2 Verification configuration

| Item | Planned configuration |
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

Parameter changes require review of the affected stimulus constraints, predictions, assertions, and coverage model.

## 3. Verification Objectives

### 3.1 Control plane

Verification shall demonstrate that:

- Software can program source address, destination address, length, tag, and interrupt enable through AXI4-Lite.
- `SUBMIT`, `COMP_POP`, and sticky-status clear operations have write-one command semantics.
- Descriptor staging registers honor byte write strobes.
- Read-only and write-only locations follow the register access policy.
- Reserved and unmapped addresses return the specified response and read data.
- Empty completion-head registers return their defined empty values.
- Status, queue level, submitted count, and completed count remain internally consistent.

### 3.2 Descriptor admission

Verification shall demonstrate that:

- A valid descriptor is accepted when the request FIFO has space.
- A descriptor is rejected when the request FIFO is full.
- Zero-length transfers are rejected.
- Source and destination alignment rules are enforced.
- Address, length, and tag fields are interpreted at their configured widths.
- Source and destination ranges remain within the configured AXI address space.
- Overlapping source and destination byte ranges are rejected.
- Adjacent, non-overlapping byte ranges remain legal.
- Invalid-descriptor and full-queue outcomes are reflected in the defined status fields.

### 3.3 Data movement

For every accepted descriptor, verification shall establish that:

- The requested source byte range is read exactly once for the transfer.
- The destination receives the source byte stream in order.
- Bytes outside the requested destination range remain unchanged.
- Burst address, length, size, increment, and 4 KiB boundary behavior are legal.
- Write data, byte strobes, and `WLAST` are correct for every beat.
- Partial final beats update only the intended byte lanes.
- Descriptor execution and completion records preserve the required ordering.
- Completion tag, actual length, read error, write error, and mismatch fields encode the expected outcome.

### 3.4 Flow control and error handling

Verification shall exercise:

- Independent stalls on AW, W, B, AR, and R channels.
- Backpressure in the internal AXI4-Stream path.
- Multiple accepted but incomplete AXI transactions.
- Address-selected AXI read and write `SLVERR` responses.
- Address-selected AXI read and write `DECERR` responses.
- Reset while idle, while a descriptor is active, and while AXI traffic is active.

The DUT is expected to preserve protocol correctness and reach the defined completion or error state for each condition.

### 3.5 Completion and interrupt

Verification shall demonstrate that:

- A completion is recorded only after the transfer reaches its defined terminal state.
- Completion-head fields represent the oldest unpopped completion.
- `COMP_POP` removes one completion without corrupting later entries.
- IRQ remains low when interrupt generation is disabled.
- With interrupt generation enabled, IRQ remains high while a completion is pending.
- IRQ deasserts after the final pending completion is removed.

## 4. Verification Methodology

The verification environment will combine directed tests, constrained-random stimulus, an independent reference model, end-to-end scoreboarding, protocol assertions, and functional coverage.

Directed scenarios will establish deterministic behavior for register semantics, descriptor boundaries, queue transitions, error responses, and reset. Constrained-random scenarios will combine legal descriptor attributes, queue timing, memory latency, backpressure, and error injection. Coverage-directed scenarios will target planned conditions that remain unobserved after the main regression suites.

## 5. Verification Environment

| Component | Planned responsibility |
| --- | --- |
| Active AXI-Lite agent | Drive and monitor register accesses, byte strobes, command writes, and responses. |
| UVM RAL model | Represent the control/status register map and support frontdoor access through an adapter and predictor. |
| Descriptor monitor | Observe descriptor acceptance, rejection, queue state, active state, and completion records. |
| AXI memory proxy | Control channel stalls, response delay, outstanding traffic, and address-selected error injection. |
| AXI RAM model | Provide deterministic source data and accept DUT AXI transactions. |
| Reference memory model | Maintain a byte-addressable expected-memory image. |
| Scoreboard | Compare AXI activity, destination data, completion metadata, counters, status, and IRQ with predictions. |
| Coverage collector | Sample planned functional events and crosses. |
| SVA checker set | Check interface stability, burst legality, FIFO bounds, state consistency, IRQ semantics, and reset behavior. |
| Regression launcher | Compile tests, select seeds, collect logs, and merge coverage data. |

### 5.1 Reference model

The reference model will:

1. Initialize with the same deterministic memory contents as the AXI RAM.
2. Capture expected source bytes when descriptor execution begins.
3. Build the expected destination image and completion fields from the descriptor and injected response behavior.
4. Update expected memory for accepted write beats and active byte lanes.
5. Predict status, counters, queue state, and interrupt behavior from observed transactions.

### 5.2 End-of-test checks

Each test will check that:

- Expected descriptors have reached their planned terminal state.
- AXI bursts and completion records are accounted for.
- Observed destination bytes match the reference memory.
- Queue, counter, status, and interrupt predictions match the DUT.
- No unexpected protocol or assertion failure remains.

## 6. Planned Test Scenarios

### 6.1 Build, reset, and basic operation

| Testpoint | Planned stimulus and checks |
| --- | --- |
| Elaboration and connectivity | Initialize the DUT, agents, RAL model, memory path, scoreboard, assertions, and coverage components. |
| Idle reset | Check FIFO state, counters, active state, completion state, sticky status, and IRQ. |
| Basic transfer | Program one aligned, non-overlapping descriptor and check data and completion fields. |
| Back-to-back transfers | Submit multiple legal descriptors and check ordering and independent completion metadata. |

### 6.2 AXI4-Lite and register behavior

| Testpoint | Planned stimulus and checks |
| --- | --- |
| RAL frontdoor access | Program descriptor fields and commands through the register model. |
| Register readback | Check writable fields, status fields, queue levels, counters, and completion-head fields. |
| Write strobes | Exercise relevant single-byte, multi-byte, and full-word strobe patterns. |
| Access policy | Read and write each register category and access unmapped addresses. |
| Command semantics | Exercise asserted and non-asserted command bits with varied write strobes. |
| Sticky status | Create each planned sticky condition, read it, clear it, and check later operation. |

### 6.3 Descriptor legality and boundaries

| Testpoint | Planned stimulus and checks |
| --- | --- |
| Length classes | Exercise zero, sub-beat, one-beat, multi-beat, long, and maximum-supported lengths. |
| Tag values | Exercise zero, intermediate, and maximum configured tag values. |
| Alignment | Exercise legal alignment and each prohibited source/destination offset. |
| Address range | Exercise low and high legal addresses, range overflow, and wraparound cases. |
| Overlap relation | Exercise non-overlap, adjacency, partial overlap in both directions, and identical ranges. |
| 4 KiB boundaries | Exercise source and destination ranges that do and do not require burst splitting. |

### 6.4 Queue and completion behavior

| Testpoint | Planned stimulus and checks |
| --- | --- |
| Request queue occupancy | Drive empty, partially occupied, full, reject, and drain transitions. |
| Completion queue occupancy | Create pending completions, observe head data, pop entries, and check ordering. |
| Simultaneous activity | Combine descriptor submission, active transfer, completion production, and completion pop. |
| Empty completion pop | Pop an empty completion queue and check the defined status behavior. |

### 6.5 AXI traffic and backpressure

| Testpoint | Planned stimulus and checks |
| --- | --- |
| AW stall | Hold `AWREADY` low, check address stability, then release the channel. |
| W stall | Hold `WREADY` low, check data, strobe, and last stability, then release the channel. |
| B delay | Delay write responses and check write completion accounting. |
| AR stall | Hold `ARREADY` low, check address stability, then release the channel. |
| R delay | Delay read data and check downstream backpressure and recovery. |
| AXI4-Stream pressure | Stall the stream path and check lossless propagation of backpressure. |
| Outstanding traffic | Permit multiple incomplete bursts and vary response latency. |
| Partial final beat | Use non-word-multiple lengths and check final byte lanes and `WLAST`. |

### 6.6 Errors, interrupt, and reset

| Testpoint | Planned stimulus and checks |
| --- | --- |
| Read `SLVERR` / `DECERR` | Inject each response and check completion and software-visible error state. |
| Write `SLVERR` / `DECERR` | Inject each response and check completion and software-visible error state. |
| IRQ disabled / enabled | Check level behavior across completion production and pop operations. |
| Reset during operation | Apply reset at planned control and AXI activity points, then check cleanup and recovery. |

### 6.7 Constrained-random scenarios

Constrained-random stimulus will combine:

- legal source and destination addresses;
- transfer length and tag classes;
- descriptor submission and completion-pop timing;
- channel latency and backpressure;
- interrupt enable state;
- legal error-injection locations and response types.

Negative random scenarios will generate one identifiable descriptor error at a time so that the expected rejection reason remains deterministic.

## 7. Assertion Plan

| Assertion family | Planned properties |
| --- | --- |
| AXI4-Lite protocol | Payload stability under stall and legal request/response handshakes. |
| AXI4 master protocol | Payload stability, INCR burst rules, beat size, 4 KiB legality, known payloads, and `WLAST`. |
| Descriptor path | Descriptor stability during acceptance stalls and execution only after acceptance. |
| AXI4-Stream path | Payload stability under stall, FIFO bounds, and backpressure propagation. |
| Queue and counters | Legal push/pop behavior, bounds, count consistency, and completion ordering. |
| IRQ and reset | Interrupt-state relation, reset cleanup, and legal post-reset activation. |

Cover properties will identify whether key legal stall, queue, error, and reset sequences have occurred.

## 8. Functional Coverage Plan

| Coverage area | Planned sample space |
| --- | --- |
| AXI4-Lite access | Operation, register category, strobe class, byte lanes, address, and response. |
| Descriptor properties | Admission result, length class, alignment, tag class, range boundary, overlap relation, and 4 KiB crossing. |
| Queue and status | Request/completion occupancy, push/pop, submit outcome, active state, sticky status, and clear sequence. |
| AXI transfer | Burst length, residual burst, boundary split, partial final beat, byte strobes, and `WLAST`. |
| Backpressure | AW/W/B/AR/R stall and recovery, stream stall and recovery, and FIFO-full propagation. |
| Error handling | Read/write response type and corresponding completion status. |
| Outstanding traffic | Read and write outstanding depth with varied response delay. |
| Completion, IRQ, and reset | Completion state, tag/length/status class, interrupt state, pop behavior, reset point, and recovery. |

Planned crosses include:

- source/destination boundary condition by transfer-length class;
- descriptor-validity class by submit outcome;
- queue occupancy by completion state;
- memory response type by completion error status;
- channel-stall type by recovery outcome;
- interrupt-enable state by completion-queue state;
- reset point by post-reset recovery result.

## 9. Regression Strategy

The regression flow will provide:

- a smoke suite for build, reset, register access, and one basic transfer;
- directed suites grouped by control plane, descriptor handling, AXI traffic, error handling, and reset;
- constrained-random suites with recorded seeds;
- coverage-directed runs for unobserved planned conditions;
- reproducible logging of simulator version, RTL revision, configuration, seed, timeout, and result;
- merged assertion, functional, and code coverage for review.

Failures will be classified by requirement, scenario, seed, failing checker, and first observed error. A fixed failure will be rerun with the reproducing seed and the affected suite before regression completion.

## 10. Entry Criteria

Regression execution may begin when:

- DUT interfaces, register map, descriptor format, and target parameters are available.
- The testbench, agents, RAL model, memory path, scoreboard, assertions, and coverage model compile together.
- Memory initialization, backpressure controls, and error injection are deterministic.
- Each scheduled testpoint has a defined stimulus intent and expected outcome.
- Basic reset and one programmed transfer complete in the smoke environment.

## 11. Completion Criteria

Verification is ready for sign-off review when:

- Every planned requirement is linked to one or more executed testpoints and checkers.
- All scheduled directed and constrained-random suites complete without unresolved failures.
- Scoreboard, protocol, completion, status, counter, reset, and interrupt checks pass.
- Planned functional coverage is exercised or reviewed with a documented disposition.
- Assertion coverage confirms activation of the planned legal scenarios, with no unresolved assertion failures.
- Code coverage is reviewed for unexecuted logic relevant to the configured feature set.
- Known issues and deferred features have an owner and disposition.
- Regression results and coverage summaries are captured in a separate verification report.

## 12. Dependencies and Risks

| Item | Planned handling |
| --- | --- |
| AXI memory behavior | Use a controllable proxy and RAM model for deterministic stalls, delay, and response injection. |
| Descriptor prediction | Derive expected transfer and completion data from observed programming transactions. |
| Reset during outstanding traffic | Coordinate monitor and scoreboard reset handling with the DUT reset contract. |
| Rare boundary combinations | Use focused constraints and coverage-directed scenarios. |
| Parameter variation | Review affected requirements and rerun the applicable suites for each supported configuration. |

## 13. Deferred Features

The following features are not scheduled for the configuration in Section 2.2:

- unaligned transfer shifting with `ENABLE_UNALIGNED=1`;
- scatter-gather descriptor fetch with `ENABLE_SG=1`;
- multi-engine or multi-channel scheduling inside the IP;
- out-of-order descriptor completion;
- write-abort behavior beyond the defined IP interface contract.

## 14. Planned Deliverables

- reviewed verification plan and requirement-to-testpoint traceability;
- reusable UVM environment and RAL model;
- directed and constrained-random tests;
- independent reference memory model and scoreboard;
- protocol and design assertions;
- functional coverage model;
- regression launcher and reproducible run configuration;
- regression results, coverage summaries, issue disposition, and sign-off report.
