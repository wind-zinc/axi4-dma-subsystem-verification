// Covers the largest legal single-RAM extent.  LEN_WIDTH is 20, but the
// configured 64-KiB RAM windows make bit 16 the highest reachable descriptor
// length bit; bits 19:17 are structural configuration constants.
class dma_subsys_legal_extent_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_legal_extent_vseq)

    localparam int unsigned FULL_RAM_BYTES = 65536;

    function new(string name = "dma_subsys_legal_extent_vseq");
        super.new(name);
    endfunction

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // Initialize through EXT0 so both the AMD memory VIP and the
        // independent byte-addressable reference model know all source bytes.
        run_dma_case(
            "full_extent_ram0_to_ram1",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR,
            RAM1_BASE_ADDR,
            FULL_RAM_BYTES,
            8'hFE,
            8'h31);

        // RAM1 now contains known data from the first checked transfer, so no
        // second external initialization is needed for the reverse direction.
        run_dma_case(
            "full_extent_ram1_to_ram0",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR,
            RAM0_BASE_ADDR,
            FULL_RAM_BYTES,
            8'h01,
            8'h31,
            DMA_ERR_NONE,
            1'b0);

        // Return descriptor address and length buses to small complementary
        // values after the full-range all-high state.
        run_dma_case(
            "legal_low_address_complement_ch0",
            DMA_CH0,
            DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_5554,
            RAM0_BASE_ADDR + 32'h0000_AAA8,
            4,
            8'h55,
            8'h42,
            DMA_ERR_NONE,
            1'b0);
        run_dma_case(
            "legal_low_address_complement_ch1",
            DMA_CH1,
            DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_AAA8,
            RAM1_BASE_ADDR + 32'h0000_5554,
            4,
            8'hAA,
            8'h53,
            DMA_ERR_NONE,
            1'b0);

        wait_probe_cycles(5);
    endtask
endclass
