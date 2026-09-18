# AXI4 DMA IP RTL Specification

This specification describes the modules under `rtl/`.

## 1. Scope

`axi_dma_subsystem` is a single-engine, descriptor-driven AXI4 memory-to-memory DMA integration. Software programs a descriptor through AXI4-Lite. The descriptor manager validates and queues the request, the DMA engine moves the byte stream through an internal AXI4-Stream FIFO, and software receives an in-order completion record and optional level-sensitive interrupt.

The checked-in testbench configuration uses:

| Item | Value |
|---|---:|
| AXI4-Lite address/data width | 8 / 32 bits |
| AXI4 address/data/ID width | 16 / 32 / 8 bits |
| Maximum AXI burst | 16 beats |
| Descriptor length/tag width | 20 / 8 bits |
| AXI4-Stream data width | 32 bits |
| Stream FIFO depth | 16 entries |
| Request/completion FIFO depth | 4 / 4 entries |
| `ENABLE_UNALIGNED` | `0` |
| `ENABLE_SG` | `0` |

## 2. Module Hierarchy

```text
axi_dma_subsystem
├── dma_desc_manager
│   ├── axil_reg_if
│   │   ├── axil_reg_if_rd
│   │   └── axil_reg_if_wr
│   ├── request_fifo: desc_fifo
│   └── completion_fifo: desc_fifo
├── axis_fifo
└── axi_dma
    ├── axi_dma_rd
    └── axi_dma_wr
```

Project-owned integration RTL is located directly under `rtl/`. `rtl/vendor/verilog_axi/` contains imported Alex Forencich `verilog-axi` DMA and AXI-Lite interface RTL. The archive does not record an exact upstream revision, so no specific vendor commit is claimed.

## 3. External Interfaces

| Interface | Direction | Purpose |
|---|---|---|
| `clk` | Input | Common module clock |
| `rst` | Input | Active-high synchronous reset |
| `s_axil_*` | Slave input/output | Descriptor staging, commands, status, queue, completion, and counters |
| `m_axi_*` | Master input/output | AXI4 source reads and destination writes |
| `irq` | Output | High while IRQ is enabled and the Completion FIFO is non-empty |

The AXI4 master exposes the AW, W, B, AR, and R channels. The AXI4-Lite slave exposes independent AW/W/B and AR/R channels.

## 4. Data and Control Flow

```text
AXI4-Lite descriptor registers
    -> validation and Request FIFO
    -> write descriptor handshake
    -> read descriptor handshake
    -> axi_dma_rd
    -> internal AXI4-Stream
    -> axis_fifo
    -> axi_dma_wr
    -> read/write status correlation
    -> Completion FIFO and IRQ
```

The manager issues the write descriptor before the read descriptor so the write engine is prepared before source data can arrive. That ordering does not require AXI write completion before AXI read completion; the read and write datapaths run concurrently after descriptor issue.

Only one descriptor executes at a time. Later accepted requests remain in the four-entry Request FIFO and complete in submission order.

## 5. `axi_dma_subsystem`

`axi_dma_subsystem` integrates the control plane, descriptor manager, DMA engine, stream FIFO, and interrupt output. It connects the DMA read-data stream to the DMA write-data stream through `axis_fifo`; the stream is not exposed at the top-level boundary.

The selected integration ties the vendor DMA write-abort input low. Scatter-gather is disabled. Unaligned address shifting is disabled, although aligned transfers with a non-word-multiple length remain legal.

## 6. `dma_desc_manager`

`dma_desc_manager` owns the register file, validation policy, request/completion queues, descriptor dispatch, status correlation, counters, sticky status, and IRQ equation.

### 6.1 State Machine

```text
IDLE
  -> SEND_WRITE
  -> SEND_READ
  -> WAIT_STATUS
  -> PUSH_COMPLETION
  -> IDLE
```

- `IDLE` selects the next queued request when completion space is available.
- `SEND_WRITE` holds the write descriptor stable until `write_desc_ready` handshakes.
- `SEND_READ` holds the read descriptor stable until `read_desc_ready` handshakes.
- `WAIT_STATUS` independently captures read and write status until both are available.
- `PUSH_COMPLETION` holds the assembled completion until the Completion FIFO accepts it.

### 6.2 Descriptor Packing

The staging registers retain 32-bit software values. A valid submission is packed as:

```text
{src_addr[AXI_ADDR_WIDTH-1:0],
 dst_addr[AXI_ADDR_WIDTH-1:0],
 length[LEN_WIDTH-1:0],
 tag[TAG_WIDTH-1:0]}
```

The packed width is:

```text
DESC_WIDTH = 2*AXI_ADDR_WIDTH + LEN_WIDTH + TAG_WIDTH
```

### 6.3 Admission Rules

A descriptor is accepted only when all of the following are true:

1. Length is nonzero.
2. Bits above `AXI_ADDR_WIDTH`, `LEN_WIDTH`, and `TAG_WIDTH` are zero in the staging registers.
3. Source and destination addresses meet the data-width alignment requirement when `ENABLE_UNALIGNED=0`.
4. The half-open source and destination ranges `[address, address+length)` fit in the configured AXI address space without wraparound.
5. Source and destination ranges do not overlap.
6. The Request FIFO can accept another entry.

Invalid descriptors set `reject_invalid_sticky`. A legal descriptor presented while the Request FIFO is full sets `reject_full_sticky`. Only accepted descriptors increment `submitted_count`.

### 6.4 Completion Assembly

After both DMA status channels complete, the manager records:

- the submitted software TAG;
- the actual write length;
- the read error code;
- the write error code;
- read-TAG mismatch;
- write-TAG mismatch; and
- write-length mismatch.

The completion is committed only when the Completion FIFO accepts it. That commit increments `completed_count`. A detected mismatch also sets `status_mismatch_sticky`.

## 7. Register Map

All registers are 32 bits wide.

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x00` | `CONTROL` | RW / WO | Bit 0: IRQ enable. Bit 1: write-one sticky clear pulse. |
| `0x04` | `STATUS` | RO | Active, FIFO, IRQ, and sticky status. |
| `0x08` | `SRC_ADDR` | RW | Staged source byte address. |
| `0x0C` | `DST_ADDR` | RW | Staged destination byte address. |
| `0x10` | `LENGTH` | RW | Staged byte length. |
| `0x14` | `TAG` | RW | Staged software tag. |
| `0x18` | `SUBMIT` | WO | Bit 0 writes one descriptor-submission pulse. |
| `0x1C` | `COMP_TAG` | RO | Completion-head TAG; zero when empty. |
| `0x20` | `COMP_LENGTH` | RO | Completion-head actual write length; zero when empty. |
| `0x24` | `COMP_STATUS` | RO | Completion-head error and mismatch fields; zero when empty. |
| `0x28` | `COMP_POP` | WO | Bit 0 writes one completion-pop pulse. |
| `0x2C` | `QUEUE_LEVELS` | RO | Request level `[15:0]`, completion level `[31:16]`. |
| `0x30` | `SUBMITTED_COUNT` | RO | Accepted descriptor count. |
| `0x34` | `COMPLETED_COUNT` | RO | Committed completion count. |

### 7.1 `STATUS[10:0]`

| Bit | Name | Meaning |
|---:|---|---|
| 0 | `ACTIVE` | A descriptor is active. |
| 1 | `REQ_EMPTY` | Request FIFO empty. |
| 2 | `REQ_FULL` | Request FIFO full. |
| 3 | `SUBMIT_READY` | A valid descriptor can be accepted. |
| 4 | `COMP_VALID` | Completion FIFO non-empty. |
| 5 | `COMP_FULL` | Completion FIFO full. |
| 6 | `IRQ` | Current IRQ level. |
| 7 | `REJECT_FULL_STICKY` | A full-queue rejection occurred. |
| 8 | `REJECT_INVALID_STICKY` | An invalid descriptor was rejected. |
| 9 | `STATUS_MISMATCH_STICKY` | A returned TAG or length mismatch occurred. |
| 10 | `POP_EMPTY_STICKY` | Software popped an empty Completion FIFO. |

### 7.2 `COMP_STATUS[10:0]`

| Bits | Meaning |
|---|---|
| `[3:0]` | Read error code |
| `[7:4]` | Write error code |
| 8 | Read TAG mismatch |
| 9 | Write TAG mismatch |
| 10 | Write length mismatch |

Reading completion fields does not pop the queue. Software must read the head fields and then write `COMP_POP[0]=1`.

### 7.3 Write Strobes and Unsupported Accesses

- `SRC_ADDR`, `DST_ADDR`, `LENGTH`, and `TAG` update only the byte lanes selected by WSTRB.
- `CONTROL`, `SUBMIT`, and `COMP_POP` command behavior requires byte lane 0.
- Writes to RO locations do not change architectural state.
- Reads of WO locations return zero.
- Unimplemented reads return zero and unimplemented writes have no architectural side effect.

## 8. Interrupt Behavior

IRQ is level-sensitive:

```text
irq = irq_enable && !completion_fifo_empty
```

With IRQ disabled, pending completions do not assert IRQ. With IRQ enabled, IRQ stays high until software pops the final completion.

## 9. `desc_fifo`

`desc_fifo` is a synchronous single-clock FIFO instantiated once for requests and once for completions.

| Signal | Direction | Meaning |
|---|---|---|
| `s_data` | Input | Entry to enqueue |
| `s_valid` | Input | Enqueue request |
| `s_ready` | Output | FIFO can accept an entry |
| `m_data` | Output | Head entry |
| `m_valid` | Output | Head entry is valid |
| `m_ready` | Input | Dequeue request |
| `level` | Output | Current occupancy |

When full, the FIFO does not accept a new push on the same cycle as a pop; this can create a one-cycle throughput bubble.

## 10. `axis_fifo`

`axis_fifo` buffers the internal stream between `axi_dma_rd` and `axi_dma_wr`. It stores DATA, KEEP, LAST, ID, DEST, and USER and propagates backpressure through standard TVALID/TREADY behavior.

## 11. Vendor DMA Modules

### 11.1 `axi_dma`

`axi_dma` integrates `axi_dma_rd` and `axi_dma_wr`. It accepts read and write descriptors, exposes read/write descriptor status, connects the internal AXI4-Stream datapath, and drives one AXI4 master interface.

### 11.2 `axi_dma_rd`

`axi_dma_rd` accepts a source address, byte length, and TAG. It splits INCR read bursts according to the maximum burst setting, remaining length, alignment, and the AXI 4-KiB boundary. Read data leaves through AXI4-Stream; terminal status returns the TAG and read error code.

### 11.3 `axi_dma_wr`

`axi_dma_wr` accepts a destination address, byte length, and TAG plus the input AXI4-Stream. It creates legal INCR write bursts, calculates WSTRB for partial final beats, handles write responses, and returns actual length, TAG, and write error status.

## 12. AXI4-Lite Adapter Modules

`axil_reg_if` combines `axil_reg_if_rd` and `axil_reg_if_wr` and converts AXI4-Lite channels into the manager's simple register interface.

- `axil_reg_if_rd` accepts AR, issues a register read request, and holds RDATA/RRESP stable until RREADY.
- `axil_reg_if_wr` accepts AW and W independently, combines them into one register write, and holds BRESP stable until BREADY.
- The current manager uses zero wait and immediate acknowledge on the simple register side.

## 13. Reset Behavior

Synchronous reset clears descriptor-manager state, request and completion FIFOs, staging registers, counters, sticky status, IRQ enable, and any partially captured DMA status. The selected vendor engines and stream FIFO are reset through the same top-level reset. A new descriptor may be submitted after reset release.

The verification environment explicitly checks reset during an active descriptor and reset arcs from stalled descriptor issue states.
