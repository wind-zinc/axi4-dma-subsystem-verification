`timescale 1ns / 1ps

class dma_subsys_random_stress_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_random_stress_vseq)

    dma_subsys_random_stress_cfg stress_cfg;
    protected semaphore axil_lock;
    protected semaphore external_lock[2];
    protected bit monitor_enabled;
    protected bit external_enabled;
    protected int unsigned completed_jobs[2];
    protected int unsigned expected_errors[2];
    protected dma_error_e expected_last_error[2];
    protected int unsigned observed_completions[2];
    protected int unsigned external_transactions[2];
    protected longint unsigned dual_busy_cycles;
    protected longint unsigned route_wait_cycles;
    protected longint unsigned external_busy_transactions;
    protected int unsigned irq_operations;
    protected int unsigned delay_updates;
    protected int unsigned source_page_splits;
    protected int unsigned destination_page_splits;

    covergroup descriptor_cg with function sample(
        int unsigned owner, int unsigned destination_channel,
        int unsigned source_ram, int unsigned destination_ram,
        int unsigned byte_count, int unsigned descriptor_kind,
        bit source_split, bit destination_split,
        logic [1:0] read_response, logic [1:0] write_response
    );
        option.per_instance = 1;
        cp_owner: coverpoint owner { bins ch0 = {0}; bins ch1 = {1}; }
        cp_destination: coverpoint destination_channel { bins ch0 = {0}; bins ch1 = {1}; }
        cp_source_ram: coverpoint source_ram { bins ram0 = {0}; bins ram1 = {1}; }
        cp_destination_ram: coverpoint destination_ram { bins ram0 = {0}; bins ram1 = {1}; }
        cp_length: coverpoint byte_count {
            bins len_zero = {0};
            bins len_byte = {1};
            bins len_tail = {[2:3]};
            bins len_word = {4};
            bins len_short = {[5:63]};
            bins len_burst = {64};
            bins len_multi = {[65:4095]};
            bins len_page = {4096};
        }
        cp_descriptor: coverpoint descriptor_kind {
            bins legal = {0}; bins len_zero = {1};
            bins src_align = {2}; bins dst_align = {3};
        }
        cp_source_split: coverpoint source_split;
        cp_destination_split: coverpoint destination_split;
        cp_read_response: coverpoint read_response {
            bins okay = {0}; bins slverr = {2}; bins decerr = {3};
        }
        cp_write_response: coverpoint write_response {
            bins okay = {0}; bins slverr = {2}; bins decerr = {3};
        }
        cx_route: cross cp_owner, cp_destination;
        cx_memory: cross cp_source_ram, cp_destination_ram;
        cx_response: cross cp_read_response, cp_write_response;
        cx_channel_error: cross cp_owner, cp_descriptor;
    endgroup

    covergroup activity_cg with function sample(logic [1:0] busy, logic [1:0] waiting);
        option.per_instance = 1;
        cp_busy: coverpoint busy {
            bins idle = {0}; bins ch0 = {1}; bins ch1 = {2}; bins both = {3};
        }
        cp_waiting: coverpoint waiting {
            bins idle = {0}; bins ch0 = {1}; bins ch1 = {2}; bins both = {3};
        }
        cx_busy_wait: cross cp_busy, cp_waiting;
    endgroup

    function new(string name = "dma_subsys_random_stress_vseq");
        super.new(name);
        axil_lock = new(1);
        foreach (external_lock[index]) begin
            external_lock[index] = new(1);
            completed_jobs[index] = 0;
            expected_errors[index] = 0;
            expected_last_error[index] = DMA_ERR_NONE;
            observed_completions[index] = 0;
            external_transactions[index] = 0;
        end
        dual_busy_cycles = 0;
        route_wait_cycles = 0;
        external_busy_transactions = 0;
        irq_operations = 0;
        delay_updates = 0;
        source_page_splits = 0;
        destination_page_splits = 0;
        descriptor_cg = new;
        activity_cg = new;
    endfunction

    protected virtual task axil_write32(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [AXIL_DATA_WIDTH-1:0] value,
        input string operation
    );
        axil_lock.get(1);
        super.axil_write32(address, value, operation);
        axil_lock.put(1);
    endtask

    protected virtual task axil_read32(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        output logic [AXIL_DATA_WIDTH-1:0] value,
        input string operation
    );
        axil_lock.get(1);
        super.axil_read32(address, value, operation);
        axil_lock.put(1);
    endtask

    protected virtual task external_write(
        input dma_master_e master,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input int unsigned beat_count,
        input bit [8*4096-1:0] payload,
        input string operation
    );
        int unsigned index;
        index = (master == DMA_MASTER_EXT1) ? 1 : 0;
        external_lock[index].get(1);
        super.external_write(master, address, beat_count, payload, operation);
        external_lock[index].put(1);
    endtask

    protected virtual task external_read(
        input dma_master_e master,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input int unsigned beat_count,
        output bit [8*4096-1:0] payload,
        output xil_axi_resp_t [255:0] response,
        input string operation
    );
        int unsigned index;
        index = (master == DMA_MASTER_EXT1) ? 1 : 0;
        external_lock[index].get(1);
        super.external_read(master, address, beat_count, payload, response, operation);
        external_lock[index].put(1);
    endtask

    protected function int unsigned chunk_size(input logic [31:0] address, input int unsigned remaining);
        int unsigned bytes_to_page;
        int unsigned result;
        bytes_to_page = 4096 - int'(address[11:0]);
        result = (remaining > AXI_MAX_BURST_LEN * AXI_STRB_WIDTH)
            ? AXI_MAX_BURST_LEN * AXI_STRB_WIDTH : remaining;
        return (result > bytes_to_page) ? bytes_to_page : result;
    endfunction

    protected task initialize_stress_region(
        input logic [31:0] address, input int unsigned byte_count,
        input byte unsigned seed, input string operation
    );
        bit [8*4096-1:0] payload;
        int unsigned rounded_bytes;
        int unsigned offset;
        int unsigned bytes_this_chunk;
        rounded_bytes = ((byte_count + 3) / 4) * 4;
        offset = 0;
        while (offset < rounded_bytes) begin
            bytes_this_chunk = chunk_size(address + offset, rounded_bytes - offset);
            build_linear_payload(payload, bytes_this_chunk, seed, offset);
            external_write(external_master_for_address(address + offset),
                address + offset, bytes_this_chunk / 4, payload, operation);
            offset += bytes_this_chunk;
        end
        wait_probe_cycles(2);
    endtask

    protected task initialize_job(input dma_subsys_random_stress_item item);
        initialize_stress_region(item.source_address(), item.byte_count,
            item.payload_seed, "stress source");
        initialize_stress_region(item.destination_address() - 4,
            ((item.byte_count + 3) / 4) * 4 + 8,
            item.payload_seed ^ 8'hA5, "stress destination and guards");
    endtask

    protected task prepare_job(input dma_subsys_random_stress_item item, input dma_error_e expected_error);
        dma_channel_e channel;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        int unsigned length;
        channel = dma_channel_e'(item.owner);
        source_address = item.source_address() + ((item.descriptor_kind == 2) ? 1 : 0);
        destination_address = item.destination_address() + ((item.descriptor_kind == 3) ? 1 : 0);
        length = (item.descriptor_kind == 1) ? 0 : item.byte_count;
        `uvm_info("STRESS_JOB",
            $sformatf("CH%0d job=%0d dst_ch=%0d src=0x%08h dst=0x%08h len=%0d tag=0x%02h expected_error=0x%02h",
                item.owner, completed_jobs[item.owner], item.destination_channel,
                source_address, destination_address, length, item.software_tag, expected_error), UVM_MEDIUM)
        publish_dma_intent($sformatf("stress_ch%0d_job%0d", item.owner, completed_jobs[item.owner]),
            channel, dma_channel_e'(item.destination_channel), source_address,
            destination_address, length, item.software_tag, expected_error,
            1'b1, 1'b1, 1'b0);
        program_dma(channel, dma_channel_e'(item.destination_channel),
            source_address, destination_address, length, item.software_tag);
    endtask

    protected task verify_destination(input dma_subsys_random_stress_item item);
        bit [8*4096-1:0] payload;
        xil_axi_resp_t [255:0] response;
        logic [31:0] address;
        int unsigned total_bytes;
        int unsigned offset;
        int unsigned bytes_this_chunk;
        int unsigned position;
        byte unsigned expected_byte;
        address = item.destination_address() - 4;
        total_bytes = ((item.byte_count + 3) / 4) * 4 + 8;
        offset = 0;
        while (offset < total_bytes) begin
            bytes_this_chunk = chunk_size(address + offset, total_bytes - offset);
            external_read(external_master_for_address(address + offset),
                address + offset, bytes_this_chunk / 4, payload, response,
                "stress destination readback");
            check_read_responses(response, bytes_this_chunk / 4, "stress destination readback");
            for (int unsigned index = 0; index < bytes_this_chunk; index++) begin
                position = offset + index;
                if ((item.descriptor_kind == 0) && (position >= 4)
                        && (position < item.byte_count + 4)) begin
                    expected_byte = byte'(item.payload_seed + (position - 4) * 8'h1D);
                end else begin
                    expected_byte = byte'((item.payload_seed ^ 8'hA5) + position * 8'h1D);
                end
                if (payload[index*8 +: 8] !== expected_byte) begin
                    `uvm_error("STRESS_READBACK",
                        $sformatf("CH%0d address=0x%08h expected=0x%02h actual=0x%02h kind=%0d",
                            item.owner, address + position, expected_byte,
                            payload[index*8 +: 8], item.descriptor_kind))
                end
            end
            offset += bytes_this_chunk;
        end
    endtask

    protected task finish_job(
        input dma_subsys_random_stress_item item, input dma_error_e expected_error,
        input logic [1:0] read_response = 0, input logic [1:0] write_response = 0
    );
        check_channel_error(dma_channel_e'(item.owner), expected_error, 1'b0, "stress DMA result");
        wait_probe_cycles(2);
        if ((expected_error == DMA_ERR_NONE) || (item.descriptor_kind != 0)) begin
            verify_destination(item);
        end
        completed_jobs[item.owner]++;
        if (expected_error != DMA_ERR_NONE) begin
            expected_errors[item.owner]++;
            expected_last_error[item.owner] = expected_error;
        end
        if (item.descriptor_kind == 0) begin
            if (int'(item.source_address() & 32'hFFF) + item.byte_count > 4096) source_page_splits++;
            if (int'(item.destination_address() & 32'hFFF) + item.byte_count > 4096) destination_page_splits++;
        end
        descriptor_cg.sample(item.owner, int'(item.destination_channel),
            int'(item.source_ram), int'(item.destination_ram),
            (item.descriptor_kind == 1) ? 0 : item.byte_count, item.descriptor_kind,
            (item.descriptor_kind == 0) && (int'(item.source_address() & 32'hFFF) + item.byte_count > 4096),
            (item.descriptor_kind == 0) && (int'(item.destination_address() & 32'hFFF) + item.byte_count > 4096),
            read_response, write_response);
        set_channel_control(dma_channel_e'(item.owner), 1'b1, 1'b0, 1'b0, 1'b1,
            "stress clear local result");
        wait_probe_cycles(2);
    endtask

    protected task dma_worker(input int unsigned owner);
        dma_subsys_random_stress_item item;
        for (int unsigned index = 0; index < stress_cfg.commands_per_channel; index++) begin
            item = dma_subsys_random_stress_item::type_id::create($sformatf("job_ch%0d_%0d", owner, index));
            item.owner = owner;
            item.max_bytes = stress_cfg.max_bytes;
            if (!item.randomize()) `uvm_fatal("STRESS_RANDOMIZE", "DMA descriptor randomization failed")
            wait_probe_cycles(item.launch_gap);
            initialize_job(item);
            prepare_job(item, item.descriptor_error());
            set_channel_control(dma_channel_e'(owner), 1'b1, 1'b1, 1'b0, 1'b0, "stress submit DMA");
            finish_job(item, item.descriptor_error());
        end
    endtask

    protected task external_worker(input int unsigned index, input int fixed_ram);
        bit [8*4096-1:0] expected_payload;
        bit [8*4096-1:0] actual_payload;
        xil_axi_resp_t [255:0] response;
        dma_master_e master;
        int unsigned memory_index;
        int unsigned beats;
        logic [31:0] address;
        master = (index == 0) ? DMA_MASTER_EXT0 : DMA_MASTER_EXT1;
        while (external_enabled) begin
            memory_index = (fixed_ram < 0) ? $urandom_range(0, 1) : int'(fixed_ram);
            beats = $urandom_range(1, AXI_MAX_BURST_LEN);
            address = (memory_index == 0 ? RAM0_BASE_ADDR : RAM1_BASE_ADDR)
                + 32'hE000 + index * 4096
                + 4 * $urandom_range(0, (4096 - beats * 4) / 4);
            build_linear_payload(expected_payload, beats * 4, byte'($urandom()));
            external_write(master, address, beats, expected_payload, "stress EXT write");
            external_read(master, address, beats, actual_payload, response, "stress EXT read");
            check_read_responses(response, beats, "stress EXT read");
            for (int unsigned byte_index = 0; byte_index < beats * 4; byte_index++) begin
                if (actual_payload[byte_index*8 +: 8] !== expected_payload[byte_index*8 +: 8]) begin
                    `uvm_error("STRESS_EXT_DATA", $sformatf("EXT%0d address=0x%08h", index, address + byte_index))
                end
            end
            external_transactions[index]++;
            if (|p_sequencer.probe_vif.mon_cb.busy) external_busy_transactions++;
            wait_probe_cycles($urandom_range(0, stress_cfg.external_gap_max));
        end
    endtask

    protected task observe_activity();
        logic [1:0] waiting;
        while (monitor_enabled) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (!monitor_enabled) break;
            waiting = p_sequencer.probe_vif.mon_cb.route_req_valid
                & ~p_sequencer.probe_vif.mon_cb.route_req_ready;
            activity_cg.sample(p_sequencer.probe_vif.mon_cb.busy, waiting);
            if (&p_sequencer.probe_vif.mon_cb.busy) dual_busy_cycles++;
            if (|waiting) route_wait_cycles++;
            foreach (observed_completions[channel]) begin
                if (p_sequencer.probe_vif.mon_cb.completion_valid[channel]) observed_completions[channel]++;
            end
        end
    endtask

    protected task random_irq_activity();
        logic [31:0] value;
        while (monitor_enabled) begin
            wait_probe_cycles($urandom_range(8, 64));
            if (!monitor_enabled) break;
            case ($urandom_range(0, 3))
                0: axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
                    $urandom() & 32'h4000_0303, "stress IRQ mask");
                1: axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
                    $urandom() & 32'h4000_0303, "stress IRQ clear");
                2: axil_read32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS, value, "stress IRQ status");
                3: axil_read32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_LAST_ERROR, value, "stress last error");
            endcase
            irq_operations++;
        end
    endtask

    protected task random_memory_delays();
        int unsigned rdelay;
        int unsigned bdelay;
        while (monitor_enabled) begin
            rdelay = $urandom_range(0, stress_cfg.rdata_delay_max);
            bdelay = $urandom_range(0, stress_cfg.bresp_delay_max);
            p_sequencer.vip_mgr.mem0.mem_model.set_inter_beat_gap_range(rdelay, rdelay);
            p_sequencer.vip_mgr.mem0.mem_model.set_bresp_delay_range(bdelay, bdelay);
            rdelay = $urandom_range(0, stress_cfg.rdata_delay_max);
            bdelay = $urandom_range(0, stress_cfg.bresp_delay_max);
            p_sequencer.vip_mgr.mem1.mem_model.set_inter_beat_gap_range(rdelay, rdelay);
            p_sequencer.vip_mgr.mem1.mem_model.set_bresp_delay_range(bdelay, bdelay);
            delay_updates++;
            wait_probe_cycles($urandom_range(64, 256));
        end
    endtask

    protected task run_pair(input bit warmup, input int unsigned pair_index);
        dma_subsys_random_stress_item jobs[2];
        logic [1:0] read_response;
        logic [1:0] write_response;
        dma_error_e expected_error;
        int unsigned memory_index;
        int unsigned mode;
        int unsigned first_channel;
        int unsigned warmup_bytes;
        bit shared_destination;
        bit destination_channel;
        memory_index = $urandom_range(0, 1);
        first_channel = warmup ? 0 : $urandom_range(0, 1);
        shared_destination = warmup || ($urandom_range(0, 1) != 0);
        destination_channel = bit'($urandom_range(0, 1));
        warmup_bytes = (stress_cfg.max_bytes < 2048) ? stress_cfg.max_bytes : 2048;
        read_response = 0;
        write_response = 0;
        if (!warmup) begin
            mode = (pair_index < 8) ? pair_index : $urandom_range(0, 7);
            case (mode)
                0: write_response = 2;
                1: write_response = 3;
                2: read_response = 2;
                3: read_response = 3;
                4: begin read_response = 2; write_response = 2; end
                5: begin read_response = 2; write_response = 3; end
                6: begin read_response = 3; write_response = 2; end
                7: begin read_response = 3; write_response = 3; end
            endcase
        end
        expected_error = DMA_ERR_NONE;
        if (write_response == 2) expected_error = DMA_ERR_AXI_WR_SLVERR;
        else if (write_response == 3) expected_error = DMA_ERR_AXI_WR_DECERR;
        else if (read_response == 2) expected_error = DMA_ERR_AXI_RD_SLVERR;
        else if (read_response == 3) expected_error = DMA_ERR_AXI_RD_DECERR;
        `uvm_info("STRESS_PAIR",
            $sformatf("warmup=%0b pair=%0d ram=%0d rresp=%0d bresp=%0d shared_destination=%0b first_ch=%0d",
                warmup, pair_index, memory_index, read_response, write_response,
                shared_destination, first_channel), UVM_MEDIUM)
        foreach (jobs[channel]) begin
            jobs[channel] = dma_subsys_random_stress_item::type_id::create($sformatf("pair%0d_ch%0d", pair_index, channel));
            jobs[channel].owner = channel;
            jobs[channel].max_bytes = stress_cfg.max_bytes;
            if (!jobs[channel].randomize() with {
                    descriptor_kind == 0;
                    source_ram == local::memory_index;
                    destination_ram == local::memory_index;
                    if (local::shared_destination) destination_channel == local::destination_channel;
                    if (local::warmup) byte_count == local::warmup_bytes;
                    if (local::warmup) source_word == 1020;
                    if (local::warmup) destination_word == 1020;
                }) `uvm_fatal("STRESS_PAIR_RANDOMIZE", "DMA pair randomization failed")
            initialize_job(jobs[channel]);
            prepare_job(jobs[channel], expected_error);
        end
        external_enabled = 1'b1;
        fork
            external_worker(0, int'(1 - memory_index));
            external_worker(1, int'(1 - memory_index));
            begin
                if (!warmup) begin
                    p_sequencer.test_ctrl_vif.forced_rresp[memory_index] = read_response;
                    p_sequencer.test_ctrl_vif.forced_bresp[memory_index] = write_response;
                    p_sequencer.test_ctrl_vif.force_rresp_enable[memory_index] = (read_response != 0);
                    p_sequencer.test_ctrl_vif.force_bresp_enable[memory_index] = (write_response != 0);
                end
                set_channel_control(dma_channel_e'(first_channel), 1'b1, 1'b1, 1'b0, 1'b0, "stress pair first submit");
                if (warmup) wait_channel_busy(dma_channel_e'(first_channel));
                set_channel_control(dma_channel_e'(1 - first_channel), 1'b1, 1'b1, 1'b0, 1'b0, "stress pair second submit");
                fork
                    finish_job(jobs[0], expected_error, read_response, write_response);
                    finish_job(jobs[1], expected_error, read_response, write_response);
                join
                wait_probe_cycles(4);
                p_sequencer.test_ctrl_vif.force_rresp_enable = '0;
                p_sequencer.test_ctrl_vif.force_bresp_enable = '0;
                wait_probe_cycles(2);
                external_enabled = 1'b0;
            end
        join
    endtask

    protected task check_final_results();
        logic [31:0] value;
        logic [31:0] expected;
        int unsigned required_jobs;
        required_jobs = stress_cfg.commands_per_channel + stress_cfg.error_pairs + 1;
        foreach (completed_jobs[channel]) begin
            if ((completed_jobs[channel] != required_jobs)
                    || (observed_completions[channel] != required_jobs)) begin
                `uvm_error("STRESS_COMPLETION_COUNT",
                    $sformatf("CH%0d required=%0d completed=%0d observed=%0d",
                        channel, required_jobs, completed_jobs[channel], observed_completions[channel]))
            end
            axil_read32(GLOBAL_IRQ_BASE_ADDR + ((channel == 0) ? REG_CH0_DONE_COUNT : REG_CH1_DONE_COUNT),
                value, "stress final done count");
            if (value !== completed_jobs[channel]) `uvm_error("STRESS_DONE_COUNT", $sformatf("CH%0d value=%0d expected=%0d", channel, value, completed_jobs[channel]))
            axil_read32(GLOBAL_IRQ_BASE_ADDR + ((channel == 0) ? REG_CH0_ERROR_COUNT : REG_CH1_ERROR_COUNT),
                value, "stress final error count");
            if (value !== expected_errors[channel]) `uvm_error("STRESS_ERROR_COUNT", $sformatf("CH%0d value=%0d expected=%0d", channel, value, expected_errors[channel]))
            axil_read32(channel_base(dma_channel_e'(channel)) + REG_CMD_COUNT, value, "stress final command count");
            if (value !== completed_jobs[channel]) `uvm_error("STRESS_CMD_COUNT", $sformatf("CH%0d value=%0d expected=%0d", channel, value, completed_jobs[channel]))
        end
        axil_read32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_LAST_ERROR, value, "stress final last errors");
        expected = {16'd0, expected_last_error[1], expected_last_error[0]};
        if (value !== expected) `uvm_error("STRESS_LAST_ERROR", $sformatf("value=0x%08h expected=0x%08h", value, expected))
        if ((dual_busy_cycles == 0) || (route_wait_cycles == 0)
                || (external_busy_transactions == 0) || (irq_operations == 0)
                || (delay_updates == 0) || (external_transactions[0] == 0)
                || (external_transactions[1] == 0) || (source_page_splits == 0)
                || (destination_page_splits == 0)) begin
            `uvm_error("STRESS_ACTIVITY",
                $sformatf("Missing required activity: dual_busy=%0d route_wait=%0d ext_busy=%0d ext=%0d/%0d irq_ops=%0d delay_updates=%0d source_splits=%0d destination_splits=%0d",
                    dual_busy_cycles, route_wait_cycles, external_busy_transactions,
                    external_transactions[0], external_transactions[1], irq_operations,
                    delay_updates, source_page_splits, destination_page_splits))
        end
        prepare_subsystem();
        axil_read32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS, value, "stress final idle status");
        if ((value !== 32'd0) || (p_sequencer.probe_vif.mon_cb.route_active !== '0)
                || (p_sequencer.probe_vif.mon_cb.route_matrix !== '0)) begin
            `uvm_error("STRESS_FINAL_IDLE", $sformatf("IRQ status=0x%08h", value))
        end
    endtask

    virtual task body();
        wait_for_infrastructure();
        if (!uvm_config_db#(dma_subsys_random_stress_cfg)::get(
                p_sequencer, "", "dma_subsys_random_stress_cfg", stress_cfg)) begin
            `uvm_fatal("STRESS_NO_CONFIG", "Random stress configuration was not supplied")
        end
        stress_cfg.validate();
        `uvm_info("STRESS_CONFIG",
            $sformatf("commands_per_ch=%0d error_pairs=%0d max_bytes=%0d rdelay_max=%0d bdelay_max=%0d ext_gap_max=%0d",
                stress_cfg.commands_per_channel, stress_cfg.error_pairs, stress_cfg.max_bytes,
                stress_cfg.rdata_delay_max, stress_cfg.bresp_delay_max, stress_cfg.external_gap_max), UVM_LOW)
        prepare_subsystem();
        monitor_enabled = 1'b1;
        fork
            observe_activity();
            random_irq_activity();
            random_memory_delays();
            begin
                run_pair(1'b1, 0);
                external_enabled = 1'b1;
                fork
                    external_worker(0, -1);
                    external_worker(1, -1);
                    begin
                        fork
                            dma_worker(0);
                            dma_worker(1);
                        join
                        external_enabled = 1'b0;
                    end
                join
                for (int unsigned pair_index = 0; pair_index < stress_cfg.error_pairs; pair_index++) begin
                    run_pair(1'b0, pair_index);
                end
                monitor_enabled = 1'b0;
            end
        join
        wait_probe_cycles(8);
        check_final_results();
        `uvm_info("STRESS_SUMMARY",
            $sformatf("dma=%0d/%0d errors=%0d/%0d ext=%0d/%0d dual_busy_cycles=%0d route_wait_cycles=%0d ext_busy=%0d irq_ops=%0d delay_updates=%0d source_splits=%0d destination_splits=%0d descriptor_cov=%0.2f%% activity_cov=%0.2f%%",
                completed_jobs[0], completed_jobs[1], expected_errors[0], expected_errors[1],
                external_transactions[0], external_transactions[1], dual_busy_cycles,
                route_wait_cycles, external_busy_transactions, irq_operations, delay_updates,
                source_page_splits, destination_page_splits,
                descriptor_cg.get_inst_coverage(), activity_cg.get_inst_coverage()), UVM_LOW)
        wait_probe_cycles(8);
    endtask
endclass
