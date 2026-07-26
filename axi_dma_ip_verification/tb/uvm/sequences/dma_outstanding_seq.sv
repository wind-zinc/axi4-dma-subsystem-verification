/* Demonstrate more than one accepted, incomplete AXI read and write burst. */
class dma_outstanding_seq extends dma_mem_ral_base_seq;

    `uvm_object_utils(dma_outstanding_seq)

    function new(string name = "dma_outstanding_seq");
        super.new(name);
    endfunction

    virtual task body();
        require_mem_vif();
        mem_vif.clear_all();
        mem_vif.set_outstanding_mode(1'b1);

        /* First hold R to accumulate AR requests.  B remains held after R is
         * released so the write engine can accumulate incomplete AW bursts. */
        mem_vif.set_stalls(1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
        ral_write(ral.control, 32'h1);
        ral_submit_descriptor(16'h0000, 16'h8000, 20'd8192, 8'hf0);

        repeat (60) @(posedge mem_vif.clk);
        mem_vif.set_stalls(1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
        repeat (200) @(posedge mem_vif.clk);
        mem_vif.clear_stalls();

        check_and_pop_completion(8'hf0, 20'd8192);

        /*
         * Target the outstanding cross bin:
         *
         *     cp_read[zero] x cp_write[multiple]
         *
         * A short four-burst transfer fits completely in the proxy queues.
         * Keep R flowing so every read burst can finish, but hold B so at
         * least two accepted write bursts remain incomplete at the same
         * time.  The monitor then observes read_level == 0 and
         * write_level >= 2 before B responses are released.
         */
        mem_vif.set_stalls(1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
        ral_submit_descriptor(16'h2000, 16'h4000, 20'd256, 8'hf1);

        repeat (200) @(posedge mem_vif.clk);
        mem_vif.clear_stalls();

        check_and_pop_completion(8'hf1, 20'd256);

        /* Mode changes only after every DUT-side response has completed. */
        mem_vif.set_outstanding_mode(1'b0);
    endtask

endclass
