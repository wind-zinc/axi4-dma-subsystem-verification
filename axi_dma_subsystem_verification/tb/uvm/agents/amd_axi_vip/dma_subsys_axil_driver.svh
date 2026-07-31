// Front-door RAL driver backed by the public AMD AXI-Lite master API.
class dma_subsys_axil_driver extends uvm_driver #(dma_subsys_reg_tr);
    `uvm_component_utils(dma_subsys_axil_driver)

    dma_subsys_vip_manager vip_mgr;
    virtual dma_subsys_probe_if probe_vif;
    dma_subsys_env_cfg cfg;

    function new(
        string        name   = "dma_subsys_axil_driver",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_subsys_probe_if)::get(
                this, "", "dma_subsys_probe_vif", probe_vif)) begin
            `uvm_fatal(
                "RAL_DRV_PROBE",
                "RAL AXI-Lite driver did not receive probe VIF")
        end
        if (!uvm_config_db#(dma_subsys_env_cfg)::get(
                this, "", "dma_subsys_env_cfg", cfg)) begin
            cfg = dma_subsys_env_cfg::type_id::create("cfg");
        end
    endfunction

    protected function dma_axi_resp_e normalize_resp(
        input xil_axi_resp_t response
    );
        case (response)
            XIL_AXI_RESP_OKAY:   return DMA_AXI_OKAY;
            XIL_AXI_RESP_EXOKAY: return DMA_AXI_EXOKAY;
            XIL_AXI_RESP_SLVERR: return DMA_AXI_SLVERR;
            XIL_AXI_RESP_DECERR: return DMA_AXI_DECERR;
            default:             return DMA_AXI_DECERR;
        endcase
    endfunction

    protected task wait_probe_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(probe_vif.mon_cb);
        end
    endtask

    protected task drive_transfer(input dma_subsys_reg_tr tr);
        bit [8*8-1:0] data;
        xil_axi_resp_t response;
        bit completed;

        data = '0;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        if (tr.access == DMA_ACCESS_WRITE) begin
            data[AXIL_DATA_WIDTH-1:0] = tr.data;
            fork : ral_write_guard
                begin
                    vip_mgr.axil_cpu.AXI4LITE_WRITE_BURST(
                        tr.addr,
                        XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                        data,
                        response);
                    completed = 1'b1;
                end
                begin
                    wait_probe_cycles(cfg.vip_timeout_cycles);
                end
            join_any
            disable ral_write_guard;
        end else begin
            fork : ral_read_guard
                begin
                    vip_mgr.axil_cpu.AXI4LITE_READ_BURST(
                        tr.addr,
                        XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                        data,
                        response);
                    completed = 1'b1;
                end
                begin
                    wait_probe_cycles(cfg.vip_timeout_cycles);
                end
            join_any
            disable ral_read_guard;
            tr.data = data[AXIL_DATA_WIDTH-1:0];
        end

        if (!completed) begin
            tr.resp = DMA_AXI_DECERR;
            `uvm_fatal(
                "RAL_DRV_TIMEOUT",
                $sformatf(
                    "AXI-Lite %s timed out at 0x%08h after %0d cycles",
                    (tr.access == DMA_ACCESS_WRITE) ? "write" : "read",
                    tr.addr, cfg.vip_timeout_cycles))
            return;
        end

        tr.resp = normalize_resp(response);
        tr.normalize();
    endtask

    virtual task run_phase(uvm_phase phase);
        dma_subsys_reg_tr tr;

        if (vip_mgr == null) begin
            `uvm_fatal(
                "RAL_DRV_VIP",
                "RAL AXI-Lite driver has no VIP manager")
            return;
        end
        vip_mgr.wait_until_ready();

        forever begin
            seq_item_port.get_next_item(tr);
            drive_transfer(tr);
            seq_item_port.item_done();
        end
    endtask

endclass
