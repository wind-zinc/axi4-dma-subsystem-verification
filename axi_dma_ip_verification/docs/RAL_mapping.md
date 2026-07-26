# RAL 文件组成

| 文件 | 作用 |
|---|---|
| `dma_reg_model.sv` | 定义寄存器、字段、寄存器块和地址映射 |
| `dma_axil_reg_adapter.sv` | 将UVM通用寄存器操作转换成AXI-Lite transaction |
| `dma_ral_base_seq.sv` | 提供RAL frontdoor读写、提交descriptor和读取completion的辅助任务 |

## 寄存器地址映射

DMA AXI-Lite寄存器默认使用32位数据、4字节地址步长和小端映射。

| RAL名称 | RTL名称 | 地址 | 访问属性 | 作用 | 备注 |
|---|---|---:|---|---|---|
| `ral.control` | `REG_CONTROL` | `0x00` | RW/WO字段 | 配置IRQ使能并清除sticky状态 | bit0=`irq_enable`；bit1=`clear_sticky`，写1产生一次清除命令 |
| `ral.status` | `REG_STATUS` | `0x04` | RO | 读取DMA和FIFO状态 | 见 `STATUS字段` |
| `ral.src_addr` | `REG_SRC_ADDR` | `0x08` | RW | 配置源内存起始字节地址 | 提交前写入；当前配置要求地址对齐 |
| `ral.dst_addr` | `REG_DST_ADDR` | `0x0C` | RW | 配置目的内存起始字节地址 | 提交前写入；当前配置要求地址对齐 |
| `ral.length` | `REG_LENGTH` | `0x10` | RW | 配置搬运字节数 | 不能为0；高位超宽数据会被判为非法descriptor |
| `ral.tag` | `REG_TAG` | `0x14` | RW | 配置descriptor任务标签 | 完成记录中返回，用于匹配任务 |
| `ral.submit` | `REG_SUBMIT` | `0x18` | WO | 将当前配置提交到Request FIFO | bit0写1触发一次提交；属于W1P命令 |
| `ral.comp_tag` | `REG_COMP_TAG` | `0x1C` | RO | 读取Completion FIFO队首TAG | FIFO为空时返回0；读取不会自动pop |
| `ral.comp_length` | `REG_COMP_LENGTH` | `0x20` | RO | 读取队首记录的实际写入长度 | FIFO为空时返回0 |
| `ral.comp_status` | `REG_COMP_STATUS` | `0x24` | RO | 读取队首记录的错误和一致性状态 | `[3:0]`读错误；`[7:4]`写错误；`[10:8]`为length/wrtag/rdtag mismatch标志 |
| `ral.comp_pop` | `REG_COMP_POP` | `0x28` | WO | 弹出Completion FIFO队首记录 | bit0写1触发一次pop；属于W1P命令 |
| `ral.queue_levels` | `REG_QUEUE_LEVELS` | `0x2C` | RO | 读取Request FIFO和Completion FIFO深度 | 低位为request level；高半字为completion level |
| `ral.submitted_count` | `REG_SUBMITTED_COUNT` | `0x30` | RO | 读取成功提交的descriptor数量 | 32位累计计数器，复位清零 |
| `ral.completed_count` | `REG_COMPLETED_COUNT` | `0x34` | RO | 读取已完成descriptor数量 | 32位累计计数器，复位清零 |

## STATUS字段

`ral.status.read()`返回32位状态值。当前RTL中的字段为：

| 位 | RAL字段 | 含义 |
|---:|---|---|
| 0 | `active` | DMA当前正在执行descriptor |
| 1 | `req_empty` | Request FIFO为空 |
| 2 | `req_full` | Request FIFO已满 |
| 3 | `submit_ready` | 当前可以接受新的descriptor |
| 4 | `comp_valid` | Completion FIFO非空，有完成记录可读取 |
| 5 | `comp_full` | Completion FIFO已满 |
| 6 | `irq` | 当前IRQ状态 |
| 7 | `reject_full_sticky` | 曾经因为Request FIFO满而拒绝提交 |
| 8 | `reject_invalid_sticky` | 曾经因为descriptor非法而拒绝提交 |
| 9 | `status_mismatch_sticky` | 曾经检测到TAG或长度不一致 |
| 10 | `pop_empty_sticky` | 曾经尝试从空Completion FIFO弹出 |
