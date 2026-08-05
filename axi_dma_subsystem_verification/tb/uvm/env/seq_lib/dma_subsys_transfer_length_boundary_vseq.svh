class dma_subsys_transfer_length_boundary_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_transfer_length_boundary_vseq)

    function new(string name = "dma_subsys_transfer_length_boundary_vseq");
        super.new(name);
    endfunction

    virtual task body();
        int unsigned lengths[11];
        dma_channel_e source_ch;
        dma_channel_e dest_ch;
        logic [AXI_ADDR_WIDTH-1:0] ram_base;
        logic [AXI_ADDR_WIDTH-1:0] source_address;
        logic [AXI_ADDR_WIDTH-1:0] destination_address;

        lengths = '{1, 2, 3, 4, 5, 16, 17, 64, 65, 256, 1024};
        wait_for_infrastructure();
        prepare_subsystem();

        foreach (lengths[index]) begin
            source_ch = (index[0] == 1'b0) ? DMA_CH0 : DMA_CH1;
            dest_ch = (index[1] == 1'b0) ? DMA_CH0 : DMA_CH1;
            ram_base = (index[0] == 1'b0)
                ? RAM0_BASE_ADDR : RAM1_BASE_ADDR;
            source_address = ram_base + 32'h0000_0100
                + (index * 32'h0000_1000);
            destination_address = ram_base + 32'h0000_0900
                + (index * 32'h0000_1000);
            run_dma_case(
                $sformatf("length_%0d", lengths[index]),
                source_ch, dest_ch, source_address, destination_address,
                lengths[index], byte'(8'h60 + index),
                byte'(8'h20 + index));
        end
        wait_probe_cycles(5);
    endtask
endclass
