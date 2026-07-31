// Common services for subsystem virtual sequences.
//
// This class drives only public AMD VIP APIs and the virtual sequencer's
// read-only probe VIF. It contains no static testbench hierarchy reference.
class dma_subsys_vseq_base extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(dma_subsys_vseq_base)
    `uvm_declare_p_sequencer(dma_subsys_virtual_sequencer)

    function new(string name = "dma_subsys_vseq_base");
        super.new(name);
    endfunction

    protected task wait_for_infrastructure();
        if (p_sequencer == null) begin
            `uvm_fatal(
                "VSEQ_NO_SEQR",
                "dma_subsys_vseq_base requires dma_subsys_virtual_sequencer")
            return;
        end
        if (p_sequencer.vip_mgr == null) begin
            `uvm_fatal("VSEQ_NO_VIP", "Virtual sequencer has no VIP manager")
            return;
        end
        if (p_sequencer.cfg == null) begin
            `uvm_fatal(
                "VSEQ_NO_CFG",
                "Virtual sequencer has no subsystem environment config")
            return;
        end

        p_sequencer.vip_mgr.wait_until_ready();

        if (p_sequencer.probe_vif == null) begin
            `uvm_fatal("VSEQ_NO_PROBE", "Virtual sequencer has no probe VIF")
            return;
        end

        do begin
            @(p_sequencer.probe_vif.mon_cb);
        end while (!p_sequencer.probe_vif.mon_cb.reset_n);

        wait_probe_cycles(2);
    endtask

    protected task wait_probe_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(p_sequencer.probe_vif.mon_cb);
        end
    endtask

    protected task axil_write32(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [AXIL_DATA_WIDTH-1:0] value,
        input string                     operation
    );
        bit [8*8-1:0] data;
        xil_axi_resp_t response;
        bit completed;

        data = '0;
        data[AXIL_DATA_WIDTH-1:0] = value;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : axil_write_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_WRITE_BURST(
                    address,
                    XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                    data,
                    response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable axil_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXIL_TIMEOUT",
                $sformatf("%s write timed out at 0x%08h",
                          operation, address))
            return;
        end
        if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal(
                "VSEQ_AXIL_RESP",
                $sformatf(
                    "%s write at 0x%08h returned response %0d",
                    operation, address, response))
        end
    endtask

    protected task axil_read32(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        output logic [AXIL_DATA_WIDTH-1:0] value,
        input  string                     operation
    );
        bit [8*8-1:0] data;
        xil_axi_resp_t response;
        bit completed;

        data = '0;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : axil_read_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_READ_BURST(
                    address,
                    XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                    data,
                    response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable axil_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXIL_TIMEOUT",
                $sformatf("%s read timed out at 0x%08h",
                          operation, address))
            value = '0;
            return;
        end
        if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal(
                "VSEQ_AXIL_RESP",
                $sformatf(
                    "%s read at 0x%08h returned response %0d",
                    operation, address, response))
        end
        value = data[AXIL_DATA_WIDTH-1:0];
    endtask

    protected task external_write(
        input dma_master_e                    master,
        input logic [AXI_ADDR_WIDTH-1:0]      address,
        input int unsigned                    beat_count,
        input bit [8*4096-1:0]                payload,
        input string                          operation
    );
        xil_axi_data_beat [255:0] write_user;
        xil_axi_resp_t response;
        bit completed;

        if ((beat_count == 0) || (beat_count > AXI_MAX_BURST_LEN)) begin
            `uvm_fatal(
                "VSEQ_AXI_BEATS",
                $sformatf("%s requested illegal beat_count=%0d",
                          operation, beat_count))
            return;
        end

        foreach (write_user[index]) begin
            write_user[index] = '0;
        end
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : external_write_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_WRITE_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, write_user, response);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_WRITE_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, write_user, response);
                    end
                    default: begin
                        `uvm_fatal(
                            "VSEQ_AXI_MASTER",
                            $sformatf(
                                "%s requires EXT0 or EXT1, got %0d",
                                operation, master))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable external_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXI_TIMEOUT",
                $sformatf("%s write timed out at 0x%08h",
                          operation, address))
            return;
        end
        if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal(
                "VSEQ_AXI_RESP",
                $sformatf(
                    "%s write at 0x%08h returned response %0d",
                    operation, address, response))
        end
    endtask

    protected task external_read(
        input  dma_master_e                   master,
        input  logic [AXI_ADDR_WIDTH-1:0]     address,
        input  int unsigned                   beat_count,
        output bit [8*4096-1:0]               payload,
        output xil_axi_resp_t [255:0]         response,
        input  string                         operation
    );
        xil_axi_data_beat [255:0] read_user;
        bit completed;

        if ((beat_count == 0) || (beat_count > AXI_MAX_BURST_LEN)) begin
            `uvm_fatal(
                "VSEQ_AXI_BEATS",
                $sformatf("%s requested illegal beat_count=%0d",
                          operation, beat_count))
            return;
        end

        payload = '0;
        foreach (response[index]) begin
            response[index] = XIL_AXI_RESP_DECERR;
            read_user[index] = '0;
        end
        completed = 1'b0;

        fork : external_read_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_READ_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, response, read_user);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_READ_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, response, read_user);
                    end
                    default: begin
                        `uvm_fatal(
                            "VSEQ_AXI_MASTER",
                            $sformatf(
                                "%s requires EXT0 or EXT1, got %0d",
                                operation, master))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable external_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXI_TIMEOUT",
                $sformatf("%s read timed out at 0x%08h",
                          operation, address))
        end
    endtask

    protected function void check_read_responses(
        input xil_axi_resp_t [255:0] response,
        input int unsigned            beat_count,
        input string                  operation
    );
        for (int unsigned beat = 0; beat < beat_count; beat++) begin
            if (response[beat] != XIL_AXI_RESP_OKAY) begin
                `uvm_error(
                    "VSEQ_AXI_RRESP",
                    $sformatf(
                        "%s beat %0d returned response %0d",
                        operation, beat, response[beat]))
            end
        end
    endfunction

endclass
