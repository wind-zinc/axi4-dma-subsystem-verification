# AXI4 DMA RAL Mapping

This document describes `tb/uvm/ral/dma_reg_model.sv` and its mapping to `rtl/dma_desc_manager.v`.

## 1. File Relationships

| File | Responsibility |
|---|---|
| `tb/uvm/ral/dma_reg_model.sv` | Defines fields, 14 registers, and the 4-byte little-endian frontdoor map. |
| `tb/uvm/ral/dma_axil_reg_adapter.sv` | Converts between `uvm_reg_bus_op` and `axil_item`. |
| `tb/uvm/sequences/dma_ral_base_seq.sv` | Provides shared RAL access, descriptor submission, completion read, and completion-pop helpers. |
| `tb/uvm/agents/axil/axil_monitor.sv` | Publishes completed AXI4-Lite transactions. |
| `tb/uvm/env/dma_env.sv` | Connects the `uvm_reg_predictor` so observed bus traffic updates the mirror. |

Automatic RAL prediction is disabled. Mirror state follows transactions observed on the AXI4-Lite bus.

## 2. Register Map

All registers are 32 bits wide and use a 4-byte address stride.

| RAL handle | RTL address | Offset | Access | Reset | Description |
|---|---|---:|---|---:|---|
| `ral.control` | `REG_CONTROL` | `0x00` | RW / WO | `0x0000_0000` | Bit 0 is `irq_enable`; bit 1 is the `clear_sticky` write-one pulse. |
| `ral.status` | `REG_STATUS` | `0x04` | RO | Dynamic | DMA, FIFO, IRQ, and sticky status. |
| `ral.src_addr` | `REG_SRC_ADDR` | `0x08` | RW | `0x0000_0000` | Staged descriptor source byte address. |
| `ral.dst_addr` | `REG_DST_ADDR` | `0x0C` | RW | `0x0000_0000` | Staged descriptor destination byte address. |
| `ral.length` | `REG_LENGTH` | `0x10` | RW | `0x0000_0000` | Staged descriptor byte length. |
| `ral.tag` | `REG_TAG` | `0x14` | RW | `0x0000_0000` | Staged software tag. |
| `ral.submit` | `REG_SUBMIT` | `0x18` | WO | `0x0000_0000` | Writing bit 0 as one emits one submit pulse. |
| `ral.comp_tag` | `REG_COMP_TAG` | `0x1C` | RO | Dynamic | Completion-head TAG; reads zero when empty. |
| `ral.comp_length` | `REG_COMP_LENGTH` | `0x20` | RO | Dynamic | Completion-head actual write length; reads zero when empty. |
| `ral.comp_status` | `REG_COMP_STATUS` | `0x24` | RO | Dynamic | Completion-head error codes and consistency flags; reads zero when empty. |
| `ral.comp_pop` | `REG_COMP_POP` | `0x28` | WO | `0x0000_0000` | Writing bit 0 as one pops one completion. |
| `ral.queue_levels` | `REG_QUEUE_LEVELS` | `0x2C` | RO | Dynamic | Request level in `[15:0]`; completion level in `[31:16]`. |
| `ral.submitted_count` | `REG_SUBMITTED_COUNT` | `0x30` | RO | `0x0000_0000` | Number of descriptors accepted. |
| `ral.completed_count` | `REG_COMPLETED_COUNT` | `0x34` | RO | `0x0000_0000` | Number of completion records committed. |

## 3. `CONTROL` Fields

| Bit | RAL field | Access | Behavior |
|---:|---|---|---|
| 0 | `irq_enable` | RW | Updates only when `WSTRB[0]` is active. |
| 1 | `clear_sticky` | WO | `WSTRB[0] && WDATA[1]` creates a one-cycle clear event; the value is not stored. |

`SUBMIT.command` and `COMP_POP.command` are also bit-0 WO write-one pulse fields. Writing zero or masking byte lane 0 creates no operation.

## 4. `STATUS` Fields

| Bit | RAL field | Meaning |
|---:|---|---|
| 0 | `active` | A descriptor is currently active. |
| 1 | `req_empty` | The Request FIFO is empty. |
| 2 | `req_full` | The Request FIFO is full. |
| 3 | `submit_ready` | The manager can accept another valid descriptor. |
| 4 | `comp_valid` | The Completion FIFO is non-empty. |
| 5 | `comp_full` | The Completion FIFO is full. |
| 6 | `irq` | Current IRQ output level. |
| 7 | `reject_full_sticky` | A submission was rejected because the Request FIFO was full. |
| 8 | `reject_invalid_sticky` | An invalid descriptor was rejected. |
| 9 | `status_mismatch_sticky` | A returned TAG or length mismatch was detected. |
| 10 | `pop_empty_sticky` | Software attempted to pop an empty Completion FIFO. |

Bits `[31:11]` read as zero. `CONTROL.clear_sticky` clears bits `[10:7]` together.

## 5. `COMP_STATUS` Fields

| Bits | RAL field | Meaning |
|---|---|---|
| `[3:0]` | `read_error` | DMA read-status error code. |
| `[7:4]` | `write_error` | DMA write-status error code. |
| 8 | `read_tag_mismatch` | Returned read TAG differs from the active descriptor TAG. |
| 9 | `write_tag_mismatch` | Returned write TAG differs from the active descriptor TAG. |
| 10 | `length_mismatch` | Returned write length differs from the requested length. |

Bits `[31:11]` read as zero.

## 6. Access and Prediction Rules

- `SRC_ADDR`, `DST_ADDR`, `LENGTH`, and `TAG` support byte-granular WSTRB updates.
- Writes to RO registers complete normally on the bus but do not change architectural state.
- Reads of WO command registers return zero.
- Unimplemented addresses read as zero; writes have no architectural side effect.
- Descriptor width and validity checks occur when SUBMIT is written. RAL deliberately preserves all 32 staging bits so tests can verify rejection of over-width values.
- Reading completion-head fields does not pop the queue. Software must separately write `COMP_POP[0]=1`.
