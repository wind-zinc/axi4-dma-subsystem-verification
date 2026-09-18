# AXI DMA Subsystem Test Scenarios

## 1. Regression structure

The no-argument launcher maintains 31 concrete tests. It compiles once, runs every test with a unique UVM test name and coverage identity, merges the results into one VDB, and generates one URG report.

This catalogue describes the 31 tests in the `regression_tests` array of `sim/run_vcs_core_amd_vip.sh`.

Every subsystem functional test derives from `dma_subsys_base_test`, starts a dedicated virtual sequence on `dma_subsys_virtual_sequencer`, and relies on the common environment for VIP startup, monitoring, RAL prediction, reference memory, scoreboard comparison, coverage, and watchdog behavior.

The pass criteria for a functional test are:

- no `UVM_ERROR` or `UVM_FATAL`;
- no AMD VIP protocol violation;
- no project SVA failure;
- all explicit sequence comparisons pass;
- the scoreboard has no unmatched intent, active flow, leaked route, or incomplete byte comparison in `check_phase`; and
- the process exits successfully.

## 2. Infrastructure tests

### 2.1 `amd_axi_vip_smoke_test`

**Purpose:** Prove that all generated AMD VIP instances can be created, started, and used before the full subsystem environment is involved.

**Scenario:**

- Starts the two memory slave agents, AXI-Lite CPU agent, and EXT0/EXT1 AXI master agents.
- Reads the channel register spaces over AXI-Lite.
- Uses EXT0 to write and read RAM0 at offset `0x100` with a recognizable `0xA5A50000` pattern.
- Uses EXT1 to write and read RAM1 at offset `0x100` with a recognizable `0x5A5A0001` pattern.

**Checks:** Agent availability, legal AXI/AXI-Lite handshakes, memory response, and readback data. This is also the safest startup diagnostic if a later test reports an AMD READY-X fatal.

### 2.2 `dma_subsys_vip_manager_smoke_test`

**Purpose:** Validate the project wrapper around the five vendor agents.

**Scenario:** Builds `dma_subsys_vip_manager`, waits for its persistent ready event, and checks that the CPU, EXT0, EXT1, MEM0, and MEM1 typed agent handles are all valid.

**Checks:** Configuration retrieval, VIF binding, slave-before-master startup order, and manager lifecycle. It does not perform a DMA transfer.

### 2.3 `dma_subsys_env_smoke_test`

**Purpose:** Prove that the complete reusable UVM environment builds and connects cleanly.

**Scenario:** Constructs the VIP manager, monitors, adapter, RAL, predictor, reference model, scoreboard, coverage, sequencers, driver, watchdog, and virtual sequencer without starting a directed data movement.

**Checks:** UVM construction/connect phases, configuration propagation, analysis connections, reset observation, and clean end-of-test reconciliation with no pending work.

### 2.4 `dma_subsys_ral_smoke_test`

**Purpose:** Validate the RAL frontdoor and passive prediction mechanism.

**Scenario:** Uses RAL to access CH0/CH1 SRC and ROUTE registers and reads all three VERSION locations. It performs write, read, mirror, and prediction-oriented operations through the AXI-Lite sequencer/adapter.

**Checks:** Register access policy, expected version value, frontdoor response, little-endian mapping, submap address placement, and mirror updates from actual monitored bus traffic rather than automatic prediction.

## 3. Nominal DMA and ordering tests

### 3.1 `dma_subsys_ch0_to_ch1_test`

**Purpose:** Verify the primary CH0-to-CH1 cross-memory flow.

**Scenario:** EXT0 initializes 64 bytes at RAM0 offset `0x1000`. DMA channel 0 is programmed to route the stream to channel 1 and write RAM1 offset `0x1000`, using software tag `0x31`.

**Checks:** Command acceptance, hardware-tag allocation, route grant/release, memory read/write data, completed length, success result, channel/global IRQ assertion, destination readback, and IRQ/status clear behavior.

### 3.2 `dma_subsys_ch1_to_ch0_test`

**Purpose:** Verify the reverse channel and memory direction.

**Scenario:** DMA channel 1 transfers 96 bytes from RAM1 offset `0x1400` to RAM0 offset `0x2400`, routes to channel 0, uses software tag `0x42`, and starts from a deterministic seed pattern `0x61`.

**Checks:** The same end-to-end flow properties as the forward test, with all owner, target, and route roles reversed.

### 3.3 `dma_subsys_crossbar_path_matrix_test`

**Purpose:** Exercise every legal source-to-memory and channel-route path.

**Scenario:**

- EXT0 reads and writes RAM0 and RAM1.
- EXT1 reads and writes RAM0 and RAM1.
- DMA0 and DMA1 execute all source/destination channel-route combinations.

**Checks:** Crossbar source identification from widened IDs, target decode, data integrity, memory origin/target/access coverage, and route ownership for all four DMA route combinations.

### 3.4 `dma_subsys_completion_reorder_test`

**Purpose:** Prove that two independent DMA channels may complete out of issue order without incorrect correlation.

**Scenario:** Issues CH0 first and deliberately delays the MEM0-side response. A short CH1 command is issued second and is expected to complete before CH0.

**Checks:** CH1-before-CH0 completion order, per-flow hardware/software tags, independent data results, pending-depth accounting, IRQ behavior, and absence of cross-channel scoreboard aliasing.

### 3.5 `dma_subsys_completion_order_reverse_test`

**Purpose:** Cover the opposite issue/completion-order combination.

**Scenario:** Issues a slow 256-byte CH1 transfer first using a delayed MEM1 path, then issues a fast 4-byte CH0 transfer. CH0 must overtake CH1.

**Checks:** Both order-case directions, concurrent pending depth, correct completion owner/tag association, memory contents, and IRQ state.

### 3.6 `dma_subsys_route_contention_test`

**Purpose:** Verify destination ownership, arbitration, wait accounting, and release under contention.

**Scenario:** CH0 holds one destination with a 1024-byte transfer while CH1 requests the same destination with a 256-byte transfer. A second controlled case creates a short two-cycle wait.

**Checks:** Owner cannot be stolen, waiting request is eventually granted, immediate/short/long wait classes are sampled, payloads remain separate, and the route is released at completion.

## 4. Length, burst, and AXI attribute tests

### 4.1 `dma_subsys_transfer_length_boundary_test`

**Purpose:** Cover software-visible DMA length classes and boundary transitions.

**Scenario:** Executes transfers of 1, 2, 3, 4, 5, 16, 17, 64, 65, 256, and 1024 bytes across both channels and route directions.

**Checks:** Sub-beat behavior, one-beat and burst boundaries, multi-burst splitting, completed length, byte-level reference comparison, and command/intent length bins.

### 4.2 `dma_subsys_axi_burst_shape_test`

**Purpose:** Exercise legal AXI shapes independently of the DMA engine's fixed INCR behavior.

**Scenario:** EXT masters generate:

- FIXED bursts of 1 and 4 beats;
- WRAP bursts of 2, 4, 8, and 16 beats;
- INCR traffic including unaligned external starts, page-boundary windows, and a 256-beat burst;
- 1-, 2-, and 4-byte beats;
- zero and nonzero IDs; and
- zero-strobe and normal writes.

**Checks:** AMD protocol completion, read responses, memory protocol coverpoints, burst-length rules, bytes-per-beat, ID class, page position, strobe class, and 4-KiB legality.

### 4.3 `dma_subsys_toggle_value_sweep_test`

**Purpose:** Increase structural value toggling across tags, lengths, addresses, and response encodings.

**Scenario:**

- Runs legal transfers of 4, 128, 256, 1024, 2048, and 32768 bytes.
- Uses complementary tags `00`, `FF`, `A5`, `5A`, `3C`, and `C3` and patterned addresses.
- Injects read DECERR on MEM0, read SLVERR on MEM1, write SLVERR on MEM0, and write DECERR on MEM1.
- Finishes with a clean transfer to return error and control fields to their normal values.

**Checks:** Correct error mapping for every injected response, legal recovery, payload for successful flows, and rising/falling transitions across a broad value set.

### 4.4 `dma_subsys_legal_extent_test`

**Purpose:** Exercise the maximum legal transfer contained in one configured RAM window.

**Scenario:**

- Transfers the full 65,536-byte RAM0 extent to RAM1 using CH0.
- Transfers the full RAM1 extent back to RAM0 using CH1.
- Follows with 4-byte transfers at complementary `0x5554` and `0xAAA8` offsets.

**Checks:** Length bit 16 reachability, full-window range checking, multi-burst operation, end-to-end byte comparison over the complete target, and return transitions to small lengths and complementary addresses. Length bits 19:17 remain unreachable by configuration.

### 4.5 `dma_subsys_axi_attribute_toggle_test`

**Purpose:** Cover programmable external-master AXI attributes independently from the DMA's fixed attributes.

**Scenario:**

- EXT0 and EXT1 each issue a 16-beat transaction with ID `0xF`, CACHE `0xF`, and PROT `0b111`.
- Each then issues a one-beat transaction with ID `0`, CACHE `0`, and PROT `0`.
- Addresses use complementary `0xAAA8` and `0x5554` patterns on RAM0/RAM1.
- EXT1 also performs a four-beat FIXED read/write on RAM1.

**Checks:** Legal responses and readback, high-to-low transitions on ID/CACHE/PROT fields, both external masters and memory targets, and MEM1 FIXED-burst activation.

### 4.6 `dma_subsys_bus_toggle_closure_test`

**Purpose:** Close remaining reachable bus/address/length toggles without manufacturing illegal crossbar behavior.

**Scenario:**

- Drives complementary mapped AXI-Lite addresses, local invalid offsets that return SLVERR, and top-level unmapped accesses that return DECERR.
- Drives legal external AXI traffic at RAM base and `RAM1+0xFFFC`, one-byte accesses at each final RAM byte, and an EXT1 maximum-length burst.
- Runs DMA transfers with length `0xFFFF`, high legal address `0xFFFC`, low addresses, and invalid maximum length on both channels.
- Applies reset to create falling edges for retained command fields.

**Checks:** AXI-Lite response classes, mapped external write/read data, final-byte legality, maximum legal burst behavior, DMA range-error handling, and address/length rising and falling transitions.

The full-AXI portion intentionally avoids unmapped writes. The imported full AXI crossbar's local decode-miss response path can expose BVALID before upstream AW acceptance, which AMD VIP correctly treats as a protocol fatal. This test therefore targets legal programmable toggles; structurally unreachable high address bits are handled through reviewed exclusions.

## 5. Register and AXI-Lite protocol tests

### 5.1 `dma_subsys_register_access_policy_test`

**Purpose:** Verify the complete software register access contract.

**Scenario:** Exercises mapped RW, RO, and WO registers; full, partial, and zero WSTRB; invalid offsets inside a decoded 4-KiB block; and addresses outside every block.

**Checks:** RW data changes, RO protection, WO semantics, byte-mask effects, OKAY for legal accesses, SLVERR for invalid local offsets, and DECERR for top-level decode misses. This test originally exposed the AXI-Lite crossbar W-before-B timing defect and remains the regression guard for its RTL fix.

### 5.2 `dma_subsys_axil_protocol_timing_test`

**Purpose:** Verify legal independence of AXI-Lite request channels and stability of response channels.

**Scenario:**

- Presents AWVALID before WVALID for a channel write.
- Presents WVALID before AWVALID at the source using AMD VIP's independent-channel mode and explicit delays.
- Repeats a W-before-AW invalid global write and expects SLVERR.
- Holds BREADY low and verifies stable BVALID/BRESP.
- Holds RREADY low and verifies stable RVALID/RRESP/data while reading GLOBAL_VERSION.

**Checks:** Observed VALID presentation order, eventual legal handshakes, response codes, version data, response stability, timeout protection, VIP protocol checks, and project SVA.

The sequence does not require the W handshake to complete before AW. The crossbar legally withholds WREADY until address decode, so requiring data acceptance first would deadlock AMD VIP and the DUT.

### 5.3 `dma_subsys_axil_condition_closure_test`

**Purpose:** Reach legal residual conditions and value transitions in channel/global register blocks and their AXI-Lite integration.

**Scenario:**

- Sweeps writable register data between all ones and all zeros on both channels.
- Sweeps IRQ enable and clear data.
- Writes START/ABORT/CLEAR with byte zero masked by WSTRB and confirms no architectural side effect.
- Issues idle aborts on both channels.
- Drives high and low AWPROT/ARPROT values.
- Checks local invalid offsets for SLVERR and complementary top-level unmapped addresses for DECERR.
- Issues batches of write and read requests to exercise response-hold conditions.
- Exercises CH1 disabled-start and busy-only start behavior.

**Checks:** Response and data correctness, byte-mask semantics, no unintended command, protection-field toggles, pending/hold behavior, disabled/busy error classification, and clean recovery.

## 6. Error, fault, and abort tests

### 6.1 `dma_subsys_descriptor_error_test`

**Purpose:** Cover every primary command-validation rejection.

**Scenario:** Issues commands with zero length, unaligned source, unaligned destination, source outside a legal RAM range, destination outside a legal RAM range, overlapping ranges, disabled channel, and a second start while the channel is busy.

**Checks:** Expected error code, accept/completion/IRQ intent, no unintended memory modification, channel status, counters, and result clear behavior.

### 6.2 `dma_subsys_memory_response_error_test`

**Purpose:** Verify translation of memory-side AXI response errors into DMA completion status.

**Scenario:** Injects read SLVERR from MEM0, read DECERR from MEM1, write SLVERR from MEM1, and write DECERR from MEM0.

**Checks:** Read/write side classification, exact DMA error code, failing flow ownership/tag, completed length expectations, error IRQ and counters, injection cleanup, and subsequent agent usability.

### 6.3 `dma_subsys_status_fault_injection_test`

**Purpose:** Exercise defensive completion/status validation and manager/route fault reporting that legal memory traffic cannot naturally corrupt.

**Scenario:** Injects read-tag mismatch, write-length mismatch, route conflict, manager illegal-state/internal fault, unexpected RD0/RD1/WR0/WR1 statuses, and a route fault, followed by reset cleanup.

**Checks:** Fault source and code, global fault pending/IRQ behavior, completion error mapping, route cleanup, test-hook lifetime, and reset recovery.

Restricted test-control hooks are used only for the corrupted fields or impossible defensive state. Ordinary register programming and traffic still use architectural interfaces.

### 6.4 `dma_subsys_status_fault_expansion_test`

**Purpose:** Add fault permutations not covered by the first status-injection test.

**Scenario:** Corrupts the write-status tag for a CH1 flow and separately places the CH0 manager into its illegal-state recovery path while leaving surrounding command/tag context naturally timed.

**Checks:** Write-side tag-mismatch detection, CH0 manager/internal fault source, fault status and IRQ, recovery, and cleanup of every override.

### 6.5 `dma_subsys_abort_timing_test`

**Purpose:** Distinguish pending and in-flight software abort behavior.

**Scenario:** Aborts CH0 after its transfer is in flight and aborts CH1 while it is pending behind CH0 route ownership.

**Checks:** `DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED` for the in-flight case, `DMA_ERR_ABORT_PENDING` for the waiting case, status/IRQ/counter behavior, route release, and no cross-channel corruption.

### 6.6 `dma_subsys_abort_phase_matrix_test`

**Purpose:** Cover the opposite channel roles and prove recovery after aborts.

**Scenario:**

- Aborts CH1 while in flight.
- Holds CH1 as route owner while CH0 waits, then aborts the pending CH0 request.
- Executes clean post-abort transfers in both channel directions.

**Checks:** Correct abort classification, natural route contention, owner/waiter state, route release, clean future commands, data integrity, and IRQ cleanup. Abort requests use the software-visible CTRL register instead of broad internal force.

## 7. IRQ and reset tests

### 7.1 `dma_subsys_irq_mask_multi_pending_test`

**Purpose:** Verify the distinction between stored pending causes, enable masks, channel IRQs, and global IRQ.

**Scenario:** Creates both-channel done pending, both-channel error pending, error-only visibility, manager fault, multiple simultaneous causes, and masked pending combinations. It changes masks and clears causes in controlled phases.

**Checks:** Pending bits persist while masked, only enabled causes drive IRQ, both-channel encodings are correct, multiple-cause summary works, and clear operations remove only selected causes.

### 7.2 `dma_subsys_irq_status_separation_test`

**Purpose:** Verify independent done, error, and manager-fault storage and byte-strobe-aware clearing.

**Scenario:** Creates done and error together, clears done while preserving error, raises an unexpected-read-status manager fault, attempts a fault clear with byte three masked, then clears with the correct strobe and finally clears the remaining error.

**Checks:** Exact `IRQ_STATUS` done/error/fault/summary fields at each stage, WSTRB masking, enable behavior, and final channel/global IRQ deassertion.

### 7.3 `dma_subsys_reset_recovery_test`

**Purpose:** Verify reset from idle and active operation and prove post-reset reuse.

**Scenario:** Applies reset while idle, applies reset during a 1024-byte active flow, waits for clean route and IRQ recovery, and then executes a 128-byte CH1-to-CH0 transfer.

**Checks:** Command/route/IRQ state clears, VIP and monitors resynchronize, no stale completion is matched, reference RAM policy is preserved, and post-reset data movement succeeds.

### 7.4 `dma_subsys_fsm_reset_arc_test`

**Purpose:** Deterministically cover reset exits from every reachable nonterminal manager state and legal stalled-descriptor abort branches.

**Scenario:** For both channels, applies reset from `ST_VALIDATE`, `ST_WAIT_ROUTE`, `ST_ISSUE_WR_DESC`, `ST_ISSUE_RD_DESC`, `ST_WAIT_STATUS`, and `ST_ERROR_RECOVERY`. It also aborts while write-descriptor READY is held low, aborts while read-descriptor READY is held low and then resets, and creates a CH1 invalid route request.

**Checks:** State entry before reset, clean return to IDLE, route/descriptor hold cleanup, recorded abort status, fault observation, VIP reset requirements, and absence of partial forced transfers.

The test-control interface holds READY low only to keep the manager in a legal backpressured state. The hold is cleared while reset is active; it is not released mid-transfer to manufacture a handshake.

## 8. Counter and tag rollover tests

### 8.1 `dma_subsys_tag_counter_rollover_test`

**Purpose:** Toggle the practical low byte of command/completion/error counters and the internal tag sequence with fast deterministic commands.

**Scenario:** Runs 129 zero-length commands on CH0 and 129 on CH1. It alternates destination channel, software tag (`0x55`/`0xAA`), and complementary full-width source/destination patterns. Every command terminates with `DMA_ERR_LEN_ZERO`. It then reads the per-channel command/done counters and global error counters and expects 129.

**Checks:** Command acceptance and error completion for every command, counter values, tag-sequence progression, and falling transitions after reset.

Because zero-length validation ends before descriptor issue, this test does not by itself toggle descriptor/status tag buses; that gap is handled by the legal tag rollover test.

### 8.2 `dma_subsys_legal_tag_rollover_test`

**Purpose:** Toggle hardware-tag bits on real descriptor and status traffic.

**Scenario:** Executes 65 successful 4-byte transfers on CH0 and 65 on CH1. CH0 moves RAM0 to RAM1; CH1 moves RAM1 to RAM0. Software tags follow the command index and payload/tag values vary. A final 20-cycle reset returns the reached tag lanes low.

**Checks:** Successful data movement and completion correlation for all 130 transfers, accepted-command index 64 raising tag bit 6, descriptor/status tag propagation, both owner lanes, and clean reset.

## 9. Coverage-to-test map

| Coverage objective | Principal tests |
|---|---|
| Environment and VIP bring-up | VIP smoke, VIP manager smoke, env smoke |
| RAL and register prediction | RAL smoke, register access policy |
| Nominal data movement | CH0-to-CH1, CH1-to-CH0, path matrix |
| Completion ordering | completion reorder, completion order reverse |
| Route arbitration | route contention, abort timing/phase matrix |
| Length classes and legal extent | transfer length boundary, legal extent, bus toggle closure |
| AXI burst protocol | AXI burst shape, AXI attribute toggle |
| AXI-Lite timing and conditions | register access policy, AXI-Lite protocol timing, AXI-Lite condition closure |
| Descriptor validation errors | descriptor error |
| Memory response errors | memory response error, toggle value sweep |
| Defensive status/fault logic | status fault injection, status fault expansion, FSM reset arc |
| IRQ combinations and masking | IRQ mask multi-pending, IRQ status separation |
| Reset and FSM arcs | reset recovery, FSM reset arc |
| Counter/tag toggles | tag counter rollover, legal tag rollover |
| Broad structural bus toggles | toggle value sweep, AXI attribute toggle, bus toggle closure |

Together these tests close all 11 functional covergroups and all reachable reviewed FSM/branch goals in the documented baseline.

## 10. Adding another scenario

When adding a test, keep the scenario focused and observable:

1. State the requirement and expected result before writing stimulus.
2. Reuse `dma_subsys_vseq_base` helpers for programming, memory setup, intent, polling, and readback.
3. Prefer public registers and AMD VIP configuration over internal force.
4. Add only the minimum test-control hook required for a defensive path and clear it in all exit paths.
5. Give the scoreboard enough intent to distinguish success, expected error, completion, and IRQ behavior.
6. Add the sequence include, concrete test file, `.f` entry, and maintained regression-list entry together.
7. Run the new test alone, the relevant neighboring tests, and finally the complete maintained regression after adding the test to `regression_tests`.
8. Review coverage object names, not only dashboard percentages, before claiming that the new scenario closed its target.
