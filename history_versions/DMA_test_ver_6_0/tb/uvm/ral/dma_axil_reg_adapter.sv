/* Converts generic UVM register operations to the AXI-Lite bus item. */
class dma_axil_reg_adapter extends uvm_reg_adapter;

    `uvm_object_utils(dma_axil_reg_adapter)

    function new(string name = "dma_axil_reg_adapter");
        super.new(name);
        supports_byte_enable = 1;
        provides_responses   = 0;
    endfunction

    virtual function uvm_sequence_item reg2bus(
        const ref uvm_reg_bus_op rw
    );
        axil_item tr;

        tr = axil_item::type_id::create("ral_axil_tr");
        tr.op   = rw.kind == UVM_WRITE ? AXIL_WRITE : AXIL_READ;
        tr.addr = rw.addr[AXIL_ADDR_WIDTH-1:0];

        if (rw.kind == UVM_WRITE) begin
            tr.wdata = rw.data[AXIL_DATA_WIDTH-1:0];
            tr.wstrb = rw.byte_en[AXIL_STRB_WIDTH-1:0];
        end else begin
            tr.wdata = '0;
            tr.wstrb = '0;
        end

        return tr;
    endfunction

    virtual function void bus2reg(
        uvm_sequence_item bus_item,
        ref uvm_reg_bus_op rw
    );
        axil_item tr;

        if (!$cast(tr, bus_item)) begin
            `uvm_fatal("RAL_ADAPTER",
                "bus item is not an axil_item")
            return;
        end

        rw.kind    = tr.op == AXIL_WRITE ? UVM_WRITE : UVM_READ;
        rw.addr    = tr.addr;
        rw.data    = tr.op == AXIL_WRITE ? tr.wdata : tr.rdata;
        rw.byte_en = tr.op == AXIL_WRITE ? tr.wstrb : '1;
        rw.status  = tr.resp == 2'b00 ? UVM_IS_OK : UVM_NOT_OK;
    endfunction

endclass
