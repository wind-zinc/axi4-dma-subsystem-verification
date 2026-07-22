typedef enum int unsigned {
    DMA_READ_SLVERR,
    DMA_READ_DECERR,
    DMA_WRITE_SLVERR,
    DMA_WRITE_DECERR
} dma_error_mode_e;

/* Injects one architecturally valid AXI error and checks its completion. */
class dma_error_response_seq extends dma_mem_ral_base_seq;

    `uvm_object_utils(dma_error_response_seq)

    dma_error_mode_e mode = DMA_READ_SLVERR;

    function new(string name = "dma_error_response_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] src_addr = 16'h1000;
        bit [15:0] dst_addr = 16'h7000;
        bit [19:0] byte_length = 20'd64;
        bit [7:0] tag;
        bit [3:0] expected_read_error;
        bit [3:0] expected_write_error;
        bit [7:0] actual_tag;
        bit [19:0] actual_length;
        bit [10:0] actual_status;
        uvm_reg_data_t status_value;

        require_mem_vif();
        mem_vif.clear_all();

        expected_read_error  = 4'h0;
        expected_write_error = 4'h0;
        tag = 8'he0 + mode;

        case (mode)
            DMA_READ_SLVERR: begin
                expected_read_error = 4'h4;
                mem_vif.set_read_fault(src_addr, 16'hffff, 2'b10);
            end
            DMA_READ_DECERR: begin
                expected_read_error = 4'h5;
                mem_vif.set_read_fault(src_addr, 16'hffff, 2'b11);
            end
            DMA_WRITE_SLVERR: begin
                expected_write_error = 4'h6;
                mem_vif.set_write_fault(dst_addr, 16'hffff, 2'b10);
            end
            DMA_WRITE_DECERR: begin
                expected_write_error = 4'h7;
                mem_vif.set_write_fault(dst_addr, 16'hffff, 2'b11);
            end
            default:
                `uvm_fatal("BAD_ERROR_MODE", "unsupported error mode")
        endcase

        /* Enable IRQ.  Completion fields are read before the FIFO is popped. */
        ral_write(ral.control, 32'h1);
        ral_submit_descriptor(src_addr, dst_addr, byte_length, tag);
        ral_read_completion(actual_tag, actual_length, actual_status);

        if (actual_tag != tag)
            `uvm_error("ERROR_COMP_TAG",
                $sformatf("got 0x%0h expected 0x%0h", actual_tag, tag))

        if (actual_length != byte_length)
            `uvm_error("ERROR_COMP_LENGTH",
                $sformatf("got %0d expected %0d",
                          actual_length, byte_length))

        if (actual_status[3:0] != expected_read_error ||
                actual_status[7:4] != expected_write_error ||
                actual_status[10:8] != 3'b000)
            `uvm_error("ERROR_COMP_STATUS",
                $sformatf("got 0x%03h expected read=%0h write=%0h",
                          actual_status, expected_read_error,
                          expected_write_error))

        if (mode inside {DMA_READ_SLVERR, DMA_READ_DECERR}) begin
            if (mem_vif.read_fault_hits == 0)
                `uvm_error("READ_FAULT_MISS",
                    "configured read address was not observed")
        end else begin
            if (mem_vif.write_fault_hits == 0)
                `uvm_error("WRITE_FAULT_MISS",
                    "configured write address was not observed")
        end

        ral_pop_completion();
        ral_read(ral.status, status_value);
        if (status_value[4] || status_value[6])
            `uvm_error("ERROR_COMP_POP",
                $sformatf("completion/IRQ remained active: 0x%08h",
                          status_value))

        mem_vif.clear_all();
    endtask

endclass

