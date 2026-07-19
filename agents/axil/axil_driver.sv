class axil_driver extends uvm_driver #(axil_item);

    `uvm_component_utils(axil_driver)

    virtual axil_if vif;

    localparam int MAX_WAIT_CYCLES = 2000;

    function new(string name = "axil_driver",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual axil_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "axil_driver did not receive axil_if")
    endfunction

    task run_phase(uvm_phase phase);
        axil_item req;

        drive_idle();

        forever begin
            wait_reset_release();
            seq_item_port.get_next_item(req);

            if (req.op == AXIL_WRITE)
                drive_write(req);
            else
                drive_read(req);

            seq_item_port.item_done();
        end
    endtask

    task drive_idle();
        vif.awaddr  <= '0;
        vif.awprot  <= '0;
        vif.awvalid <= 1'b0;
        vif.wdata   <= '0;
        vif.wstrb   <= '0;
        vif.wvalid  <= 1'b0;
        vif.bready  <= 1'b0;
        vif.araddr  <= '0;
        vif.arprot  <= '0;
        vif.arvalid <= 1'b0;
        vif.rready  <= 1'b0;
    endtask

    task wait_reset_release();
        while (vif.rst)
            @(vif.drv_cb);
    endtask

    /*
     * AW and W are independent.  The two threads hold their VALID and
     * payload until their own handshake completes.  BREADY is asserted
     * independently so the response cannot be lost.
     */
    task drive_write(axil_item tr);
        int unsigned aw_wait;
        int unsigned w_wait;
        int unsigned b_wait;

        aw_wait = 0;
        w_wait  = 0;
        b_wait  = 0;

        fork
            begin : drive_aw
                @(vif.drv_cb);
                vif.drv_cb.awaddr  <= tr.addr;
                vif.drv_cb.awprot  <= 3'b000;
                vif.drv_cb.awvalid <= 1'b1;

                do begin
                    @(vif.drv_cb);
                    aw_wait++;
                    if (aw_wait >= MAX_WAIT_CYCLES)
                        `uvm_fatal("AXIL_AW_TIMEOUT",
                            "AWREADY timeout")
                end while (!vif.drv_cb.awready);

                vif.drv_cb.awvalid <= 1'b0;
            end

            begin : drive_w
                @(vif.drv_cb);
                vif.drv_cb.wdata  <= tr.wdata;
                vif.drv_cb.wstrb  <= tr.wstrb;
                vif.drv_cb.wvalid <= 1'b1;

                do begin
                    @(vif.drv_cb);
                    w_wait++;
                    if (w_wait >= MAX_WAIT_CYCLES)
                        `uvm_fatal("AXIL_W_TIMEOUT",
                            "WREADY timeout")
                end while (!vif.drv_cb.wready);

                vif.drv_cb.wvalid <= 1'b0;
            end

            begin : receive_b
                @(vif.drv_cb);
                vif.drv_cb.bready <= 1'b1;

                do begin
                    @(vif.drv_cb);
                    b_wait++;
                    if (b_wait >= MAX_WAIT_CYCLES)
                        `uvm_fatal("AXIL_B_TIMEOUT",
                            "BVALID timeout")
                end while (!vif.drv_cb.bvalid);

                tr.resp = vif.drv_cb.bresp;
                vif.drv_cb.bready <= 1'b0;
            end
        join
    endtask

    task drive_read(axil_item tr);
        int unsigned ar_wait;
        int unsigned r_wait;

        ar_wait = 0;
        r_wait  = 0;

        fork
            begin : drive_ar
                @(vif.drv_cb);
                vif.drv_cb.araddr  <= tr.addr;
                vif.drv_cb.arprot  <= 3'b000;
                vif.drv_cb.arvalid <= 1'b1;

                do begin
                    @(vif.drv_cb);
                    ar_wait++;
                    if (ar_wait >= MAX_WAIT_CYCLES)
                        `uvm_fatal("AXIL_AR_TIMEOUT",
                            "ARREADY timeout")
                end while (!vif.drv_cb.arready);

                vif.drv_cb.arvalid <= 1'b0;
            end

            begin : receive_r
                @(vif.drv_cb);
                vif.drv_cb.rready <= 1'b1;

                do begin
                    @(vif.drv_cb);
                    r_wait++;
                    if (r_wait >= MAX_WAIT_CYCLES)
                        `uvm_fatal("AXIL_R_TIMEOUT",
                            "RVALID timeout")
                end while (!vif.drv_cb.rvalid);

                tr.rdata = vif.drv_cb.rdata;
                tr.resp  = vif.drv_cb.rresp;
                vif.drv_cb.rready <= 1'b0;
            end
        join
    endtask

endclass

