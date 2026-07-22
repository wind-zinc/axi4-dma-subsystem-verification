/* Covers none/source/destination/both sides crossing a 4 KB boundary. */
class dma_boundary_matrix_seq extends dma_base_seq;

    `uvm_object_utils(dma_boundary_matrix_seq)

    function new(string name = "dma_boundary_matrix_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] src[4];
        bit [15:0] dst[4];
        bit [31:0] value;

        src[0] = 16'h1100; dst[0] = 16'h5100; /* neither */
        src[1] = 16'h1fe0; dst[1] = 16'h5200; /* source only */
        src[2] = 16'h2200; dst[2] = 16'h5fe0; /* destination only */
        src[3] = 16'h2fe0; dst[3] = 16'h6fe0; /* both */

        write_reg(REG_CONTROL, 32'h1);

        for (int index = 0; index < 4; index++)
            submit_descriptor(src[index], dst[index], 20'd64,
                              8'h40 + index);

        read_reg(REG_QUEUE_LEVELS, value);

        for (int index = 0; index < 4; index++)
            check_and_pop_completion(8'h40 + index, 20'd64);

        `uvm_info("DMA_4K_MATRIX",
            "four source/destination 4 KB boundary combinations completed",
            UVM_LOW)
    endtask

endclass
