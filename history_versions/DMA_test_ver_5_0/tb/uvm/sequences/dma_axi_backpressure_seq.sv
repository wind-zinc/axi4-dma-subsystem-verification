/* Pauses each AXI memory channel and verifies forward progress afterwards. */
class dma_axi_backpressure_seq extends dma_mem_ral_base_seq;

    `uvm_object_utils(dma_axi_backpressure_seq)

    function new(string name = "dma_axi_backpressure_seq");
        super.new(name);
    endfunction

    virtual task run_stalled_transfer(
        input bit stall_aw,
        input bit stall_w,
        input bit stall_b,
        input bit stall_ar,
        input bit stall_r,
        input int unsigned stall_cycles,
        input bit [15:0] src_addr,
        input bit [15:0] dst_addr,
        input bit [19:0] byte_length,
        input bit [7:0] tag
    );
        mem_vif.set_stalls(stall_aw, stall_w, stall_b,
                           stall_ar, stall_r);
        fork
            mem_vif.release_stalls_after(stall_cycles);
            ral_submit_descriptor(src_addr, dst_addr, byte_length, tag);
        join
        check_and_pop_completion(tag, byte_length);
    endtask

    virtual task body();
        require_mem_vif();
        mem_vif.clear_all();
        ral_write(ral.control, 32'h1);

        run_stalled_transfer(1, 0, 0, 0, 0, 16,
                             16'h1000, 16'h8000, 20'd128, 8'hb0);
        /* A long W stall lets the read side fill the internal AXIS FIFO. */
        run_stalled_transfer(0, 1, 0, 0, 0, 80,
                             16'h1200, 16'h8200, 20'd512, 8'hb1);
        run_stalled_transfer(0, 0, 1, 0, 0, 20,
                             16'h1600, 16'h8600, 20'd128, 8'hb2);
        run_stalled_transfer(0, 0, 0, 1, 0, 20,
                             16'h1800, 16'h8800, 20'd128, 8'hb3);
        run_stalled_transfer(0, 0, 0, 0, 1, 24,
                             16'h1a00, 16'h8a00, 20'd128, 8'hb4);

        mem_vif.clear_all();
    endtask

endclass

