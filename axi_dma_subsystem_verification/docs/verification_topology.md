# Active AMD AXI VIP verification topology

`axi_dma_subsystem_core` is the active DUT. It contains the AXI-Lite control
plane, two DMA channels, the AXIS route/switch fabric, and the AXI crossbar.
Its two flattened `m_axi_mem_*` interfaces are the decoded memory-side AXI
master ports: index 0 is the RAM0 region and index 1 is the RAM1 region.

The active verification top is `tb/core_vip/tb_axi_dma_core_amd_vip.sv`.
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

The launcher defaults to `amd_axi_vip_smoke_test` whenever no
`+UVM_TESTNAME` argument is supplied. A simulation is never intentionally
started with inactive VIP agents.

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
