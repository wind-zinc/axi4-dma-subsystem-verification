class dma_subsys_coverage extends uvm_component;
    `uvm_component_utils(dma_subsys_coverage)

    uvm_analysis_imp_intent #(
        dma_subsys_cmd_tr, dma_subsys_coverage) intent_imp;
    uvm_analysis_imp_cmd #(
        dma_subsys_cmd_tr, dma_subsys_coverage) cmd_imp;
    uvm_analysis_imp_reg #(
        dma_subsys_reg_tr, dma_subsys_coverage) reg_imp;
    uvm_analysis_imp_mem #(
        dma_subsys_mem_tr, dma_subsys_coverage) mem_imp;
    uvm_analysis_imp_route #(
        dma_subsys_route_tr, dma_subsys_coverage) route_imp;
    uvm_analysis_imp_completion #(
        dma_subsys_completion_tr, dma_subsys_coverage) completion_imp;
    uvm_analysis_imp_irq #(
        dma_subsys_irq_tr, dma_subsys_coverage) irq_imp;
    uvm_analysis_imp_fault #(
        dma_subsys_fault_tr, dma_subsys_coverage) fault_imp;
    uvm_analysis_imp_reset #(
        dma_subsys_reset_tr, dma_subsys_coverage) reset_imp;

    typedef enum int unsigned {
        DMA_REG_RW_READ,
        DMA_REG_RW_WRITE,
        DMA_REG_RO_READ,
        DMA_REG_RO_WRITE_ATTEMPT,
        DMA_REG_WO_READ_ATTEMPT,
        DMA_REG_WO_WRITE,
        DMA_REG_UNMAPPED_READ,
        DMA_REG_UNMAPPED_WRITE
    } dma_reg_access_kind_e;

    protected function automatic dma_reg_access_kind_e
            classify_register_access(
                input dma_ctrl_block_e block,
                input logic [AXIL_BLOCK_ADDR_WIDTH-1:0] block_offset,
                input dma_access_e access
            );
        bit mapped;
        bit readable;
        bit writable;

        mapped = 1'b0;
        readable = 1'b0;
        writable = 1'b0;

        case (block)
            DMA_CTRL_CH0,
            DMA_CTRL_CH1: begin
                case (block_offset)
                    REG_CTRL,
                    REG_SRC_ADDR,
                    REG_DST_ADDR,
                    REG_LENGTH,
                    REG_ROUTE,
                    REG_SW_TAG: begin
                        mapped = 1'b1;
                        readable = 1'b1;
                        writable = 1'b1;
                    end
                    REG_STATUS,
                    REG_LAST_HW_TAG,
                    REG_COMPLETED_LEN,
                    REG_LAST_ERROR,
                    REG_CMD_COUNT,
                    REG_DONE_COUNT,
                    REG_VERSION: begin
                        mapped = 1'b1;
                        readable = 1'b1;
                    end
                    default: begin end
                endcase
            end
            DMA_CTRL_GLOBAL: begin
                case (block_offset)
                    REG_IRQ_ENABLE: begin
                        mapped = 1'b1;
                        readable = 1'b1;
                        writable = 1'b1;
                    end
                    REG_IRQ_CLEAR: begin
                        mapped = 1'b1;
                        writable = 1'b1;
                    end
                    REG_IRQ_STATUS,
                    REG_IRQ_LAST_ERROR,
                    REG_CH0_DONE_COUNT,
                    REG_CH1_DONE_COUNT,
                    REG_CH0_ERROR_COUNT,
                    REG_CH1_ERROR_COUNT,
                    REG_ROUTE_STATUS,
                    REG_GLOBAL_VERSION,
                    REG_FAULT_STATUS: begin
                        mapped = 1'b1;
                        readable = 1'b1;
                    end
                    default: begin end
                endcase
            end
            default: begin end
        endcase

        if (!mapped) begin
            return (access == DMA_ACCESS_READ)
                ? DMA_REG_UNMAPPED_READ : DMA_REG_UNMAPPED_WRITE;
        end
        if (access == DMA_ACCESS_READ) begin
            if (!readable) begin
                return DMA_REG_WO_READ_ATTEMPT;
            end
            return writable ? DMA_REG_RW_READ : DMA_REG_RO_READ;
        end
        if (!writable) begin
            return DMA_REG_RO_WRITE_ATTEMPT;
        end
        return readable ? DMA_REG_RW_WRITE : DMA_REG_WO_WRITE;
    endfunction

    protected function automatic bit incrementing_burst_crosses_4k(
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input int unsigned beat_count,
        input int unsigned bytes_per_beat
    );
        longint unsigned end_offset;

        if ((beat_count == 0) || (bytes_per_beat == 0)) begin
            return 1'b0;
        end
        end_offset = address[11:0]
            + (beat_count * bytes_per_beat);
        return end_offset > 4096;
    endfunction

    protected function automatic int unsigned memory_strobe_class(
        input dma_subsys_mem_tr tr
    );
        int unsigned valid_bytes;

        if (tr.access != DMA_ACCESS_WRITE) begin
            return 0;
        end
        valid_bytes = tr.valid_byte_count();
        if (valid_bytes == 0) begin
            return 1;
        end
        if (valid_bytes == tr.byte_enable.size()) begin
            return 3;
        end
        return 2;
    endfunction

    covergroup command_cg with function sample(
        dma_channel_e source_ch,
        dma_channel_e dest_ch,
        int unsigned length
    );
        option.per_instance = 1;
        option.name = "command_acceptance_group";
        option.comment = "Commands accepted by the DMA subsystem";
        cp_source: coverpoint source_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_dest: coverpoint dest_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_length: coverpoint length {
            illegal_bins zero = {0};
            bins sub_beat = {[1:3]};
            bins one_beat = {4};
            bins short = {[5:16]};
            bins one_burst = {[17:64]};
            bins multi_burst = {[65:256]};
            bins large_transfer = {[257:$]};
        }
        cross_route: cross cp_source, cp_dest;
    endgroup

    // Test intent carries the expected result.  Keep it separate from the
    // observed command: cmd_monitor reconstructs what RTL accepted and does
    // not know the test's expected error/completion/IRQ policy.
    covergroup intent_cg with function sample(
        dma_channel_e source_ch,
        dma_channel_e dest_ch,
        int unsigned  length,
        dma_error_e   expected_error,
        bit           expect_accept,
        bit           expect_completion,
        bit           expect_irq
    );
        option.per_instance = 1;
        option.name = "test_intent_group";
        option.comment = "Expected command behavior published by sequences";
        cp_source: coverpoint source_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_dest: coverpoint dest_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_length: coverpoint length {
            bins zero = {0};
            bins sub_beat = {[1:3]};
            bins one_beat = {4};
            bins short = {[5:16]};
            bins one_burst = {[17:64]};
            bins multi_burst = {[65:256]};
            bins large_transfer = {[257:$]};
        }
        cp_error: coverpoint expected_error {
            bins success = {DMA_ERR_NONE};
            bins disabled = {DMA_ERR_DISABLED};
            bins length_zero = {DMA_ERR_LEN_ZERO};
            bins source_alignment = {DMA_ERR_SRC_ALIGN};
            bins destination_alignment = {DMA_ERR_DST_ALIGN};
            bins source_range = {DMA_ERR_SRC_RANGE};
            bins destination_range = {DMA_ERR_DST_RANGE};
            bins overlap = {DMA_ERR_OVERLAP};
            bins busy = {DMA_ERR_BUSY};
            bins read_slverr = {DMA_ERR_AXI_RD_SLVERR};
            bins read_decerr = {DMA_ERR_AXI_RD_DECERR};
            bins write_slverr = {DMA_ERR_AXI_WR_SLVERR};
            bins write_decerr = {DMA_ERR_AXI_WR_DECERR};
            bins route_conflict = {DMA_ERR_ROUTE_CONFLICT};
            bins tag_mismatch = {DMA_ERR_TAG_MISMATCH};
            bins unexpected_status = {DMA_ERR_UNEXPECTED_STATUS};
            bins length_mismatch = {DMA_ERR_LEN_MISMATCH};
            bins abort_pending = {DMA_ERR_ABORT_PENDING};
            bins abort_inflight = {DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED};
            bins internal = {DMA_ERR_INTERNAL};
        }
        cp_expect_accept: coverpoint expect_accept;
        cp_expect_completion: coverpoint expect_completion;
        cp_expect_irq: coverpoint expect_irq;
        cross_route: cross cp_source, cp_dest;
    endgroup

    covergroup register_cg with function sample(
        dma_ctrl_block_e block,
        logic [AXIL_ADDR_WIDTH-1:0] addr,
        dma_access_e access,
        logic [AXIL_STRB_WIDTH-1:0] strb,
        dma_axi_resp_e response,
        dma_reg_access_kind_e access_kind
    );
        option.per_instance = 1;
        option.name = "register_access_group";
        option.comment = "AXI-Lite register accesses and responses";
        cp_block: coverpoint block;
        cp_register: coverpoint addr {
            bins ch0_registers[] = {
                CH0_CTRL_BASE_ADDR + REG_CTRL,
                CH0_CTRL_BASE_ADDR + REG_STATUS,
                CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
                CH0_CTRL_BASE_ADDR + REG_DST_ADDR,
                CH0_CTRL_BASE_ADDR + REG_LENGTH,
                CH0_CTRL_BASE_ADDR + REG_ROUTE,
                CH0_CTRL_BASE_ADDR + REG_SW_TAG,
                CH0_CTRL_BASE_ADDR + REG_LAST_HW_TAG,
                CH0_CTRL_BASE_ADDR + REG_COMPLETED_LEN,
                CH0_CTRL_BASE_ADDR + REG_LAST_ERROR,
                CH0_CTRL_BASE_ADDR + REG_CMD_COUNT,
                CH0_CTRL_BASE_ADDR + REG_DONE_COUNT,
                CH0_CTRL_BASE_ADDR + REG_VERSION
            };
            bins ch1_registers[] = {
                CH1_CTRL_BASE_ADDR + REG_CTRL,
                CH1_CTRL_BASE_ADDR + REG_STATUS,
                CH1_CTRL_BASE_ADDR + REG_SRC_ADDR,
                CH1_CTRL_BASE_ADDR + REG_DST_ADDR,
                CH1_CTRL_BASE_ADDR + REG_LENGTH,
                CH1_CTRL_BASE_ADDR + REG_ROUTE,
                CH1_CTRL_BASE_ADDR + REG_SW_TAG,
                CH1_CTRL_BASE_ADDR + REG_LAST_HW_TAG,
                CH1_CTRL_BASE_ADDR + REG_COMPLETED_LEN,
                CH1_CTRL_BASE_ADDR + REG_LAST_ERROR,
                CH1_CTRL_BASE_ADDR + REG_CMD_COUNT,
                CH1_CTRL_BASE_ADDR + REG_DONE_COUNT,
                CH1_CTRL_BASE_ADDR + REG_VERSION
            };
            bins global_registers[] = {
                GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
                GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
                GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
                GLOBAL_IRQ_BASE_ADDR + REG_IRQ_LAST_ERROR,
                GLOBAL_IRQ_BASE_ADDR + REG_CH0_DONE_COUNT,
                GLOBAL_IRQ_BASE_ADDR + REG_CH1_DONE_COUNT,
                GLOBAL_IRQ_BASE_ADDR + REG_CH0_ERROR_COUNT,
                GLOBAL_IRQ_BASE_ADDR + REG_CH1_ERROR_COUNT,
                GLOBAL_IRQ_BASE_ADDR + REG_ROUTE_STATUS,
                GLOBAL_IRQ_BASE_ADDR + REG_GLOBAL_VERSION,
                GLOBAL_IRQ_BASE_ADDR + REG_FAULT_STATUS
            };
            // Values outside these explicit mapped-address bins are covered
            // semantically by cp_access_kind as UNMAPPED_READ/WRITE.
        }
        cp_access: coverpoint access;
        cp_access_kind: coverpoint access_kind;
        cp_strb: coverpoint strb iff (access == DMA_ACCESS_WRITE) {
            bins none = {'0};
            bins partial = {[1:(2**AXIL_STRB_WIDTH)-2]};
            bins full = {'1};
        }
        cp_response: coverpoint response {
            bins okay = {DMA_AXI_OKAY};
            bins slverr = {DMA_AXI_SLVERR};
            bins decerr = {DMA_AXI_DECERR};
            ignore_bins exclusive = {DMA_AXI_EXOKAY};
        }
        cross_access_response: cross cp_access, cp_response;
    endgroup

    covergroup memory_cg with function sample(
        dma_master_e master,
        dma_memory_e target,
        dma_access_e access,
        dma_axi_resp_e response
    );
        option.per_instance = 1;
        option.name = "memory_traffic_group";
        option.comment = "Memory-side AXI traffic observed by VIP";
        cp_master: coverpoint master {
            bins dma0 = {DMA_MASTER_DMA0};
            bins dma1 = {DMA_MASTER_DMA1};
            bins ext0 = {DMA_MASTER_EXT0};
            bins ext1 = {DMA_MASTER_EXT1};
            ignore_bins unknown = {DMA_MASTER_UNKNOWN};
        }
        cp_target: coverpoint target {
            bins ram0 = {DMA_MEM_RAM0};
            bins ram1 = {DMA_MEM_RAM1};
            // Unmapped traffic never reaches a memory-side VIP. Decode-error
            // coverage belongs to the requesting interface, not this group.
            ignore_bins unmapped = {DMA_MEM_UNMAPPED};
        }
        cp_access: coverpoint access;
        cp_response: coverpoint response {
            bins okay = {DMA_AXI_OKAY};
            bins slverr = {DMA_AXI_SLVERR};
            bins decerr = {DMA_AXI_DECERR};
            // EXOKAY is only meaningful for exclusive accesses, which are
            // outside the current subsystem feature set.
            ignore_bins exclusive = {DMA_AXI_EXOKAY};
        }
        // The AXI crossbar is fully connected: every DMA/EXT master can
        // legally reach RAM0 and RAM1 for reads and writes.
        cross_path: cross cp_master, cp_target, cp_access;
        cross_access_response: cross cp_access, cp_response;
    endgroup

    // Protocol-relevant attributes already present in dma_subsys_mem_tr.
    // This complements AMD VIP protocol checking by showing which legal
    // transaction shapes the regression has actually exercised. LOCK,
    // CACHE and PROT require future transaction-adapter fields before they
    // can be sampled without vendor-specific references in this component.
    covergroup memory_protocol_cg with function sample(
        dma_access_e access,
        dma_burst_e burst,
        int unsigned beat_count,
        int unsigned bytes_per_beat,
        logic [AXI_ID_WIDTH-1:0] original_id,
        logic [11:0] page_offset,
        bit start_aligned,
        bit crosses_4k,
        int unsigned strobe_class,
        bit protocol_error
    );
        option.per_instance = 1;
        option.name = "memory_protocol_shape_group";
        option.comment = "AXI burst, size, ID, alignment and byte-lane usage";
        cp_access: coverpoint access;
        cp_burst: coverpoint burst {
            bins fixed = {DMA_BURST_FIXED};
            bins incr = {DMA_BURST_INCR};
            bins wrap = {DMA_BURST_WRAP};
            illegal_bins unknown = {DMA_BURST_UNKNOWN};
        }
        cp_beat_count: coverpoint beat_count {
            bins single = {1};
            bins short = {[2:4]};
            bins _medium = {[5:8]};
            bins dma_max_window = {[9:AXI_MAX_BURST_LEN]};
            // AXI4 INCR permits up to 256 transfers even though the two DMA
            // engines are configured to split at AXI_MAX_BURST_LEN (16).
            bins extended_incr = {[AXI_MAX_BURST_LEN+1:256]};
            illegal_bins zero = {0};
            illegal_bins exceeds_axi4_limit = {[257:$]};
        }
        cp_fixed_length: coverpoint beat_count
                iff (burst == DMA_BURST_FIXED) {
            bins single = {1};
            bins multi = {[2:16]};
            illegal_bins too_long = {[17:$]};
        }
        cp_wrap_length: coverpoint beat_count
                iff (burst == DMA_BURST_WRAP) {
            bins two = {2};
            bins four = {4};
            bins eight = {8};
            bins sixteen = {16};
            illegal_bins invalid_length = {
                0, 1, 3, [5:7], [9:15], [17:$]
            };
        }
        cp_bytes_per_beat: coverpoint bytes_per_beat {
            bins byte_1 = {1};
            bins byte_2 = {2};
            bins byte_4 = {4};
            illegal_bins unsupported = {0, 3, [5:$]};
        }
        cp_original_id: coverpoint original_id {
            bins zero = {0};
            bins nonzero = {[1:(2**AXI_ID_WIDTH)-1]};
        }
        cp_page_offset: coverpoint page_offset {
            bins page_start = {12'h000};
            bins body = {[12'h001:12'hFBF]};
            bins boundary_window = {[12'hFC0:12'hFFF]};
        }
        cp_start_alignment: coverpoint start_aligned;
        cp_incr_4k_rule: coverpoint crosses_4k
                iff (burst == DMA_BURST_INCR) {
            bins stays_in_page = {1'b0};
            illegal_bins crosses_boundary = {1'b1};
        }
        cp_write_strobe: coverpoint strobe_class
                iff (access == DMA_ACCESS_WRITE) {
            bins none = {1};
            bins partial = {2};
            bins full = {3};
        }
        cp_protocol_error: coverpoint protocol_error {
            bins clean = {1'b0};
            illegal_bins malformed = {1'b1};
        }
        cross_burst_access: cross cp_burst, cp_access;
    endgroup

    covergroup route_cg with function sample(
        dma_route_event_e event_kind,
        dma_channel_e source_ch,
        dma_channel_e dest_ch,
        int unsigned wait_cycles
    );
        option.per_instance = 1;
        option.name = "route_arbitration_group";
        option.comment = "Route requests, grants and wait time";
        cp_event: coverpoint event_kind;
        cp_path_event: coverpoint event_kind {
            bins request = {DMA_ROUTE_REQUEST};
            bins granted = {DMA_ROUTE_GRANTED};
            bins released = {DMA_ROUTE_RELEASED};
            ignore_bins fault = {DMA_ROUTE_FAULT};
        }
        cp_source: coverpoint source_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_dest: coverpoint dest_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_wait: coverpoint wait_cycles
                iff (event_kind == DMA_ROUTE_GRANTED) {
            bins immediate = {0};
            bins short_wait = {[1:4]};
            bins long_wait = {[5:$]};
        }
        cross_path: cross cp_path_event, cp_source, cp_dest;
    endgroup

    covergroup completion_cg with function sample(
        dma_channel_e owner_ch,
        dma_error_e error,
        bit aborted
    );
        option.per_instance = 1;
        option.name = "completion_result_group";
        option.comment = "DMA completion owner and result";
        cp_owner: coverpoint owner_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_error: coverpoint error {
            bins success = {DMA_ERR_NONE};
            bins length_zero = {DMA_ERR_LEN_ZERO};
            bins source_alignment = {DMA_ERR_SRC_ALIGN};
            bins destination_alignment = {DMA_ERR_DST_ALIGN};
            bins source_range = {DMA_ERR_SRC_RANGE};
            bins destination_range = {DMA_ERR_DST_RANGE};
            bins overlap = {DMA_ERR_OVERLAP};
            bins read_slverr = {DMA_ERR_AXI_RD_SLVERR};
            bins read_decerr = {DMA_ERR_AXI_RD_DECERR};
            bins write_slverr = {DMA_ERR_AXI_WR_SLVERR};
            bins write_decerr = {DMA_ERR_AXI_WR_DECERR};
            bins route_conflict = {DMA_ERR_ROUTE_CONFLICT};
            bins tag_mismatch = {DMA_ERR_TAG_MISMATCH};
            bins length_mismatch = {DMA_ERR_LEN_MISMATCH};
            bins abort_pending = {DMA_ERR_ABORT_PENDING};
            bins abort_inflight = {DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED};
            bins internal = {DMA_ERR_INTERNAL};
            ignore_bins not_a_completion = {
                DMA_ERR_DISABLED,
                DMA_ERR_BUSY,
                DMA_ERR_UNEXPECTED_STATUS
            };
        }
        cp_aborted: coverpoint aborted;
        cross_owner_abort: cross cp_owner, cp_aborted;
    endgroup

    // Completion order is a system-level property across independent DMA
    // channels.  It is deliberately separate from AXI response ordering:
    // each current DMA engine uses one fixed AXI ID and accepts only one
    // active command, while CH0 and CH1 may complete in either issue order.
    covergroup completion_order_cg with function sample(
        dma_channel_e first_issued_ch,
        dma_channel_e completed_ch,
        bit           reordered,
        int unsigned  pending_depth,
        int unsigned  order_case
    );
        option.per_instance = 1;
        option.name = "completion_order_group";
        option.comment = "Cross-channel completion ordering";
        cp_first_issued: coverpoint first_issued_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_completed: coverpoint completed_ch {
            bins ch0 = {DMA_CH0};
            bins ch1 = {DMA_CH1};
            ignore_bins unknown = {DMA_CH_UNKNOWN};
        }
        cp_reordered: coverpoint reordered {
            bins in_issue_order = {1'b0};
            bins out_of_issue_order = {1'b1};
        }
        cp_pending_depth: coverpoint pending_depth {
            bins single = {1};
            bins concurrent = {[2:$]};
        }
        cp_order_case: coverpoint order_case {
            bins ch0_first_ch0_completes = {0};
            bins ch0_first_ch1_overtakes = {1};
            bins ch1_first_ch1_completes = {2};
            bins ch1_first_ch0_overtakes = {3};
            ignore_bins uncorrelated = {[4:$]};
        }
    endgroup

    covergroup irq_cg with function sample(
        dma_irq_event_e event_kind,
        bit global_irq,
        logic [DMA_CH_COUNT-1:0] irq_ch,
        logic [DMA_CH_COUNT-1:0] done_pending,
        logic [DMA_CH_COUNT-1:0] error_pending,
        logic [DMA_CH_COUNT-1:0] done_enable,
        logic [DMA_CH_COUNT-1:0] error_enable,
        bit fault_pending,
        bit fault_enable,
        logic [2:0] enabled_cause,
        bit masked_pending,
        bit global_consistent,
        bit channel_consistent
    );
        option.per_instance = 1;
        option.name = "irq_behavior_group";
        option.comment = "Per-channel and global IRQ behavior";
        cp_event: coverpoint event_kind {
            bins asserted = {DMA_IRQ_ASSERTED};
            bins deasserted = {DMA_IRQ_DEASSERTED};
            bins status_sampled = {DMA_IRQ_STATUS_SAMPLED};
            // The current monitor represents a software clear as a pending
            // state transition plus IRQ deassertion, not a separate event.
            ignore_bins not_published = {DMA_IRQ_CLEARED};
        }
        cp_global: coverpoint global_irq;
        cp_channel: coverpoint irq_ch {
            bins none = {'0};
            bins ch0 = {2'b01};
            bins ch1 = {2'b10};
            bins both = {'1};
        }
        cp_done_pending: coverpoint done_pending {
            bins none = {'0};
            bins ch0 = {2'b01};
            bins ch1 = {2'b10};
            bins both = {'1};
        }
        cp_error_pending: coverpoint error_pending {
            bins none = {'0};
            bins ch0 = {2'b01};
            bins ch1 = {2'b10};
            bins both = {'1};
        }
        cp_done_enable: coverpoint done_enable {
            bins none = {'0};
            bins ch0 = {2'b01};
            bins ch1 = {2'b10};
            bins both = {'1};
        }
        cp_error_enable: coverpoint error_enable {
            bins none = {'0};
            bins ch0 = {2'b01};
            bins ch1 = {2'b10};
            bins both = {'1};
        }
        cp_fault_pending: coverpoint fault_pending;
        cp_fault_enable: coverpoint fault_enable;
        cp_enabled_cause: coverpoint enabled_cause {
            bins none = {3'b000};
            bins done_only = {3'b001};
            bins error_only = {3'b010};
            bins fault_only = {3'b100};
            bins multiple = {
                3'b011, 3'b101, 3'b110, 3'b111
            };
        }
        cp_masked_pending: coverpoint masked_pending;
        cp_global_consistency: coverpoint global_consistent {
            bins consistent = {1'b1};
            illegal_bins inconsistent = {1'b0};
        }
        cp_channel_consistency: coverpoint channel_consistent {
            bins consistent = {1'b1};
            illegal_bins inconsistent = {1'b0};
        }
    endgroup

    covergroup fault_cg with function sample(
        dma_fault_event_e event_kind,
        dma_error_e error,
        dma_fault_source_e source,
        bit enabled
    );
        option.per_instance = 1;
        option.name = "global_fault_group";
        option.comment = "Internal subsystem faults and IRQ mask state";
        cp_event: coverpoint event_kind {
            bins raised = {DMA_FAULT_RAISED};
            ignore_bins clear_not_published = {DMA_FAULT_CLEARED};
        }
        cp_error: coverpoint error {
            bins unexpected_status = {DMA_ERR_UNEXPECTED_STATUS};
            bins route_conflict = {DMA_ERR_ROUTE_CONFLICT};
            bins internal = {DMA_ERR_INTERNAL};
            illegal_bins non_fault_error = {
                DMA_ERR_NONE,
                DMA_ERR_DISABLED,
                DMA_ERR_LEN_ZERO,
                DMA_ERR_SRC_ALIGN,
                DMA_ERR_DST_ALIGN,
                DMA_ERR_SRC_RANGE,
                DMA_ERR_DST_RANGE,
                DMA_ERR_OVERLAP,
                DMA_ERR_BUSY,
                DMA_ERR_AXI_RD_SLVERR,
                DMA_ERR_AXI_RD_DECERR,
                DMA_ERR_AXI_WR_SLVERR,
                DMA_ERR_AXI_WR_DECERR,
                DMA_ERR_TAG_MISMATCH,
                DMA_ERR_LEN_MISMATCH,
                DMA_ERR_ABORT_PENDING,
                DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED
            };
        }
        cp_source: coverpoint source;
        cp_enabled: coverpoint enabled;
    endgroup

    covergroup reset_cg with function sample(
        dma_reset_event_e event_kind,
        int unsigned reset_epoch,
        bit had_pending_command
    );
        option.per_instance = 1;
        option.name = "reset_behavior_group";
        option.comment = "Initial and repeated reset, including active reset";
        cp_event: coverpoint event_kind;
        cp_epoch: coverpoint reset_epoch {
            bins initial_boot = {0};
            bins repeated_reset = {[1:$]};
        }
        cp_assert_context: coverpoint had_pending_command
                iff (event_kind == DMA_RESET_ASSERTED) {
            bins idle = {1'b0};
            bins active = {1'b1};
        }
    endgroup

    protected longint unsigned intent_samples;
    protected longint unsigned register_samples;
    protected longint unsigned fault_samples;
    protected longint unsigned reset_samples;
    protected dma_channel_e issue_order[$];

    function new(
        string        name   = "dma_subsys_coverage",
        uvm_component parent = null
    );
        super.new(name, parent);
        intent_imp = new("intent_imp", this);
        cmd_imp = new("cmd_imp", this);
        reg_imp = new("reg_imp", this);
        mem_imp = new("mem_imp", this);
        route_imp = new("route_imp", this);
        completion_imp = new("completion_imp", this);
        irq_imp = new("irq_imp", this);
        fault_imp = new("fault_imp", this);
        reset_imp = new("reset_imp", this);
        intent_cg = new();
        command_cg = new();
        register_cg = new();
        memory_cg = new();
        memory_protocol_cg = new();
        route_cg = new();
        completion_cg = new();
        completion_order_cg = new();
        irq_cg = new();
        fault_cg = new();
        reset_cg = new();
    endfunction

    virtual function void write_intent(input dma_subsys_cmd_tr tr);
        intent_samples++;
        intent_cg.sample(
            tr.source_ch,
            tr.dest_ch,
            tr.length,
            tr.expected_error,
            tr.expect_accept,
            tr.expect_completion,
            tr.expect_irq);
    endfunction

    virtual function void write_cmd(input dma_subsys_cmd_tr tr);
        command_cg.sample(tr.source_ch, tr.dest_ch, tr.length);
        if (tr.event_kind == DMA_CMD_ACCEPTED) begin
            issue_order.push_back(tr.source_ch);
        end
    endfunction

    virtual function void write_reg(input dma_subsys_reg_tr tr);
        dma_reg_access_kind_e access_kind;

        register_samples++;
        access_kind = classify_register_access(
            tr.block, tr.block_offset(), tr.access);
        register_cg.sample(
            tr.block,
            tr.addr,
            tr.access,
            tr.strb,
            tr.resp,
            access_kind);
    endfunction

    virtual function void write_mem(input dma_subsys_mem_tr tr);
        bit start_aligned;
        bit crosses_4k;

        memory_cg.sample(tr.master, tr.target, tr.access, tr.resp);
        if (tr.bytes_per_beat == 0) begin
            start_aligned = 1'b0;
        end else begin
            start_aligned = ((tr.addr % tr.bytes_per_beat) == 0);
        end
        crosses_4k = incrementing_burst_crosses_4k(
            tr.addr, tr.beat_count, tr.bytes_per_beat);
        memory_protocol_cg.sample(
            tr.access,
            tr.burst,
            tr.beat_count,
            tr.bytes_per_beat,
            tr.axi_id[AXI_ID_WIDTH-1:0],
            tr.addr[11:0],
            start_aligned,
            crosses_4k,
            memory_strobe_class(tr),
            tr.protocol_error);
    endfunction

    virtual function void write_route(input dma_subsys_route_tr tr);
        route_cg.sample(
            tr.event_kind, tr.source_ch, tr.dest_ch, tr.wait_cycles);
    endfunction

    virtual function void write_completion(
        input dma_subsys_completion_tr tr
    );
        dma_channel_e first_issued_ch;
        int matched_index;
        int unsigned order_case;
        bit reordered;

        first_issued_ch = DMA_CH_UNKNOWN;
        matched_index = -1;
        order_case = 4;
        reordered = 1'b0;

        if (issue_order.size() != 0) begin
            first_issued_ch = issue_order[0];
            foreach (issue_order[index]) begin
                if (issue_order[index] == tr.owner_ch) begin
                    matched_index = index;
                    break;
                end
            end
            reordered = (matched_index > 0);
        end

        if ((first_issued_ch == DMA_CH0)
                && (tr.owner_ch == DMA_CH0) && !reordered) begin
            order_case = 0;
        end else if ((first_issued_ch == DMA_CH0)
                && (tr.owner_ch == DMA_CH1) && reordered) begin
            order_case = 1;
        end else if ((first_issued_ch == DMA_CH1)
                && (tr.owner_ch == DMA_CH1) && !reordered) begin
            order_case = 2;
        end else if ((first_issued_ch == DMA_CH1)
                && (tr.owner_ch == DMA_CH0) && reordered) begin
            order_case = 3;
        end

        completion_cg.sample(tr.owner_ch, tr.error, tr.aborted);
        completion_order_cg.sample(
            first_issued_ch,
            tr.owner_ch,
            reordered,
            issue_order.size(),
            order_case);

        if (matched_index >= 0) begin
            issue_order.delete(matched_index);
        end
    endfunction

    virtual function void write_irq(input dma_subsys_irq_tr tr);
        logic [2:0] enabled_cause;
        logic [DMA_CH_COUNT-1:0] expected_irq_ch;
        bit expected_global_irq;
        bit masked_pending;

        enabled_cause[0] = |(tr.done_pending & tr.done_enable);
        enabled_cause[1] = |(tr.error_pending & tr.error_enable);
        enabled_cause[2] = tr.fault_pending & tr.fault_enable;
        expected_irq_ch = (tr.done_pending & tr.done_enable)
            | (tr.error_pending & tr.error_enable);
        expected_global_irq = |enabled_cause;
        masked_pending = |(tr.done_pending & ~tr.done_enable)
            || |(tr.error_pending & ~tr.error_enable)
            || (tr.fault_pending && !tr.fault_enable);

        irq_cg.sample(
            tr.event_kind,
            tr.global_irq,
            tr.irq_ch,
            tr.done_pending,
            tr.error_pending,
            tr.done_enable,
            tr.error_enable,
            tr.fault_pending,
            tr.fault_enable,
            enabled_cause,
            masked_pending,
            (tr.global_irq == expected_global_irq),
            (tr.irq_ch == expected_irq_ch));
    endfunction

    virtual function void write_fault(input dma_subsys_fault_tr tr);
        fault_samples++;
        fault_cg.sample(tr.event_kind, tr.error, tr.source, tr.enabled);
    endfunction

    virtual function void write_reset(input dma_subsys_reset_tr tr);
        reset_samples++;
        reset_cg.sample(
            tr.event_kind,
            tr.reset_epoch,
            (issue_order.size() != 0));
        if (tr.event_kind == DMA_RESET_ASSERTED) begin
            issue_order.delete();
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(
            "COV_SUMMARY",
            $sformatf(
                "intent=%0.2f%% command=%0.2f%% register=%0.2f%% memory=%0.2f%% memory_protocol=%0.2f%% route=%0.2f%% completion=%0.2f%% completion_order=%0.2f%% irq=%0.2f%% fault=%0.2f%% reset=%0.2f%% intent_samples=%0d reg_samples=%0d fault_samples=%0d reset_samples=%0d",
                intent_cg.get_inst_coverage(),
                command_cg.get_inst_coverage(),
                register_cg.get_inst_coverage(),
                memory_cg.get_inst_coverage(),
                memory_protocol_cg.get_inst_coverage(),
                route_cg.get_inst_coverage(),
                completion_cg.get_inst_coverage(),
                completion_order_cg.get_inst_coverage(),
                irq_cg.get_inst_coverage(),
                fault_cg.get_inst_coverage(),
                reset_cg.get_inst_coverage(),
                intent_samples, register_samples,
                fault_samples, reset_samples),
            UVM_LOW)
    endfunction

endclass
