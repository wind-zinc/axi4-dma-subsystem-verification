/*
 * Passive monitor.  One analysis stream keeps event ordering deterministic
 * when descriptor, address, and data handshakes share a clock edge.
 */
class dma_observer_monitor extends uvm_monitor;

    `uvm_component_utils(dma_observer_monitor)

    virtual dma_observer_if vif;
    uvm_analysis_port #(dma_observed_item) ap;

    function new(string name = "dma_observer_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_observer_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("DMA_OBS", "dma_observer_if was not configured")
    endfunction

    task run_phase(uvm_phase phase);
        dma_observed_item tr;
        bit reset_reported = 1'b0;

        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.rst) begin
                if (!reset_reported) begin
                    tr = dma_observed_item::type_id::create("reset_tr");
                    tr.kind = DMA_OBS_RESET;
                    ap.write(tr);
                    reset_reported = 1'b1;
                end
                continue;
            end
            reset_reported = 1'b0;

            /* The write descriptor is dispatched first, so it marks start. */
            if (vif.mon_cb.desc_valid && vif.mon_cb.desc_ready) begin
                tr = dma_observed_item::type_id::create("desc_tr");
                tr.kind     = DMA_OBS_DESCRIPTOR;
                tr.src_addr = vif.mon_cb.desc_src_addr;
                tr.dst_addr = vif.mon_cb.desc_dst_addr;
                tr.length   = vif.mon_cb.desc_length;
                tr.tag      = vif.mon_cb.desc_tag;
                ap.write(tr);
            end

            if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
                tr = dma_observed_item::type_id::create("ar_tr");
                tr.kind      = DMA_OBS_AR;
                tr.axi_addr  = vif.mon_cb.araddr;
                tr.axi_len   = vif.mon_cb.arlen;
                tr.axi_size  = vif.mon_cb.arsize;
                tr.axi_burst = vif.mon_cb.arburst;
                ap.write(tr);
            end

            if (vif.mon_cb.awvalid && vif.mon_cb.awready) begin
                tr = dma_observed_item::type_id::create("aw_tr");
                tr.kind      = DMA_OBS_AW;
                tr.axi_addr  = vif.mon_cb.awaddr;
                tr.axi_len   = vif.mon_cb.awlen;
                tr.axi_size  = vif.mon_cb.awsize;
                tr.axi_burst = vif.mon_cb.awburst;
                ap.write(tr);
            end

            if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
                tr = dma_observed_item::type_id::create("w_tr");
                tr.kind = DMA_OBS_W;
                tr.data = vif.mon_cb.wdata;
                tr.strb = vif.mon_cb.wstrb;
                tr.last = vif.mon_cb.wlast;
                ap.write(tr);
            end

            /* Observe completion when it is committed into the FIFO. */
            if (vif.mon_cb.completion_valid &&
                    vif.mon_cb.completion_ready) begin
                tr = dma_observed_item::type_id::create("completion_tr");
                tr.kind        = DMA_OBS_COMPLETION;
                tr.tag         = vif.mon_cb.completion_tag;
                tr.length      = vif.mon_cb.completion_length;
                tr.flags       = vif.mon_cb.completion_flags;
                tr.write_error = vif.mon_cb.completion_write_error;
                tr.read_error  = vif.mon_cb.completion_read_error;
                ap.write(tr);
            end
        end
    endtask

endclass
