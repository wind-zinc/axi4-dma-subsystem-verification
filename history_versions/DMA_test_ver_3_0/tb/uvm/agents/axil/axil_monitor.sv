class axil_monitor extends uvm_component;

    `uvm_component_utils(axil_monitor)

    typedef struct packed {
        bit [AXIL_DATA_WIDTH-1:0] data;
        bit [AXIL_STRB_WIDTH-1:0] strb;
    } write_payload_t;

    virtual axil_if vif;
    uvm_analysis_port #(axil_item) ap;

    bit [AXIL_ADDR_WIDTH-1:0] awaddr_q[$];
    write_payload_t           wdata_q[$];
    bit [AXIL_ADDR_WIDTH-1:0] araddr_q[$];

    function new(string name = "axil_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual axil_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "axil_monitor did not receive axil_if")
    endfunction

    task run_phase(uvm_phase phase);
        axil_item tr;
        write_payload_t wp;

        forever begin
            @(vif.mon_cb);

            if (vif.rst) begin
                awaddr_q.delete();
                wdata_q.delete();
                araddr_q.delete();
                continue;
            end

            if (vif.mon_cb.awvalid && vif.mon_cb.awready)
                awaddr_q.push_back(vif.mon_cb.awaddr);

            if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
                wp.data = vif.mon_cb.wdata;
                wp.strb = vif.mon_cb.wstrb;
                wdata_q.push_back(wp);
            end

            if (vif.mon_cb.bvalid && vif.mon_cb.bready) begin
                if (awaddr_q.size() == 0 || wdata_q.size() == 0) begin
                    `uvm_error("AXIL_MON",
                        "B response without captured AW and W")
                end else begin
                    tr = axil_item::type_id::create("write_tr");
                    wp = wdata_q.pop_front();
                    tr.op    = AXIL_WRITE;
                    tr.addr  = awaddr_q.pop_front();
                    tr.wdata = wp.data;
                    tr.wstrb = wp.strb;
                    tr.resp  = vif.mon_cb.bresp;
                    ap.write(tr);
                end
            end

            if (vif.mon_cb.arvalid && vif.mon_cb.arready)
                araddr_q.push_back(vif.mon_cb.araddr);

            if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
                if (araddr_q.size() == 0) begin
                    `uvm_error("AXIL_MON",
                        "R response without captured AR")
                end else begin
                    tr = axil_item::type_id::create("read_tr");
                    tr.op    = AXIL_READ;
                    tr.addr  = araddr_q.pop_front();
                    tr.rdata = vif.mon_cb.rdata;
                    tr.resp  = vif.mon_cb.rresp;
                    ap.write(tr);
                end
            end
        end
    endtask

endclass

