/*
 * Central functional-coverage anchor.
 *
 * It consumes completed AXI-Lite transactions from the monitor, rebuilds the
 * descriptor staging registers, and samples a descriptor when a successful
 * SUBMIT register write is observed.  Therefore direct sequences and future RAL sequences both
 * contribute to exactly the same coverage model.
 */
class dma_coverage extends uvm_subscriber #(axil_item);

    `uvm_component_utils(dma_coverage)

    virtual irq_if irq_vif;

    bit [31:0] src_shadow;
    bit [31:0] dst_shadow;
    bit [31:0] length_shadow;
    bit [31:0] tag_shadow;
    bit [31:0] comp_tag_shadow;
    bit [31:0] comp_length_shadow;
    bit        irq_enable_shadow;
    bit        comp_valid_shadow;

    covergroup axil_cg with function sample(
        axil_op_e op,
        bit [7:0] addr,
        bit [3:0] wstrb,
        bit [1:0] resp
    );
        option.per_instance = 1;
        option.name = "dma_axil_access_cov";

        cp_op: coverpoint op {
            bins read  = {AXIL_READ};
            bins write = {AXIL_WRITE};
        }

        cp_addr: coverpoint addr {
            bins control         = {REG_CONTROL};
            bins status          = {REG_STATUS};
            bins src_addr        = {REG_SRC_ADDR};
            bins dst_addr        = {REG_DST_ADDR};
            bins length          = {REG_LENGTH};
            bins tag             = {REG_TAG};
            bins submit          = {REG_SUBMIT};
            bins comp_tag        = {REG_COMP_TAG};
            bins comp_length     = {REG_COMP_LENGTH};
            bins comp_status     = {REG_COMP_STATUS};
            bins comp_pop        = {REG_COMP_POP};
            bins queue_levels    = {REG_QUEUE_LEVELS};
            bins submitted_count = {REG_SUBMITTED_COUNT};
            bins completed_count = {REG_COMPLETED_COUNT};
            bins unmapped        = default;
        }

        cp_wstrb: coverpoint wstrb iff (op == AXIL_WRITE) {
            bins full    = {4'hf};
            bins partial = {[4'h1:4'he]};
            bins _none   = {4'h0};
        }

        /*
         * Detailed byte-enable coverage is limited to the four 32-bit
         * descriptor staging registers, where every byte lane is writable.
         */
        cp_staging_write_addr: coverpoint addr iff (
            op == AXIL_WRITE &&
            addr inside {REG_SRC_ADDR, REG_DST_ADDR, REG_LENGTH, REG_TAG}
        ) {
            bins src_addr = {REG_SRC_ADDR};
            bins dst_addr = {REG_DST_ADDR};
            bins length   = {REG_LENGTH};
            bins tag      = {REG_TAG};
        }

        cp_wstrb_pattern: coverpoint wstrb iff (
            op == AXIL_WRITE &&
            addr inside {REG_SRC_ADDR, REG_DST_ADDR, REG_LENGTH, REG_TAG}
        ) {
            bins zero          = {4'b0000};
            bins single_lane[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
            bins adjacent[]    = {4'b0011, 4'b0110, 4'b1100};
            bins separated[]   = {4'b0101, 4'b1001, 4'b1010};
            bins triple[]      = {4'b0111, 4'b1011, 4'b1101, 4'b1110};
            bins full          = {4'b1111};
        }

        cp_lane0: coverpoint wstrb[0] iff (op == AXIL_WRITE);
        cp_lane1: coverpoint wstrb[1] iff (op == AXIL_WRITE);
        cp_lane2: coverpoint wstrb[2] iff (op == AXIL_WRITE);
        cp_lane3: coverpoint wstrb[3] iff (op == AXIL_WRITE);

        cp_resp: coverpoint resp {
            bins okay = {2'b00};
            ignore_bins unsupported = {[2'b01:2'b11]};
        }

        op_x_addr: cross cp_op, cp_addr;
        wstrb_x_staging_addr: cross cp_wstrb_pattern,
                                     cp_staging_write_addr;
    endgroup

    covergroup descriptor_cg with function sample(
        bit [15:0] src_addr,
        bit [15:0] dst_addr,
        bit [19:0] byte_length,
        bit [7:0]  tag,
        bit        src_cross_4k,
        bit        dst_cross_4k
    );
        option.per_instance = 1;
        option.name = "dma_descriptor_cov";

        cp_length: coverpoint byte_length {
            bins zero        = {20'd0};
            bins sub_beat    = {[20'd1:20'd3]};
            bins one_beat    = {20'd4};
            bins short       = {[20'd5:20'd64]};
            bins _medium     = {[20'd65:20'd256]};
            bins long        = {[20'd257:20'd4096]};
            bins very_long   = {[20'd4097:20'hfffff]};
        }

        cp_src_align: coverpoint src_addr[1:0] {
            bins aligned = {2'b00};
            bins unaligned[] = {[2'b01:2'b11]};
        }

        cp_dst_align: coverpoint dst_addr[1:0] {
            bins aligned = {2'b00};
            bins unaligned[] = {[2'b01:2'b11]};
        }

        cp_src_cross_4k: coverpoint src_cross_4k {
            bins no  = {1'b0};
            bins yes = {1'b1};
        }

        cp_dst_cross_4k: coverpoint dst_cross_4k {
            bins no  = {1'b0};
            bins yes = {1'b1};
        }

        cp_tag: coverpoint tag {
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }

        boundary_matrix: cross cp_src_cross_4k, cp_dst_cross_4k;
    endgroup

    covergroup irq_cg with function sample(
        bit irq_value,
        bit irq_enable,
        bit comp_valid
    );
        option.per_instance = 1;
        option.name = "dma_irq_cov";

        cp_irq_level: coverpoint irq_value {
            bins low  = {1'b0};
            bins high = {1'b1};
        }

        cp_irq_transition: coverpoint irq_value {
            bins rise = (1'b0 => 1'b1);
            bins fall = (1'b1 => 1'b0);
        }

        cp_enable: coverpoint irq_enable {
            bins disabled = {1'b0};
            bins enabled  = {1'b1};
        }

        cp_comp_valid: coverpoint comp_valid {
            bins empty    = {1'b0};
            bins nonempty = {1'b1};
        }

        enable_x_irq: cross cp_enable, cp_irq_level {
            ignore_bins disabled_high =
                binsof(cp_enable) intersect {1'b0} &&
                binsof(cp_irq_level) intersect {1'b1};
        }

        completion_x_irq: cross cp_comp_valid, cp_irq_level {
            ignore_bins empty_high =
                binsof(cp_comp_valid) intersect {1'b0} &&
                binsof(cp_irq_level) intersect {1'b1};
        }
    endgroup

    covergroup manager_status_cg with function sample(bit [31:0] status);
        option.per_instance = 1;
        option.name = "dma_manager_status_cov";

        cp_active: coverpoint status[0];
        cp_req_empty: coverpoint status[1];
        cp_req_full: coverpoint status[2];
        cp_submit_ready: coverpoint status[3];
        cp_comp_valid: coverpoint status[4];
        cp_comp_full: coverpoint status[5];
        cp_irq: coverpoint status[6];

        cp_reject_full: coverpoint status[7];
        cp_reject_invalid: coverpoint status[8];
        /*
         * A mismatch requires corrupting the private DMA status interface.
         * It is covered in a manager unit test, not through this subsystem's
         * software-visible frontdoor.
         */
        cp_status_mismatch: coverpoint status[9] {
            bins normal = {1'b0};
            ignore_bins requires_internal_fault = {1'b1};
        }
        cp_pop_empty: coverpoint status[10];
    endgroup

    covergroup queue_level_cg with function sample(
        bit [15:0] request_level,
        bit [15:0] completion_level
    );
        option.per_instance = 1;
        option.name = "dma_queue_level_cov";

        cp_request_level: coverpoint request_level {
            bins empty = {0};
            bins one   = {1};
            bins mid   = {[2:3]};
            bins full  = {4};
            illegal_bins invalid = default;
        }

        cp_completion_level: coverpoint completion_level {
            bins empty = {0};
            bins one   = {1};
            bins mid   = {[2:3]};
            bins full  = {4};
            illegal_bins invalid = default;
        }

        /* Four useful occupancy modes; the raw 4x4 level cross overstates
         * combinations that are transient or architecture-dependent. */
        cp_request_present: coverpoint (request_level != 0) {
            bins empty    = {1'b0};
            bins nonempty = {1'b1};
        }

        cp_completion_present: coverpoint (completion_level != 0) {
            bins empty    = {1'b0};
            bins nonempty = {1'b1};
        }

        levels_x: cross cp_request_present, cp_completion_present;
    endgroup

    covergroup completion_cg with function sample(
        bit [7:0]  tag,
        bit [19:0] byte_length,
        bit [10:0] status
    );
        option.per_instance = 1;
        option.name = "dma_completion_cov";

        cp_tag: coverpoint tag {
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }

        cp_length: coverpoint byte_length {
            /* Zero-length descriptors are rejected before a completion is
             * created, so zero is intentionally absent from this stream. */
            ignore_bins zero = {20'd0};
            bins short     = {[20'd1:20'd64]};
            bins _medium   = {[20'd65:20'd256]};
            bins long      = {[20'd257:20'd4096]};
            bins very_long = {[20'd4097:20'hfffff]};
        }

        cp_read_error: coverpoint status[3:0] {
            bins _none = {4'h0};
            bins slverr = {4'h4};
            bins decerr = {4'h5};
            ignore_bins unsupported = {[4'h1:4'h3],[4'h6:4'hf]};
        }

        cp_write_error: coverpoint status[7:4] {
            bins _none = {4'h0};
            bins slverr = {4'h6};
            bins decerr = {4'h7};
            ignore_bins unsupported = {[4'h1:4'h5],[4'h8:4'hf]};
        }

        cp_mismatch: coverpoint status[10:8] {
            bins _none = {3'b000};
            ignore_bins requires_internal_fault = {[3'b001:3'b111]};
        }
    endgroup

    function new(string name = "dma_coverage",
                 uvm_component parent = null);
        super.new(name, parent);
        axil_cg       = new();
        descriptor_cg = new();
        irq_cg        = new();
        manager_status_cg = new();
        queue_level_cg = new();
        completion_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual irq_if)::get(
                this, "", "irq_vif", irq_vif))
            `uvm_fatal("NO_IRQ_VIF",
                "dma_coverage did not receive irq_if")

    endfunction

    function automatic bit [31:0] apply_wstrb(
        bit [31:0] old_value,
        bit [31:0] new_value,
        bit [3:0]  strb
    );
        bit [31:0] result;
        result = old_value;
        for (int i = 0; i < 4; i++)
            if (strb[i])
                result[i*8 +: 8] = new_value[i*8 +: 8];
        return result;
    endfunction

    function automatic bit crosses_4k(
        bit [15:0] addr,
        bit [19:0] byte_length
    );
        bit [20:0] last_offset;

        if (byte_length == 0)
            return 1'b0;

        last_offset = {9'd0, addr[11:0]} + byte_length - 1'b1;
        return last_offset >= 21'd4096;
    endfunction

    virtual function void write(axil_item tr);
        axil_cg.sample(tr.op, tr.addr, tr.wstrb, tr.resp);

        if (tr.resp == 2'b00 && tr.op == AXIL_WRITE) begin
            case (tr.addr)
                REG_CONTROL: begin
                    if (tr.wstrb[0])
                        irq_enable_shadow = tr.wdata[0];
                end
                REG_SRC_ADDR:
                    src_shadow = apply_wstrb(
                        src_shadow, tr.wdata, tr.wstrb);
                REG_DST_ADDR:
                    dst_shadow = apply_wstrb(
                        dst_shadow, tr.wdata, tr.wstrb);
                REG_LENGTH:
                    length_shadow = apply_wstrb(
                        length_shadow, tr.wdata, tr.wstrb);
                REG_TAG:
                    tag_shadow = apply_wstrb(
                        tag_shadow, tr.wdata, tr.wstrb);
                REG_SUBMIT: begin
                    if (tr.wstrb[0] && tr.wdata[0]) begin
                        descriptor_cg.sample(
                            src_shadow[15:0],
                            dst_shadow[15:0],
                            length_shadow[19:0],
                            tag_shadow[7:0],
                            crosses_4k(src_shadow[15:0],
                                       length_shadow[19:0]),
                            crosses_4k(dst_shadow[15:0],
                                       length_shadow[19:0])
                        );
                    end
                end
                default: ;
            endcase
        end

        if (tr.resp == 2'b00 && tr.op == AXIL_READ) begin
            case (tr.addr)
                REG_STATUS: begin
                    comp_valid_shadow = tr.rdata[4];
                    manager_status_cg.sample(tr.rdata);
                end
                REG_COMP_TAG:
                    comp_tag_shadow = tr.rdata;
                REG_COMP_LENGTH:
                    comp_length_shadow = tr.rdata;
                REG_COMP_STATUS:
                    completion_cg.sample(
                        comp_tag_shadow[7:0],
                        comp_length_shadow[19:0],
                        tr.rdata[10:0]
                    );
                REG_QUEUE_LEVELS:
                    queue_level_cg.sample(
                        tr.rdata[15:0], tr.rdata[31:16]);
                default: ;
            endcase
        end

    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(irq_vif.mon_cb);
            if (irq_vif.rst)
                continue;

            irq_cg.sample(
                irq_vif.mon_cb.irq,
                irq_enable_shadow,
                comp_valid_shadow
            );
        end
    endtask

    function real combined_coverage();
        return (axil_cg.get_inst_coverage() +
                descriptor_cg.get_inst_coverage() +
                irq_cg.get_inst_coverage() +
                manager_status_cg.get_inst_coverage() +
                queue_level_cg.get_inst_coverage() +
                completion_cg.get_inst_coverage()) / 6.0;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COVERAGE",
            $sformatf(
                {"functional coverage: AXIL=%0.2f%% DESC=%0.2f%% ",
                 "IRQ=%0.2f%% MANAGER=%0.2f%% QUEUE=%0.2f%% ",
                 "COMPLETION=%0.2f%% COMBINED=%0.2f%%"},
                axil_cg.get_inst_coverage(),
                descriptor_cg.get_inst_coverage(),
                irq_cg.get_inst_coverage(),
                manager_status_cg.get_inst_coverage(),
                queue_level_cg.get_inst_coverage(),
                completion_cg.get_inst_coverage(),
                combined_coverage()),
            UVM_NONE)
    endfunction

endclass
