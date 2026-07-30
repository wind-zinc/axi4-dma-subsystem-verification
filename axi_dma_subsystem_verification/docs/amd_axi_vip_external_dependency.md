# AMD AXI VIP external dependency

The AMD AXI VIP generated sources are intentionally excluded from this
repository.  They are proprietary tool output and must be supplied locally by
an appropriately licensed Vivado 2022.2 installation.

Set `AXI_VIP_HOME` to an exported source bundle.  The default used by
`sim/run_vcs_core_amd_vip.sh` is:

```text
$HOME/Desktop/verify_study/vip
```

The bundle must contain the following paths:

```text
vendor/xilinx_vip/hdl/axi_vip_pkg.sv
ipstatic/hdl/axi_vip_v1_1_vl_rfs.sv
generated/axil_cpu_vip/sim/axil_cpu_vip_pkg.sv
generated/ext_m0_vip/sim/ext_m0_vip_pkg.sv
generated/ext_m1_vip/sim/ext_m1_vip_pkg.sv
generated/mem0_vip/sim/mem0_vip_pkg.sv
generated/mem1_vip/sim/mem1_vip_pkg.sv
```

The five generated instances are fixed by the static test top:

| Instance | Mode | Address/Data/ID width |
| --- | --- | --- |
| `axil_cpu_vip` | AXI4-Lite master | 32 / 32 / 0 |
| `ext_m0_vip`, `ext_m1_vip` | AXI4 masters | 32 / 32 / 4 |
| `mem0_vip`, `mem1_vip` | AXI4 slaves | 32 / 32 / 6 |

The launcher uses `sim/run_core_amd_vip.f` as the only active project file
list. With no simulation arguments it defaults to the functional smoke test:

```bash
chmod +x sim/run_vcs_core_amd_vip.sh
sim/run_vcs_core_amd_vip.sh
```

The equivalent explicit command is:

```bash
sim/run_vcs_core_amd_vip.sh +UVM_TESTNAME=amd_axi_vip_smoke_test
```

Both commands start all five VIP agents, read both AXI-Lite channel windows,
then perform independent write/readback operations through `ext_m0 -> mem0`
and `ext_m1 -> mem1`.

To compile and elaborate without starting a simulation, use:

```bash
COMPILE_ONLY=1 sim/run_vcs_core_amd_vip.sh
```

Do not start the generated `simv` without a UVM test. Inactive VIP agents can
leave interface outputs at `X`, and the AMD protocol checker correctly treats
unknown AXI control signals after reset as fatal protocol violations.

An `AMD_AXI_VIP_SMOKE` UVM info message, with no UVM errors or fatals, proves
that the exported VIP packages, static hierarchy and basic AXI paths are all
working.  Set `AXI_VIP_HOME` only when using a non-default local location.
