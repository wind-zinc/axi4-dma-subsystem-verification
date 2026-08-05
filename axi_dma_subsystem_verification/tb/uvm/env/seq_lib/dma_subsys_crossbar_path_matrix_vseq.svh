class dma_subsys_crossbar_path_matrix_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_crossbar_path_matrix_vseq)

    function new(string name = "dma_subsys_crossbar_path_matrix_vseq");
        super.new(name);
    endfunction

    protected task exercise_external_path(
        input dma_master_e master,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input byte unsigned seed,
        input string label_text
    );
        bit [8*4096-1:0] payload;
        bit [8*4096-1:0] readback;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(payload, 16, seed);
        external_write(master, address, 4, payload,
            $sformatf("%s write", label_text));
        external_read(master, address, 4, readback, responses,
            $sformatf("%s read", label_text));
        check_read_responses(responses, 4,
            $sformatf("%s read", label_text));
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // All EXT-master/target/read-write combinations.
        exercise_external_path(DMA_MASTER_EXT0,
            RAM0_BASE_ADDR + 32'h0000_0100, 8'h10, "EXT0-RAM0");
        exercise_external_path(DMA_MASTER_EXT0,
            RAM1_BASE_ADDR + 32'h0000_0100, 8'h20, "EXT0-RAM1");
        exercise_external_path(DMA_MASTER_EXT1,
            RAM0_BASE_ADDR + 32'h0000_0200, 8'h30, "EXT1-RAM0");
        exercise_external_path(DMA_MASTER_EXT1,
            RAM1_BASE_ADDR + 32'h0000_0200, 8'h40, "EXT1-RAM1");

        // Four route combinations chosen so each DMA-side AXI master also
        // reads and writes both RAM targets across the complete set.
        run_dma_case("matrix_ch0_ch0", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_3000,
            RAM1_BASE_ADDR + 32'h0000_3800,
            64, 8'h50, 8'h51);
        run_dma_case("matrix_ch0_ch1", DMA_CH0, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_4000,
            RAM0_BASE_ADDR + 32'h0000_4800,
            64, 8'h51, 8'h62);
        run_dma_case("matrix_ch1_ch0", DMA_CH1, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_5000,
            RAM0_BASE_ADDR + 32'h0000_5800,
            64, 8'h52, 8'h73);
        run_dma_case("matrix_ch1_ch1", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_6000,
            RAM1_BASE_ADDR + 32'h0000_6800,
            64, 8'h53, 8'h84);
        wait_probe_cycles(5);
    endtask
endclass
