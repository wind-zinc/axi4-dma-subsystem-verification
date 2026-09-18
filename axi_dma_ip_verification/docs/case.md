# AXI4 DMA UVM Test Catalogue

`sim/run_regression.sh` currently maintains 28 UVM tests. This catalogue follows the regression array and the checked-in sequence sources.

## 1. Basic and RAL Access

| Test | Primary sequence | Scenario and checks |
|---|---|---|
| `dma_random_smoke_test` | `dma_random_smoke_seq` | Runs one constrained-random legal transfer and checks descriptor acceptance, data movement, completion, counters, and IRQ behavior. |
| `dma_ral_smoke_test` | `dma_ral_smoke_seq` | Programs SRC, DST, LENGTH, TAG, and SUBMIT through the RAL frontdoor, then reads and pops the completion. |
| `dma_wstrb_test` | `dma_wstrb_seq` | Exercises all 16 WSTRB patterns across the four descriptor staging registers and checks byte preservation. |
| `dma_command_noop_test` | `dma_command_noop_seq` | Writes zero data or masked byte lane 0 to SUBMIT, COMP_POP, and sticky clear; verifies that no command pulse occurs. |
| `dma_ro_write_protection_test` | `dma_ro_write_protection_seq` | Attempts writes to all seven read-only registers and confirms that their values do not change. |
| `dma_access_policy_test` | `dma_access_policy_seq` | Checks the CONTROL reset value, verifies that WO command registers read as zero, and confirms that writing STATUS has no effect. |

## 2. Descriptor Validity and Queues

| Test | Primary sequence | Scenario and checks |
|---|---|---|
| `dma_invalid_desc_test` | `dma_invalid_desc_seq` | Separately submits a zero length, an unaligned source address, and an over-width TAG; checks `reject_invalid_sticky` and an unchanged submitted count. |
| `dma_length_sweep_test` | `dma_length_sweep_seq` | Transfers 4, 32, 128, 512, 4096, and 8192 bytes to close the implemented one-beat through very-long length classes. |
| `dma_alignment_reject_test` | `dma_alignment_reject_seq` | Exercises every nonzero source and destination byte offset while `ENABLE_UNALIGNED=0`; verifies rejection without DMA activity. |
| `dma_address_range_reject_test` | `dma_address_range_reject_seq` | Separately overflows SRC, DST, and LENGTH beyond their configured widths; checks rejection and count stability. |
| `dma_overlap_reject_test` | `dma_overlap_reject_seq` | Covers both overlap directions, identical ranges, source/destination wraparound, and one legal adjacent-range case. |
| `dma_queue_saturation_test` | `dma_queue_saturation_seq` | Accepts five requests while one is active, fills the four-entry request FIFO, rejects a sixth request, fills the four-entry completion FIFO, and drains all completions in order. |
| `dma_queue_mid_level_test` | `dma_queue_mid_level_seq` | Holds the active transfer and submits additional requests to observe deterministic mid-level request occupancy before draining. |

## 3. AXI Transfers, Errors, and Backpressure

| Test | Primary sequence | Scenario and checks |
|---|---|---|
| `dma_boundary_matrix_test` | `dma_boundary_matrix_seq` | Covers neither/source/destination/both-side 4-KiB crossings and verifies legal burst splitting. |
| `dma_sub_beat_tag_test` | `dma_sub_beat_tag_seq` | Runs legal 1-, 2-, and 3-byte transfers with boundary TAG values; checks TKEEP, final beat, completion TAG, and length. |
| `dma_read_slverr_test` | `dma_error_response_seq(DMA_READ_SLVERR)` | Injects a source-address-matched read SLVERR and checks completion encoding. |
| `dma_read_decerr_test` | `dma_error_response_seq(DMA_READ_DECERR)` | Injects a source-address-matched read DECERR and checks completion encoding. |
| `dma_write_slverr_test` | `dma_error_response_seq(DMA_WRITE_SLVERR)` | Injects a destination-address-matched write SLVERR and checks completion encoding. |
| `dma_write_decerr_test` | `dma_error_response_seq(DMA_WRITE_DECERR)` | Injects a destination-address-matched write DECERR and checks completion encoding. |
| `dma_axi_backpressure_test` | `dma_axi_backpressure_seq` | Independently stalls AW, W, B, AR, and R; checks stable payloads, AXIS pressure, forward progress, and data integrity. |
| `dma_outstanding_test` | `dma_outstanding_seq` | Enables queued address handling and delayed responses so at least two read and two write bursts are simultaneously outstanding. |
| `dma_write_engine_corner_test` | `dma_write_engine_corner_seq` | Exercises partial beats, a 4-KiB split, a long transfer, delayed B responses, and simulation-only write-engine recovery activation. |
| `dma_toggle_stress_test` | `dma_toggle_stress_seq` | Uses eight diverse address, length, TAG, and queue combinations to expand meaningful structural toggles. |

## 4. Completion, IRQ, Reset, and SVA

| Test | Primary sequence | Scenario and checks |
|---|---|---|
| `dma_irq_mode_test` | `dma_irq_mode_seq` | Verifies completion behavior with IRQ disabled and enabled, level hold while completion is pending, and deassertion after the final pop. |
| `dma_pop_empty_test` | `dma_pop_empty_seq` | Pops an empty Completion FIFO, checks `pop_empty_sticky`, and verifies software clear behavior. |
| `dma_empty_completion_read_test` | `dma_empty_completion_read_seq` | Reads empty COMP_TAG, COMP_LENGTH, and COMP_STATUS and expects zero without an implicit pop. |
| `dma_reset_recovery_test` | `dma_reset_recovery_seq` | Resets while an 8192-byte descriptor is active with AR stalled, checks reset state and counters, then completes a clean 64-byte transfer. |
| `dma_sva_activation_test` | `dma_sva_activation_seq` | Activates AXI-Lite request/response stalls, descriptor stalls, PROT toggles, and manager reset arcs; checks all targeted assertion cover properties. |

## 5. Running the Maintained Regression

```bash
cd axi_dma_ip_verification/sim
BASE_SEED=1000 ./run_regression.sh
```

The script compiles once, runs the tests in the maintained array with incrementing seeds, merges coverage, and invokes URG with the strict exclusion file when present.
