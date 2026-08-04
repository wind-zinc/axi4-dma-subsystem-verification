# Active AMD AXI VIP verification topology

`axi_dma_subsystem_core` is the active DUT. It contains the AXI-Lite control
plane, two DMA channels, the AXIS route/switch fabric, and the AXI crossbar.
Its two flattened `m_axi_mem_*` interfaces are the decoded memory-side AXI
master ports: index 0 is the RAM0 region and index 1 is the RAM1 region.

The active verification top is `tb/tb_axi_dma_core_amd_vip.sv`.
It connects five generated AMD AXI VIP instances:

| Instance | Role |
| --- | --- |
| `axil_cpu_vip` | AXI4-Lite master for channel register access |
| `ext_m0_vip`, `ext_m1_vip` | External AXI masters for preload, readback, and competing traffic |
| `mem0_vip`, `mem1_vip` | AXI slave-memory agents for the two decoded memory ports |

The generated VIP sources remain outside the public repository. They are
loaded from the licensed VM through `AXI_VIP_HOME`.

## Active file list and launcher

`sim/run_core_amd_vip.f` is the only active project file list. The launcher
always compiles this file list and top:

```text
-f run_core_amd_vip.f -top tb_axi_dma_core_amd_vip
```

Run the default smoke test:

```bash
sim/run_vcs_core_amd_vip.sh
```

Select a UVM test explicitly:

```bash
sim/run_vcs_core_amd_vip.sh +UVM_TESTNAME=amd_axi_vip_smoke_test
```

Compile and elaborate without starting `simv`:

```bash
COMPILE_ONLY=1 sim/run_vcs_core_amd_vip.sh
```

Coverage collection and URG report generation are enabled by default:

```bash
sim/run_vcs_core_amd_vip.sh \
  +UVM_TESTNAME=dma_subsys_ch0_to_ch1_test
```

The launcher prints the generated VDB path and
`urg_*/dashboard.html` path at the end of a passing run. Code coverage is
restricted to `tb_axi_dma_core_amd_vip.dut` by `sim/cm_hier.cfg`; UVM
covergroups are retained in the same database. Use `COVERAGE=0` for a fast
compile/run without coverage, or override `COV_DIR`, `REPORT_DIR`, and
`COVERAGE_METRICS` when a fixed artifact path or metric set is required.

The default VCS code metrics are `line+cond+tgl+fsm+branch+assert`; URG also
requests the `group` metric so that the UVM functional covergroups appear as
separate entries in the report. The hierarchy
configuration excludes structural code coverage for the imported
`verilog-axi`, `verilog-axis`, arbiter, and priority-encoder modules. Their
behavior remains checked through subsystem transactions and AMD AXI VIP,
while line and other structural closure metrics focus on the project-owned
DMA subsystem RTL. This boundary also avoids a VCS/URG V-2023.12-SP2 crash
observed while loading the complete parameterized vendor line-shape data.
Do not reuse a VDB that URG has already reported as corrupted.

When no `+UVM_TESTNAME` argument is supplied, the launcher compiles once,
runs every concrete test in its maintained `regression_tests` list into one
coverage database, and then generates one cumulative URG report. Supplying
`+UVM_TESTNAME=<name>` still runs only the selected test. A simulation is
never intentionally started with inactive VIP agents.

The previous RAM-backed smoke test and its file lists have been removed from
the active verification flow. `axi_dma_subsystem_ram_top.sv` and
`axi_dma_subsystem_top.sv` remain optional integration RTL wrappers; they are
not compiled by `run_core_amd_vip.f`.

## UVM ownership

Use active AXI-Lite and AXI4 **master VIP agents** as the CPU / bus-master
transport. A UVM virtual sequence owns the software-like intent: register
programming, external-memory initialization, concurrent traffic, interrupt
handling, and checking. A full CPU instruction-set model is unnecessary
unless firmware itself is a verification target.

## Reusable subsystem environment

`dma_subsys_env` now contains the complete reusable framework needed before
adding the remaining functional scenarios:

```text
dma_subsys_env
├── cfg
├── vip_mgr
├── memory_behavior_controller
├── axil_sequencer + axil_driver
├── RAL model + adapter + passive predictor
├── cmd_monitor
├── route_monitor
├── irq_monitor
├── vip_transaction_adapter
├── reference_model
├── scoreboard
├── coverage
├── watchdog
└── virtual_sequencer
```

The RAL predictor consumes transactions from the passive AXI-Lite monitor.
It does not predict from the driver, so register mirrors reflect traffic that
actually completed on the interface. The scoreboard remains responsible for
end-to-end DMA behavior; RAL is not a replacement for the reference model.

`dma_subsys_env_cfg` centralizes VIP operation timeouts, status polling,
global simulation timeout, and route-grant progress limits.
`dma_subsys_memory_behavior_cfg` centralizes the public AMD memory-agent
READY, read-data gap, write-response delay, and default-fill policies.

The stock AMD slave-memory agent always generates successful responses.
Targeted `SLVERR`/`DECERR` injection therefore requires a separate reactive
slave responder and is intentionally deferred until the negative-memory
test phase. Mid-transaction reset also requires moving reset ownership from
the static top into a reset driver; it is intentionally kept separate from
this stable positive-path framework.

## Known UVM 1.2 message

UVM 1.2 may report `UVM/RSRC/NOREGEX` for `ral.channel0`,
`ral.channel1`, and `ral.global_regs`. These names are generated when
`uvm_reg_block::configure()` registers nested RAL blocks by hierarchical
full name. In this environment the message does not indicate a failed
lookup or a DUT problem, so it is left visible rather than globally
suppressed.
