# AXI DMA Subsystem 功能覆盖率收敛计划

## 1. 当前基线

本计划基于 `urg_regression_20260804_055004`，其中包含 6 个测试。旧覆盖模型的总功能覆盖率为 **57.06%**。

| Covergroup | 当前覆盖率 | 主要未覆盖内容 | 结论 |
|---|---:|---|---|
| `completion_cg` | 30.83% | 失败完成、abort、两通道结果 | 主要缺少负向 DMA case；旧 cross 还包含大量不合理组合 |
| `intent_cg` | 39.82% | 长度边界、预期失败、拒绝、无 IRQ | 当前 sequence 几乎只发布“成功并产生 IRQ”的 intent |
| `register_cg` | 50.85% | 完整寄存器表、partial/zero strobe、SLVERR/DECERR | RAL smoke 只访问了少量稳定寄存器 |
| `command_cg` | 54.17% | CH1→CH0、短长度、多 burst、长传输 | 已覆盖另外三个 route，但长度类型不足 |
| `memory_cg` | 59.67% | 交叉 RAM 路径、SLVERR/DECERR | 目前主要是 EXT0/RAM0、EXT1/RAM1 和同侧 DMA 路径 |
| `completion_order_cg` | 62.22% | CH1 先发、CH0 后发并超车的镜像场景 | 当前只完成了 CH0 先发、CH1 超车 |
| `route_cg` | 67.22% | 1–4 cycle wait、5+ cycle wait、route fault | 当前 grant 基本都是 immediate |
| `irq_cg` | 91.67% | 旧模型中的 `CLEARED` 事件 | monitor 实际用 pending 变化和 DEASSERTED 表示 clear，旧 bin 定义不一致 |

旧分数中有一部分是“假缺口”：`UNKNOWN` 枚举、AXI-Lite `EXOKAY`、memory-side `UNMAPPED`、RO/WO 不可能访问组合，以及过大的自动 cross 都被算入了分母。覆盖模型修正后，总分会重新计算，因此下一次完整 regression 的结果应作为新基线，不能直接与 57.06% 做数值比较。

## 2. 已完成的覆盖模型调整

`dma_subsys_coverage.svh` 现在包含 11 个 covergroup：

1. `command_cg`：接受命令的 source、destination、精细长度区间和四种 route。
2. `intent_cg`：每个 DMA error code、期望 accept/completion/IRQ 和 route。
3. `register_cg`：37 个真实寄存器地址、RW/RO/WO/非法访问类别、WSTRB、OKAY/SLVERR/DECERR。
4. `memory_cg`：4 个 master × 2 个 RAM × read/write 的完整 cross，以及读写响应。
5. `memory_protocol_cg`：FIXED/INCR/WRAP、burst length、beat size、原始 ID、起始对齐、4KB 边界、写 strobe 和 adapter 协议错误。
6. `route_cg`：request/grant/release/fault、四种 route 和 grant 等待时间。
7. `completion_cg`：两个 owner、每个可形成 completion 的 error code、abort。
8. `completion_order_cg`：CH0-first 与 CH1-first 的顺序完成和反向超车。
9. `irq_cg`：pending、enable、mask、done/error/fault cause、双通道组合及 IRQ 方程一致性。
10. `fault_cg`：route、RD0/RD1、WR0/WR1、manager fault 来源及屏蔽状态。
11. `reset_cg`：初始 reset、重复 reset、idle reset 和 active reset。

以下非法或不可达值不再作为“为了 100% 必须命中”的目标：

- `UNKNOWN` source/master/target；
- AXI-Lite 正常访问中的 `EXOKAY`；
- memory-side monitor 中的 `UNMAPPED`（非法地址不会到达 RAM VIP）；
- accepted command 的 length=0；
- AXI burst 跨 4KB、非法 WRAP 长度、超总线宽度 SIZE、未知 BURST；
- IRQ 输出与 pending/enable 方程不一致。

这些值被设置为 `ignore_bins` 或 `illegal_bins`。`ignore_bins` 表示不属于当前功能范围；`illegal_bins` 表示一旦出现就是 DUT、stimulus 或 adapter 的错误，而不是覆盖目标。

## 3. 建议新增的定向测试

建议按下列顺序实现。一个 test 可以在内部运行一组紧密相关的子场景，不建议为了每一个单独 bin 创建一个几乎空白的 test。

### P0：不需要故障注入即可完成

#### 3.1 `dma_subsys_ch1_to_ch0_test`

- 从 CH1 发起，route 到 CH0，完成一次可核对数据的 DMA copy。
- 建议让 EXT1 初始化 RAM0、DMA1 从 RAM0 读、DMA0 向 RAM1 写、EXT0 从 RAM1 读回。
- 主要关闭 `command_cg/intent_cg/route_cg` 的 CH1→CH0 缺口，同时补若干 crossbar 交叉路径。

#### 3.2 `dma_subsys_crossbar_path_matrix_test`

- EXT0、EXT1 分别对 RAM0、RAM1 做 read/write。
- 通过 CH0 本地 route 和 CH1 本地 route，让 DMA0、DMA1 也分别访问两个 RAM 的 read/write 路径。
- 目标是命中 `4 masters × 2 targets × 2 accesses = 16` 个合法 memory path。
- 每条路径都要检查响应、读回数据和 memory reference model，而不只是“总线有活动”。

#### 3.3 `dma_subsys_transfer_length_boundary_test`

- 建议长度集合：1、3、4、5、16、17、64、65、256、257，以及一个较大的多 burst 长度。
- 地址保持合法且源/目的不重叠；对首尾 guard bytes 也做检查，防止 partial last beat 多写。
- 关闭 intent/command length bins，并产生 partial WSTRB。
- 大于 64 byte 的初始化和读回需要把 external helper 改为自动分段，不要突破单个 helper 当前的 16-beat 限制。

#### 3.4 `dma_subsys_register_access_policy_test`

- 读取 CH0、CH1 和 global 的全部映射寄存器。
- 对 RW 寄存器做 read/write；对 WO 做合法 write 和非法 read；对 RO 做合法 read 和非法 write。
- 对块内保留地址验证 `SLVERR`，对 crossbar 地址窗口外验证 `DECERR`。
- 使用 full、partial、zero WSTRB，并验证只更新被 strobe 选中的 byte。
- RAL 可负责合法访问；负向响应和特殊 WSTRB 建议使用底层 AXI-Lite VIP transaction helper。

#### 3.5 `dma_subsys_axi_burst_shape_test`

- 使用 external AXI VIP 产生 FIXED、INCR、WRAP 的 read/write。
- WRAP 分别覆盖 2、4、8、16 beats；FIXED 覆盖 single 和 multi；INCR 覆盖 1、2–4、5–8、9–16、17–256。
- 覆盖 1/2/4 bytes per beat、ID=0/非 0、aligned/合法 unaligned start、4KB 边界前的合法事务。
- 覆盖 full/partial/zero WSTRB，并检查地址、数据和响应。
- 跨 4KB、非法 WRAP 长度等由 AMD VIP protocol checker 和 `illegal_bins` 拦截，不应为了覆盖率主动发送非法事务，除非单独建立 protocol-negative suite。

#### 3.6 `dma_subsys_route_contention_test`

- 两通道请求同一个 AXIS destination，验证只有一个 owner，另一个等待并在释放后获得 grant。
- 一个子场景让第二个请求等待 1–4 cycles；另一个让其等待 5 cycles 以上。
- 检查 round-robin、公平性、route matrix、busy、release 后无残留。
- short-wait 需要在第一个 flow 即将释放时再启动第二个 flow；同时启动通常会直接落入 long-wait。

#### 3.7 `dma_subsys_completion_order_reverse_test`

- CH1 先发一个慢事务，CH0 后发一个快事务，令 CH0 先完成。
- 再执行 CH1-first 且 CH1 正常先完成的子场景。
- 与已有的 CH0-first reorder test 形成镜像，关闭四个有意义的 order case。

#### 3.8 `dma_subsys_irq_mask_multi_pending_test`

- done pending 在 enable=0 时不拉 IRQ，随后打开 enable 应立即反映 level IRQ。
- 分别覆盖 CH0、CH1、双通道 done pending。
- 使用 descriptor error 产生 error pending，并覆盖 error masked/enabled。
- 覆盖 done+error 同时存在、clear 一个 cause 后 IRQ 仍保持、清完最后一个 cause 后 deassert。
- fault cause 在 P1 故障注入测试中补齐。

#### 3.9 `dma_subsys_descriptor_error_test`

- 分别验证 `DISABLED`、`BUSY` 控制拒绝。
- 分别验证 `LEN_ZERO`、`SRC_ALIGN`、`DST_ALIGN`、`SRC_RANGE`、`DST_RANGE`、`OVERLAP` completion。
- 每个子场景都检查：command 是否被 manager 接受、completion error、completed_len、local/global pending、IRQ mask 行为、错误计数和目标内存未被意外改写。
- `ROUTE_CONFLICT` 的 source 字段由寄存器块固定生成，正常软件路径不可构造，应放入 P1 注入测试或明确 waiver。

#### 3.10 `dma_subsys_abort_timing_test`

- 在 validate/wait-route/issue-descriptor 前后触发 abort，覆盖 `ABORT_PENDING`。
- 在已经进入 data/status 阶段时触发 abort，覆盖 `ABORT_INFLIGHT_UNSUPPORTED`。
- 两个通道都应至少出现一次 aborted completion，以关闭 owner×aborted cross。

#### 3.11 `dma_subsys_reset_recovery_test`

- 运行期 idle reset，然后重新配置并完成一笔传输。
- DMA/route 活跃时 reset，检查 outstanding intent 被取消、route/busy/IRQ/pending 释放、scoreboard epoch 清空。
- reset 释放后再次执行传输，证明环境和 DUT 都可恢复，而不只是寄存器回到零。

### P1：需要可控故障注入

#### 3.12 `dma_subsys_memory_response_error_test`

- 在指定地址/指定 beat 注入 read `SLVERR`、read `DECERR`、write `SLVERR`、write `DECERR`。
- 同时检查 memory-side response coverage、DMA completion error 映射、IRQ/error counter 和数据副作用。
- 当前 stock reactive memory loop 只返回 OKAY，需要先增加可配置 response policy；不能只在 scoreboard 中伪造 error。

#### 3.13 `dma_subsys_status_fault_injection_test`

- 注入 RD0/RD1/WR0/WR1 unexpected status，命中四个 fault source。
- 注入 tag mismatch、completed length mismatch。
- 构造 route invalid request/release，覆盖 route fault。
- manager internal state fault 需要 test-only bind/force；若项目不允许内部状态注入，应在 coverage review 中以“防御性不可达状态”记录 waiver，而不是编写正常 sequence 假装能到达。

## 4. AXI 覆盖完整性审计

ARM AXI4 规范要求关注 burst 类型和长度、transfer size、byte strobe、4KB 边界、ID、多 outstanding 与乱序完成等维度。AXI4 INCR 可到 256 transfers，FIXED 和 WRAP 不超过 16，WRAP 长度必须为 2/4/8/16，burst 不能跨 4KB。参见 [Arm AMBA AXI and ACE Protocol Specification, IHI 0022H](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf)。

AMD AXI VIP 自带 protocol checks，可检查 4KB、WRAP 对齐/长度、SIZE、VALID/READY backpressure 下的稳定性等协议规则；这些检查解决“事务是否合法”，本项目 covergroup 解决“合法事务类型是否真的被测试过”。参见 [AMD AXI VIP Protocol Checks](https://docs.amd.com/r/en-US/pg267-axi-vip/AXI-Protocol-Checks-and-Descriptions)。

当前新增模型已覆盖本阶段最重要且现有 adapter 可以观察的字段：address、master/target、read/write、ID、burst、length、size、alignment、4KB、WSTRB、response。

以下维度仍建议列入第二阶段，而不是声称已经完整覆盖：

- `AxLOCK`/exclusive 和 `EXOKAY`；
- `AxCACHE`、`AxPROT` 的透传组合；
- read/write outstanding depth、不同 ID 的并发和同 ID ordering；
- AW/W、AR/R/B 各 channel 的 backpressure latency；
- response interleaving 和真正的 AXI ID-based out-of-order。

当前 core 没有对外暴露 QOS/REGION/USER，内部 QOS 固定为 0，因此这些字段不应进入当前必须 100% 的 coverage denominator。AMD 文档列出了 AXI4 与 AXI4-Lite 的信号差异，见 [AMD AXI VIP Port Descriptions](https://docs.amd.com/r/en-US/pg267-axi-vip/Port-Descriptions)。VIP 也允许配置同时接受的 transaction threads，可用于后续 outstanding 测试，见 [AMD AXI VIP Issue Capability](https://docs.amd.com/r/en-US/pg267-axi-vip/Issue-Capability)。

要覆盖第二阶段维度，需要先扩展 `dma_subsys_mem_tr` 和 VIP adapter，使 sideband、各 channel handshake 时间以及 outstanding 状态进入 vendor-neutral transaction；否则只看最终 memory transaction 无法可靠区分 backpressure 与 ordering 场景。

## 5. 收敛方法与完成标准

1. 先跑现有 6-test regression，保存新 covergroup 基线。
2. 每新增一个 test，只关闭其声明负责的 bins，并检查是否产生新的 failure 或 illegal bin。
3. 每个 test 必须同时通过 scoreboard、协议检查、UVM error/fatal 检查；不能用 coverage hit 代替结果检查。
4. 对 0-hit bin 分类为：stimulus 缺失、monitor/adapter 不可见、RTL 不支持、设计不可达、防御性非法状态。
5. 只有 stimulus 缺失项通过 sequence 收敛；不可见项先补 monitor；不支持或不可达项经过 RTL/验证评审后写 waiver。
6. 功能覆盖率 100% 指“审计后的合法功能空间 100%”，不包含为了美化数字而合并错误码、采样假 transaction 或强行命中 illegal bin。
7. 功能覆盖稳定后，再开始代码覆盖分析和 `.el` waiver；两类覆盖不要混在同一轮调试中。

