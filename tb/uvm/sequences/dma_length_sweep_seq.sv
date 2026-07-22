/* Deterministically hits all descriptor length coverage classes. */
class dma_length_sweep_seq extends dma_base_seq;

    `uvm_object_utils(dma_length_sweep_seq)

    function new(string name = "dma_length_sweep_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [19:0] lengths[6];

        lengths[0] = 20'd4;
        lengths[1] = 20'd32;
        lengths[2] = 20'd128;
        lengths[3] = 20'd512;
        lengths[4] = 20'd4096;
        lengths[5] = 20'd8192;

        write_reg(REG_CONTROL, 32'h1);

        for (int index = 0; index < 6; index++) begin
            submit_descriptor(16'h1000, 16'h8000,
                              lengths[index], 8'h80 + index);
            check_and_pop_completion(8'h80 + index, lengths[index]);
        end

        `uvm_info("DMA_LENGTH_SWEEP",
            "all descriptor length classes completed", UVM_LOW)
    endtask

endclass
