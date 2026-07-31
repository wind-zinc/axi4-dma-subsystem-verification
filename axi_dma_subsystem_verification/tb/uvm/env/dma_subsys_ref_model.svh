// Independent sparse byte-addressable memory model.
//
// It never reads the AMD VIP memory model.  External-master writes establish
// expected contents; DMA writes are committed with expected bytes only after
// the scoreboard compares the observed bus payload.
class dma_subsys_ref_model extends uvm_component;
    `uvm_component_utils(dma_subsys_ref_model)

    protected byte unsigned memory [longint unsigned];
    protected longint unsigned write_count;
    protected longint unsigned read_count;

    function new(
        string        name   = "dma_subsys_ref_model",
        uvm_component parent = null
    );
        super.new(name, parent);
        write_count = 0;
        read_count = 0;
    endfunction

    virtual function void invalidate_all();
        memory.delete();
    endfunction

    virtual function bit is_known(input longint unsigned address);
        return memory.exists(address);
    endfunction

    virtual function void write_byte(
        input longint unsigned address,
        input byte unsigned    value
    );
        memory[address] = value;
        write_count++;
    endfunction

    virtual function bit read_byte(
        input  longint unsigned address,
        output byte unsigned    value
    );
        read_count++;
        if (!memory.exists(address)) begin
            value = '0;
            return 1'b0;
        end
        value = memory[address];
        return 1'b1;
    endfunction

    virtual function void snapshot(
        input  logic [AXI_ADDR_WIDTH-1:0] start_address,
        input  int unsigned               length,
        output byte unsigned              data[],
        output bit                        valid[]
    );
        longint unsigned address;

        data = new[length];
        valid = new[length];
        for (int unsigned index = 0; index < length; index++) begin
            address = longint'(start_address) + index;
            valid[index] = read_byte(address, data[index]);
        end
    endfunction

    virtual function longint unsigned payload_address(
        input dma_subsys_mem_tr tr,
        input int unsigned      flat_index
    );
        longint unsigned beat_address;
        longint unsigned wrap_base;
        longint unsigned wrap_span;
        int unsigned beat_index;
        int unsigned byte_index;

        if (tr.bytes_per_beat == 0) begin
            return longint'(tr.addr);
        end

        beat_index = flat_index / tr.bytes_per_beat;
        byte_index = flat_index % tr.bytes_per_beat;

        case (tr.burst)
            DMA_BURST_FIXED: begin
                beat_address = longint'(tr.addr);
            end
            DMA_BURST_WRAP: begin
                wrap_span = tr.beat_count * tr.bytes_per_beat;
                if (wrap_span == 0) begin
                    beat_address = longint'(tr.addr);
                end else begin
                    wrap_base = (longint'(tr.addr) / wrap_span) * wrap_span;
                    beat_address = longint'(tr.addr)
                        + beat_index * tr.bytes_per_beat;
                    while (beat_address >= (wrap_base + wrap_span)) begin
                        beat_address -= wrap_span;
                    end
                end
            end
            default: begin
                beat_address = longint'(tr.addr)
                    + beat_index * tr.bytes_per_beat;
            end
        endcase

        return beat_address + byte_index;
    endfunction

    virtual function void apply_external_write(
        input dma_subsys_mem_tr tr
    );
        for (int unsigned index = 0; index < tr.data.size(); index++) begin
            if (tr.byte_enable[index]) begin
                write_byte(payload_address(tr, index), tr.data[index]);
            end
        end
    endfunction

    virtual function int unsigned compare_read(
        input  dma_subsys_mem_tr tr,
        output int unsigned      unknown_count
    );
        int unsigned mismatch_count;
        byte unsigned expected;
        longint unsigned address;

        mismatch_count = 0;
        unknown_count = 0;
        for (int unsigned index = 0; index < tr.data.size(); index++) begin
            if (!tr.byte_enable[index]) begin
                continue;
            end
            address = payload_address(tr, index);
            if (!read_byte(address, expected)) begin
                unknown_count++;
            end else if (tr.data[index] != expected) begin
                mismatch_count++;
            end
        end
        return mismatch_count;
    endfunction

    virtual function int unsigned known_byte_count();
        return memory.num();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(
            "REF_MODEL",
            $sformatf(
                "known_bytes=%0d byte_reads=%0d byte_writes=%0d",
                known_byte_count(), read_count, write_count),
            UVM_LOW)
    endfunction

endclass
