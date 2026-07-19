/*
 * Reusable register-level sequence helpers.
 *
 * This class intentionally accesses registers through axil_item instead of
 * reaching into the DUT.  A later RAL adapter will generate the same items,
 * so the agent and the coverage subscriber do not need to change.
 */
class dma_base_seq extends uvm_sequence #(axil_item);

    `uvm_object_utils(dma_base_seq)

    localparam int unsigned MAX_STATUS_POLLS = 5000;

    function new(string name = "dma_base_seq");
        super.new(name);
    endfunction

    virtual task write_reg(
        bit [AXIL_ADDR_WIDTH-1:0] addr,
        bit [AXIL_DATA_WIDTH-1:0] data,
        bit [AXIL_STRB_WIDTH-1:0] strb = '1
    );
        axil_item tr;

        tr = axil_item::type_id::create("write_tr");
        start_item(tr);
        tr.op    = AXIL_WRITE;
        tr.addr  = addr;
        tr.wdata = data;
        tr.wstrb = strb;
        finish_item(tr);

        if (!tr.is_okay())
            `uvm_error("AXIL_WRITE",
                $sformatf("Write failed: %s", tr.convert2string()))
    endtask

    virtual task read_reg(
        bit [AXIL_ADDR_WIDTH-1:0] addr,
        output bit [AXIL_DATA_WIDTH-1:0] data
    );
        axil_item tr;

        tr = axil_item::type_id::create("read_tr");
        start_item(tr);
        tr.op    = AXIL_READ;
        tr.addr  = addr;
        tr.wdata = '0;
        tr.wstrb = '0;
        finish_item(tr);

        data = tr.rdata;
        if (!tr.is_okay())
            `uvm_error("AXIL_READ",
                $sformatf("Read failed: %s", tr.convert2string()))
    endtask

    virtual task submit_descriptor(
        bit [15:0] src_addr,
        bit [15:0] dst_addr,
        bit [19:0] byte_length,
        bit [7:0]  tag
    );
        write_reg(REG_SRC_ADDR, src_addr);
        write_reg(REG_DST_ADDR, dst_addr);
        write_reg(REG_LENGTH, byte_length);
        write_reg(REG_TAG, tag);
        write_reg(REG_SUBMIT, 32'h0000_0001);
    endtask

    virtual task wait_for_completion();
        bit [31:0] status;

        repeat (MAX_STATUS_POLLS) begin
            read_reg(REG_STATUS, status);
            if (status[4])
                return;
        end

        `uvm_fatal("DMA_TIMEOUT",
            "Completion FIFO did not become valid")
    endtask

    virtual task check_and_pop_completion(
        bit [7:0]  expected_tag,
        bit [19:0] expected_length
    );
        bit [31:0] value;

        wait_for_completion();

        read_reg(REG_COMP_TAG, value);
        if (value[7:0] != expected_tag)
            `uvm_error("COMP_TAG",
                $sformatf("got 0x%0h expected 0x%0h",
                          value[7:0], expected_tag))

        read_reg(REG_COMP_LENGTH, value);
        if (value[19:0] != expected_length)
            `uvm_error("COMP_LENGTH",
                $sformatf("got %0d expected %0d",
                          value[19:0], expected_length))

        read_reg(REG_COMP_STATUS, value);
        if (value[10:0] != 0)
            `uvm_error("COMP_STATUS",
                $sformatf("completion status is 0x%08h", value))

        write_reg(REG_COMP_POP, 32'h0000_0001);

        /* Confirm that the only completion was removed and IRQ fell. */
        read_reg(REG_STATUS, value);
        if (value[4] || value[6])
            `uvm_error("COMP_POP",
                $sformatf("completion/IRQ remained active: 0x%08h", value))
    endtask

    virtual task body();
        `uvm_fatal("BASE_SEQ", "dma_base_seq must be extended")
    endtask

endclass
