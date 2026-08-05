class dma_subsys_ch1_to_ch0_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_ch1_to_ch0_vseq)

    function new(string name = "dma_subsys_ch1_to_ch0_vseq");
        super.new(name);
    endfunction

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();
        run_dma_case(
            "ch1_to_ch0", DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_1400,
            RAM0_BASE_ADDR + 32'h0000_2400,
            96, 8'h42, 8'h61);
        wait_probe_cycles(5);
    endtask
endclass
