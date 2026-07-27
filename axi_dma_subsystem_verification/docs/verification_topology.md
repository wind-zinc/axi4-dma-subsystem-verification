# Core and RAM-wrapper verification topology

`axi_dma_subsystem_core` is the reusable DUT.  It contains the control plane,
two DMA channels, the AXIS route/switch fabric, and the AXI crossbar.  Its two
flattened `m_axi_mem_*` ports are the AXI master interfaces after address
decode: index 0 is the RAM0 region and index 1 is the RAM1 region.

`axi_dma_subsystem_ram_top` is the reference integration wrapper.  It connects
those ports to two `axi_ram` instances.  `axi_dma_subsystem_top_wrapper.sv`
provides the legacy module name `axi_dma_subsystem_top` for the existing smoke
test; do not compile the legacy monolithic `axi_dma_subsystem_top.sv` in the
new file-list flows.

## File lists

- `sim/run_system_ram.f` compiles the core, RAM wrapper, compatibility top,
  and the established smoke test.  It is the system-integration baseline.
- `sim/run_core_vip.f` compiles the same core without `axi_ram`.  The two
  `axi_mem_vip_if` instances in `tb/core_vip/tb_axi_dma_core_vip_elab.sv` are
  the attachment points for memory-slave VIPs.  That top is intentionally an
  elaboration harness only; replace its short initial block with the selected
  UVM test top after the VIP vendor and licensing flow are chosen.

Both verification environments should retain the same core parameters,
coverage options, binds, and core instance path.  Merge only coverage rooted
at the core; publish the RAM-system and VIP-resilience reports separately in
addition to the merged core report.

## UVM ownership

Use active AXI-Lite and AXI4 **master VIP agents** as the CPU / bus-master
transport.  A UVM virtual sequence owns the software-like intent: register
programming, external-memory initialization, concurrent traffic, interrupt
handling, and checking.  A full CPU instruction-set model is unnecessary
unless firmware itself is a verification target.
