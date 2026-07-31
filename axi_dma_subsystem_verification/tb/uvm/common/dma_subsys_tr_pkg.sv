`default_nettype none

package dma_subsys_tr_pkg;

    import uvm_pkg::*;
    import dma_subsystem_pkg::*;
    `include "uvm_macros.svh"

    localparam int unsigned XBAR_MASTER_INDEX_WIDTH = $clog2(AXI_MASTER_COUNT);
    localparam logic [AXIL_ADDR_WIDTH-1:0] AXIL_BLOCK_SIZE =
        (1 << AXIL_BLOCK_ADDR_WIDTH);

    typedef enum int unsigned {
        DMA_RECORD_INTENT,
        DMA_RECORD_OBSERVED,
        DMA_RECORD_EXPECTED
    } dma_record_kind_e;

    typedef enum int unsigned {
        DMA_CH0,
        DMA_CH1,
        DMA_CH_UNKNOWN
    } dma_channel_e;

    typedef enum int unsigned {
        DMA_CTRL_CH0,
        DMA_CTRL_CH1,
        DMA_CTRL_GLOBAL,
        DMA_CTRL_UNMAPPED
    } dma_ctrl_block_e;

    typedef enum int unsigned {
        DMA_MEM_RAM0,
        DMA_MEM_RAM1,
        DMA_MEM_UNMAPPED
    } dma_memory_e;

    // These values match the low-to-high order of axi_s_* in
    // axi_dma_subsystem_core: DMA0, DMA1, EXT0, EXT1.
    typedef enum int unsigned {
        DMA_MASTER_DMA0,
        DMA_MASTER_DMA1,
        DMA_MASTER_EXT0,
        DMA_MASTER_EXT1,
        DMA_MASTER_UNKNOWN
    } dma_master_e;

    typedef enum int unsigned {
        DMA_ACCESS_READ,
        DMA_ACCESS_WRITE
    } dma_access_e;

    typedef enum logic [1:0] {
        DMA_AXI_OKAY   = 2'b00,
        DMA_AXI_EXOKAY = 2'b01,
        DMA_AXI_SLVERR = 2'b10,
        DMA_AXI_DECERR = 2'b11
    } dma_axi_resp_e;

    typedef enum int unsigned {
        DMA_BURST_FIXED,
        DMA_BURST_INCR,
        DMA_BURST_WRAP,
        DMA_BURST_UNKNOWN
    } dma_burst_e;

    typedef enum int unsigned {
        DMA_CMD_INTENT,
        DMA_CMD_ACCEPTED,
        DMA_CMD_REJECTED,
        DMA_CMD_ABORT_REQUESTED
    } dma_cmd_event_e;

    typedef enum int unsigned {
        DMA_ROUTE_REQUEST,
        DMA_ROUTE_GRANTED,
        DMA_ROUTE_RELEASED,
        DMA_ROUTE_FAULT
    } dma_route_event_e;

    typedef enum int unsigned {
        DMA_IRQ_ASSERTED,
        DMA_IRQ_DEASSERTED,
        DMA_IRQ_STATUS_SAMPLED,
        DMA_IRQ_CLEARED
    } dma_irq_event_e;

    typedef enum int unsigned {
        DMA_FAULT_RAISED,
        DMA_FAULT_CLEARED
    } dma_fault_event_e;

    typedef enum int unsigned {
        DMA_RESET_ASSERTED,
        DMA_RESET_DEASSERTED
    } dma_reset_event_e;

    function automatic string dma_channel_name(input dma_channel_e channel);
        case (channel)
            DMA_CH0: return "CH0";
            DMA_CH1: return "CH1";
            default: return "CH_UNKNOWN";
        endcase
    endfunction

    function automatic dma_channel_e dma_channel_from_bit(input logic channel);
        return channel ? DMA_CH1 : DMA_CH0;
    endfunction

    function automatic dma_ctrl_block_e dma_ctrl_block_from_addr(
        input logic [AXIL_ADDR_WIDTH-1:0] addr
    );
        if ((addr >= CH0_CTRL_BASE_ADDR)
                && (addr < (CH0_CTRL_BASE_ADDR + AXIL_BLOCK_SIZE))) begin
            return DMA_CTRL_CH0;
        end
        if ((addr >= CH1_CTRL_BASE_ADDR)
                && (addr < (CH1_CTRL_BASE_ADDR + AXIL_BLOCK_SIZE))) begin
            return DMA_CTRL_CH1;
        end
        if ((addr >= GLOBAL_IRQ_BASE_ADDR)
                && (addr < (GLOBAL_IRQ_BASE_ADDR + AXIL_BLOCK_SIZE))) begin
            return DMA_CTRL_GLOBAL;
        end
        return DMA_CTRL_UNMAPPED;
    endfunction

    function automatic dma_memory_e dma_memory_from_addr(
        input logic [AXI_ADDR_WIDTH-1:0] addr
    );
        if (addr_in_ram0(addr)) begin
            return DMA_MEM_RAM0;
        end
        if (addr_in_ram1(addr)) begin
            return DMA_MEM_RAM1;
        end
        return DMA_MEM_UNMAPPED;
    endfunction

    // The verilog-axi crossbar appends the input-master index above the
    // original AXI_ID_WIDTH ID. Memory-side VIP transactions can therefore
    // recover the originating DMA/EXT master from the widened ID.
    function automatic dma_master_e dma_master_from_xbar_id(
        input logic [AXI_XBAR_M_ID_WIDTH-1:0] axi_id
    );
        logic [XBAR_MASTER_INDEX_WIDTH-1:0] master_index;

        master_index = axi_id[
            AXI_ID_WIDTH +: XBAR_MASTER_INDEX_WIDTH];
        case (master_index)
            0: return DMA_MASTER_DMA0;
            1: return DMA_MASTER_DMA1;
            2: return DMA_MASTER_EXT0;
            3: return DMA_MASTER_EXT1;
            default: return DMA_MASTER_UNKNOWN;
        endcase
    endfunction

    class dma_subsys_base_tr extends uvm_sequence_item;

        // flow_id is shared by command, memory, route, completion and IRQ
        // records that belong to one logical DMA operation. Zero is reserved
        // for global or not-yet-correlated observations.
        int unsigned      flow_id;
        dma_record_kind_e record_kind;
        longint unsigned  sample_cycle;
        time              sample_time;
        string            producer;

        protected static int unsigned next_flow_id = 1;

        `uvm_object_utils_begin(dma_subsys_base_tr)
            `uvm_field_int(flow_id, UVM_DEFAULT | UVM_DEC)
            `uvm_field_enum(dma_record_kind_e, record_kind, UVM_DEFAULT)
            `uvm_field_int(sample_cycle, UVM_DEFAULT | UVM_DEC | UVM_NOCOMPARE)
            `uvm_field_int(sample_time, UVM_DEFAULT | UVM_TIME | UVM_NOCOMPARE)
            `uvm_field_string(producer, UVM_DEFAULT | UVM_NOCOMPARE)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_base_tr");
            super.new(name);
            flow_id = 0;
            record_kind = DMA_RECORD_OBSERVED;
            sample_cycle = 0;
            sample_time = 0;
            producer = "";
        endfunction

        static function int unsigned allocate_flow_id();
            int unsigned allocated_id;

            allocated_id = next_flow_id;
            next_flow_id++;
            if (next_flow_id == 0) begin
                next_flow_id = 1;
            end
            return allocated_id;
        endfunction

        function void ensure_flow_id();
            if (flow_id == 0) begin
                flow_id = allocate_flow_id();
            end
        endfunction

        function void stamp(
            input string producer_name,
            input longint unsigned cycle = 0
        );
            producer = producer_name;
            sample_cycle = cycle;
            sample_time = $time;
        endfunction

        virtual function string context_string();
            return $sformatf(
                "flow=%0d record=%0d producer=%s cycle=%0d time=%0t",
                flow_id, record_kind, producer, sample_cycle, sample_time);
        endfunction

        virtual function string convert2string();
            return context_string();
        endfunction

    endclass

    // Normalized AXI-Lite register access. The AXI-Lite VIP adapter produces
    // this object; RAL prediction, command assembly and register coverage can
    // consume it without depending on an AMD transaction class.
    class dma_subsys_reg_tr extends dma_subsys_base_tr;

        rand dma_access_e                  access;
        rand logic [AXIL_ADDR_WIDTH-1:0]  addr;
        rand logic [AXIL_DATA_WIDTH-1:0]  data;
        rand logic [AXIL_STRB_WIDTH-1:0]  strb;
        dma_axi_resp_e                    resp;
        dma_ctrl_block_e                  block;

        `uvm_object_utils_begin(dma_subsys_reg_tr)
            `uvm_field_enum(dma_access_e, access, UVM_DEFAULT)
            `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(data, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(strb, UVM_DEFAULT | UVM_HEX)
            `uvm_field_enum(dma_axi_resp_e, resp, UVM_DEFAULT)
            `uvm_field_enum(dma_ctrl_block_e, block, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_reg_tr");
            super.new(name);
            access = DMA_ACCESS_READ;
            addr = '0;
            data = '0;
            strb = '0;
            resp = DMA_AXI_OKAY;
            block = DMA_CTRL_UNMAPPED;
        endfunction

        function void normalize();
            block = dma_ctrl_block_from_addr(addr);
        endfunction

        function logic [AXIL_BLOCK_ADDR_WIDTH-1:0] block_offset();
            return addr[AXIL_BLOCK_ADDR_WIDTH-1:0];
        endfunction

        function bit is_okay();
            return resp inside {DMA_AXI_OKAY, DMA_AXI_EXOKAY};
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s access=%0d block=%0d addr=0x%08h data=0x%08h strb=0x%0h resp=%0d",
                context_string(), access, block, addr, data, strb, resp);
        endfunction

    endclass

    // One software-visible DMA command or the DUT's acceptance/rejection of
    // that command. It is the main intent object used by virtual sequences.
    class dma_subsys_cmd_tr extends dma_subsys_base_tr;

        dma_cmd_event_e                  event_kind;
        rand dma_channel_e              source_ch;
        rand dma_channel_e              dest_ch;
        rand logic [AXI_ADDR_WIDTH-1:0] src_addr;
        rand logic [AXI_ADDR_WIDTH-1:0] dst_addr;
        rand logic [LEN_WIDTH-1:0]      length;
        rand logic [7:0]                sw_tag;
        logic [TAG_WIDTH-1:0]           hw_tag;
        bit                             hw_tag_valid;
        bit                             expect_accept;
        bit                             expect_completion;
        bit                             expect_irq;
        dma_error_e                     expected_error;

        constraint c_known_channels {
            source_ch != DMA_CH_UNKNOWN;
            dest_ch != DMA_CH_UNKNOWN;
        }

        `uvm_object_utils_begin(dma_subsys_cmd_tr)
            `uvm_field_enum(dma_cmd_event_e, event_kind, UVM_DEFAULT)
            `uvm_field_enum(dma_channel_e, source_ch, UVM_DEFAULT)
            `uvm_field_enum(dma_channel_e, dest_ch, UVM_DEFAULT)
            `uvm_field_int(src_addr, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(dst_addr, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(length, UVM_DEFAULT | UVM_DEC)
            `uvm_field_int(sw_tag, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(hw_tag, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(hw_tag_valid, UVM_DEFAULT)
            `uvm_field_int(expect_accept, UVM_DEFAULT)
            `uvm_field_int(expect_completion, UVM_DEFAULT)
            `uvm_field_int(expect_irq, UVM_DEFAULT)
            `uvm_field_enum(dma_error_e, expected_error, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_cmd_tr");
            super.new(name);
            record_kind = DMA_RECORD_INTENT;
            event_kind = DMA_CMD_INTENT;
            source_ch = DMA_CH0;
            dest_ch = DMA_CH0;
            src_addr = '0;
            dst_addr = '0;
            length = '0;
            sw_tag = '0;
            hw_tag = '0;
            hw_tag_valid = 1'b0;
            expect_accept = 1'b1;
            expect_completion = 1'b1;
            expect_irq = 1'b0;
            expected_error = DMA_ERR_NONE;
        endfunction

        function void from_rtl_cmd(
            input dma_cmd_t value,
            input dma_cmd_event_e observed_event = DMA_CMD_ACCEPTED
        );
            event_kind = observed_event;
            source_ch = dma_channel_from_bit(value.src_ch);
            dest_ch = dma_channel_from_bit(value.dst_ch);
            src_addr = value.src_addr;
            dst_addr = value.dst_addr;
            length = value.len;
            sw_tag = value.sw_tag;
        endfunction

        function dma_cmd_t to_rtl_cmd();
            dma_cmd_t value;

            value = '0;
            value.src_addr = src_addr;
            value.dst_addr = dst_addr;
            value.len = length;
            value.src_ch = (source_ch == DMA_CH1);
            value.dst_ch = (dest_ch == DMA_CH1);
            value.sw_tag = sw_tag;
            return value;
        endfunction

        function bit ranges_overlap();
            return dma_subsystem_pkg::ranges_overlap(
                src_addr, dst_addr, length);
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s event=%0d route=%s->%s src=0x%08h dst=0x%08h len=%0d sw_tag=0x%02h hw_tag=%0h expected_error=0x%02h",
                context_string(), event_kind, dma_channel_name(source_ch),
                dma_channel_name(dest_ch), src_addr, dst_addr, length,
                sw_tag, hw_tag, expected_error);
        endfunction

    endclass

    // Normalized complete AXI4 read or write transaction observed at one of
    // the memory-side VIPs. data and byte_enable are flattened byte arrays so
    // the scoreboard can compare valid bytes without knowing VIP beat types.
    class dma_subsys_mem_tr extends dma_subsys_base_tr;

        rand dma_access_e                        access;
        rand dma_master_e                        master;
        rand dma_memory_e                        target;
        rand dma_burst_e                         burst;
        rand logic [AXI_XBAR_M_ID_WIDTH-1:0]    axi_id;
        rand logic [AXI_ADDR_WIDTH-1:0]         addr;
        rand int unsigned                        beat_count;
        rand int unsigned                        bytes_per_beat;
        rand byte unsigned                       data[];
        rand bit                                 byte_enable[];
        dma_axi_resp_e                           resp;
        bit                                      transaction_done;
        bit                                      protocol_error;

        constraint c_payload_arrays {
            data.size() == byte_enable.size();
            data.size() <= 4096;
        }

        `uvm_object_utils_begin(dma_subsys_mem_tr)
            `uvm_field_enum(dma_access_e, access, UVM_DEFAULT)
            `uvm_field_enum(dma_master_e, master, UVM_DEFAULT)
            `uvm_field_enum(dma_memory_e, target, UVM_DEFAULT)
            `uvm_field_enum(dma_burst_e, burst, UVM_DEFAULT)
            `uvm_field_int(axi_id, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(beat_count, UVM_DEFAULT | UVM_DEC)
            `uvm_field_int(bytes_per_beat, UVM_DEFAULT | UVM_DEC)
            `uvm_field_array_int(data, UVM_DEFAULT | UVM_HEX)
            `uvm_field_array_int(byte_enable, UVM_DEFAULT | UVM_BIN)
            `uvm_field_enum(dma_axi_resp_e, resp, UVM_DEFAULT)
            `uvm_field_int(transaction_done, UVM_DEFAULT)
            `uvm_field_int(protocol_error, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_mem_tr");
            super.new(name);
            access = DMA_ACCESS_READ;
            master = DMA_MASTER_UNKNOWN;
            target = DMA_MEM_UNMAPPED;
            burst = DMA_BURST_UNKNOWN;
            axi_id = '0;
            addr = '0;
            beat_count = 1;
            bytes_per_beat = AXI_STRB_WIDTH;
            resp = DMA_AXI_OKAY;
            transaction_done = 1'b0;
            protocol_error = 1'b0;
        endfunction

        function void normalize();
            if (master == DMA_MASTER_UNKNOWN) begin
                master = dma_master_from_xbar_id(axi_id);
            end
            if (target == DMA_MEM_UNMAPPED) begin
                target = dma_memory_from_addr(addr);
            end
        endfunction

        function int unsigned valid_byte_count();
            int unsigned count;

            count = 0;
            foreach (byte_enable[index]) begin
                if (byte_enable[index]) begin
                    count++;
                end
            end
            return count;
        endfunction

        function logic [AXI_ADDR_WIDTH-1:0] end_address();
            int unsigned byte_count;

            byte_count = data.size();
            if (byte_count == 0) begin
                byte_count = beat_count * bytes_per_beat;
            end
            if (byte_count == 0) begin
                return addr;
            end
            return addr + byte_count - 1;
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s access=%0d master=%0d memory=%0d id=0x%0h addr=0x%08h beats=%0d beat_bytes=%0d payload_bytes=%0d valid_bytes=%0d resp=%0d done=%0b protocol_error=%0b",
                context_string(), access, master, target, axi_id, addr,
                beat_count, bytes_per_beat, data.size(), valid_byte_count(),
                resp, transaction_done, protocol_error);
        endfunction

    endclass

    // Route-controller request/grant/release/fault event. The route matrix
    // gives the scoreboard and coverage collector a consistent system view.
    class dma_subsys_route_tr extends dma_subsys_base_tr;

        dma_route_event_e                      event_kind;
        dma_channel_e                          source_ch;
        dma_channel_e                          dest_ch;
        logic [DMA_CH_COUNT-1:0]               route_active;
        logic [DMA_CH_COUNT*DMA_CH_COUNT-1:0]  route_matrix;
        int unsigned                           wait_cycles;
        dma_error_e                            error;
        dma_fault_source_e                     fault_source;

        `uvm_object_utils_begin(dma_subsys_route_tr)
            `uvm_field_enum(dma_route_event_e, event_kind, UVM_DEFAULT)
            `uvm_field_enum(dma_channel_e, source_ch, UVM_DEFAULT)
            `uvm_field_enum(dma_channel_e, dest_ch, UVM_DEFAULT)
            `uvm_field_int(route_active, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(route_matrix, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(wait_cycles, UVM_DEFAULT | UVM_DEC)
            `uvm_field_enum(dma_error_e, error, UVM_DEFAULT)
            `uvm_field_enum(dma_fault_source_e, fault_source, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_route_tr");
            super.new(name);
            event_kind = DMA_ROUTE_REQUEST;
            source_ch = DMA_CH_UNKNOWN;
            dest_ch = DMA_CH_UNKNOWN;
            route_active = '0;
            route_matrix = '0;
            wait_cycles = 0;
            error = DMA_ERR_NONE;
            fault_source = DMA_FAULT_SRC_ROUTE;
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s event=%0d route=%s->%s active=%0b matrix=%0b wait=%0d error=0x%02h fault_source=%0d",
                context_string(), event_kind, dma_channel_name(source_ch),
                dma_channel_name(dest_ch), route_active, route_matrix,
                wait_cycles, error, fault_source);
        endfunction

    endclass

    // Completion emitted by dma_desc_manager. owner_ch + hw_tag + sw_tag
    // are the primary keys used to correlate the completion with a command.
    class dma_subsys_completion_tr extends dma_subsys_base_tr;

        dma_channel_e              owner_ch;
        dma_channel_e              dest_ch;
        bit                        dest_ch_valid;
        logic [TAG_WIDTH-1:0]      hw_tag;
        logic [7:0]                sw_tag;
        logic [LEN_WIDTH-1:0]      completed_len;
        dma_error_e                error;
        bit                        aborted;

        `uvm_object_utils_begin(dma_subsys_completion_tr)
            `uvm_field_enum(dma_channel_e, owner_ch, UVM_DEFAULT)
            `uvm_field_enum(dma_channel_e, dest_ch, UVM_DEFAULT)
            `uvm_field_int(dest_ch_valid, UVM_DEFAULT)
            `uvm_field_int(hw_tag, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(sw_tag, UVM_DEFAULT | UVM_HEX)
            `uvm_field_int(completed_len, UVM_DEFAULT | UVM_DEC)
            `uvm_field_enum(dma_error_e, error, UVM_DEFAULT)
            `uvm_field_int(aborted, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_completion_tr");
            super.new(name);
            owner_ch = DMA_CH_UNKNOWN;
            dest_ch = DMA_CH_UNKNOWN;
            dest_ch_valid = 1'b0;
            hw_tag = '0;
            sw_tag = '0;
            completed_len = '0;
            error = DMA_ERR_NONE;
            aborted = 1'b0;
        endfunction

        function void from_rtl_completion(input dma_completion_t value);
            owner_ch = dma_channel_from_bit(value.owner_ch);
            hw_tag = value.hw_tag;
            sw_tag = value.sw_tag;
            completed_len = value.completed_len;
            error = value.error;
            aborted = value.aborted;
        endfunction

        function dma_completion_t to_rtl_completion();
            dma_completion_t value;

            value = '0;
            value.owner_ch = (owner_ch == DMA_CH1);
            value.hw_tag = hw_tag;
            value.sw_tag = sw_tag;
            value.completed_len = completed_len;
            value.error = error;
            value.aborted = aborted;
            return value;
        endfunction

        function bit correlates_with(input dma_subsys_cmd_tr command);
            if ((owner_ch != command.source_ch)
                    || (sw_tag != command.sw_tag)) begin
                return 1'b0;
            end
            if (command.hw_tag_valid && (hw_tag != command.hw_tag)) begin
                return 1'b0;
            end
            return 1'b1;
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s owner=%s dest=%s dest_valid=%0b hw_tag=0x%0h sw_tag=0x%02h completed_len=%0d error=0x%02h aborted=%0b",
                context_string(), dma_channel_name(owner_ch),
                dma_channel_name(dest_ch), dest_ch_valid, hw_tag, sw_tag,
                completed_len, error, aborted);
        endfunction

    endclass

    class dma_subsys_fault_tr extends dma_subsys_base_tr;

        dma_fault_event_e  event_kind;
        dma_error_e        error;
        dma_fault_source_e source;
        bit                pending;
        bit                enabled;

        `uvm_object_utils_begin(dma_subsys_fault_tr)
            `uvm_field_enum(dma_fault_event_e, event_kind, UVM_DEFAULT)
            `uvm_field_enum(dma_error_e, error, UVM_DEFAULT)
            `uvm_field_enum(dma_fault_source_e, source, UVM_DEFAULT)
            `uvm_field_int(pending, UVM_DEFAULT)
            `uvm_field_int(enabled, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_fault_tr");
            super.new(name);
            event_kind = DMA_FAULT_RAISED;
            error = DMA_ERR_NONE;
            source = DMA_FAULT_SRC_MANAGER;
            pending = 1'b0;
            enabled = 1'b0;
        endfunction

        function void from_rtl_fault(input dma_fault_t value);
            error = value.error;
            source = dma_fault_source_e'(value.source);
            pending = 1'b1;
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s event=%0d error=0x%02h source=%0d pending=%0b enabled=%0b",
                context_string(), event_kind, error, source, pending, enabled);
        endfunction

    endclass

    // Snapshot or edge of the global/channel IRQ state. Pending/enable bits
    // mirror the global register block and allow level-sensitive IRQ checks.
    class dma_subsys_irq_tr extends dma_subsys_base_tr;

        dma_irq_event_e                        event_kind;
        logic [DMA_CH_COUNT-1:0]               irq_ch;
        bit                                    global_irq;
        logic [DMA_CH_COUNT-1:0]               done_pending;
        logic [DMA_CH_COUNT-1:0]               error_pending;
        logic [DMA_CH_COUNT-1:0]               busy;
        logic [DMA_CH_COUNT-1:0]               done_enable;
        logic [DMA_CH_COUNT-1:0]               error_enable;
        bit                                    fault_pending;
        bit                                    fault_enable;
        dma_error_e                            fault_code;
        dma_fault_source_e                     fault_source;
        logic [DMA_CH_COUNT-1:0]               done_clear_mask;
        logic [DMA_CH_COUNT-1:0]               error_clear_mask;
        bit                                    fault_clear;

        `uvm_object_utils_begin(dma_subsys_irq_tr)
            `uvm_field_enum(dma_irq_event_e, event_kind, UVM_DEFAULT)
            `uvm_field_int(irq_ch, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(global_irq, UVM_DEFAULT)
            `uvm_field_int(done_pending, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(error_pending, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(busy, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(done_enable, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(error_enable, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(fault_pending, UVM_DEFAULT)
            `uvm_field_int(fault_enable, UVM_DEFAULT)
            `uvm_field_enum(dma_error_e, fault_code, UVM_DEFAULT)
            `uvm_field_enum(dma_fault_source_e, fault_source, UVM_DEFAULT)
            `uvm_field_int(done_clear_mask, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(error_clear_mask, UVM_DEFAULT | UVM_BIN)
            `uvm_field_int(fault_clear, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_irq_tr");
            super.new(name);
            event_kind = DMA_IRQ_STATUS_SAMPLED;
            irq_ch = '0;
            global_irq = 1'b0;
            done_pending = '0;
            error_pending = '0;
            busy = '0;
            done_enable = '0;
            error_enable = '0;
            fault_pending = 1'b0;
            fault_enable = 1'b0;
            fault_code = DMA_ERR_NONE;
            fault_source = DMA_FAULT_SRC_MANAGER;
            done_clear_mask = '0;
            error_clear_mask = '0;
            fault_clear = 1'b0;
        endfunction

        function bit has_pending_status();
            return (|done_pending) || (|error_pending) || fault_pending;
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s event=%0d irq=%0b irq_ch=%0b done_pending=%0b error_pending=%0b busy=%0b done_enable=%0b error_enable=%0b fault_pending=%0b fault_enable=%0b fault=0x%02h/%0d",
                context_string(), event_kind, global_irq, irq_ch,
                done_pending, error_pending, busy, done_enable,
                error_enable, fault_pending, fault_enable, fault_code,
                fault_source);
        endfunction

    endclass

    // Reset is a global epoch boundary. Monitors and the scoreboard use
    // reset_epoch to discard pre-reset partial transactions deterministically.
    class dma_subsys_reset_tr extends dma_subsys_base_tr;

        dma_reset_event_e          event_kind;
        bit                        reset_n;
        int unsigned               reset_epoch;
        logic [DMA_CH_COUNT-1:0]   affected_channels;
        string                     reason;

        `uvm_object_utils_begin(dma_subsys_reset_tr)
            `uvm_field_enum(dma_reset_event_e, event_kind, UVM_DEFAULT)
            `uvm_field_int(reset_n, UVM_DEFAULT)
            `uvm_field_int(reset_epoch, UVM_DEFAULT | UVM_DEC)
            `uvm_field_int(affected_channels, UVM_DEFAULT | UVM_BIN)
            `uvm_field_string(reason, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "dma_subsys_reset_tr");
            super.new(name);
            event_kind = DMA_RESET_ASSERTED;
            reset_n = 1'b0;
            reset_epoch = 0;
            affected_channels = {DMA_CH_COUNT{1'b1}};
            reason = "";
        endfunction

        virtual function string convert2string();
            return $sformatf(
                "%s event=%0d reset_n=%0b epoch=%0d channels=%0b reason=%s",
                context_string(), event_kind, reset_n, reset_epoch,
                affected_channels, reason);
        endfunction

    endclass

endpackage

`default_nettype wire
