# AXI4 DMA Functional Coverage Guide

This guide matches the coverage implemented in:

- `tb/uvm/env/dma_coverage.sv`
- `tb/uvm/agents/dma_outstanding_monitor.sv`

The current implementation contains **7 covergroups, 43 named coverpoints, and 7 crosses**. The 30 assertions and 19 cover properties are reported separately and are not part of the 43 functional coverpoints.

## 1. Summary

| Covergroup | Source | Coverpoints | Crosses | Sampling source |
|---|---|---:|---:|---|
| `axil_cg` | `dma_coverage.sv` | 10 | 2 | Completed AXI4-Lite monitor transactions |
| `descriptor_cg` | `dma_coverage.sv` | 7 | 1 | Shadow descriptor on a successful `SUBMIT[0]=1` write |
| `irq_cg` | `dma_coverage.sv` | 4 | 2 | Every non-reset monitor clock |
| `manager_status_cg` | `dma_coverage.sv` | 11 | 0 | Successful STATUS reads |
| `queue_level_cg` | `dma_coverage.sv` | 4 | 1 | Successful QUEUE_LEVELS reads |
| `completion_cg` | `dma_coverage.sv` | 5 | 0 | Completion TAG/LENGTH/STATUS read sequence |
| `outstanding_cg` | `dma_outstanding_monitor.sv` | 2 | 1 | Every non-reset AXI monitor clock |
| **Total** |  | **43** | **7** |  |

## 2. `axil_cg`

`axil_cg` samples every transaction published by the AXI4-Lite monitor. Its instance name is `dma_axil_access_cov`.

| Coverpoint | Bins and rules |
|---|---|
| `cp_op` | `read`, `write` |
| `cp_addr` | One bin for each of the 14 implemented registers; every other address enters `unmapped = default` |
| `cp_wstrb` | On writes: `full=4'hf`, `partial=1..e`, `_none=0` |
| `cp_staging_write_addr` | On writes to SRC, DST, LENGTH, or TAG: one bin per register |
| `cp_wstrb_pattern` | On staging-register writes: `zero`, four `single_lane[]`, three `adjacent[]`, three `separated[]`, four `triple[]`, and `full` |
| `cp_lane0` | `WSTRB[0]` low/high on writes |
| `cp_lane1` | `WSTRB[1]` low/high on writes |
| `cp_lane2` | `WSTRB[2]` low/high on writes |
| `cp_lane3` | `WSTRB[3]` low/high on writes |
| `cp_resp` | `okay=2'b00`; ignored encodings: `01..11` |

Crosses:

- `op_x_addr = cp_op × cp_addr`
- `wstrb_x_staging_addr = cp_wstrb_pattern × cp_staging_write_addr`

Primary closure tests: `dma_ral_smoke_test`, `dma_wstrb_test`, `dma_access_policy_test`, `dma_ro_write_protection_test`, `dma_command_noop_test`, and `dma_empty_completion_read_test`.

## 3. `descriptor_cg`

A successful AXI4-Lite SUBMIT write triggers sampling. The subscriber reconstructs the staging values from observed bus writes; it does not sample a sequence-side prediction. Its instance name is `dma_descriptor_cov`.

| Coverpoint | Bins |
|---|---|
| `cp_length` | `zero=0`, `sub_beat=1..3`, `one_beat=4`, `short=5..64`, `_medium=65..256`, `long=257..4096`, `very_long=4097..0xfffff` |
| `cp_src_align` | `aligned=00`, `unaligned[]=01..11` |
| `cp_dst_align` | `aligned=00`, `unaligned[]=01..11` |
| `cp_src_cross_4k` | `no`, `yes` |
| `cp_dst_cross_4k` | `no`, `yes` |
| `cp_ranges_overlap` | `separate`, `overlap` |
| `cp_tag` | `zero=00`, `low=01..3f`, `mid=40..bf`, `high=c0..ff` |

Cross: `boundary_matrix = cp_src_cross_4k × cp_dst_cross_4k`.

Primary closure tests: boundary matrix, length sweep, sub-beat/TAG, invalid descriptor, alignment rejection, address-range rejection, and overlap rejection.

## 4. `irq_cg`

`irq_cg` samples the IRQ output, shadow IRQ enable, and the completion-valid value retained from the most recent STATUS read on every non-reset monitor clock. Its instance name is `dma_irq_cov`.

| Coverpoint | Bins |
|---|---|
| `cp_irq_level` | `low`, `high` |
| `cp_irq_transition` | `rise=(0=>1)`, `fall=(1=>0)` |
| `cp_enable` | `disabled`, `enabled` |
| `cp_comp_valid` | `empty`, `nonempty` |

Crosses:

- `enable_x_irq = cp_enable × cp_irq_level`, ignoring `disabled × high`
- `completion_x_irq = cp_comp_valid × cp_irq_level`, ignoring `empty × high`

Primary closure tests: `dma_irq_mode_test`, `dma_ral_smoke_test`, and `dma_queue_saturation_test`.

## 5. `manager_status_cg`

STATUS reads sample bits `[10:0]`. The instance name is `dma_manager_status_cov`.

| Coverpoint | STATUS bit | Meaning |
|---|---:|---|
| `cp_active` | 0 | Active descriptor |
| `cp_req_empty` | 1 | Request FIFO empty |
| `cp_req_full` | 2 | Request FIFO full |
| `cp_submit_ready` | 3 | Submission ready |
| `cp_comp_valid` | 4 | Completion FIFO non-empty |
| `cp_comp_full` | 5 | Completion FIFO full |
| `cp_irq` | 6 | IRQ level |
| `cp_reject_full` | 7 | Full-queue rejection sticky |
| `cp_reject_invalid` | 8 | Invalid-descriptor rejection sticky |
| `cp_status_mismatch` | 9 | `normal=0`; ignored value: `1` (`requires_internal_fault`) |
| `cp_pop_empty` | 10 | Empty-pop sticky |

Except for `cp_status_mismatch`, the one-bit points use automatically generated low/high bins. Queue, invalid-descriptor, empty-pop, IRQ, and RAL scenarios close this group.

## 6. `queue_level_cg`

QUEUE_LEVELS reads sample both FIFO depths. The instance name is `dma_queue_level_cov`.

| Coverpoint | Bins |
|---|---|
| `cp_request_level` | `empty=0`, `one=1`, `mid=2..3`, `full=4`; every other value is `illegal_bins invalid` |
| `cp_completion_level` | `empty=0`, `one=1`, `mid=2..3`, `full=4`; every other value is `illegal_bins invalid` |
| `cp_request_present` | `empty`, `nonempty` |
| `cp_completion_present` | `empty`, `nonempty` |

Cross: `levels_x = cp_request_present × cp_completion_present`.

Primary closure tests: `dma_queue_mid_level_test`, `dma_queue_saturation_test`, and `dma_empty_completion_read_test`.

## 7. `completion_cg`

The subscriber saves COMP_TAG and COMP_LENGTH reads, then combines them with COMP_STATUS when that register is read. The instance name is `dma_completion_cov`.

| Coverpoint | Bins and ignored values |
|---|---|
| `cp_tag` | `zero=00`, `low=01..3f`, `mid=40..bf`, `high=c0..ff` |
| `cp_length` | `short=1..64`, `_medium=65..256`, `long=257..4096`, `very_long=4097..0xfffff`; zero is ignored because zero-length descriptors are rejected before completion |
| `cp_read_error` | `_none=0`, `slverr=4`, `decerr=5`; ignored encodings: `1..3`, `6..f` |
| `cp_write_error` | `_none=0`, `slverr=6`, `decerr=7`; ignored encodings: `1..5`, `8..f` |
| `cp_mismatch` | `_none=000`; ignored values: `001..111` |

Normal transfers, the four error-response tests, and the length/TAG scenarios close the implemented bins.

## 8. `outstanding_cg`

`dma_outstanding_monitor` updates read and write burst counts from AR, RLAST, AW, and B handshakes, then samples on every non-reset monitor clock. Its instance name is `dma_axi_outstanding_cov`.

| Coverpoint | Bins |
|---|---|
| `cp_read` | `zero=0`, `one=1`, `multiple=2..32` |
| `cp_write` | `zero=0`, `one=1`, `multiple=2..32` |

Cross: `read_x_write = cp_read × cp_write`.

`dma_outstanding_test` also checks in `check_phase` that the maximum read and write outstanding depths each reach at least two.

## 9. Baseline Result

All seven functional covergroups report 100% in the merged 28-test baseline.
