class dma_subsys_axi_burst_shape_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_axi_burst_shape_vseq)

    function new(string name = "dma_subsys_axi_burst_shape_vseq");
        super.new(name);
    endfunction

    protected task run_shape(
        input dma_master_e master,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input int unsigned beat_count,
        input int unsigned bytes_per_beat,
        input xil_axi_burst_t burst,
        input logic [AXI_ID_WIDTH-1:0] transaction_id,
        input byte unsigned seed,
        input string label_text
    );
        bit [8*4096-1:0] payload;
        bit [8*4096-1:0] readback;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(
            payload, beat_count * AXI_STRB_WIDTH, seed);
        external_write_shape(master, transaction_id, address,
            beat_count, bytes_per_beat, burst, payload,
            $sformatf("%s write", label_text));
        external_read_shape(master, transaction_id, address,
            beat_count, bytes_per_beat, burst, readback, responses,
            $sformatf("%s read", label_text));
        check_read_responses(responses, beat_count,
            $sformatf("%s read", label_text));
    endtask

    virtual task body();
        bit [8*4096-1:0] payload;

        wait_for_infrastructure();

        run_shape(DMA_MASTER_EXT0, RAM0_BASE_ADDR + 32'h0000_0800,
            1, 1, XIL_AXI_BURST_TYPE_FIXED, 4'h0, 8'h10,
            "FIXED single byte");
        run_shape(DMA_MASTER_EXT0, RAM0_BASE_ADDR + 32'h0000_0900,
            4, 2, XIL_AXI_BURST_TYPE_FIXED, 4'h3, 8'h20,
            "FIXED multi halfword");
        run_shape(DMA_MASTER_EXT0, RAM0_BASE_ADDR + 32'h0000_1000,
            2, 4, XIL_AXI_BURST_TYPE_WRAP, 4'h1, 8'h30,
            "WRAP two");
        run_shape(DMA_MASTER_EXT0, RAM0_BASE_ADDR + 32'h0000_1100,
            4, 4, XIL_AXI_BURST_TYPE_WRAP, 4'h2, 8'h40,
            "WRAP four");
        run_shape(DMA_MASTER_EXT1, RAM1_BASE_ADDR + 32'h0000_1200,
            8, 4, XIL_AXI_BURST_TYPE_WRAP, 4'h4, 8'h50,
            "WRAP eight");
        run_shape(DMA_MASTER_EXT1, RAM1_BASE_ADDR + 32'h0000_1400,
            16, 4, XIL_AXI_BURST_TYPE_WRAP, 4'h5, 8'h60,
            "WRAP sixteen");
        run_shape(DMA_MASTER_EXT1, RAM1_BASE_ADDR + 32'h0000_2001,
            8, 4, XIL_AXI_BURST_TYPE_INCR, 4'h6, 8'h70,
            "unaligned INCR");
        run_shape(DMA_MASTER_EXT1, RAM1_BASE_ADDR + 32'h0000_2FC0,
            16, 4, XIL_AXI_BURST_TYPE_INCR, 4'h7, 8'h80,
            "boundary-window INCR");
        run_shape(DMA_MASTER_EXT0, RAM0_BASE_ADDR + 32'h0000_4000,
            256, 4, XIL_AXI_BURST_TYPE_INCR, 4'hF, 8'h90,
            "maximum-length INCR");

        // AXI permits a write beat with every byte lane disabled.  Force only
        // the wrapper net for one otherwise ordinary transaction so the
        // memory-side monitor observes the explicit zero-strobe bin.
        build_linear_payload(payload, 4, 8'hA0);
        p_sequencer.test_ctrl_vif.force_ext_wstrb_zero[0] = 1'b1;
        external_write_shape(DMA_MASTER_EXT0, 4'h8,
            RAM0_BASE_ADDR + 32'h0000_6000,
            1, 4, XIL_AXI_BURST_TYPE_INCR, payload,
            "zero-strobe legal write");
        p_sequencer.test_ctrl_vif.force_ext_wstrb_zero[0] = 1'b0;
        wait_probe_cycles(5);
    endtask
endclass
