# AXI4 DMA Dual-Channel Subsystem Functional Verification Report

| Item | Value |
| --- | --- |
| Verification level | Integrated dual-channel subsystem |
| Methodology | SystemVerilog, UVM 1.2, UVM RAL, SVA, and AMD AXI VIP |
| Simulator and coverage | Synopsys VCS/URG V-2023.12-SP2 |
| Regression baseline | August 9, 2026 |
| Report date | August 25, 2026 |
| Source revision | `01b79ed1ce55d82f7d9febaaf26b3a4ef1ed711b` |
| Status | PASS |

## 1. Executive Summary

The AXI4 DMA dual-channel subsystem completed the maintained functional verification regression. All 31 tests passed with `UVM_ERROR=0` and `UVM_FATAL=0`. AMD AXI VIP reported no protocol violations, project assertions reported no failures, explicit data comparisons passed, and the scoreboard completed with no unmatched activity.

| Result | Value |
| --- | ---: |
| Regression | 31/31 PASS |
| Pass rate | 100% |
| Overall coverage score | 95.93% |
| Line coverage | 99.36% |
| Condition coverage | 93.60% |
| Toggle coverage | 91.40% |
| FSM coverage | 100.00% |
| Branch coverage | 100.00% |
| Assertion coverage, aggregate | 87.16% |
| Assertion coverage, DUT hierarchy | 91.23% |
| Functional group coverage | 100.00% |

The regression covered the control plane, descriptor admission, dual-channel transfers, all legal crossbar routes, AXI traffic, completion ordering, routing contention, response errors, internal fault reporting, abort behavior, interrupt handling, reset recovery, transfer boundaries, and counter/tag rollover.

## 2. Design Under Verification

The verification target is `axi_dma_subsystem_core`. The subsystem integrates two DMA channels, two external AXI masters, a 4-to-2 AXI crossbar, a 2-to-2 AXI-Stream switch, per-channel control registers, descriptor management, route ownership, and global interrupt/status logic.

The synthesizable wrapper provides two RAM targets. The AMD VIP testbench instantiates the core directly and replaces those targets with MEM0 and MEM1 slave VIPs for controlled latency, backpressure, response injection, and passive observation.

### 2.1 Configuration

| Configuration | Value |
| --- | --- |
| DMA channels | 2: DMA0 and DMA1 |
| External AXI masters | 2: EXT0 and EXT1 |
| AXI crossbar | 4 source ports to 2 memory targets |
| AXI address / data / input ID width | 32 / 32 / 4 bits |
| AXI crossbar output ID width | 6 bits |
| Maximum DMA burst | 16 beats |
| AXI-Lite address / data width | 32 / 32 bits |
| AXI-Lite block window | 4 KiB |
| AXI-Stream data / KEEP width | 32 / 4 bits |
| AXI-Stream ID / DEST / USER width | 2 / 1 / 1 bits |
| Descriptor length / tag width | 20 / 8 bits |
| Per-channel stream FIFO | 32 beats |
| Scatter-gather | Disabled (`ENABLE_SG=0`) |
| Unaligned DMA | Disabled (`ENABLE_UNALIGNED=0`) |
| Version value | `0x0001_0000` |

### 2.2 Address map

| Target or register block | Address range or base |
| --- | --- |
| RAM0 | `0x0000_0000` to `0x0000_FFFF` |
| RAM1 | `0x1000_0000` to `0x1000_FFFF` |
| DMA channel 0 control | Base `0x0000_0000`, 4 KiB window |
| DMA channel 1 control | Base `0x0000_1000`, 4 KiB window |
| Global interrupt/status | Base `0x0000_2000`, 4 KiB window |

### 2.3 Main RTL blocks

| Module | Responsibility |
| --- | --- |
| `axi_dma_subsystem_core` | Integrates the control crossbar, AXI crossbar, DMA wrappers, AXI-Stream switch, descriptor manager, route controller, and interrupt controller. |
| `dma_ctrl_regs` | Implements channel control, status, source, destination, length, route, tag, result, counter, and version registers. |
| `dma_desc_manager` | Validates commands, allocates hardware tags, acquires routes, issues descriptors, correlates status, maps errors, and records completions. |
| `dma_channel_wrap` | Wraps the AXI DMA read/write engines, AXI-Stream FIFO, and status paths. |
| `dma_axis_route_ctrl` | Arbitrates destination ownership and tracks requests, grants, release, and route faults. |
| `dma_irq_status_ctrl` | Stores completion, error, and fault state; applies masks and clear operations; generates channel and global interrupts. |

The descriptor-manager state flow is:

```text
IDLE -> VALIDATE -> WAIT_ROUTE -> ISSUE_WR_DESC -> ISSUE_RD_DESC
     -> WAIT_STATUS -> COMPLETE -> IDLE
                         \-> ERROR_RECOVERY -> IDLE
```

## 3. Verification Environment

The testbench `tb_axi_dma_core_amd_vip` contains clock and reset generation, the DUT, five AMD AXI VIP instances, passive internal probes, negative-test controls, and SVA bindings on both memory-side AXI interfaces.

### 3.1 AMD AXI VIP configuration

| Role | Mode | Address / data / ID width | Verification use |
| --- | --- | --- | --- |
| AXI-Lite CPU | Master | 32 / 32 / 0 | Register frontdoor access, WSTRB, invalid addresses, and timing. |
| EXT0 | AXI4 master | 32 / 32 / 4 | External source traffic, RAM paths, burst shapes, and attributes. |
| EXT1 | AXI4 master | 32 / 32 / 4 | External source traffic, RAM paths, and concurrency. |
| MEM0 | AXI4 slave | 32 / 32 / 6 | RAM0 behavior, latency, backpressure, and response injection. |
| MEM1 | AXI4 slave | 32 / 32 / 6 | RAM1 behavior, latency, backpressure, and response injection. |

### 3.2 UVM components

| Component | Responsibility |
| --- | --- |
| `dma_subsys_vip_manager` | Creates, starts, validates, and publishes the five typed VIP agents. |
| `dma_subsys_memory_behavior_controller` | Configures deterministic memory responses, READY behavior, B/R delay, and errors. |
| AXI-Lite sequencer and driver | Convert project register transactions into public AMD AXI-Lite calls. |
| Virtual sequencer | Coordinates system-level sequences. |
| Command, route, and IRQ monitors | Observe command acceptance, tags, route lifecycle, completion, interrupt, fault, and reset events. |
| `dma_subsys_vip_transaction_adapter` | Converts AMD monitor transactions into project-owned register and memory transactions. |
| `dma_subsys_ref_model` | Maintains an independent sparse byte-addressable expected memory. |
| `dma_subsys_scoreboard` | Correlates intent, commands, routes, bus traffic, completions, register state, and interrupts. |
| `dma_subsys_coverage` | Samples the system-domain functional coverage model. |
| RAL model and predictor | Provide a 4-byte little-endian frontdoor map and update mirrors from observed AXI-Lite traffic. |
| `dma_subsys_watchdog` | Detects global hangs and excessive route wait. |

### 3.3 Self-checking data path

1. Virtual sequences publish the expected operation before starting traffic, including route, length, tags, acceptance, completion, interrupt, and error expectations.
2. AMD VIP and passive monitors record AXI-Lite, AXI, route, completion, interrupt, fault, and reset activity.
3. The reference model maintains the expected source and destination bytes and commits destination data after the modeled operation completes.
4. The scoreboard decodes widened crossbar IDs to distinguish DMA0, DMA1, EXT0, and EXT1, then checks byte data, tags, lengths, errors, ordering, route release, and interrupts.
5. The UVM `check_phase` confirms that no expected intent, active flow, route ownership, or data comparison remains outstanding.

## 4. Regression Execution and Results

The regression launcher compiles the environment, executes the maintained test list, merges the coverage databases, and invokes URG. Each test retains its simulation log and coverage identity.

### 4.1 Regression verdict

- All 31 maintained tests returned a successful status.
- Every test completed with `UVM_ERROR=0` and `UVM_FATAL=0`.
- AMD VIP protocol checks, project SVA, explicit sequence comparisons, and scoreboard end checks passed.
- The merged coverage database and URG dashboard were generated on August 9, 2026 at 01:31:37.

### 4.2 Results by scenario group

| Scenario group | Tests | Result | Primary objective |
| --- | ---: | --- | --- |
| Infrastructure | 4 | 4/4 PASS | VIP startup, environment connectivity, RAL frontdoor access, and prediction. |
| Nominal DMA, ordering, and routing | 6 | 6/6 PASS | Bidirectional transfers, path matrix, completion ordering, route contention, and release. |
| Length, burst, and AXI attributes | 6 | 6/6 PASS | Length boundaries, 64 KiB extent, burst forms, attributes, and bus toggles. |
| Registers and AXI-Lite | 3 | 3/3 PASS | Access policy, WSTRB, AW/W independence, B/R stability, and condition closure. |
| Errors, faults, and abort | 6 | 6/6 PASS | Command rejection, response errors, status/fault protection, and abort timing. |
| Interrupt and reset | 4 | 4/4 PASS | Pending causes, masking, status separation, active reset, and FSM reset arcs. |
| Counter and tag rollover | 2 | 2/2 PASS | Counter low-byte rollover and hardware-tag transitions on legal traffic. |
| **Total** | **31** | **31/31 PASS** | Maintained regression completed successfully. |

### 4.3 Covered behavior

- Bidirectional DMA transfers across every legal DMA0/DMA1/EXT0/EXT1 to RAM0/RAM1 path.
- Both issue/completion ordering combinations, deterministic reordering, route contention, ownership, wait accounting, and release.
- Zero-length rejection, software-visible length classes, and legal single-window transfers from 4 through 65,536 bytes.
- External-master FIXED, INCR, and WRAP bursts, including legal 256-beat INCR traffic.
- AXI `SLVERR` and `DECERR`, descriptor validation failures, tag/length/status faults, interrupt masking, and multiple pending causes.
- Idle and active reset, reachable nonterminal FSM reset arcs, pending and in-flight abort behavior, and post-reset reuse.

## 5. Coverage Results

### 5.1 Merged coverage summary

| Metric | Result |
| --- | ---: |
| Overall score | 95.93% |
| Line | 99.36% |
| Condition | 93.60% |
| Toggle | 91.40% |
| FSM | 100.00% |
| Branch | 100.00% |
| Assertion, aggregate | 87.16% |
| Assertion, DUT hierarchy | 91.23% |
| Functional group | 100.00% |

The aggregate assertion value includes instrumented `axi_vip_pkg` and `uvm_pkg` statistics. The DUT hierarchy row is reported separately for the project testbench and DUT hierarchy.

![Final Synopsys URG dashboard](Coverage_report.png)

### 5.2 Functional coverage model

The coverage model contains 11 covergroups, 65 coverpoints, and 8 crosses.

| Covergroup | Main dimensions | Result |
| --- | --- | ---: |
| `command_cg` | Accepted source and destination, length classes, and route cross. | 100% |
| `intent_cg` | Intended route and length, result class, acceptance, completion, and interrupt expectation. | 100% |
| `register_cg` | Register block/address, access type, WSTRB, response, and access-response cross. | 100% |
| `memory_cg` | DMA0/DMA1/EXT0/EXT1 origin, RAM0/RAM1 target, access, response, and path crosses. | 100% |
| `memory_protocol_cg` | Burst, beat count, size, ID, alignment, page position, 4 KiB rule, strobe, and malformed traffic. | 100% |
| `route_cg` | Request, grant, release, fault, route, wait class, and path cross. | 100% |
| `completion_cg` | Owner, error/result class, abort state, and owner-abort cross. | 100% |
| `completion_order_cg` | Issue order, completion order, reordering, and pending depth. | 100% |
| `irq_cg` | Pending/enables, channel/global interrupt, causes, masking, and consistency. | 100% |
| `fault_cg` | Manager/route fault type, source, and enable state. | 100% |
| `reset_cg` | Assertion, deassertion, epoch, and idle/active context. | 100% |

### 5.3 Structural coverage exclusions

The merged report applies `sim/exclusions/subsystem_unreachable.el` with strict checksum and object matching.

| Metric or object | Directives | Reviewed basis |
| --- | ---: | --- |
| Line block | 6 | Unreachable statements in integrated command and abort handshakes. |
| Condition | 22 | Boolean vectors prevented by prerequisites, compound predicates, or direct handshakes. |
| Toggle | 170 | Constants and fixed alignment, width, address-window, protocol, configuration, and ownership fields. |
| FSM transition | 2 | One unreachable `ISSUE_RD_DESC -> COMPLETE` transition in each channel manager. |
| Branch | 2 | Unreachable pending-only abort and register-write default paths. |

Project assertions and functional covergroups are not excluded by this file. Detailed object-level analysis is recorded in [AXI_DMA_Subsystem_Coverage_Waiver_Rationale.md](AXI_DMA_Subsystem_Coverage_Waiver_Rationale.md).

## 6. Assertions and Protocol Checking

The project SVA checker contains 21 assertion properties and 5 cover properties and is bound to both memory-side AXI interfaces.

| Check family | Checked behavior | Activation |
| --- | --- | --- |
| Reset clearing | AW, W, and AR request VALID signals clear after reset. | Reset recovery and FSM reset-arc tests. |
| Payload stability | AW, W, AR, B, and R payloads remain stable while VALID is asserted and READY is low. | AXI backpressure and memory delay/error tests. |
| Known values | Addresses, controls, data, responses, and IDs contain no X/Z values on valid channels. | Continuous during regression. |
| Size and burst legality | AWSIZE and ARSIZE are legal; reserved burst encodings are rejected. | Burst-shape and attribute tests. |
| FIXED constraints | FIXED burst length does not exceed the configured limit. | AXI burst-shape test. |
| WRAP constraints | WRAP length is 2, 4, 8, or 16 beats. | AXI burst-shape test. |
| 4 KiB boundary | INCR bursts do not cross the AXI 4 KiB boundary. | Path, boundary, and burst tests. |
| Cover properties | AW, W, and AR backpressure plus FIXED and WRAP activation. | Directed protocol tests. |

No project assertion failure or AMD AXI/AXI-Lite protocol violation occurred in the regression.

## 7. Scoreboard, Reference Model, and RAL Results

### 7.1 Scoreboard and reference model

The scoreboard completed with no unmatched intent, active flow, route ownership, route leak, or byte mismatch. Its checks covered:

- command source, destination, route, length, software tag, and hardware tag;
- crossbar ID ownership, read/write addresses, byte strobes, data, and final destination memory;
- route request, grant, wait, release, pending depth, and issue/completion order;
- completion owner, tags, error, completed length, abort class, and register-visible state;
- completion, error, and fault pending state, masks, channel interrupts, global interrupt, and clear operations.

### 7.2 Register model

`dma_subsys_reg_block` contains CH0, CH1, and GLOBAL sub-blocks in one 4-byte little-endian frontdoor map. A passive `uvm_reg_predictor` updates register mirrors from observed AXI-Lite transactions.

RAL smoke, access-policy, timing, and condition-closure tests verified register reset values, read/write/read-only/write-only behavior, WSTRB handling, invalid-address responses, version value `0x0001_0000`, and mirror consistency.

## 8. AXI-Lite DECERR Fix Verification

The imported `axil_crossbar_wr.v` logic was corrected so that an unmapped write produces the local DECERR response only after the corresponding W-channel handshake. The local response path also remains isolated from downstream B responses.

| Fix area | Verification result |
| --- | --- |
| DECERR BVALID timing | Local DECERR is issued only after write data is accepted. |
| WREADY and W-state gating | State updates occur only for a valid write command. |
| Local/downstream response isolation | Downstream BREADY remains suppressed while local DECERR is at the response head. |
| Reset consistency | W-select, W-drop, and W-select-valid state reset together. |
| Directed verification | Register-access-policy, AXI-Lite timing, and condition-closure tests passed. |

Further implementation details are recorded in [RTL_fix_intro.md](RTL_fix_intro.md).

## 9. Sign-Off Assessment

| Sign-off item | Result |
| --- | --- |
| Regression | 31/31 PASS |
| UVM | `UVM_ERROR=0`, `UVM_FATAL=0` |
| Protocol checking | No AMD VIP protocol violations |
| Project SVA | No assertion failures |
| Scoreboard and data integrity | No unmatched activity, route leak, or byte mismatch |
| Functional coverage | 11/11 covergroups at 100.00% |
| Structural coverage | Line 99.36%, Condition 93.60%, Toggle 91.40%, FSM 100.00%, Branch 100.00% |
| Overall coverage | 95.93% |
| Final status | **PASS** |

## Appendix A. Regression Inventory

| Group | Test | Verification objective |
| --- | --- | --- |
| Infrastructure | `amd_axi_vip_smoke_test` | Start and exercise all five AMD VIPs, including register access and EXT0/EXT1 memory traffic. |
| Infrastructure | `dma_subsys_vip_manager_smoke_test` | Check VIP manager configuration, startup order, handles, and lifecycle. |
| Infrastructure | `dma_subsys_env_smoke_test` | Check reusable UVM environment construction, connectivity, and idle-state behavior. |
| Infrastructure | `dma_subsys_ral_smoke_test` | Check RAL frontdoor access, passive prediction, mirrors, reset values, and version values. |
| Nominal/routing | `dma_subsys_ch0_to_ch1_test` | Check the primary DMA0-driven RAM0-to-RAM1 path. |
| Nominal/routing | `dma_subsys_ch1_to_ch0_test` | Check the reverse DMA1-driven RAM1-to-RAM0 path. |
| Nominal/routing | `dma_subsys_crossbar_path_matrix_test` | Exercise every legal DMA0/DMA1 and EXT0/EXT1 path to RAM0/RAM1. |
| Nominal/routing | `dma_subsys_completion_reorder_test` | Check correlation when two channels complete out of issue order. |
| Nominal/routing | `dma_subsys_completion_order_reverse_test` | Exercise the opposite issue/completion ordering combination. |
| Nominal/routing | `dma_subsys_route_contention_test` | Check destination ownership, arbitration, wait accounting, and release. |
| Length/AXI | `dma_subsys_transfer_length_boundary_test` | Exercise software-visible length classes and boundary transitions. |
| Length/AXI | `dma_subsys_axi_burst_shape_test` | Exercise legal FIXED, INCR, and WRAP burst forms. |
| Length/AXI | `dma_subsys_toggle_value_sweep_test` | Toggle tags, lengths, addresses, and response encodings across reachable values. |
| Length/AXI | `dma_subsys_legal_extent_test` | Exercise the maximum legal 65,536-byte transfer within one RAM window. |
| Length/AXI | `dma_subsys_axi_attribute_toggle_test` | Exercise programmable external-master IDs, CACHE, PROT, and related attributes. |
| Length/AXI | `dma_subsys_bus_toggle_closure_test` | Exercise remaining reachable bus, address, and length toggles. |
| AXI-Lite | `dma_subsys_register_access_policy_test` | Check RW/RO/WO policy, WSTRB behavior, and invalid-address responses. |
| AXI-Lite | `dma_subsys_axil_protocol_timing_test` | Check AW/W independence and B/R stability under backpressure. |
| AXI-Lite | `dma_subsys_axil_condition_closure_test` | Exercise remaining reachable channel/global register and AXI-Lite conditions. |
| Error/abort | `dma_subsys_descriptor_error_test` | Check disabled, zero-length, alignment, range, overlap, busy, and route errors. |
| Error/abort | `dma_subsys_memory_response_error_test` | Check AXI read/write `SLVERR` and `DECERR` mapping into completion status. |
| Error/abort | `dma_subsys_status_fault_injection_test` | Check tag/length/status protection and manager/route fault reporting. |
| Error/abort | `dma_subsys_status_fault_expansion_test` | Expand channel, source, and encoding permutations for status faults. |
| Error/abort | `dma_subsys_abort_timing_test` | Distinguish pending-command and in-flight abort behavior. |
| Error/abort | `dma_subsys_abort_phase_matrix_test` | Cover both channel roles, multiple abort phases, and subsequent recovery. |
| IRQ/reset | `dma_subsys_irq_mask_multi_pending_test` | Check pending-cause separation, masks, channel interrupts, and global interrupt. |
| IRQ/reset | `dma_subsys_irq_status_separation_test` | Check independent completion/error/fault storage and byte-strobe-aware clearing. |
| IRQ/reset | `dma_subsys_reset_recovery_test` | Check idle and active reset, route/interrupt cleanup, and post-reset transfer reuse. |
| IRQ/reset | `dma_subsys_fsm_reset_arc_test` | Exercise reset exits from every reachable nonterminal state and legal stalled abort branches. |
| Rollover | `dma_subsys_tag_counter_rollover_test` | Exercise counter low-byte rollover and hardware-tag transitions with deterministic errors. |
| Rollover | `dma_subsys_legal_tag_rollover_test` | Exercise hardware-tag transitions using legal successful transfers. |

## Appendix B. Verification Artifacts

- [Subsystem verification environment](../README.md)
- [Detailed test scenarios](AXI_DMA_Subsystem_Test_Scenarios.md)
- [Coverage waiver rationale](AXI_DMA_Subsystem_Coverage_Waiver_Rationale.md)
- [Coverage dashboard image](Coverage_report.png)
- [AXI-Lite correction summary](RTL_fix_intro.md)
- [AMD AXI VIP dependency](AMD_axi_vip_external_dependency.md)
- [`dma_subsys_coverage.svh`](../tb/uvm/env/dma_subsys_coverage.svh)
- [`dma_subsys_scoreboard.svh`](../tb/uvm/env/dma_subsys_scoreboard.svh)
- [`dma_subsys_axi_sva.sv`](../tb/sva/dma_subsys_axi_sva.sv)
- [`run_vcs_core_amd_vip.sh`](../sim/run_vcs_core_amd_vip.sh)
- [`cm_hier.cfg`](../sim/cm_hier.cfg)
- [`subsystem_unreachable.el`](../sim/exclusions/subsystem_unreachable.el)
