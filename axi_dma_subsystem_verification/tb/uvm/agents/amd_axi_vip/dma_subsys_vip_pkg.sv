`default_nettype none

package dma_subsys_vip_pkg;

    import uvm_pkg::*;
    import dma_subsystem_pkg::*;
    import axi_vip_pkg::*;
    import axil_cpu_vip_pkg::*;
    import ext_m0_vip_pkg::*;
    import ext_m1_vip_pkg::*;
    import mem0_vip_pkg::*;
    import mem1_vip_pkg::*;
    `include "uvm_macros.svh"

    `include "dma_subsys_vip_cfg.svh"
    `include "dma_subsys_memory_behavior_cfg.svh"
    `include "dma_subsys_vip_manager.svh"

endpackage

`default_nettype wire
