// First concrete user of the subsystem RAL frontdoor.
//
// The register model, adapter, AXI-Lite sequencer/driver and passive
// predictor were already connected by dma_subsys_env.  This sequence proves
// that chain with stable RW registers and all three mapped register blocks.
class dma_subsys_ral_smoke_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_ral_smoke_vseq)

    function new(string name = "dma_subsys_ral_smoke_vseq");
        super.new(name);
    endfunction

    protected task require_okay(
        input uvm_status_e status,
        input string       operation
    );
        if (status != UVM_IS_OK) begin
            `uvm_error(
                "RAL_ACCESS",
                $sformatf(
                    "%s returned UVM status %0d",
                    operation,
                    status))
        end
    endtask

    protected task ral_write(
        input uvm_reg        target_reg,
        input uvm_reg_data_t value,
        input string         operation
    );
        uvm_status_e status;

        target_reg.write(
            status,
            value,
            UVM_FRONTDOOR,
            p_sequencer.ral.default_map,
            this);
        require_okay(status, operation);
    endtask

    protected task ral_read(
        input uvm_reg          target_reg,
        output uvm_reg_data_t value,
        input string           operation
    );
        uvm_status_e status;

        target_reg.read(
            status,
            value,
            UVM_FRONTDOOR,
            p_sequencer.ral.default_map,
            this);
        require_okay(status, operation);
    endtask

    protected function void check_value(
        input uvm_reg_data_t actual,
        input uvm_reg_data_t expected,
        input string         operation
    );
        if (actual != expected) begin
            `uvm_error(
                "RAL_DATA",
                $sformatf(
                    "%s expected 0x%08h got 0x%08h",
                    operation,
                    expected,
                    actual))
        end
    endfunction

    protected task wait_for_mirror(
        input uvm_reg        target_reg,
        input uvm_reg_data_t expected,
        input string         operation
    );
        uvm_reg_data_t mirrored;

        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.vip_timeout_cycles; cycle++) begin
            mirrored = target_reg.get_mirrored_value();
            if (mirrored == expected) begin
                return;
            end
            wait_probe_cycles(1);
        end

        `uvm_error(
            "RAL_PREDICT_TIMEOUT",
            $sformatf(
                "%s expected mirror 0x%08h got 0x%08h",
                operation,
                expected,
                target_reg.get_mirrored_value()))
    endtask

    virtual task body();
        uvm_reg_data_t value;

        wait_for_infrastructure();

        // Channel 0 submap: base 0x0000_0000 + offset 0x008.
        ral_write(
            p_sequencer.ral.channel[0].src_addr,
            32'h0000_4000,
            "write CH0 SRC_ADDR through RAL");

        // Auto prediction is disabled.  The mirror must be updated by the
        // passive AXI-Lite VIP monitor and uvm_reg_predictor.
        wait_for_mirror(
            p_sequencer.ral.channel[0].src_addr,
            32'h0000_4000,
            "predict CH0 SRC_ADDR mirror");

        ral_read(
            p_sequencer.ral.channel[0].src_addr,
            value,
            "read CH0 SRC_ADDR through RAL");
        check_value(
            value,
            32'h0000_4000,
            "check CH0 SRC_ADDR readback");

        // Channel 1 submap: base 0x0000_1000 + offset 0x008.
        ral_write(
            p_sequencer.ral.channel[1].src_addr,
            32'h1000_4000,
            "write CH1 SRC_ADDR through RAL");
        ral_read(
            p_sequencer.ral.channel[1].src_addr,
            value,
            "read CH1 SRC_ADDR through RAL");
        check_value(
            value,
            32'h1000_4000,
            "check CH1 SRC_ADDR readback");

        // Exercise one more RW register in each channel map.
        ral_write(
            p_sequencer.ral.channel[0].route,
            32'd1,
            "write CH0 ROUTE through RAL");
        ral_write(
            p_sequencer.ral.channel[1].route,
            32'd0,
            "write CH1 ROUTE through RAL");

        ral_read(
            p_sequencer.ral.channel[0].route,
            value,
            "read CH0 ROUTE through RAL");
        check_value(value, 32'd1, "check CH0 ROUTE readback");

        ral_read(
            p_sequencer.ral.channel[1].route,
            value,
            "read CH1 ROUTE through RAL");
        check_value(value, 32'd0, "check CH1 ROUTE readback");

        // Read all three version registers to prove channel/global mapping.
        ral_read(
            p_sequencer.ral.channel[0].version,
            value,
            "read CH0 VERSION through RAL");
        check_value(value, VERSION_VALUE, "check CH0 VERSION");

        ral_read(
            p_sequencer.ral.channel[1].version,
            value,
            "read CH1 VERSION through RAL");
        check_value(value, VERSION_VALUE, "check CH1 VERSION");

        ral_read(
            p_sequencer.ral.global_regs.version,
            value,
            "read global VERSION through RAL");
        check_value(value, VERSION_VALUE, "check global VERSION");

        wait_probe_cycles(2);
        `uvm_info(
            "RAL_SMOKE",
            "RAL frontdoor and passive predictor passed for CH0, CH1 and global register maps",
            UVM_LOW)
    endtask

endclass
