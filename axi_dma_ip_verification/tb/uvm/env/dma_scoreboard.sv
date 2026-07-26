/*
 * End-to-end DMA scoreboard.
 *
 * At descriptor start it snapshots the source bytes from dma_ref_model.
 * It then reconstructs every AXI write burst and compares enabled WDATA
 * bytes against that snapshot.  Accepted writes update the reference memory,
 * so later descriptors naturally see the effects of earlier descriptors.
 */
class dma_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dma_scoreboard)

    typedef struct {
        longint unsigned base_addr;
        int unsigned     beats_total;
        int unsigned     beat_index;
        int unsigned     beat_bytes;
    } aw_context_t;

    uvm_analysis_imp #(dma_observed_item, dma_scoreboard) analysis_export;
    dma_ref_model ref_model;

    aw_context_t aw_queue[$];
    byte unsigned source_snapshot[$];
    string data_mismatch_samples[$];

    bit active;
    longint unsigned active_src_addr;
    longint unsigned active_dst_addr;
    int unsigned active_length;
    bit [7:0] active_tag;
    int unsigned bytes_written;
    int unsigned read_bytes_requested;
    int unsigned descriptors_checked;

    function new(string name = "dma_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        int ref_init_mode;
        super.build_phase(phase);
        ref_model = dma_ref_model::type_id::create("ref_model");
        ref_init_mode = dma_ref_model::INIT_XORSHIFT;
        void'(uvm_config_db#(int)::get(
            this, "", "ref_init_mode", ref_init_mode));
        ref_model.initialize(ref_init_mode);
        clear_active();
    endfunction

    function void clear_active();
        active = 1'b0;
        active_src_addr = 0;
        active_dst_addr = 0;
        active_length = 0;
        active_tag = '0;
        bytes_written = 0;
        read_bytes_requested = 0;
        source_snapshot.delete();
        data_mismatch_samples.delete();
        aw_queue.delete();
    endfunction

    function automatic longint unsigned relative_address(
        input longint unsigned address,
        input longint unsigned base_address
    );
        /* AXI_ADDR_WIDTH is 16 in this testbench. */
        return (address - base_address) & 64'h0000_0000_0000_ffff;
    endfunction

    function void write(dma_observed_item tr);
        case (tr.kind)
            DMA_OBS_RESET:      handle_reset();
            DMA_OBS_DESCRIPTOR: handle_descriptor(tr);
            DMA_OBS_AR:         handle_ar(tr);
            DMA_OBS_AW:         handle_aw(tr);
            DMA_OBS_W:          handle_w(tr);
            DMA_OBS_COMPLETION: handle_completion(tr);
            default:
                `uvm_error("DMA_SCB", "Unknown observer transaction kind")
        endcase
    endfunction

    /* Reset aborts the active task but does not erase the external RAM. */
    function void handle_reset();
        clear_active();
    endfunction

    function void handle_descriptor(dma_observed_item tr);
        if (active)
            `uvm_error("DMA_SCB",
                "A new descriptor started while the previous one was active")

        clear_active();
        active = 1'b1;
        active_src_addr = tr.src_addr;
        active_dst_addr = tr.dst_addr;
        active_length   = tr.length;
        active_tag      = tr.tag;
        ref_model.snapshot(active_src_addr, active_length,
                           source_snapshot);
    endfunction

    function void handle_ar(dma_observed_item tr);
        longint unsigned offset;
        int unsigned burst_bytes;

        if (!active) begin
            `uvm_error("DMA_SCB", "AXI AR handshake without an active descriptor")
            return;
        end

        offset = relative_address(tr.axi_addr, active_src_addr);
        burst_bytes = (int'(tr.axi_len) + 1) << tr.axi_size;

        if (tr.axi_burst != 2'b01)
            `uvm_error("DMA_SCB", "DMA issued a non-INCR read burst")
        if (tr.axi_size != 3'd2)
            `uvm_error("DMA_SCB", "DMA issued an unexpected read beat size")
        if (offset >= active_length)
            `uvm_error("DMA_SCB", $sformatf(
                "ARADDR 0x%04x is outside source range 0x%04x + %0d",
                tr.axi_addr[15:0], active_src_addr[15:0], active_length))

        read_bytes_requested += burst_bytes;
    endfunction

    function void handle_aw(dma_observed_item tr);
        aw_context_t context;
        longint unsigned offset;

        if (!active) begin
            `uvm_error("DMA_SCB", "AXI AW handshake without an active descriptor")
            return;
        end

        offset = relative_address(tr.axi_addr, active_dst_addr);
        if (tr.axi_burst != 2'b01)
            `uvm_error("DMA_SCB", "DMA issued a non-INCR write burst")
        if (tr.axi_size != 3'd2)
            `uvm_error("DMA_SCB", "DMA issued an unexpected write beat size")
        if (offset >= active_length)
            `uvm_error("DMA_SCB", $sformatf(
                "AWADDR 0x%04x is outside destination range 0x%04x + %0d",
                tr.axi_addr[15:0], active_dst_addr[15:0], active_length))

        context.base_addr   = tr.axi_addr;
        context.beats_total = int'(tr.axi_len) + 1;
        context.beat_index  = 0;
        context.beat_bytes  = 1 << tr.axi_size;
        aw_queue.push_back(context);
    endfunction

    function void handle_w(dma_observed_item tr);
        aw_context_t context;
        longint unsigned beat_addr;
        longint unsigned byte_addr;
        longint unsigned offset;
        byte unsigned actual_byte;
        byte unsigned expected_byte;
        bit expected_last;

        if (!active) begin
            `uvm_error("DMA_SCB", "AXI W handshake without an active descriptor")
            return;
        end
        if (aw_queue.size() == 0) begin
            `uvm_error("DMA_SCB", "AXI W handshake without a preceding AW")
            return;
        end

        context = aw_queue[0];
        beat_addr = context.base_addr +
                    context.beat_index * context.beat_bytes;
        expected_last = context.beat_index == context.beats_total-1;

        if (tr.last != expected_last)
            `uvm_error("DMA_SCB", $sformatf(
                "WLAST=%0b, expected %0b on burst beat %0d/%0d",
                tr.last, expected_last, context.beat_index,
                context.beats_total-1))

        for (int unsigned lane = 0; lane < 4; lane++) begin
            if (tr.strb[lane]) begin
                byte_addr = beat_addr + lane;
                offset = relative_address(byte_addr, active_dst_addr);
                actual_byte = tr.data[lane*8 +: 8];

                if (offset >= active_length) begin
                    `uvm_error("DMA_SCB", $sformatf(
                        "WSTRB enabled destination byte 0x%04x outside length %0d",
                        byte_addr[15:0], active_length))
                end else begin
                    expected_byte = source_snapshot[offset];
                    if (actual_byte != expected_byte &&
                            data_mismatch_samples.size() < 8)
                        data_mismatch_samples.push_back($sformatf(
                            "tag=0x%02x dst=0x%04x offset=%0d exp=%02x got=%02x",
                            active_tag, byte_addr[15:0], offset,
                            expected_byte, actual_byte));
                    bytes_written++;
                end

                /* Reflect what the memory accepted, even for error responses. */
                ref_model.write_byte(byte_addr, actual_byte);
            end
        end

        context.beat_index++;
        if (context.beat_index == context.beats_total)
            void'(aw_queue.pop_front());
        else
            aw_queue[0] = context;
    endfunction

    function void handle_completion(dma_observed_item tr);
        if (!active) begin
            `uvm_error("DMA_SCB", "Completion without an active descriptor")
            return;
        end

        if (tr.tag != active_tag)
            `uvm_error("DMA_SCB", $sformatf(
                "Completion tag 0x%02x, expected 0x%02x",
                tr.tag, active_tag))
        if (tr.length != active_length)
            `uvm_error("DMA_SCB", $sformatf(
                "Completion length %0d, expected %0d",
                tr.length, active_length))
        if (tr.flags != 3'b000)
            `uvm_error("DMA_SCB", $sformatf(
                "Completion mismatch flags are nonzero: 0x%0x", tr.flags))
        if (bytes_written != active_length)
            `uvm_error("DMA_SCB", $sformatf(
                "Accepted %0d write bytes, expected %0d",
                bytes_written, active_length))
        if (read_bytes_requested < active_length ||
                read_bytes_requested > active_length+3)
            `uvm_error("DMA_SCB", $sformatf(
                "Read bursts requested %0d bytes for descriptor length %0d",
                read_bytes_requested, active_length))
        if (aw_queue.size() != 0)
            `uvm_error("DMA_SCB", $sformatf(
                "%0d write burst(s) were unfinished at completion",
                aw_queue.size()))

        /* AXI read-error data is not architecturally meaningful. */
        if (tr.read_error == 4'd0) begin
            foreach (data_mismatch_samples[index])
                `uvm_error("DMA_DATA", data_mismatch_samples[index])
        end

        descriptors_checked++;
        clear_active();
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (active)
            `uvm_error("DMA_SCB", "Test ended with an active DMA descriptor")
        if (aw_queue.size() != 0)
            `uvm_error("DMA_SCB", "Test ended with unfinished AXI write bursts")
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("DMA_SCB", $sformatf(
            "End-to-end checked descriptors: %0d", descriptors_checked), UVM_LOW)
    endfunction

endclass
