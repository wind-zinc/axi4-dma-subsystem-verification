`timescale 1ns / 1ps
`default_nettype none

module tb_axi_dma_smoke;

    import dma_subsystem_pkg::*;

    localparam int unsigned AXI_EXT_COUNT = EXT_AXI_MASTER_COUNT;
    localparam int unsigned HANDSHAKE_TIMEOUT_CYCLES = 2000;
    localparam int unsigned MAX_POLL_CYCLES = 2000;
    localparam int unsigned GLOBAL_WATCHDOG_CYCLES = 2_000_000;
    localparam int unsigned CONCURRENT_LEN = 1024;

    logic clk;
    logic rst;

    logic [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr;
    logic [2:0] s_axil_awprot;
    logic s_axil_awvalid;
    logic s_axil_awready;
    logic [AXIL_DATA_WIDTH-1:0] s_axil_wdata;
    logic [AXIL_STRB_WIDTH-1:0] s_axil_wstrb;
    logic s_axil_wvalid;
    logic s_axil_wready;
    logic [1:0] s_axil_bresp;
    logic s_axil_bvalid;
    logic s_axil_bready;
    logic [AXIL_ADDR_WIDTH-1:0] s_axil_araddr;
    logic [2:0] s_axil_arprot;
    logic s_axil_arvalid;
    logic s_axil_arready;
    logic [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
    logic [1:0] s_axil_rresp;
    logic s_axil_rvalid;
    logic s_axil_rready;

    logic [AXI_EXT_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_awid;
    logic [AXI_EXT_COUNT*AXI_ADDR_WIDTH-1:0] s_axi_ext_awaddr;
    logic [AXI_EXT_COUNT*8-1:0] s_axi_ext_awlen;
    logic [AXI_EXT_COUNT*3-1:0] s_axi_ext_awsize;
    logic [AXI_EXT_COUNT*2-1:0] s_axi_ext_awburst;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_awlock;
    logic [AXI_EXT_COUNT*4-1:0] s_axi_ext_awcache;
    logic [AXI_EXT_COUNT*3-1:0] s_axi_ext_awprot;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_awvalid;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_awready;
    logic [AXI_EXT_COUNT*AXI_DATA_WIDTH-1:0] s_axi_ext_wdata;
    logic [AXI_EXT_COUNT*AXI_STRB_WIDTH-1:0] s_axi_ext_wstrb;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_wlast;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_wvalid;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_wready;
    logic [AXI_EXT_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_bid;
    logic [AXI_EXT_COUNT*2-1:0] s_axi_ext_bresp;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_bvalid;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_bready;
    logic [AXI_EXT_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_arid;
    logic [AXI_EXT_COUNT*AXI_ADDR_WIDTH-1:0] s_axi_ext_araddr;
    logic [AXI_EXT_COUNT*8-1:0] s_axi_ext_arlen;
    logic [AXI_EXT_COUNT*3-1:0] s_axi_ext_arsize;
    logic [AXI_EXT_COUNT*2-1:0] s_axi_ext_arburst;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_arlock;
    logic [AXI_EXT_COUNT*4-1:0] s_axi_ext_arcache;
    logic [AXI_EXT_COUNT*3-1:0] s_axi_ext_arprot;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_arvalid;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_arready;
    logic [AXI_EXT_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_rid;
    logic [AXI_EXT_COUNT*AXI_DATA_WIDTH-1:0] s_axi_ext_rdata;
    logic [AXI_EXT_COUNT*2-1:0] s_axi_ext_rresp;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_rlast;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_rvalid;
    logic [AXI_EXT_COUNT-1:0] s_axi_ext_rready;

    logic [DMA_CH_COUNT-1:0] irq_ch;
    logic irq;
    logic [DMA_CH_COUNT-1:0] subsys_busy;

    axi_dma_subsystem_top dut (.*);

    always #5 clk = ~clk;

    initial begin
        repeat (GLOBAL_WATCHDOG_CYCLES) @(posedge clk);
        $fatal(1, "Global smoke-test watchdog expired");
    end

    function automatic logic [31:0] channel_base(input int unsigned channel);
        channel_base = (channel == 0) ? CH0_CTRL_BASE_ADDR : CH1_CTRL_BASE_ADDR;
    endfunction

    function automatic logic [31:0] make_word(
        input logic [31:0] seed,
        input int unsigned word_index
    );
        make_word = seed ^ (32'h1020_3040 * (word_index + 1));
    endfunction

    task automatic axil_write(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        bit aw_seen;
        bit w_seen;
        int unsigned wait_cycles;
        begin
            @(negedge clk);
            s_axil_awaddr = addr[AXIL_ADDR_WIDTH-1:0];
            s_axil_awprot = 3'd0;
            s_axil_awvalid = 1'b1;
            s_axil_wdata = data;
            s_axil_wstrb = '1;
            s_axil_wvalid = 1'b1;
            aw_seen = 1'b0;
            w_seen = 1'b0;
            wait_cycles = 0;

            while (!aw_seen || !w_seen) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI-Lite write handshake timeout: addr=0x%08x", addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
                if (!aw_seen && s_axil_awready) begin
                    aw_seen = 1'b1;
                end
                if (!w_seen && s_axil_wready) begin
                    w_seen = 1'b1;
                end
                @(negedge clk);
                if (aw_seen) begin
                    s_axil_awvalid = 1'b0;
                end
                if (w_seen) begin
                    s_axil_wvalid = 1'b0;
                end
            end

            s_axil_bready = 1'b1;
            wait_cycles = 0;
            while (!s_axil_bvalid) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI-Lite write response timeout: addr=0x%08x", addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
            end
            if (s_axil_bresp !== 2'b00) begin
                $fatal(1, "AXI-Lite write response error: addr=0x%08x resp=%0d", addr, s_axil_bresp);
            end
            @(negedge clk);
            s_axil_bready = 1'b0;
        end
    endtask

    task automatic axil_read(
        input logic [31:0] addr,
        output logic [31:0] data
    );
        bit ar_seen;
        int unsigned wait_cycles;
        begin
            @(negedge clk);
            s_axil_araddr = addr[AXIL_ADDR_WIDTH-1:0];
            s_axil_arprot = 3'd0;
            s_axil_arvalid = 1'b1;
            s_axil_rready = 1'b1;
            ar_seen = 1'b0;
            wait_cycles = 0;

            while (!ar_seen) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI-Lite read address timeout: addr=0x%08x", addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
                if (s_axil_arready) begin
                    ar_seen = 1'b1;
                end
                @(negedge clk);
                if (ar_seen) begin
                    s_axil_arvalid = 1'b0;
                end
            end

            wait_cycles = 0;
            while (!s_axil_rvalid) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI-Lite read response timeout: addr=0x%08x", addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
            end
            if (s_axil_rresp !== 2'b00) begin
                $fatal(1, "AXI-Lite read response error: addr=0x%08x resp=%0d", addr, s_axil_rresp);
            end
            data = s_axil_rdata;
            @(negedge clk);
            s_axil_rready = 1'b0;
        end
    endtask

    task automatic axi_write_word(
        input int unsigned master,
        input logic [31:0] addr,
        input logic [31:0] data
    );
        bit aw_seen;
        bit w_seen;
        int unsigned wait_cycles;
        begin
            @(negedge clk);
            s_axi_ext_awid[master*AXI_ID_WIDTH +: AXI_ID_WIDTH] = 4'h1;
            s_axi_ext_awaddr[master*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = addr;
            s_axi_ext_awlen[master*8 +: 8] = 8'd0;
            s_axi_ext_awsize[master*3 +: 3] = 3'd2;
            s_axi_ext_awburst[master*2 +: 2] = 2'b01;
            s_axi_ext_awlock[master] = 1'b0;
            s_axi_ext_awcache[master*4 +: 4] = 4'd0;
            s_axi_ext_awprot[master*3 +: 3] = 3'd0;
            s_axi_ext_awvalid[master] = 1'b1;
            s_axi_ext_wdata[master*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data;
            s_axi_ext_wstrb[master*AXI_STRB_WIDTH +: AXI_STRB_WIDTH] = '1;
            s_axi_ext_wlast[master] = 1'b1;
            s_axi_ext_wvalid[master] = 1'b1;
            aw_seen = 1'b0;
            w_seen = 1'b0;
            wait_cycles = 0;

            while (!aw_seen || !w_seen) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI write handshake timeout: master=%0d addr=0x%08x", master, addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
                if (!aw_seen && s_axi_ext_awready[master]) begin
                    aw_seen = 1'b1;
                end
                if (!w_seen && s_axi_ext_wready[master]) begin
                    w_seen = 1'b1;
                end
                @(negedge clk);
                if (aw_seen) begin
                    s_axi_ext_awvalid[master] = 1'b0;
                end
                if (w_seen) begin
                    s_axi_ext_wvalid[master] = 1'b0;
                end
            end

            s_axi_ext_bready[master] = 1'b1;
            wait_cycles = 0;
            while (!s_axi_ext_bvalid[master]) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI write response timeout: master=%0d addr=0x%08x", master, addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
            end
            if (s_axi_ext_bresp[master*2 +: 2] !== 2'b00) begin
                $fatal(1, "AXI write response error: master=%0d addr=0x%08x resp=%0d",
                    master, addr, s_axi_ext_bresp[master*2 +: 2]);
            end
            @(negedge clk);
            s_axi_ext_bready[master] = 1'b0;
        end
    endtask

    task automatic axi_read_word(
        input int unsigned master,
        input logic [31:0] addr,
        output logic [31:0] data
    );
        bit ar_seen;
        int unsigned wait_cycles;
        begin
            @(negedge clk);
            s_axi_ext_arid[master*AXI_ID_WIDTH +: AXI_ID_WIDTH] = 4'h2;
            s_axi_ext_araddr[master*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = addr;
            s_axi_ext_arlen[master*8 +: 8] = 8'd0;
            s_axi_ext_arsize[master*3 +: 3] = 3'd2;
            s_axi_ext_arburst[master*2 +: 2] = 2'b01;
            s_axi_ext_arlock[master] = 1'b0;
            s_axi_ext_arcache[master*4 +: 4] = 4'd0;
            s_axi_ext_arprot[master*3 +: 3] = 3'd0;
            s_axi_ext_arvalid[master] = 1'b1;
            s_axi_ext_rready[master] = 1'b1;
            ar_seen = 1'b0;
            wait_cycles = 0;

            while (!ar_seen) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI read address timeout: master=%0d addr=0x%08x", master, addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
                if (s_axi_ext_arready[master]) begin
                    ar_seen = 1'b1;
                end
                @(negedge clk);
                if (ar_seen) begin
                    s_axi_ext_arvalid[master] = 1'b0;
                end
            end

            wait_cycles = 0;
            while (!s_axi_ext_rvalid[master]) begin
                if (wait_cycles >= HANDSHAKE_TIMEOUT_CYCLES) begin
                    $fatal(1, "AXI read response timeout: master=%0d addr=0x%08x", master, addr);
                end
                wait_cycles = wait_cycles + 1;
                @(posedge clk);
            end
            if (s_axi_ext_rresp[master*2 +: 2] !== 2'b00
                    || !s_axi_ext_rlast[master]) begin
                $fatal(1, "AXI read response error: master=%0d addr=0x%08x", master, addr);
            end
            data = s_axi_ext_rdata[master*AXI_DATA_WIDTH +: AXI_DATA_WIDTH];
            @(negedge clk);
            s_axi_ext_rready[master] = 1'b0;
        end
    endtask

    task automatic fill_words(
        input int unsigned master,
        input logic [31:0] base_addr,
        input int unsigned byte_len,
        input logic [31:0] seed
    );
        int unsigned word_index;
        begin
            for (word_index = 0; word_index < byte_len / 4; word_index++) begin
                axi_write_word(master, base_addr + word_index*4, make_word(seed, word_index));
            end
        end
    endtask

    task automatic check_words(
        input int unsigned master,
        input logic [31:0] base_addr,
        input int unsigned byte_len,
        input logic [31:0] seed
    );
        int unsigned word_index;
        logic [31:0] actual;
        logic [31:0] expected;
        begin
            for (word_index = 0; word_index < byte_len / 4; word_index++) begin
                axi_read_word(master, base_addr + word_index*4, actual);
                expected = make_word(seed, word_index);
                if (actual !== expected) begin
                    $fatal(1, "Data mismatch: addr=0x%08x expected=0x%08x actual=0x%08x",
                        base_addr + word_index*4, expected, actual);
                end
            end
        end
    endtask

    task automatic configure_channel(
        input int unsigned channel,
        input logic [31:0] src_addr,
        input logic [31:0] dst_addr,
        input int unsigned byte_len,
        input int unsigned dst_channel,
        input logic [7:0] sw_tag
    );
        logic [31:0] base;
        begin
            base = channel_base(channel);
            axil_write(base + REG_CTRL, 32'h0000_0014);
            axil_write(base + REG_SRC_ADDR, src_addr);
            axil_write(base + REG_DST_ADDR, dst_addr);
            axil_write(base + REG_LENGTH, byte_len);
            axil_write(base + REG_ROUTE, dst_channel ? 32'd1 : 32'd0);
            axil_write(base + REG_SW_TAG, {24'd0, sw_tag});
        end
    endtask

    task automatic start_channel(input int unsigned channel);
        begin
            axil_write(channel_base(channel) + REG_CTRL, 32'h0000_0005);
        end
    endtask

    task automatic wait_channel_busy(input int unsigned channel);
        logic [31:0] status;
        int unsigned poll;
        begin
            for (poll = 0; poll < MAX_POLL_CYCLES; poll++) begin
                axil_read(channel_base(channel) + REG_STATUS, status);
                if (status[0]) begin
                    return;
                end
            end
            $fatal(1, "Timeout waiting for CH%0d busy", channel);
        end
    endtask

    task automatic wait_channel_done(
        input int unsigned channel,
        input int unsigned expected_len
    );
        logic [31:0] status;
        logic [31:0] completed_len;
        int unsigned poll;
        begin
            for (poll = 0; poll < MAX_POLL_CYCLES; poll++) begin
                axil_read(channel_base(channel) + REG_STATUS, status);
                if (status[1]) begin
                    if (status[2]) begin
                        $fatal(1, "CH%0d completed with error 0x%02x", channel, status[15:8]);
                    end
                    axil_read(channel_base(channel) + REG_COMPLETED_LEN, completed_len);
                    if (completed_len[LEN_WIDTH-1:0] !== expected_len[LEN_WIDTH-1:0]) begin
                        $fatal(1, "CH%0d completed length mismatch: expected=%0d actual=%0d",
                            channel, expected_len, completed_len[LEN_WIDTH-1:0]);
                    end
                    return;
                end
            end
            $fatal(1, "Timeout waiting for CH%0d completion", channel);
        end
    endtask

    task automatic run_single_route(
        input string test_name,
        input int unsigned owner_channel,
        input int unsigned dst_channel,
        input logic [31:0] src_addr,
        input logic [31:0] dst_addr,
        input logic [31:0] seed
    );
        localparam int unsigned SINGLE_LEN = 32;
        begin
            $display("[SMOKE] START %s", test_name);
            fill_words(0, src_addr, SINGLE_LEN, seed);
            configure_channel(owner_channel, src_addr, dst_addr, SINGLE_LEN, dst_channel, seed[7:0]);
            start_channel(owner_channel);
            wait_channel_done(owner_channel, SINGLE_LEN);
            check_words(0, dst_addr, SINGLE_LEN, seed);
            $display("[SMOKE] PASS  %s", test_name);
        end
    endtask

    task automatic run_concurrent_routes;
        localparam logic [31:0] CH0_SRC = RAM0_BASE_ADDR + 32'h0000_1000;
        localparam logic [31:0] CH0_DST = RAM1_BASE_ADDR + 32'h0000_1000;
        localparam logic [31:0] CH1_SRC = RAM1_BASE_ADDR + 32'h0000_2000;
        localparam logic [31:0] CH1_DST = RAM0_BASE_ADDR + 32'h0000_2000;
        localparam logic [31:0] CH0_SEED = 32'hC000_0000;
        localparam logic [31:0] CH1_SEED = 32'hD000_0000;
        bit both_busy_seen;
        int unsigned cycle_count;
        begin
            $display("[SMOKE] START concurrent 0->1 + 1->0");
            fill_words(0, CH0_SRC, CONCURRENT_LEN, CH0_SEED);
            fill_words(0, CH1_SRC, CONCURRENT_LEN, CH1_SEED);
            configure_channel(0, CH0_SRC, CH0_DST, CONCURRENT_LEN, 1, 8'hC1);
            configure_channel(1, CH1_SRC, CH1_DST, CONCURRENT_LEN, 0, 8'hD1);

            start_channel(0);
            wait_channel_busy(0);
            start_channel(1);

            both_busy_seen = 1'b0;
            for (cycle_count = 0; cycle_count < MAX_POLL_CYCLES; cycle_count++) begin
                @(posedge clk);
                if (subsys_busy == 2'b11) begin
                    both_busy_seen = 1'b1;
                    break;
                end
            end
            if (!both_busy_seen) begin
                $fatal(1, "Concurrent test did not observe both channels busy at once");
            end

            wait_channel_done(0, CONCURRENT_LEN);
            wait_channel_done(1, CONCURRENT_LEN);
            check_words(0, CH0_DST, CONCURRENT_LEN, CH0_SEED);
            check_words(0, CH1_DST, CONCURRENT_LEN, CH1_SEED);
            $display("[SMOKE] PASS  concurrent 0->1 + 1->0");
        end
    endtask

    initial begin
        string test_sel;

        clk = 1'b0;
        rst = 1'b1;
        s_axil_awaddr = '0;
        s_axil_awprot = '0;
        s_axil_awvalid = 1'b0;
        s_axil_wdata = '0;
        s_axil_wstrb = '0;
        s_axil_wvalid = 1'b0;
        s_axil_bready = 1'b0;
        s_axil_araddr = '0;
        s_axil_arprot = '0;
        s_axil_arvalid = 1'b0;
        s_axil_rready = 1'b0;

        s_axi_ext_awid = '0;
        s_axi_ext_awaddr = '0;
        s_axi_ext_awlen = '0;
        s_axi_ext_awsize = '0;
        s_axi_ext_awburst = '0;
        s_axi_ext_awlock = '0;
        s_axi_ext_awcache = '0;
        s_axi_ext_awprot = '0;
        s_axi_ext_awvalid = '0;
        s_axi_ext_wdata = '0;
        s_axi_ext_wstrb = '0;
        s_axi_ext_wlast = '0;
        s_axi_ext_wvalid = '0;
        s_axi_ext_bready = '0;
        s_axi_ext_arid = '0;
        s_axi_ext_araddr = '0;
        s_axi_ext_arlen = '0;
        s_axi_ext_arsize = '0;
        s_axi_ext_arburst = '0;
        s_axi_ext_arlock = '0;
        s_axi_ext_arcache = '0;
        s_axi_ext_arprot = '0;
        s_axi_ext_arvalid = '0;
        s_axi_ext_rready = '0;

        repeat (10) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        if (!$value$plusargs("TEST=%s", test_sel)) begin
            test_sel = "all";
        end

        if (!(test_sel == "all"
                || test_sel == "route_00"
                || test_sel == "route_01"
                || test_sel == "route_10"
                || test_sel == "route_11"
                || test_sel == "concurrent")) begin
            $fatal(1, "Unknown +TEST=%s", test_sel);
        end

        if (test_sel == "all" || test_sel == "route_00") begin
            run_single_route("route 0->0", 0, 0,
                RAM0_BASE_ADDR + 32'h0000_0100,
                RAM0_BASE_ADDR + 32'h0000_0200, 32'hA000_0000);
        end
        if (test_sel == "all" || test_sel == "route_01") begin
            run_single_route("route 0->1", 0, 1,
                RAM0_BASE_ADDR + 32'h0000_0300,
                RAM1_BASE_ADDR + 32'h0000_0300, 32'hA100_0000);
        end
        if (test_sel == "all" || test_sel == "route_10") begin
            run_single_route("route 1->0", 1, 0,
                RAM1_BASE_ADDR + 32'h0000_0300,
                RAM0_BASE_ADDR + 32'h0000_0300, 32'hA200_0000);
        end
        if (test_sel == "all" || test_sel == "route_11") begin
            run_single_route("route 1->1", 1, 1,
                RAM1_BASE_ADDR + 32'h0000_0800,
                RAM1_BASE_ADDR + 32'h0000_0A00, 32'hA300_0000);
        end
        if (test_sel == "all" || test_sel == "concurrent") begin
            run_concurrent_routes();
        end

        $display("[SMOKE] ALL REQUESTED TESTS PASSED");
        $finish;
    end

endmodule

`default_nettype wire
