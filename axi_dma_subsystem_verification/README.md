# AXI DMA Subsystem Verification

This repository provides a UVM verification environment for a dual-channel AXI DMA subsystem. This README is a short placeholder and can be expanded as the project evolves.

## RTL Overview

The RTL uses `axi_dma_subsystem_core` as its top-level module and mainly contains:

- Two DMA channels that transfer data from source addresses to destination addresses.
- AXI-Lite control registers for address, length, route, and command configuration.
- AXI and AXI-Stream interconnect and routing logic.
- Descriptor management logic for accepting and scheduling DMA commands.
- Completion, status, and interrupt logic for reporting transfer results.

RTL sources are located in `rtl/`. The testbench and UVM environment are located in `tb/`, while simulation scripts and filelists are located in `sim/`.

## Verification Flow

The verification environment uses UVM and AMD AXI VIP. The VIP handles AXI-Lite register accesses, external memory initialization, AXI responses, and memory-side transaction monitoring.

A typical verification flow is:

1. Initialize clocks, reset, and all AXI VIP agents.
2. Configure DMA registers through a sequence or the RAL model.
3. Initialize source data through the appropriate AXI VIP.
4. Start a DMA command and wait for completion or an interrupt.
5. Collect command, routing, memory, completion, and interrupt transactions with monitors.
6. Compare test intent, observed bus activity, and destination memory data using the reference model and scoreboard.
7. Collect functional and RTL code coverage and generate an URG report.

From the `sim/` directory, run the maintained regression list with:

```bash
./run_vcs_core_amd_vip.sh
```

Run a single test by specifying `UVM_TESTNAME`:

```bash
./run_vcs_core_amd_vip.sh +UVM_TESTNAME=dma_subsys_ral_smoke_test
```

AMD AXI VIP sources are not included in the public repository. Set `AXI_VIP_HOME` to the local VIP bundle before running the simulation.
