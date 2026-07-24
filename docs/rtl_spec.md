# RTL

通过 AXI4-Lite 从机接口接收软件配置的 DMA 描述符，由描述符管理模块完成合法性检查和排队；  
随后驱动 AXI DMA 主机通过 AXI4 总线将数据从源地址搬运到目的地址，并通过完成队列和中断向软件报告执行结果。

## 层次关系

```text
axi_dma_subsystem
├── dma_desc_manager
│   ├── axil_reg_if
│   │   ├── axil_reg_if_rd
│   │   └── axil_reg_if_wr
│   ├── request_fifo
│   └── completion_fifo
├── axis_fifo
└── axi_dma
    ├── axi_dma_rd
    └── axi_dma_wr
```

---

## vendor/

下载源：alexforencich

## axi_dma

主文件，AXI DMA 顶层。

作用：实现完整的 AXI DMA 引擎，例化 `axi_dma_rd` 和 `axi_dma_wr` 两个子模块，作为 vendor DMA 核的顶层包装。

输入格式：

- 读写描述符通过 AXIS 流输入。
- 写数据流通过 AXIS 输入。
- AXI4 读数据通道和写响应通道由外部 AXI 从设备返回。

输出格式：

- 读数据流通过 AXIS 输出。
- 读写描述符状态通过 AXIS 输出。
- 通过 AXI4 主控接口输出读写地址、写数据及相关控制信号。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axis_read_desc_*` | 输入 | AXIS 读描述符接口 | 输入源地址、长度、标签等读任务信息 |
| `m_axis_read_desc_status_*` | 输出 | AXIS 读描述符状态接口 | 返回读描述符标签、错误码和有效信号 |
| `m_axis_read_data_*` | 输出 | AXIS 读数据接口 | 输出从 AXI4 总线读取的数据 |
| `s_axis_write_desc_*` | 输入 | AXIS 写描述符接口 | 输入目的地址、长度、标签等写任务信息 |
| `m_axis_write_desc_status_*` | 输出 | AXIS 写描述符状态接口 | 返回写完成长度、标签、错误码及其他状态 |
| `s_axis_write_data_*` | 输入 | AXIS 写数据接口 | 输入需要写入 AXI4 总线的数据流 |
| `m_axi_ar*` | 输出 | AXI4 读地址通道 | 向外部 AXI 从设备发起读突发 |
| `m_axi_r*` | 输入 | AXI4 读数据通道 | 接收外部 AXI 从设备返回的读数据和响应 |
| `m_axi_aw*` | 输出 | AXI4 写地址通道 | 向外部 AXI 从设备发起写突发 |
| `m_axi_w*` | 输出 | AXI4 写数据通道 | 输出写数据、字节使能和突发结束信息 |
| `m_axi_b*` | 输入 | AXI4 写响应通道 | 接收外部 AXI 从设备返回的写响应 |
| `read_enable` | 输入 | 读通道使能 | 控制读 DMA 子模块是否允许接收任务 |
| `write_enable` | 输入 | 写通道使能 | 控制写 DMA 子模块是否允许接收任务 |
| `write_abort` | 输入 | 写操作中止控制 | 请求中止当前写操作 |

`write_abort`为vendor DMA预留输入，因源仓库未实现且现已停止维护，故当前版本固定为0，即不支持DMA中止功能。

---

## axi_dma_rd

根据描述符从 AXI 总线读取数据，根据 4 KB 边界、最大 burst 长度、剩余传输长度和地址偏移自动拆分 AXI burst；读取的数据通过 AXIS 输出，并在任务结束后报告错误码。
AXI burst不得跨越4KB边界。DMA根据当前地址、剩余长度和最大burst长度自动拆分读写burst。源地址和目的地址分别独立计算边界拆分。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axis_read_desc_*` | 输入 | AXIS 读描述符接口 | 接收读地址、长度和标签 |
| `m_axis_read_desc_status_*` | 输出 | AXIS 读状态接口 | 返回任务标签、错误码和完成状态 |
| `m_axis_read_data_*` | 输出 | AXIS 读数据接口 | 输出从 AXI4 总线读取的数据 |
| `m_axi_ar*` | 输出 | AXI4 读地址通道 | 产生 AXI4 读地址和 burst 控制信号 |
| `m_axi_r*` | 输入 | AXI4 读数据通道 | 接收 AXI4 读数据、响应和 `rlast` |
| `enable` | 输入 | 模块使能 | 控制模块是否接受新的读描述符 |

---

## axi_dma_wr

接收 AXIS 写数据流，通过 AXI 总线写入数据；根据 4 KB 边界、最大 burst 长度、剩余传输长度和地址偏移自动拆分burst，处理数据对齐，并在任务结束后发送错误码。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axis_write_desc_*` | 输入 | AXIS 写描述符接口 | 接收写地址、长度和标签 |
| `m_axis_write_desc_status_*` | 输出 | AXIS 写状态接口 | 返回写完成长度、标签、错误码及其他状态 |
| `s_axis_write_data_*` | 输入 | AXIS 写数据接口 | 接收待写入 AXI4 总线的数据流 |
| `m_axi_aw*` | 输出 | AXI4 写地址通道 | 产生 AXI4 写地址和 burst 控制信号 |
| `m_axi_w*` | 输出 | AXI4 写数据通道 | 输出写数据、`wstrb` 和 `wlast` |
| `m_axi_b*` | 输入 | AXI4 写响应通道 | 接收 AXI4 写响应 |
| `enable` | 输入 | 模块使能 | 控制模块是否接受新的写描述符 |
| `abort` | 输入 | 写操作中止控制 | 请求中止当前写操作 |

---

## axil_reg_if

转换器：AXI4-Lite → 简单寄存器接口。

内部例化 `axil_reg_if_rd` 和 `axil_reg_if_wr`，分别处理 AXI4-Lite 读通道和写通道。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axil_aw*` | 输入 | AXI4-Lite 写地址通道 | 接收软件写地址 |
| `s_axil_w*` | 输入 | AXI4-Lite 写数据通道 | 接收软件写数据和字节使能 |
| `s_axil_b*` | 输出 | AXI4-Lite 写响应通道 | 返回写访问结果 |
| `s_axil_ar*` | 输入 | AXI4-Lite 读地址通道 | 接收软件读地址 |
| `s_axil_r*` | 输出 | AXI4-Lite 读数据通道 | 返回寄存器读数据和响应 |
| `reg_wr_*` | 输出/输入 | 简单寄存器写接口 | 输出写地址、写数据、字节使能和写使能；接收等待与确认 |
| `reg_rd_*` | 输出/输入 | 简单寄存器读接口 | 输出读地址和读使能；接收读数据、等待与确认 |

---

## axil_reg_if_rd

AXI4-Lite 读通道 → 简单寄存器读接口。

AXI4-Lite 输入读地址，模块输出对寄存器访问的地址和使能；寄存器逻辑返回数据后，模块通过 AXI4-Lite R 通道输出读数据。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axil_araddr` | 输入 | AXI4-Lite 读地址 | 软件访问的寄存器地址 |
| `s_axil_arprot` | 输入 | AXI4-Lite 读保护属性 | 当前设计通常不使用该字段 |
| `s_axil_arvalid` | 输入 | AXI4-Lite 读地址有效 | 与 `s_axil_arready` 握手 |
| `s_axil_arready` | 输出 | AXI4-Lite 读地址就绪 | 表示可以接收读地址 |
| `s_axil_rdata` | 输出 | AXI4-Lite 读数据 | 返回寄存器读数据 |
| `s_axil_rresp` | 输出 | AXI4-Lite 读响应 | 返回读访问响应 |
| `s_axil_rvalid` | 输出 | AXI4-Lite 读数据有效 | 与 `s_axil_rready` 握手 |
| `s_axil_rready` | 输入 | AXI4-Lite 读数据就绪 | 软件侧接收读数据 |
| `reg_rd_addr` | 输出 | 寄存器读地址 | 传递给内部寄存器逻辑 |
| `reg_rd_en` | 输出 | 寄存器读使能 | 请求寄存器逻辑执行读操作 |
| `reg_rd_data` | 输入 | 寄存器读数据 | 内部寄存器逻辑返回的数据 |
| `reg_rd_wait` | 输入 | 寄存器读等待 | 表示当前读请求需要等待 |
| `reg_rd_ack` | 输入 | 寄存器读确认 | 表示当前寄存器读请求完成 |

---

## axil_reg_if_wr

AXI4-Lite 输入写地址和写数据，输出寄存器端写地址、写数据、字节使能和写使能。

模块允许 AW 和 W 通道独立到达，在两者都有效后组合成一次内部寄存器写请求。寄存器逻辑确认后，模块通过 AXI4-Lite B 通道输出写响应。本工程中寄存器写请求采用零等待、立即确认方式。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axil_awaddr` | 输入 | AXI4-Lite 写地址 | 软件访问的寄存器地址 |
| `s_axil_awprot` | 输入 | AXI4-Lite 写保护属性 | 当前设计通常不使用该字段 |
| `s_axil_awvalid` | 输入 | AXI4-Lite 写地址有效 | 与 `s_axil_awready` 握手 |
| `s_axil_awready` | 输出 | AXI4-Lite 写地址就绪 | 表示可以接收写地址 |
| `s_axil_wdata` | 输入 | AXI4-Lite 写数据 | 软件写入的寄存器数据 |
| `s_axil_wstrb` | 输入 | AXI4-Lite 写字节使能 | 控制哪些字节有效 |
| `s_axil_wvalid` | 输入 | AXI4-Lite 写数据有效 | 与 `s_axil_wready` 握手 |
| `s_axil_wready` | 输出 | AXI4-Lite 写数据就绪 | 表示可以接收写数据 |
| `s_axil_bresp` | 输出 | AXI4-Lite 写响应 | 返回写访问结果 |
| `s_axil_bvalid` | 输出 | AXI4-Lite 写响应有效 | 与 `s_axil_bready` 握手 |
| `s_axil_bready` | 输入 | AXI4-Lite 写响应就绪 | 软件侧接收写响应 |
| `reg_wr_addr` | 输出 | 寄存器写地址 | 传递给内部寄存器逻辑 |
| `reg_wr_data` | 输出 | 寄存器写数据 | 传递给内部寄存器逻辑 |
| `reg_wr_strb` | 输出 | 寄存器写字节使能 | 对应 AXI4-Lite `wstrb` |
| `reg_wr_en` | 输出 | 寄存器写使能 | 请求寄存器逻辑执行写操作 |
| `reg_wr_wait` | 输入 | 寄存器写等待 | 本工程固定为 0 |
| `reg_wr_ack` | 输入 | 寄存器写确认 | 本工程由 `reg_wr_en` 立即确认 |

---

## 配置模块及其他模块

## desc_fifo

通用单时钟 FIFO，用于存储描述符请求或完成记录。该模块在 `dma_desc_manager` 中例化两次，分别作为 Request FIFO 和 Completion FIFO。

当 FIFO 处于满状态时，即使同周期发生 pop，也不能在该周期继续接受 push，因此可能产生一个周期的吞吐空泡。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_data` | 输入 | FIFO 写入数据 | 写入请求描述符或完成记录 |
| `s_valid` | 输入 | FIFO 写入有效 | 与 `s_ready` 握手 |
| `s_ready` | 输出 | FIFO 写入就绪 | FIFO 未满时允许写入 |
| `m_data` | 输出 | FIFO 读出数据 | 输出队首数据 |
| `m_valid` | 输出 | FIFO 读出有效 | FIFO 非空时有效 |
| `m_ready` | 输入 | FIFO 读出就绪 | 与 `m_valid` 握手后弹出队首 |
| `level` | 输出 | FIFO 当前深度 | 表示当前已存储的数据条目数 |

---

## axis_fifo

AXIS 数据 FIFO，连接 AXI DMA 内部读写路径，是 AXI DMA 读路径与写路径之间的数据缓冲和反压解耦单元。

连接关系：

```text
axi_dma_rd 的 AXIS 输出
          ↓
       axis_fifo
          ↓
axi_dma_wr 的 AXIS 输入
```

FIFO 保存 `tdata`、`tkeep`、`tlast`、`tid`、`tdest` 和 `tuser` 等 AXIS sideband 信号。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axis_tdata` | 输入 | AXIS 输入数据 | 来自 `axi_dma_rd` |
| `s_axis_tkeep` | 输入 | AXIS 输入字节有效 | 标记每个字节是否有效 |
| `s_axis_tvalid` | 输入 | AXIS 输入有效 | 与 `s_axis_tready` 握手 |
| `s_axis_tready` | 输出 | AXIS 输入就绪 | FIFO 可接收数据时有效 |
| `s_axis_tlast` | 输入 | AXIS 输入包结束 | 标记一次数据流的末拍 |
| `s_axis_tid` | 输入 | AXIS 输入 ID | 透传保存 |
| `s_axis_tdest` | 输入 | AXIS 输入目标字段 | 透传保存 |
| `s_axis_tuser` | 输入 | AXIS 输入用户字段 | 透传保存 |
| `m_axis_tdata` | 输出 | AXIS 输出数据 | 发送给 `axi_dma_wr` |
| `m_axis_tkeep` | 输出 | AXIS 输出字节有效 | 从 FIFO 中恢复 |
| `m_axis_tvalid` | 输出 | AXIS 输出有效 | 与 `m_axis_tready` 握手 |
| `m_axis_tready` | 输入 | AXIS 输出就绪 | 来自 `axi_dma_wr` |
| `m_axis_tlast` | 输出 | AXIS 输出包结束 | 从 FIFO 中恢复 |
| `m_axis_tid` | 输出 | AXIS 输出 ID | 透传输出 |
| `m_axis_tdest` | 输出 | AXIS 输出目标字段 | 透传输出 |
| `m_axis_tuser` | 输出 | AXIS 输出用户字段 | 透传输出 |

---

## axi_dma_subsystem

集成顶层。在 `clk`、`rst` 和 `irq` 外，提供 AXI4-Lite 从机接口和 AXI4 主机接口。

该模块集成：

- AXI4-Lite 控制面；
- 描述符合法性检查；
- Request FIFO；
- AXI DMA 引擎；
- AXIS 数据 FIFO；
- Completion FIFO；
- 中断逻辑。

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `clk` | 输入 | 系统时钟 | 所有模块共用单时钟 |
| `rst` | 输入 | 系统复位 | 复位子系统内部状态 |
| `s_axil_*` | 输入/输出 | AXI4-Lite 从机接口 | 软件配置寄存器和读取状态 |
| `m_axi_*` | 输入/输出 | AXI4 主机接口 | 对外部存储器执行读写访问 |
| `irq` | 输出 | 中断请求 | Completion FIFO 非空且中断使能时保持有效 |

---

## dma_desc_manager

提供 AXI4-Lite 从机接口，验证描述符有效性，并通过 Request FIFO 和 Completion FIFO 管理请求队列和完成队列。

先发写描述符，后发读描述符，避免读通道已经开始输出数据时，写通道还没有准备好接收对应事务。写描述符先握手并不表示 AXI 写总线一定先于 AXI 读总线完成，读写数据路径仍会并发运行。

描述符管理器接收 `axi_dma` 返回的读完成状态和写完成状态，检查返回标签及写完成长度是否与当前活动描述符一致，并将读错误码、写错误码和状态不一致标志打包写入 Completion FIFO。

当前同一时间只允许一个活动描述符，Request FIFO 可以排队多个请求，但描述符按顺序逐个执行。

### 状态机

```text
IDLE
  ↓
SEND_WRITE
  ↓
SEND_READ
  ↓
WAIT_STATUS
  ↓
PUSH_COMPLETION
  ↓
IDLE
```

| 接口信号 | 接口方向 | 接口定义 | 备注 |
|---|---|---|---|
| `s_axil_*` | 输入/输出 | AXI4-Lite 从机接口 | 连接 `axil_reg_if`，供软件配置和读取状态 |
| `write_desc_addr` | 输出 | DMA 写描述符地址 | 连接 `s_axis_write_desc_addr` |
| `write_desc_len` | 输出 | DMA 写描述符长度 | 连接 `s_axis_write_desc_len` |
| `write_desc_tag` | 输出 | DMA 写描述符标签 | 连接 `s_axis_write_desc_tag` |
| `write_desc_valid` | 输出 | DMA 写描述符有效 | 与 DMA 的 `write_desc_ready` 握手 |
| `write_desc_ready` | 输入 | DMA 写描述符就绪 | 表示写通道可接收描述符 |
| `read_desc_addr` | 输出 | DMA 读描述符地址 | 连接 `s_axis_read_desc_addr` |
| `read_desc_len` | 输出 | DMA 读描述符长度 | 连接 `s_axis_read_desc_len` |
| `read_desc_tag` | 输出 | DMA 读描述符标签 | 连接 `s_axis_read_desc_tag` |
| `read_desc_valid` | 输出 | DMA 读描述符有效 | 与 DMA 的 `read_desc_ready` 握手 |
| `read_desc_ready` | 输入 | DMA 读描述符就绪 | 表示读通道可接收描述符 |
| `read_status_*` | 输入 | DMA 读完成状态 | 接收读标签、错误码和有效信号 |
| `write_status_*` | 输入 | DMA 写完成状态 | 接收写长度、标签、错误码和有效信号 |
| `irq` | 输出 | 中断请求 | Completion FIFO 非空且 IRQ 使能时拉高 |

---

## 描述符格式

```text
软件 → 寄存器暂存区 → Request FIFO → DMA
```

### 寄存器暂存区

| 偏移 | 寄存器 | 作用 | 备注 |
|---|---|---|---|
| `0x08` | `REG_SRC_ADDR` | 32 位源地址暂存 | 入队时只使用低 `AXI_ADDR_WIDTH` 位 |
| `0x0C` | `REG_DST_ADDR` | 32 位目的地址暂存 | 入队时只使用低 `AXI_ADDR_WIDTH` 位 |
| `0x10` | `REG_LENGTH` | 32 位传输长度暂存 | 入队时只使用低 `LEN_WIDTH` 位 |
| `0x14` | `REG_TAG` | 32 位标签暂存 | 实际只使用低 `TAG_WIDTH` 位 |

Request FIFO 格式为打包长串：

```text
{src_addr, dst_addr, length, tag}
```

其真实位宽为：

```text
DESC_WIDTH = 2*AXI_ADDR_WIDTH + LEN_WIDTH + TAG_WIDTH
```

从 FIFO pop 后进行解包，然后通过以下信号传给 DMA：

```text
read_desc_addr
read_desc_len
read_desc_tag
read_desc_valid

write_desc_addr
write_desc_len
write_desc_tag
write_desc_valid
```

对应连接到：

```text
s_axis_read_desc_*
s_axis_write_desc_*
```

---

## 描述符验证规则

1. 长度不为 0。
2. `src_addr`、`dst_addr`、`length`、`tag` 位宽受限，寄存器中超出参数位宽的高位必须为 0。
3. 当 `ENABLE_UNALIGNED=0` 时，源地址和目的地址必须按照 `AXI_STRB_WIDTH` 对齐；当 `ENABLE_UNALIGNED=1` 时，不执行该对齐限制。
4. 使用扩展一位的加法检查源地址加长度和目的地址加长度，保证传输范围不超出总地址空间，并防止地址回绕。传输区间按 `[address, address+length)` 解释。
5. 源地址范围与目的地址范围不重叠。该限制是本子系统的设计策略，不是 AXI 协议本身的限制。

   *Vendor DMA保留非对齐数据移位能力，但当前集成配置为 `ENABLE_UNALIGNED=0` ，仅支持对齐传输，并对非对齐描述符进行拒绝验证。*

软件写 `REG_SUBMIT[0]=1` 后：

```text
描述符非法
  → 不进入 Request FIFO
  → 设置 reject_invalid_sticky

Request FIFO 已满
  → 不进入 Request FIFO
  → 设置 reject_full_sticky

描述符合法且 Request FIFO 有空间
  → 写入 Request FIFO
  → submitted_count 加 1
```

---

## 完成记录

DMA 执行结束后，描述符管理器将完成记录写入 Completion FIFO。完成记录包含：

- 标签；
- 写完成长度；
- 读错误码；
- 写错误码；
- 状态不一致标志。

状态不一致标志包括：

```text
bit 0：read tag mismatch
bit 1：write tag mismatch
bit 2：write length mismatch
```

软件可通过以下寄存器读取和弹出完成项：

| 偏移 | 寄存器 | 作用 | 备注 |
|---|---|---|---|
| `0x1C` | `REG_COMP_TAG` | 读取完成项标签 | 当前 Completion FIFO 队首 |
| `0x20` | `REG_COMP_LENGTH` | 读取写完成长度 | 用于检查实际写入长度 |
| `0x24` | `REG_COMP_STATUS` | 读取完成状态 | `[3:0]` 读错误码，`[7:4]` 写错误码，`[10:8]` mismatch 标志 |
| `0x28` | `REG_COMP_POP` | 弹出完成项 | 软件写入指定控制位后 pop |

IRQ 为电平中断：

```text
irq = irq_enable && Completion FIFO 非空
```

Completion FIFO 非空且中断使能时，IRQ 保持拉高；软件持续 pop 完成项，当 Completion FIFO 变空后，IRQ 撤销。

## 附：寄存器表

| 地址   | 名称              | 作用                                                           | 备注                                                                                     |
|--------|-------------------|----------------------------------------------------------------|------------------------------------------------------------------------------------------|
| 0x00   | CONTROL           | 配置IRQ使能，并清除sticky状态                                   | bit0=IRQ_ENABLE；bit1=CLEAR_STICKY，写1脉冲                                             |
| 0x04   | STATUS            | 读取DMA、Request FIFO、Completion FIFO及错误状态               | bit0=busy；bit1=req_empty；bit2=req_full；bit3=req_ready；bit4=comp_valid；bit5=comp_full；bit6=irq；bit7=reject_full；bit8=reject_invalid；bit9=status_mismatch；bit10=pop_empty |
| 0x08   | SRC_ADDR          | 保存DMA源内存的起始字节地址                                     | 提交descriptor前写入；当前要求按数据宽度对齐                                             |
| 0x0C   | DST_ADDR          | 保存DMA目的内存的起始字节地址                                   | 提交descriptor前写入；当前要求按数据宽度对齐                                             |
| 0x10   | LENGTH            | 保存本次DMA搬运的字节数                                         | 不能为0；高于LEN_WIDTH的位必须为0                                                         |
| 0x14   | TAG               | 保存当前descriptor的任务标签                                    | 完成记录中原样返回，用于匹配任务                                                         |
| 0x18   | SUBMIT            | 将当前配置寄存器组提交到Request FIFO                           | bit0写1触发一次提交；属于W1P命令                                                         |
| 0x1C   | COMP_TAG          | 读取Completion FIFO队首记录的TAG                               | FIFO为空时读回0                                                                          |
| 0x20   | COMP_LENGTH       | 读取队首descriptor实际写入的字节数                             | FIFO为空时读回0                                                                          |
| 0x24   | COMP_STATUS       | 读取队首descriptor的错误和一致性状态                           | [3:0]读错误；[7:4]写错误；[10:8]状态不一致标志                                           |
| 0x28   | COMP_POP          | 弹出当前Completion FIFO队首记录                                | bit0写1触发一次pop；属于W1P命令                                                          |
| 0x2C   | QUEUE_LEVELS      | 读取Request FIFO和Completion FIFO当前深度                     | 低位为Request FIFO level；从bit16开始为Completion FIFO level                             |
| 0x30   | SUBMITTED_COUNT   | 读取已成功提交的descriptor数量                                 | 32位累计计数器，复位后清零                                                               |
| 0x34   | COMPLETED_COUNT   | 读取已完成并写入Completion FIFO的descriptor数量               | 32位累计计数器，复位后清零                                                               |
