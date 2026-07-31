// Typed virtual-interface bundle passed from the static testbench module to
// the package-based UVM environment.  The package may store virtual interface
// handles, but it must not reach into the module instance hierarchy itself.
class dma_subsys_vip_cfg extends uvm_object;
    `uvm_object_utils(dma_subsys_vip_cfg)

    virtual interface axi_vip_if #(
        axil_cpu_vip_VIP_PROTOCOL,
        axil_cpu_vip_VIP_ADDR_WIDTH,
        axil_cpu_vip_VIP_DATA_WIDTH,
        axil_cpu_vip_VIP_DATA_WIDTH,
        axil_cpu_vip_VIP_ID_WIDTH,
        axil_cpu_vip_VIP_ID_WIDTH,
        axil_cpu_vip_VIP_AWUSER_WIDTH,
        axil_cpu_vip_VIP_WUSER_WIDTH,
        axil_cpu_vip_VIP_BUSER_WIDTH,
        axil_cpu_vip_VIP_ARUSER_WIDTH,
        axil_cpu_vip_VIP_RUSER_WIDTH,
        axil_cpu_vip_VIP_SUPPORTS_NARROW,
        axil_cpu_vip_VIP_HAS_BURST,
        axil_cpu_vip_VIP_HAS_LOCK,
        axil_cpu_vip_VIP_HAS_CACHE,
        axil_cpu_vip_VIP_HAS_REGION,
        axil_cpu_vip_VIP_HAS_PROT,
        axil_cpu_vip_VIP_HAS_QOS,
        axil_cpu_vip_VIP_HAS_WSTRB,
        axil_cpu_vip_VIP_HAS_BRESP,
        axil_cpu_vip_VIP_HAS_RRESP,
        axil_cpu_vip_VIP_HAS_ARESETN
    ) axil_cpu_vif;

    virtual interface axi_vip_if #(
        ext_m0_vip_VIP_PROTOCOL,
        ext_m0_vip_VIP_ADDR_WIDTH,
        ext_m0_vip_VIP_DATA_WIDTH,
        ext_m0_vip_VIP_DATA_WIDTH,
        ext_m0_vip_VIP_ID_WIDTH,
        ext_m0_vip_VIP_ID_WIDTH,
        ext_m0_vip_VIP_AWUSER_WIDTH,
        ext_m0_vip_VIP_WUSER_WIDTH,
        ext_m0_vip_VIP_BUSER_WIDTH,
        ext_m0_vip_VIP_ARUSER_WIDTH,
        ext_m0_vip_VIP_RUSER_WIDTH,
        ext_m0_vip_VIP_SUPPORTS_NARROW,
        ext_m0_vip_VIP_HAS_BURST,
        ext_m0_vip_VIP_HAS_LOCK,
        ext_m0_vip_VIP_HAS_CACHE,
        ext_m0_vip_VIP_HAS_REGION,
        ext_m0_vip_VIP_HAS_PROT,
        ext_m0_vip_VIP_HAS_QOS,
        ext_m0_vip_VIP_HAS_WSTRB,
        ext_m0_vip_VIP_HAS_BRESP,
        ext_m0_vip_VIP_HAS_RRESP,
        ext_m0_vip_VIP_HAS_ARESETN
    ) ext_m0_vif;

    virtual interface axi_vip_if #(
        ext_m1_vip_VIP_PROTOCOL,
        ext_m1_vip_VIP_ADDR_WIDTH,
        ext_m1_vip_VIP_DATA_WIDTH,
        ext_m1_vip_VIP_DATA_WIDTH,
        ext_m1_vip_VIP_ID_WIDTH,
        ext_m1_vip_VIP_ID_WIDTH,
        ext_m1_vip_VIP_AWUSER_WIDTH,
        ext_m1_vip_VIP_WUSER_WIDTH,
        ext_m1_vip_VIP_BUSER_WIDTH,
        ext_m1_vip_VIP_ARUSER_WIDTH,
        ext_m1_vip_VIP_RUSER_WIDTH,
        ext_m1_vip_VIP_SUPPORTS_NARROW,
        ext_m1_vip_VIP_HAS_BURST,
        ext_m1_vip_VIP_HAS_LOCK,
        ext_m1_vip_VIP_HAS_CACHE,
        ext_m1_vip_VIP_HAS_REGION,
        ext_m1_vip_VIP_HAS_PROT,
        ext_m1_vip_VIP_HAS_QOS,
        ext_m1_vip_VIP_HAS_WSTRB,
        ext_m1_vip_VIP_HAS_BRESP,
        ext_m1_vip_VIP_HAS_RRESP,
        ext_m1_vip_VIP_HAS_ARESETN
    ) ext_m1_vif;

    virtual interface axi_vip_if #(
        mem0_vip_VIP_PROTOCOL,
        mem0_vip_VIP_ADDR_WIDTH,
        mem0_vip_VIP_DATA_WIDTH,
        mem0_vip_VIP_DATA_WIDTH,
        mem0_vip_VIP_ID_WIDTH,
        mem0_vip_VIP_ID_WIDTH,
        mem0_vip_VIP_AWUSER_WIDTH,
        mem0_vip_VIP_WUSER_WIDTH,
        mem0_vip_VIP_BUSER_WIDTH,
        mem0_vip_VIP_ARUSER_WIDTH,
        mem0_vip_VIP_RUSER_WIDTH,
        mem0_vip_VIP_SUPPORTS_NARROW,
        mem0_vip_VIP_HAS_BURST,
        mem0_vip_VIP_HAS_LOCK,
        mem0_vip_VIP_HAS_CACHE,
        mem0_vip_VIP_HAS_REGION,
        mem0_vip_VIP_HAS_PROT,
        mem0_vip_VIP_HAS_QOS,
        mem0_vip_VIP_HAS_WSTRB,
        mem0_vip_VIP_HAS_BRESP,
        mem0_vip_VIP_HAS_RRESP,
        mem0_vip_VIP_HAS_ARESETN
    ) mem0_vif;

    virtual interface axi_vip_if #(
        mem1_vip_VIP_PROTOCOL,
        mem1_vip_VIP_ADDR_WIDTH,
        mem1_vip_VIP_DATA_WIDTH,
        mem1_vip_VIP_DATA_WIDTH,
        mem1_vip_VIP_ID_WIDTH,
        mem1_vip_VIP_ID_WIDTH,
        mem1_vip_VIP_AWUSER_WIDTH,
        mem1_vip_VIP_WUSER_WIDTH,
        mem1_vip_VIP_BUSER_WIDTH,
        mem1_vip_VIP_ARUSER_WIDTH,
        mem1_vip_VIP_RUSER_WIDTH,
        mem1_vip_VIP_SUPPORTS_NARROW,
        mem1_vip_VIP_HAS_BURST,
        mem1_vip_VIP_HAS_LOCK,
        mem1_vip_VIP_HAS_CACHE,
        mem1_vip_VIP_HAS_REGION,
        mem1_vip_VIP_HAS_PROT,
        mem1_vip_VIP_HAS_QOS,
        mem1_vip_VIP_HAS_WSTRB,
        mem1_vip_VIP_HAS_BRESP,
        mem1_vip_VIP_HAS_RRESP,
        mem1_vip_VIP_HAS_ARESETN
    ) mem1_vif;

    function new(string name = "dma_subsys_vip_cfg");
        super.new(name);
    endfunction

    virtual function bit all_vifs_set();
        return (axil_cpu_vif != null) &&
               (ext_m0_vif   != null) &&
               (ext_m1_vif   != null) &&
               (mem0_vif     != null) &&
               (mem1_vif     != null);
    endfunction

endclass
