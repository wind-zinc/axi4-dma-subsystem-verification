# AXI4 DMA UVM Test Case 清单

最终Stage11回归包含28个UVM test.

## 基础和RAL访问

这一组验证AXI-Lite控制面、RAL frontdoor访问、基本提交流程和只读寄存器保护。

| Test | Sequence | 主要动作 | 覆盖点 |
|---|---|---|---|
| `dma_random_smoke_test` | `dma_random_smoke_seq` | 随机产生合法源地址、目的地址、长度和TAG，完成一次正常搬运 | `descriptor_cg`合法bin；`completion_cg`正常完成；读写错误`_none`；基本`irq_cg` |
| `dma_ral_smoke_test` | `dma_ral_smoke_seq` | 通过RAL写SRC/DST/LENGTH/TAG，写SUBMIT，读取并POP completion | `axil_cg`寄存器访问；RAL frontdoor；descriptor提交；completion读取；IRQ完成路径 |
| `dma_wstrb_test` | `dma_wstrb_seq` | 使用不同WSTRB组合执行寄存器部分字节写并检查寄存器结果 | `axil_cg`各WSTRB字节；部分写；寄存器保持；高位合法性检查 |
| `dma_command_noop_test` | `dma_command_noop_seq` | 向SUBMIT/COMP_POP写0或使用无效WSTRB，确认不产生命令脉冲 | W1P无效写；submitted/completed计数保持；命令译码分支 |
| `dma_ro_write_protection_test` | `dma_ro_write_protection_seq` | 对STATUS、COMP、QUEUE_LEVELS和计数器等RO寄存器执行写操作 | RO写保护；寄存器值保持；AXI-Lite写响应 |
| `dma_access_policy_test` | `dma_access_policy_seq` | 访问保留地址、未实现地址和非法控制组合 | AXI-Lite非法/保留地址；默认读零；访问响应；控制面保护分支 |

## Descriptor合法性与队列

这一组验证descriptor进入Request FIFO之前的检查，以及请求队列的容量和状态。

| Test | Sequence | 主要动作 | 覆盖点 |
|---|---|---|---|
| `dma_invalid_desc_test` | `dma_invalid_desc_seq` | 提交长度为0、非法地址、非法长度和非对齐地址 | `descriptor_cg`非法bin；`reject_invalid_sticky`；非法descriptor不入队 |
| `dma_length_sweep_test` | `dma_length_sweep_seq` | 扫描1、2、3、4、5、6、7、9、63、64、65等长度 | 长度bin；部分beat；完整beat；TKEEP；TLAST；实际写入长度 |
| `dma_alignment_reject_test` | `dma_alignment_reject_seq` | 测试源/目的地址偏移1、2、3的非对齐descriptor | 对齐策略；非对齐拒绝；`reject_invalid_sticky`；不覆盖正向unaligned shift |
| `dma_address_range_reject_test` | `dma_address_range_reject_seq` | 分别使SRC、DST、LENGTH、TAG高位超出参数宽度 | `src_addr_fits`、`dst_addr_fits`、`length_fits`、`tag_fits`拒绝分支 |
| `dma_overlap_reject_test` | `dma_overlap_reject_seq` | 测试源目的区间重叠和地址回绕 | `ranges_overlap`；地址范围检查；非法descriptor拒绝 |
| `dma_queue_saturation_test` | `dma_queue_saturation_seq` | 第一个descriptor仍执行时连续提交请求，填满Request FIFO后继续提交 | Request FIFO中间/满；`req_full`；`reject_full_sticky`；提交拒绝分支 |
| `dma_queue_mid_level_test` | `dma_queue_mid_level_seq` | 阻塞第一个descriptor并提交后续请求，使Request FIFO达到中间深度2 | `queue_level_cg`中间level；FIFO push/pop；active与queue并存 |

## AXI传输、错误和反压

这一组验证AXI burst、4KB边界、AXI错误、AXIS FIFO反压、outstanding和写引擎边界状态。

| Test | Sequence | 主要动作 | 覆盖点 |
|---|---|---|---|
| `dma_boundary_matrix_test` | `dma_boundary_matrix_seq` | 分别测试源跨4KB、目的跨4KB、源目的同时跨4KB和都不跨 | 边界分类；AXI burst拆分；读写地址burst；4KB边界SVA |
| `dma_sub_beat_tag_test` | `dma_sub_beat_tag_seq` | 使用短于一个数据beat的长度和不同TAG，检查completion匹配 | 短长度；TAG；TKEEP；最后一拍；completion TAG/length |
| `dma_read_slverr_test` | `dma_error_response_seq(DMA_READ_SLVERR)` | 对匹配源地址注入读SLVERR并检查completion | `cp_read_error.slverr`；读错误码；错误completion；IRQ |
| `dma_read_decerr_test` | `dma_error_response_seq(DMA_READ_DECERR)` | 对匹配源地址注入读DECERR | `cp_read_error.decerr`；读错误响应；错误completion |
| `dma_write_slverr_test` | `dma_error_response_seq(DMA_WRITE_SLVERR)` | 对匹配目的地址注入写SLVERR | `cp_write_error.slverr`；写错误码；写状态捕获 |
| `dma_write_decerr_test` | `dma_error_response_seq(DMA_WRITE_DECERR)` | 对匹配目的地址注入写DECERR | `cp_write_error.decerr`；写错误响应；错误completion |
| `dma_axi_backpressure_test` | `dma_axi_backpressure_seq` | 分别阻塞AW、W、B、AR、R通道并等待恢复 | `cp_aw_stall`、`cp_w_stall`、`cp_ar_stall`、`cp_r_stall`；AXIS反压；FIFO full；恢复活性 |
| `dma_outstanding_test` | `dma_outstanding_seq` | 打开memory proxy outstanding模式，延迟R/B响应，使多个burst同时在途 | `outstanding_cg`读/写最大在途数；多个AR/AW；响应延迟；数据完整性 |
| `dma_write_engine_corner_test` | `dma_write_engine_corner_seq` | 测试短长度、4KB边界写、B响应积累，并注入写引擎恢复状态 | `axi_dma_wr`部分长度；FINISH_BURST；DROP_DATA；status FIFO积累；写侧FSM/Branch/Toggle |
| `dma_toggle_stress_test` | `dma_toggle_stress_seq` | 使用多组地址、长度、TAG和队列操作扩大有效信号翻转范围 | 有意义Toggle；地址/长度/TAG；FIFO指针；状态翻转 |

## Completion、IRQ、复位和SVA

这一组验证完成队列、IRQ电平、复位恢复和断言激活。

| Test | Sequence | 主要动作 | 覆盖点 |
|---|---|---|---|
| `dma_irq_mode_test` | `dma_irq_mode_seq` | 分别测试IRQ_ENABLE=0/1，保持completion不POP，再POP completion | `irq_cg`无IRQ、有IRQ、IRQ保持、POP后IRQ撤销 |
| `dma_pop_empty_test` | `dma_pop_empty_seq` | Completion FIFO为空时读取COMP寄存器并执行COMP_POP | 空队列读取；`pop_empty_sticky`；空completion返回零 |
| `dma_empty_completion_read_test` | `dma_empty_completion_read_seq` | 空Completion FIFO时读取TAG、LENGTH、STATUS | `comp_valid=0`；completion head读零；保护分支 |
| `dma_reset_recovery_test` | `dma_reset_recovery_seq` | descriptor执行过程中重新拉高reset，随后重新配置并搬运 | FIFO清空；状态回IDLE；计数器恢复；reset SVA；恢复搬运 |
| `dma_sva_activation_test` | `dma_sva_activation_seq` | 制造AXI-Lite request stall和descriptor stall，激活稳定性断言 | `cp_axil_*_stable_success`；descriptor stable；stall cover；SVA success |

## 完整回归指令

```bash
cd sim
./run_regression.sh
```
