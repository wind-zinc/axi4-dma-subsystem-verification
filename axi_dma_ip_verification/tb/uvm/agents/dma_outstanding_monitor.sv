/*
 * Counts accepted AXI bursts that have not completed yet.
 * Read bursts complete on RLAST; write bursts complete on B.
 */
class dma_outstanding_monitor extends uvm_component;

    `uvm_component_utils(dma_outstanding_monitor)

    virtual dma_observer_if vif;
    int unsigned read_level;
    int unsigned write_level;
    int unsigned max_read_level;
    int unsigned max_write_level;
    bit require_read_multiple;
    bit require_write_multiple;

    covergroup outstanding_cg with function sample(
        int unsigned read_count,
        int unsigned write_count
    );
        option.per_instance = 1;
        option.name = "dma_axi_outstanding_cov";

        cp_read: coverpoint read_count {
            bins zero = {0};
            bins one = {1};
            bins multiple = {[2:32]};
        }

        cp_write: coverpoint write_count {
            bins zero = {0};
            bins one = {1};
            bins multiple = {[2:32]};
        }

        read_x_write: cross cp_read, cp_write;
    endgroup

    function new(string name = "dma_outstanding_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
        outstanding_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_observer_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("DMA_OUTSTANDING",
                "dma_observer_if was not configured")
        void'(uvm_config_db#(bit)::get(
            this, "", "require_read_multiple", require_read_multiple));
        void'(uvm_config_db#(bit)::get(
            this, "", "require_write_multiple", require_write_multiple));
    endfunction

    task run_phase(uvm_phase phase);
        bit ar_push;
        bit read_pop;
        bit aw_push;
        bit write_pop;
        int unsigned next_read;
        int unsigned next_write;

        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.rst) begin
                read_level = 0;
                write_level = 0;
                continue;
            end

            ar_push = vif.mon_cb.arvalid && vif.mon_cb.arready;
            read_pop = vif.mon_cb.rvalid && vif.mon_cb.rready &&
                       vif.mon_cb.rlast;
            aw_push = vif.mon_cb.awvalid && vif.mon_cb.awready;
            write_pop = vif.mon_cb.bvalid && vif.mon_cb.bready;

            next_read = read_level;
            case ({ar_push, read_pop})
                2'b10: next_read++;
                2'b01: begin
                    if (read_level == 0)
                        `uvm_error("DMA_OUTSTANDING",
                            "Read outstanding counter underflow")
                    else
                        next_read--;
                end
                default: ;
            endcase

            next_write = write_level;
            case ({aw_push, write_pop})
                2'b10: next_write++;
                2'b01: begin
                    if (write_level == 0)
                        `uvm_error("DMA_OUTSTANDING",
                            "Write outstanding counter underflow")
                    else
                        next_write--;
                end
                default: ;
            endcase

            read_level = next_read;
            write_level = next_write;
            if (read_level > max_read_level)
                max_read_level = read_level;
            if (write_level > max_write_level)
                max_write_level = write_level;
            outstanding_cg.sample(read_level, write_level);
        end
    endtask

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (read_level != 0)
            `uvm_error("DMA_OUTSTANDING", $sformatf(
                "Test ended with %0d incomplete read burst(s)", read_level))
        if (write_level != 0)
            `uvm_error("DMA_OUTSTANDING", $sformatf(
                "Test ended with %0d incomplete write burst(s)", write_level))
        if (require_read_multiple && max_read_level < 2)
            `uvm_error("DMA_OUTSTANDING",
                "Test did not demonstrate multiple read outstanding bursts")
        if (require_write_multiple && max_write_level < 2)
            `uvm_error("DMA_OUTSTANDING",
                "Test did not demonstrate multiple write outstanding bursts")
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("DMA_OUTSTANDING", $sformatf(
            "maximum outstanding bursts: read=%0d write=%0d",
            max_read_level, max_write_level), UVM_LOW)
    endfunction

endclass

