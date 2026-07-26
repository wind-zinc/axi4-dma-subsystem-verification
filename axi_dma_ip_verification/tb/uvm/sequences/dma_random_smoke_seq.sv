/* One legal randomized descriptor and its completion checks. */
class dma_random_smoke_seq extends dma_base_seq;

    rand bit [15:0] src_addr;
    rand bit [15:0] dst_addr;
    rand bit [19:0] byte_length;
    rand bit [7:0]  tag;

    /*
     * Source and destination occupy separate RAM regions.  Keeping this first
     * test aligned and non-overlapping makes failures easy to diagnose.  More
     * aggressive boundary and invalid cases will override these constraints.
     */
    constraint c_legal_descriptor {
        src_addr inside {[16'h0100:16'h2f00]};
        dst_addr inside {[16'h4000:16'h7f00]};
        src_addr[1:0] == 2'b00;
        dst_addr[1:0] == 2'b00;
        byte_length inside {[20'd4:20'd512]};
        byte_length[1:0] == 2'b00;
        tag != 8'h00;
    }

    `uvm_object_utils_begin(dma_random_smoke_seq)
        `uvm_field_int(src_addr,    UVM_HEX)
        `uvm_field_int(dst_addr,    UVM_HEX)
        `uvm_field_int(byte_length, UVM_DEC)
        `uvm_field_int(tag,         UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "dma_random_smoke_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] value;

        /* Enable the level-sensitive completion interrupt. */
        write_reg(REG_CONTROL, 32'h0000_0001);

        submit_descriptor(src_addr, dst_addr, byte_length, tag);

        read_reg(REG_SUBMITTED_COUNT, value);
        if (value != 1)
            `uvm_error("SUBMITTED_COUNT",
                $sformatf("got %0d expected 1", value))

        /* Gives the queue-level covergroup its first legal sample. */
        read_reg(REG_QUEUE_LEVELS, value);

        check_and_pop_completion(tag, byte_length);

        read_reg(REG_COMPLETED_COUNT, value);
        if (value != 1)
            `uvm_error("COMPLETED_COUNT",
                $sformatf("got %0d expected 1", value))

        `uvm_info("DMA_RANDOM_SMOKE",
            $sformatf("completed src=0x%04h dst=0x%04h len=%0d tag=0x%02h",
                      src_addr, dst_addr, byte_length, tag),
            UVM_LOW)
    endtask

endclass
