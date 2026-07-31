`default_nettype none

import uvm_pkg::*;
import dma_subsys_vip_pkg::*;
`include "uvm_macros.svh"

// Lifecycle-only test for dma_subsys_vip_manager.  Functional AXI traffic
// remains in amd_axi_vip_smoke_test and in the future subsystem sequences.
class dma_subsys_vip_manager_smoke_test extends uvm_test;
    `uvm_component_utils(dma_subsys_vip_manager_smoke_test)

    dma_subsys_vip_manager vip_mgr;

    function new(
        string        name   = "dma_subsys_vip_manager_smoke_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        vip_mgr = dma_subsys_vip_manager::type_id::create("vip_mgr", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        vip_mgr.wait_until_ready();
        vip_mgr.require_ready(get_full_name());

        if ((vip_mgr.axil_cpu == null) ||
            (vip_mgr.ext_m0   == null) ||
            (vip_mgr.ext_m1   == null) ||
            (vip_mgr.mem0     == null) ||
            (vip_mgr.mem1     == null)) begin
            `uvm_fatal(
                "VIP_MGR_SMOKE",
                "At least one AMD AXI VIP agent handle is null")
        end

        @(negedge tb_axi_dma_core_amd_vip.rst);
        `uvm_info(
            "VIP_MGR_SMOKE",
            "dma_subsys_vip_manager created and started all five agents",
            UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass

`default_nettype wire
