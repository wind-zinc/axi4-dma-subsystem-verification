/*
 * White-box write-engine coverage sequence.
 *
 * Normal descriptors cover partial final beats, a partial transfer crossing a
 * 4 KiB boundary, and write-response accumulation.  Two short fault-injection
 * phases exercise the vendor core's malformed AXI-Stream recovery states.
 * The force operations affect simulation only and are always released.
 */
class dma_write_engine_corner_seq extends dma_mem_ral_base_seq;

    `uvm_object_utils(dma_write_engine_corner_seq)

    virtual dma_reset_if reset_vif;

    localparam string WRITE_VALID_PATH =
        "tb_uvm_top.dut.dma_write_tvalid";
    localparam string WRITE_READY_PATH =
        "tb_uvm_top.dut.dma_write_tready";
    localparam string WRITE_LAST_PATH =
        "tb_uvm_top.dut.dma_write_tlast";
    localparam string SHIFT_VALID_PATH =
        "tb_uvm_top.dut.axi_dma_inst.axi_dma_wr_inst.shift_axis_tvalid";
    localparam string SHIFT_LAST_PATH =
        "tb_uvm_top.dut.axi_dma_inst.axi_dma_wr_inst.shift_axis_tlast";
    localparam string WRITE_STATE_PATH =
        "tb_uvm_top.dut.axi_dma_inst.axi_dma_wr_inst.state_reg";

    localparam bit [2:0] STATE_IDLE         = 3'd0;
    localparam bit [2:0] STATE_FINISH_BURST = 3'd3;
    localparam bit [2:0] STATE_DROP_DATA    = 3'd4;

    function new(string name = "dma_write_engine_corner_seq");
        super.new(name);
    endfunction

    virtual function void require_hdl_paths();
        if (!uvm_hdl_check_path(WRITE_VALID_PATH) ||
            !uvm_hdl_check_path(WRITE_READY_PATH) ||
            !uvm_hdl_check_path(WRITE_LAST_PATH) ||
            !uvm_hdl_check_path(SHIFT_VALID_PATH) ||
            !uvm_hdl_check_path(SHIFT_LAST_PATH) ||
            !uvm_hdl_check_path(WRITE_STATE_PATH))
            `uvm_fatal("WRITE_COV_PATH",
                "one or more axi_dma_wr backdoor paths are unavailable")
    endfunction

    virtual task read_path(
        input string path,
        output uvm_hdl_data_t value
    );
        if (!uvm_hdl_read(path, value))
            `uvm_fatal("WRITE_COV_READ",
                $sformatf("uvm_hdl_read failed for %s", path))
    endtask

    virtual task force_path(
        input string path,
        input uvm_hdl_data_t value
    );
        if (!uvm_hdl_force(path, value))
            `uvm_fatal("WRITE_COV_FORCE",
                $sformatf("uvm_hdl_force failed for %s", path))
    endtask

    virtual task release_path(input string path);
        if (!uvm_hdl_release(path))
            `uvm_fatal("WRITE_COV_RELEASE",
                $sformatf("uvm_hdl_release failed for %s", path))
    endtask

    /* Override shift_axis_tlast for one accepted input beat. */
    virtual task override_last_on_handshake(
        input bit required_original_last,
        input bit forced_last,
        input int unsigned handshakes_to_skip = 0
    );
        uvm_hdl_data_t valid_value;
        uvm_hdl_data_t ready_value;
        uvm_hdl_data_t last_value;
        uvm_hdl_data_t force_value;
        int unsigned skipped = 0;

        repeat (5000) begin
            @(negedge mem_vif.clk);
            read_path(WRITE_VALID_PATH, valid_value);
            read_path(WRITE_READY_PATH, ready_value);
            read_path(WRITE_LAST_PATH, last_value);

            if (valid_value[0] && ready_value[0] &&
                    last_value[0] == required_original_last) begin
                if (skipped < handshakes_to_skip) begin
                    skipped++;
                end else begin
                    force_value = '0;
                    force_value[0] = forced_last;
                    force_path(SHIFT_LAST_PATH, force_value);
                    @(posedge mem_vif.clk);
                    @(negedge mem_vif.clk);
                    release_path(SHIFT_LAST_PATH);
                    return;
                end
            end
        end

        `uvm_fatal("WRITE_COV_TIMEOUT",
            "did not find the requested AXI-Stream handshake")
    endtask

    virtual task wait_write_state(
        input bit [2:0] expected_state,
        input int unsigned maximum_cycles = 200
    );
        uvm_hdl_data_t state_value;

        repeat (maximum_cycles) begin
            @(negedge mem_vif.clk);
            read_path(WRITE_STATE_PATH, state_value);
            if (state_value[2:0] == expected_state)
                return;
        end

        `uvm_fatal("WRITE_STATE_TIMEOUT", $sformatf(
            "axi_dma_wr did not reach state %0d", expected_state))
    endtask

    /* Supply a synthetic TLAST only to the write core's drop-state logic. */
    virtual task terminate_drop_state();
        uvm_hdl_data_t one_value;
        one_value = '0;
        one_value[0] = 1'b1;

        force_path(SHIFT_VALID_PATH, one_value);
        force_path(SHIFT_LAST_PATH, one_value);
        @(posedge mem_vif.clk);
        @(negedge mem_vif.clk);
        release_path(SHIFT_LAST_PATH);
        release_path(SHIFT_VALID_PATH);
    endtask

    virtual task run_partial_length_cases();
        bit [19:0] lengths[6];

        lengths[0] = 20'd5;
        lengths[1] = 20'd6;
        lengths[2] = 20'd7;
        lengths[3] = 20'd9;
        lengths[4] = 20'd63;
        lengths[5] = 20'd65;

        for (int unsigned index = 0; index < 6; index++) begin
            ral_submit_descriptor(
                16'h2000 + index*16'h0100,
                16'h8000 + index*16'h0100,
                lengths[index],
                8'h60 + index
            );
            check_and_pop_completion(8'h60 + index, lengths[index]);
        end

        /* Aligned destination, partial final beat, and destination-side 4 KiB
         * burst split in the same operation. */
        ral_submit_descriptor(16'h5000, 16'h0ffc, 20'd69, 8'h66);
        check_and_pop_completion(8'h66, 20'd69);
    endtask

    virtual task run_long_toggle_case();
        /* Exercise the highest reachable length bit, repeated burst
         * scheduling, FIFO pointer wrap, and long-running byte counters.
         * Two adjacent 32768-byte ranges exactly fill the 64 KiB map without
         * overlap: [0x0000,0x8000) -> [0x8000,0x10000).  LEN[15] is therefore
         * reachable; LEN[19:16] is structurally unreachable in this fixed
         * 16-bit-address, non-overlap configuration. */
        ral_submit_descriptor(16'h0000, 16'h8000, 20'd32768, 8'h6a);
        check_and_pop_completion(8'h6a, 20'd32768);
    endtask

    virtual task fill_write_status_capacity();
        mem_vif.set_outstanding_mode(1'b1);
        /* Accumulate B responses while AR/R/AW/W continue.  The 4096-byte
         * descriptor contains 64 bursts, exceeding the write core's 32-entry
         * active/status capacity and exercising its wait path. */
        mem_vif.set_stalls(1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
        ral_submit_descriptor(16'h0000, 16'h8000, 20'd4096, 8'h67);
        repeat (900) @(posedge mem_vif.clk);
        mem_vif.clear_stalls();
        check_and_pop_completion(8'h67, 20'd4096);
        mem_vif.set_outstanding_mode(1'b0);
    endtask

    virtual task exercise_finish_burst_state();
        /* Prevent B completion from reaching the manager while an early TLAST
         * is injected.  FINISH_BURST pads the current AXI burst with WSTRB=0;
         * reset then discards the intentionally incomplete descriptor. */
        mem_vif.set_stalls(1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
        ral_submit_descriptor(16'h3000, 16'ha000, 20'd128, 8'h68);
        mem_vif.set_stalls(1'b0, 1'b0, 1'b1, 1'b0, 1'b0);

        override_last_on_handshake(1'b0, 1'b1, 2);
        wait_write_state(STATE_FINISH_BURST);
        wait_write_state(STATE_IDLE, 100);

        reset_vif.pulse(4);
        mem_vif.clear_all();
        ral.reset();
        repeat (2) @(posedge mem_vif.clk);
    endtask

    virtual task exercise_drop_data_state();
        /* Suppress the real final TLAST for one beat.  The write engine has
         * completed the requested byte count but waits in DROP_DATA for the
         * packet boundary.  A synthetic internal TLAST releases that state. */
        mem_vif.set_stalls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
        ral_write(ral.control, 32'h1);
        ral_submit_descriptor(16'h4000, 16'hb000, 20'd128, 8'h69);
        mem_vif.clear_stalls();

        override_last_on_handshake(1'b1, 1'b0, 0);
        wait_write_state(STATE_DROP_DATA);
        terminate_drop_state();
        wait_write_state(STATE_IDLE);
        check_and_pop_completion(8'h69, 20'd128);
    endtask

    virtual task body();
        require_mem_vif();
        if (reset_vif == null)
            `uvm_fatal("NO_RESET_VIF", "reset virtual interface is null")
        require_hdl_paths();

        mem_vif.clear_all();
        ral_write(ral.control, 32'h1);

        run_partial_length_cases();
        run_long_toggle_case();
        fill_write_status_capacity();
        exercise_finish_burst_state();
        exercise_drop_data_state();

        mem_vif.clear_all();
    endtask

endclass
