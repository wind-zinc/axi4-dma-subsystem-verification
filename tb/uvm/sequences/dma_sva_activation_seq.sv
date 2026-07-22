/*
 * Directed activation for the seven stability assertions that were vacuous
 * in the normal regression.  AXI-Lite request stalls use a legal testbench
 * gate; only descriptor READY uses a white-box force because the current
 * subsystem has no external control for descriptor backpressure.
 */
class dma_sva_activation_seq extends dma_base_seq;

    `uvm_object_utils(dma_sva_activation_seq)

    virtual dma_mem_ctrl_if mem_vif;
    virtual dma_sva_ctrl_if sva_ctrl_vif;
    virtual dma_reset_if reset_vif;

    localparam string READ_DESC_READY_REG_PATH =
        "tb_uvm_top.dut.axi_dma_inst.axi_dma_rd_inst.s_axis_read_desc_ready_reg";
    localparam string READ_DESC_READY_NET_PATH =
        "tb_uvm_top.dut.read_desc_ready";
    localparam string READ_DESC_VALID_PATH =
        "tb_uvm_top.dut.read_desc_valid";
    localparam string WRITE_DESC_READY_REG_PATH =
        "tb_uvm_top.dut.axi_dma_inst.axi_dma_wr_inst.s_axis_write_desc_ready_reg";
    localparam string WRITE_DESC_READY_NET_PATH =
        "tb_uvm_top.dut.write_desc_ready";
    localparam string WRITE_DESC_VALID_PATH =
        "tb_uvm_top.dut.write_desc_valid";

    function new(string name = "dma_sva_activation_seq");
        super.new(name);
    endfunction

    virtual function void require_paths();
        if (!uvm_hdl_check_path(READ_DESC_READY_REG_PATH) ||
            !uvm_hdl_check_path(READ_DESC_READY_NET_PATH) ||
            !uvm_hdl_check_path(READ_DESC_VALID_PATH) ||
            !uvm_hdl_check_path(WRITE_DESC_READY_REG_PATH) ||
            !uvm_hdl_check_path(WRITE_DESC_READY_NET_PATH) ||
            !uvm_hdl_check_path(WRITE_DESC_VALID_PATH))
            `uvm_fatal("SVA_PATH",
                "one or more SVA activation backdoor paths are unavailable")
    endfunction

    virtual task force_low(input string path);
        uvm_hdl_data_t value;
        value = '0;
        if (!uvm_hdl_force(path, value))
            `uvm_fatal("SVA_FORCE",
                $sformatf("uvm_hdl_force failed for %s", path))
    endtask

    virtual task release_path(input string path);
        if (!uvm_hdl_release(path))
            `uvm_fatal("SVA_RELEASE",
                $sformatf("uvm_hdl_release failed for %s", path))
    endtask

    virtual task wait_high(input string path);
        uvm_hdl_data_t value;

        repeat (2000) begin
            @(negedge mem_vif.clk);
            if (!uvm_hdl_read(path, value))
                `uvm_fatal("SVA_READ",
                    $sformatf("uvm_hdl_read failed for %s", path))
            if (value[0])
                return;
        end

        `uvm_fatal("SVA_TIMEOUT",
            $sformatf("%s did not assert", path))
    endtask

    /*
     * Force both the engine register and the subsystem-visible net.  This
     * prevents a hidden core handshake and makes the same low READY visible
     * to the descriptor manager and the bound assertion.
     */
    virtual task release_descriptor_after_stall(
        input string ready_reg_path,
        input string ready_net_path,
        input string valid_path,
        input int unsigned cycles = 4
    );
        wait_high(valid_path);
        repeat (cycles) @(posedge mem_vif.clk);
        @(negedge mem_vif.clk);
        release_path(ready_reg_path);
        release_path(ready_net_path);
    endtask

    virtual task force_descriptor_ready_low(
        input string ready_reg_path,
        input string ready_net_path
    );
        force_low(ready_reg_path);
        force_low(ready_net_path);
    endtask

    virtual task release_descriptor_ready(
        input string ready_reg_path,
        input string ready_net_path
    );
        @(negedge mem_vif.clk);
        release_path(ready_reg_path);
        release_path(ready_net_path);
    endtask

    virtual task exercise_axil_request_stability();
        bit [31:0] read_value;

        sva_ctrl_vif.set_request_stalls(1'b1, 1'b0, 1'b0);
        fork
            write_reg(REG_TAG, 32'h0000_0011);
            sva_ctrl_vif.release_after(8);
        join

        sva_ctrl_vif.set_request_stalls(1'b0, 1'b1, 1'b0);
        fork
            write_reg(REG_TAG, 32'h0000_0022);
            sva_ctrl_vif.release_after(8);
        join

        sva_ctrl_vif.set_request_stalls(1'b0, 1'b0, 1'b1);
        fork
            read_reg(REG_STATUS, read_value);
            sva_ctrl_vif.release_after(8);
        join
    endtask

    virtual task write_with_bready_delay(
        input bit [AXIL_ADDR_WIDTH-1:0] addr,
        input bit [AXIL_DATA_WIDTH-1:0] data,
        input int unsigned delay_cycles
    );
        axil_item tr;

        tr = axil_item::type_id::create("delayed_b_tr");
        start_item(tr);
        tr.op             = AXIL_WRITE;
        tr.addr           = addr;
        tr.wdata          = data;
        tr.wstrb          = '1;
        tr.bready_delay   = delay_cycles;
        tr.rready_delay   = 0;
        finish_item(tr);

        if (!tr.is_okay())
            `uvm_error("SVA_DELAYED_B",
                $sformatf("write failed: %s", tr.convert2string()))
    endtask

    virtual task read_with_rready_delay(
        input bit [AXIL_ADDR_WIDTH-1:0] addr,
        input int unsigned delay_cycles
    );
        axil_item tr;

        tr = axil_item::type_id::create("delayed_r_tr");
        start_item(tr);
        tr.op             = AXIL_READ;
        tr.addr           = addr;
        tr.wdata          = '0;
        tr.wstrb          = '0;
        tr.bready_delay   = 0;
        tr.rready_delay   = delay_cycles;
        finish_item(tr);

        if (!tr.is_okay())
            `uvm_error("SVA_DELAYED_R",
                $sformatf("read failed: %s", tr.convert2string()))
    endtask

    virtual task access_with_prot(
        input axil_op_e op,
        input bit [AXIL_ADDR_WIDTH-1:0] addr,
        input bit [AXIL_DATA_WIDTH-1:0] data,
        input bit [2:0] prot
    );
        axil_item tr;

        tr = axil_item::type_id::create("prot_tr");
        start_item(tr);
        tr.op             = op;
        tr.addr           = addr;
        tr.wdata          = op == AXIL_WRITE ? data : '0;
        tr.wstrb          = op == AXIL_WRITE ? '1 : '0;
        tr.prot           = prot;
        tr.bready_delay   = 0;
        tr.rready_delay   = 0;
        finish_item(tr);

        if (!tr.is_okay())
            `uvm_error("AXIL_PROT",
                $sformatf("sideband access failed: %s",
                          tr.convert2string()))
    endtask

    virtual task exercise_axil_prot_toggles();
        /* PROT is legally ignored by this register block, but its interface
         * still accepts all encodings.  000 -> 111 -> 000 toggles every bit
         * in both write- and read-address channels. */
        access_with_prot(AXIL_WRITE, REG_TAG, 32'h0000_0044, 3'b111);
        access_with_prot(AXIL_WRITE, REG_TAG, 32'h0000_0055, 3'b000);
        access_with_prot(AXIL_READ,  REG_STATUS, '0, 3'b111);
        access_with_prot(AXIL_READ,  REG_STATUS, '0, 3'b000);
    endtask

    virtual task exercise_descriptor_stability();
        force_descriptor_ready_low(
            WRITE_DESC_READY_REG_PATH, WRITE_DESC_READY_NET_PATH);
        fork
            submit_descriptor(16'h1000, 16'h8000, 20'd128, 8'hd0);
            release_descriptor_after_stall(
                WRITE_DESC_READY_REG_PATH,
                WRITE_DESC_READY_NET_PATH,
                WRITE_DESC_VALID_PATH);
        join
        check_and_pop_completion(8'hd0, 20'd128);

        force_descriptor_ready_low(
            READ_DESC_READY_REG_PATH, READ_DESC_READY_NET_PATH);
        fork
            submit_descriptor(16'h1200, 16'h8200, 20'd128, 8'hd1);
            release_descriptor_after_stall(
                READ_DESC_READY_REG_PATH,
                READ_DESC_READY_NET_PATH,
                READ_DESC_VALID_PATH);
        join
        check_and_pop_completion(8'hd1, 20'd128);
    endtask

    /*
     * The manager's two reset arcs are legitimate FSM behavior, not waiver
     * candidates.  Hold the relevant descriptor channel stalled, observe a
     * stable VALID/payload for several cycles, then reset from SEND_WRITE and
     * SEND_READ respectively.  No incomplete descriptor is expected to
     * generate a completion after reset.
     */
    virtual task exercise_manager_reset_arcs();
        force_descriptor_ready_low(
            WRITE_DESC_READY_REG_PATH, WRITE_DESC_READY_NET_PATH);
        submit_descriptor(16'h1400, 16'h8400, 20'd128, 8'hd2);
        wait_high(WRITE_DESC_VALID_PATH);
        repeat (4) @(posedge mem_vif.clk);
        reset_vif.pulse(4);
        release_descriptor_ready(
            WRITE_DESC_READY_REG_PATH, WRITE_DESC_READY_NET_PATH);
        repeat (2) @(posedge mem_vif.clk);
        write_reg(REG_CONTROL, 32'h0000_0001);

        force_descriptor_ready_low(
            READ_DESC_READY_REG_PATH, READ_DESC_READY_NET_PATH);
        submit_descriptor(16'h1600, 16'h8600, 20'd128, 8'hd3);
        wait_high(READ_DESC_VALID_PATH);
        repeat (4) @(posedge mem_vif.clk);
        reset_vif.pulse(4);
        release_descriptor_ready(
            READ_DESC_READY_REG_PATH, READ_DESC_READY_NET_PATH);
        repeat (2) @(posedge mem_vif.clk);
        write_reg(REG_CONTROL, 32'h0000_0001);

        /* A normal transfer proves recovery after both reset arcs. */
        submit_descriptor(16'h1800, 16'h8800, 20'd128, 8'hd4);
        check_and_pop_completion(8'hd4, 20'd128);
    endtask

    virtual task body();
        if (mem_vif == null)
            `uvm_fatal("NO_MEM_VIF", "memory-control interface is null")
        if (sva_ctrl_vif == null)
            `uvm_fatal("NO_SVA_CTRL_VIF",
                "AXI-Lite SVA control interface is null")
        if (reset_vif == null)
            `uvm_fatal("NO_RESET_VIF", "reset interface is null")

        require_paths();
        mem_vif.clear_all();
        sva_ctrl_vif.clear_all();
        write_reg(REG_CONTROL, 32'h0000_0001);

        exercise_axil_request_stability();
        exercise_axil_prot_toggles();

        /* These legal response delays activate ap_axil_b_stable and
         * ap_axil_r_stable without any hierarchical force. */
        write_with_bready_delay(REG_TAG, 32'h0000_0033, 8);
        read_with_rready_delay(REG_STATUS, 8);

        exercise_descriptor_stability();
        exercise_manager_reset_arcs();
        mem_vif.clear_all();
        sva_ctrl_vif.clear_all();
    endtask

endclass
