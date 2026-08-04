# 新增验证：跨 Channel Completion Reorder 与 RAL Frontdoor

## 1. 本次新增内容

### `dma_subsys_completion_reorder_test`

验证的“乱序”定义为：

- CH0 command 先被 DUT 接受；
- CH1 command 后被 DUT 接受；
- 通过 MEM0 固定延迟，使 CH1 completion 先于 CH0 completion；
- 两条 flow 的数据、route、completion、IRQ 和最终 readback 都必须正确。

这属于双 channel 独立 flow 的系统级 completion reorder。

它不等同于“一个 AXI master 内部不同 ID 的 R/B response reorder”。当前两个 DMA engine 的 AXI ID 都固定为 0，并且每个 channel 同时只接受一条 active command，因此当前 DUT 没有适合宣称为同-master AXI response reorder 的激励条件。

场景参数：

| Flow | issue | route | memory | address | length | delay |
|---|---:|---|---|---|---:|---:|
| slow | 第 1 | CH0→CH0 | RAM0 | 0x0000_2000→0x0000_3000 | 64 B | MEM0 R/B 固定 12 cycles |
| fast | 第 2 | CH1→CH1 | RAM1 | 0x1000_2000→0x1000_3000 | 4 B | 默认 0 |

预期 completion order：

~~~text
issue order      : CH0, CH1
completion order : CH1, CH0
~~~

运行：

~~~bash
./run_vcs_core_amd_vip.sh \
  +UVM_TESTNAME=dma_subsys_completion_reorder_test
~~~

应看到：

~~~text
[REORDER_OBSERVED] CH0 was issued first, CH1 was issued second,
and CH1 completed first
~~~

同时 `COV_SUMMARY` 中增加 `completion_order` coverage。

## 2. 新增 completion-order coverage

`completion_order_cg` 根据 accepted command 建立 issue queue，在 completion 到达时采样：

- first issued channel；
- completed owner channel；
- in-order / out-of-order；
- completion 前 pending depth；
- first-issued × completed × reordered cross。

reset assertion 会清空 issue queue，避免跨 reset epoch 关联。

这只负责 coverage，正确性仍由 test 的明确 completion-order check 和 scoreboard 的 flow/data/status 检查共同保证。

## 3. 新增 intent coverage

此前 intent 只有计数，observed command 中的 `expected_error` 也不能代表测试期望。

现在 `intent_cg` 采样：

- source channel；
- destination channel；
- length boundary；
- expected error；
- expect accept；
- expect completion；
- expect IRQ；
- route × expected-error cross。

observed `command_cg` 只保留 DUT 真正接受的 source/destination/length。

## 4. 新增 register coverage

此前 AXI-Lite register transaction 只有计数。

现在 `register_cg` 采样：

- CH0/CH1/global/unmapped block；
- block offset；
- read/write；
- none/partial/full WSTRB；
- AXI response；
- block × offset × access；
- block × access × response。

## 5. `dma_subsys_ral_smoke_test`

这是当前系统级环境中第一条真正调用 RAL frontdoor 的 concrete test。

覆盖路径：

~~~text
uvm_reg.write/read
→ dma_subsys_reg_adapter
→ dma_subsys_axil_sequencer
→ dma_subsys_axil_driver
→ AMD AXI-Lite VIP
→ DUT
~~~

同时验证 passive prediction：

~~~text
AMD AXI-Lite VIP monitor
→ dma_subsys_vip_transaction_adapter
→ uvm_reg_predictor
→ RAL mirror
~~~

访问内容：

- CH0 SRC_ADDR 写、预测、读回；
- CH1 SRC_ADDR 写、读回；
- CH0/CH1 ROUTE 写读；
- CH0/CH1/global VERSION 读取。

运行：

~~~bash
./run_vcs_core_amd_vip.sh \
  +UVM_TESTNAME=dma_subsys_ral_smoke_test
~~~

应看到：

~~~text
[RAL_SMOKE] RAL frontdoor and passive predictor passed for CH0,
CH1 and global register maps
~~~

## 6. 本轮没有声称完成的内容

- 同一 AXI master 多 ID response reorder。
- 多 outstanding descriptor。
- 同 destination route arbitration。
- AXI SLVERR/DECERR injection。
- mid-transaction reset。
- register access-policy 全矩阵。
- coverage closure。

这些仍属于后续 case。

