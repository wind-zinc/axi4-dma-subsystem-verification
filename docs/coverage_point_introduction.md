# AXI4 DMA Coverage 说明

本文档与 `case.md` 的四个测试分组保持一致。每个 coverage point 使用一个四级标题，并单独列出“Bin名称 / 内容 / 备注”三列表格。

## 基础和RAL访问

### `axil_cg`：AXI-Lite访问覆盖

#### AXI-Lite操作方向

| Bin名称 | 内容 | 备注 |
|---|---|---|
| write | AXI-Lite写事务 | `dma_ral_smoke_test`、`dma_random_smoke_test` |
| read | AXI-Lite读事务 | 同上，覆盖寄存器读回 |

#### AXI-Lite寄存器地址

| Bin名称 | 内容 | 备注 |
|---|---|---|
| control/status | CONTROL、STATUS | 基础和RAL访问测试 |
| descriptor_cfg | SRC、DST、LENGTH、TAG | RAL smoke、随机测试 |
| command | SUBMIT、COMP_POP | RAL smoke、command noop |
| completion | COMP_TAG、COMP_LENGTH、COMP_STATUS | completion读取测试 |
| queue_count | QUEUE、COUNT、submitted/completed count | 队列和状态测试 |

#### WSTRB

| Bin名称 | 内容 | 备注 |
|---|---|---|
| byte0 | `4'b0001` | `dma_wstrb_test` |
| byte1 | `4'b0010` | `dma_wstrb_test` |
| byte2 | `4'b0100` | `dma_wstrb_test` |
| byte3 | `4'b1000` | `dma_wstrb_test` |
| multi_byte | 多个字节有效但不是全字节 | `dma_wstrb_test` |
| all_bytes | `4'b1111` | 正常寄存器写入 |

#### AXI-Lite响应

| Bin名称 | 内容 | 备注 |
|---|---|---|
| okay | 合法访问返回OKAY | 基础/RAL测试 |
| protected | 只读寄存器写入后的保护响应或保持不变 | `dma_ro_write_protection_test` |
| default | 未实现地址的安全读写响应 | `dma_access_policy_test` |

### `ral_register_access`：RAL frontdoor覆盖

#### 配置寄存器frontdoor写

| Bin名称 | 内容 | 备注 |
|---|---|---|
| src | 通过 `uvm_reg::write()` 写SRC | `dma_ral_smoke_test` |
| dst | 通过RAL写DST | `dma_ral_smoke_test` |
| length | 通过RAL写LENGTH | `dma_ral_smoke_test` |
| tag | 通过RAL写TAG | `dma_ral_smoke_test` |

#### 命令寄存器frontdoor写

| Bin名称 | 内容 | 备注 |
|---|---|---|
| submit | 写SUBMIT触发提交 | RAL smoke |
| comp_pop | 写COMP_POP弹出完成记录 | RAL smoke、completion测试 |
| noop | 命令位为0或无效组合 | `dma_command_noop_test` |

#### 状态寄存器frontdoor读

| Bin名称 | 内容 | 备注 |
|---|---|---|
| status | 读取STATUS | RAL smoke |
| completion_fields | 读取COMP_TAG、COMP_LENGTH、COMP_STATUS | completion读取测试 |
| queue_levels | 读取QUEUE_LEVELS和COUNT | 队列测试 |

### `read_only_protection_cg`：只读寄存器保护

#### RO寄存器写入

| Bin名称 | 内容 | 备注 |
|---|---|---|
| status_ro | 写STATUS后值保持只读语义 | `dma_ro_write_protection_test` |
| completion_ro | 写COMP_TAG、COMP_LENGTH、COMP_STATUS | 同上 |
| queue_ro | 写QUEUE_LEVELS、SUBMITTED_COUNT、COMPLETED_COUNT | 同上 |

#### 未实现地址访问

| Bin名称 | 内容 | 备注 |
|---|---|---|
| default_read | 读取未实现地址 | `dma_access_policy_test` |
| benign_write | 写未实现地址且不触发DMA | `dma_access_policy_test` |

## Descriptor合法性与队列

### `descriptor_cg`：descriptor属性覆盖

#### descriptor合法性

| Bin名称 | 内容 | 备注 |
|---|---|---|
| legal | 地址、长度和TAG均合法 | `dma_random_smoke_test` |
| invalid | 至少一个字段非法 | `dma_invalid_desc_test` |

#### 长度类型

| Bin名称 | 内容 | 备注 |
|---|---|---|
| zero | 长度为0 | `dma_invalid_desc_test` |
| one_byte | 1字节长度 | 长度边界测试 |
| sub_beat | 小于一个AXI beat | `dma_length_sweep_test` |
| full_beat | 一个完整beat | 同上 |
| multi_beat | 多个beat | 基础和随机测试 |
| long_transfer | 长burst或多burst传输 | 长度扫描 |

#### 地址对齐

| Bin名称 | 内容 | 备注 |
|---|---|---|
| aligned | 地址按数据宽度对齐 | 正常传输 |
| offset1 | 地址低位偏移1 | `dma_alignment_reject_test` |
| offset2 | 地址低位偏移2 | 同上 |
| offset3 | 地址低位偏移3 | 同上 |

#### TAG

| Bin名称 | 内容 | 备注 |
|---|---|---|
| tag_zero | TAG为0 | TAG边界测试 |
| tag_nonzero | 多个非零TAG | `dma_random_smoke_test`、`dma_sub_beat_tag_test` |
| tag_max | TAG最大值 | 边界/随机测试 |

#### 源/目的范围

| Bin名称 | 内容 | 备注 |
|---|---|---|
| legal_range | 地址加长度未越界 | 正常测试 |
| wrap_reject | 地址或长度导致范围回绕 | `dma_address_range_reject_test` |

#### 源目的关系

| Bin名称 | 内容 | 备注 |
|---|---|---|
| non_overlap | 源目的区间不重叠 | 正常测试 |
| overlap_reject | 源目的区间重叠并被拒绝 | `dma_overlap_reject_test` |

#### 高位合法性

| Bin名称 | 内容 | 备注 |
|---|---|---|
| high_bits_zero | 地址、长度、TAG高位满足约束 | 正常测试 |
| high_bits_overflow | 高位溢出或不符合宽度 | `dma_address_range_reject_test` |

### `queue_level_cg`：FIFO深度覆盖

#### Request FIFO状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| empty | FIFO为空 | 空闲状态 |
| level1 | FIFO中有1条请求 | `dma_queue_mid_level_test` |
| level2 | FIFO中有2条请求 | 同上 |
| mid_level | FIFO处于中间深度 | `dma_queue_mid_level_test` |
| full | FIFO达到容量上限 | `dma_queue_saturation_test` |

#### Completion FIFO状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| empty | 没有completion | `dma_empty_completion_read_test` |
| non_empty | 至少存在一条completion | RAL smoke、IRQ测试 |
| full | completion FIFO达到容量上限 | completion积累测试 |

#### FIFO操作

| Bin名称 | 内容 | 备注 |
|---|---|---|
| push | 成功写入FIFO | 队列测试 |
| pop | 成功弹出FIFO | RAL smoke、completion测试 |
| simultaneous | 同周期push和pop | 队列随机测试 |

### `manager_status_cg`：管理器状态覆盖

#### DMA管理状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| idle | 管理器空闲 | 所有测试的起始/结束 |
| send_write | 发送写descriptor | 正常搬运 |
| send_read | 发送读descriptor | 正常搬运 |
| wait_status | 等待读写完成状态 | 正常和延迟测试 |
| push_completion | 生成completion记录 | completion测试 |

#### submit状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| ready | 可以接收提交 | 基础测试 |
| accepted | descriptor被接受 | 正常测试 |
| rejected_full | FIFO满时拒绝 | `dma_queue_saturation_test` |
| rejected_invalid | 非法descriptor被拒绝 | `dma_invalid_desc_test` |

#### sticky状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| clear | 错误/完成状态清除 | RAL和命令测试 |
| set | 错误或完成状态置位 | 非法/错误测试 |
| readback | 通过STATUS读回 | `dma_ral_smoke_test` |

## AXI传输、错误和反压

### `boundary_cg`：4KB边界覆盖

#### 源地址边界

| Bin名称 | 内容 | 备注 |
|---|---|---|
| source_no_cross | 源burst不跨4KB边界 | `dma_boundary_matrix_test` |
| source_cross | 源burst跨4KB边界并拆分 | 同上 |

#### 目的地址边界

| Bin名称 | 内容 | 备注 |
|---|---|---|
| destination_no_cross | 目的burst不跨4KB边界 | 边界矩阵 |
| destination_cross | 目的burst跨4KB边界并拆分 | 边界矩阵、写引擎corner |

#### 同时跨界

| Bin名称 | 内容 | 备注 |
|---|---|---|
| neither | 源和目的都不跨界 | `dma_boundary_matrix_test` |
| source_only | 只有源地址跨界 | 同上 |
| destination_only | 只有目的地址跨界 | 同上 |
| both | 源和目的同时跨界 | 同上 |

#### burst长度限制

| Bin名称 | 内容 | 备注 |
|---|---|---|
| max_burst | 达到最大burst长度 | 长度扫描 |
| residual_burst | 末尾剩余burst | 长度扫描 |
| boundary_shortened | 因4KB边界而缩短burst | 边界矩阵 |

### `cp_read_error`：读错误覆盖

#### 读响应错误

| Bin名称 | 内容 | 备注 |
|---|---|---|
| none | 读响应为OKAY | 所有正常搬运测试 |
| slverr | 读响应为SLVERR | `dma_read_slverr_test` |
| decerr | 读响应为DECERR | `dma_read_decerr_test` |

### `cp_write_error`：写错误覆盖

#### 写响应错误

| Bin名称 | 内容 | 备注 |
|---|---|---|
| none | 写响应为OKAY | 所有正常搬运测试 |
| slverr | 写响应为SLVERR | `dma_write_slverr_test` |
| decerr | 写响应为DECERR | `dma_write_decerr_test` |

### `axis_backpressure_cg`：AXIS反压覆盖

#### AXIS握手

| Bin名称 | 内容 | 备注 |
|---|---|---|
| transfer | `TVALID && TREADY` | 基础搬运、反压测试 |
| blocked | `TVALID && !TREADY` | `dma_axi_backpressure_test` |
| resumed | 阻塞后重新握手 | 同上 |

#### FIFO反压传播

| Bin名称 | 内容 | 备注 |
|---|---|---|
| fifo_not_full | FIFO未满，读端继续接收 | 反压测试 |
| fifo_full | FIFO满并向上游施加反压 | 反压测试 |
| recovery | FIFO清空后恢复传输 | 反压测试 |

### `axi_channel_stall_cg`：AXI通道stall覆盖

#### AW通道stall

| Bin名称 | 内容 | 备注 |
|---|---|---|
| aw_stall | `AWVALID && !AWREADY` | `dma_axi_backpressure_test` |
| aw_transfer | `AWVALID && AWREADY` | 正常写事务 |

#### W通道stall

| Bin名称 | 内容 | 备注 |
|---|---|---|
| w_stall | `WVALID && !WREADY` | 反压测试 |
| w_transfer | `WVALID && WREADY` | 正常写事务 |

#### B通道stall

| Bin名称 | 内容 | 备注 |
|---|---|---|
| b_stall | `BVALID && !BREADY` | 反压测试、写引擎corner |
| b_transfer | `BVALID && BREADY` | 正常写响应 |

#### AR通道stall

| Bin名称 | 内容 | 备注 |
|---|---|---|
| ar_stall | `ARVALID && !ARREADY` | 反压测试 |
| ar_transfer | `ARVALID && ARREADY` | 正常读事务 |

#### R通道stall

| Bin名称 | 内容 | 备注 |
|---|---|---|
| r_stall | `RVALID && !RREADY` | 反压测试 |
| r_transfer | `RVALID && RREADY` | 正常读数据 |

### `outstanding_cg`：AXI在途事务覆盖

#### 读在途burst深度

| Bin名称 | 内容 | 备注 |
|---|---|---|
| zero | 没有未完成读burst | 空闲/完成阶段 |
| one | 一个在途burst | `dma_outstanding_test` |
| two | 两个在途burst | 同上 |
| multiple | 多个在途burst | 同上，高延迟memory |

#### 写在途burst深度

| Bin名称 | 内容 | 备注 |
|---|---|---|
| zero | 没有未完成写burst | 空闲/完成阶段 |
| one | 一个在途burst | `dma_outstanding_test` |
| two | 两个在途burst | 同上 |
| multiple | 多个在途burst | 同上 |

#### 延迟响应

| Bin名称 | 内容 | 备注 |
|---|---|---|
| delayed_r | R响应延迟后数据仍正确 | `dma_outstanding_test` |
| delayed_b | B响应延迟后数据仍正确 | 同上 |

### `axi_dma_wr_corner_cg`：写引擎边界覆盖

#### 部分最后beat

| Bin名称 | 内容 | 备注 |
|---|---|---|
| short_length | 长度小于完整beat | `dma_write_engine_corner_test` |
| partial_tkeep | 最后一拍TKEEP部分有效 | 长度扫描 |
| full_tkeep | 最后一拍全部字节有效 | 正常测试 |

#### 写状态机恢复

| Bin名称 | 内容 | 备注 |
|---|---|---|
| finish_burst | 正常完成burst | 写引擎corner |
| drop_data | 异常AXIS边界下丢弃/收尾路径 | 白盒异常场景 |

#### 状态FIFO积累

| Bin名称 | 内容 | 备注 |
|---|---|---|
| b_delayed | B响应延迟导致状态积累 | 写引擎corner |
| status_capacity | status FIFO达到容量限制 | 写引擎corner |

## Completion、IRQ、复位和SVA

### `completion_cg`：完成记录覆盖

#### completion存在

| Bin名称 | 内容 | 备注 |
|---|---|---|
| empty | completion FIFO为空 | `dma_empty_completion_read_test` |
| valid | completion FIFO非空 | RAL smoke、IRQ测试 |
| pop | 成功弹出completion | completion和RAL测试 |

#### TAG匹配

| Bin名称 | 内容 | 备注 |
|---|---|---|
| expected | 返回TAG等于提交TAG | 正常完成 |
| mismatch | 返回TAG不匹配并被检测 | 状态错误测试 |

#### 写入长度

| Bin名称 | 内容 | 备注 |
|---|---|---|
| expected_length | completion长度等于期望值 | 长度扫描 |
| mismatch_length | completion长度不匹配并被检测 | 异常状态测试 |

#### completion状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| no_error | 无错误完成 | 正常测试 |
| read_error | 读错误完成 | 读SLVERR/DECERR |
| write_error | 写错误完成 | 写SLVERR/DECERR |
| mismatch_error | TAG或长度不匹配 | 状态错误测试 |

### `irq_cg`：IRQ覆盖

#### IRQ使能

| Bin名称 | 内容 | 备注 |
|---|---|---|
| disabled | `irq_enable=0` | `dma_irq_mode_test` |
| enabled | `irq_enable=1` | 同上 |

#### completion与IRQ

| Bin名称 | 内容 | 备注 |
|---|---|---|
| no_completion | 没有completion时IRQ保持低 | IRQ模式测试 |
| completion_irq | completion有效且IRQ有效 | IRQ模式、RAL smoke |

#### IRQ电平

| Bin名称 | 内容 | 备注 |
|---|---|---|
| held_high | completion FIFO非空期间保持高 | `dma_irq_mode_test` |
| deassert_after_pop | 最后一条completion弹出后拉低 | 同上 |
| level_not_pulse | 多条completion不要求每条产生上升沿 | completion积累测试 |

### `reset_cg`：复位恢复覆盖

#### 复位位置

| Bin名称 | 内容 | 备注 |
|---|---|---|
| idle | IDLE状态下复位 | `dma_reset_recovery_test` |
| descriptor_active | descriptor发送期间复位 | 同上 |
| axi_active | AXI传输期间复位 | 同上 |

#### 复位后状态

| Bin名称 | 内容 | 备注 |
|---|---|---|
| fifo_empty | 请求/完成FIFO清空 | 复位测试 |
| manager_idle | 管理器回到IDLE | 复位测试 |
| irq_low | IRQ清零 | 复位测试 |

#### 复位后恢复

| Bin名称 | 内容 | 备注 |
|---|---|---|
| resubmit | 复位后重新提交descriptor | `dma_reset_recovery_test` |
| complete | 复位后重新搬运并完成 | 同上 |
