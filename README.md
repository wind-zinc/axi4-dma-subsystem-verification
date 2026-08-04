# AXI DMA Verification Projects

This repository contains two related SystemVerilog/UVM projects for verifying an AXI memory-to-memory DMA design at different integration levels. This README is a temporary overview and will be expanded later.

## IP-Level Verification

[`axi_dma_ip_verification`](axi_dma_ip_verification/) verifies a single DMA IP instance.

The design accepts DMA descriptors through an AXI-Lite control interface, reads source data through AXI4, transfers it through an internal AXI-Stream path, and writes it back to memory. The IP-level environment focuses on descriptor handling, register behavior, AXI transfers, completion status, interrupts, error handling, backpressure, reset recovery, and protocol corner cases.

## Subsystem-Level Verification

[`axi_dma_subsystem_verification`](axi_dma_subsystem_verification/) verifies a dual-channel DMA subsystem.

The subsystem integrates two DMA channels with AXI-Lite control registers, AXI interconnects, AXI-Stream routing, descriptor management, completion handling, and interrupt logic. Its UVM environment uses AMD AXI VIP to verify system-level data movement, channel routing, concurrent operation, completion ordering, register access, memory contents, and IRQ behavior.

## Repository Layout

```text
axi_dma_ip_verification/         Single-DMA IP-level RTL and verification
axi_dma_subsystem_verification/  Dual-channel subsystem RTL and verification
```

Each project contains its own RTL, testbench, simulation scripts, documentation, and project-specific README.

Commercial AMD AXI VIP sources are not included in the public repository and must be supplied separately when running the subsystem-level simulation.
