class dma_subsys_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(dma_subsys_reg_adapter)

    function new(string name = "dma_subsys_reg_adapter");
        super.new(name);
        supports_byte_enable = 1;
        provides_responses = 0;
    endfunction

    virtual function uvm_sequence_item reg2bus(
        const ref uvm_reg_bus_op rw
    );
        dma_subsys_reg_tr tr;

        tr = dma_subsys_reg_tr::type_id::create("ral_axil_tr");
        tr.access = (rw.kind == UVM_WRITE)
            ? DMA_ACCESS_WRITE : DMA_ACCESS_READ;
        tr.addr = rw.addr[AXIL_ADDR_WIDTH-1:0];
        tr.data = rw.data[AXIL_DATA_WIDTH-1:0];
        tr.strb = (rw.kind == UVM_WRITE)
            ? rw.byte_en[AXIL_STRB_WIDTH-1:0] : '1;
        tr.resp = DMA_AXI_OKAY;
        tr.normalize();
        return tr;
    endfunction

    virtual function void bus2reg(
        uvm_sequence_item bus_item,
        ref uvm_reg_bus_op rw
    );
        dma_subsys_reg_tr tr;

        if (!$cast(tr, bus_item)) begin
            `uvm_fatal(
                "RAL_ADAPTER",
                "bus item is not a dma_subsys_reg_tr")
            return;
        end

        rw.kind = (tr.access == DMA_ACCESS_WRITE)
            ? UVM_WRITE : UVM_READ;
        rw.addr = tr.addr;
        rw.data = tr.data;
        rw.byte_en = (tr.access == DMA_ACCESS_WRITE) ? tr.strb : '1;
        rw.status = tr.is_okay() ? UVM_IS_OK : UVM_NOT_OK;
    endfunction

endclass
