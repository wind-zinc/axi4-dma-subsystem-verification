/*
 * Byte-addressable reference memory matching the 64 KiB testbench RAM.
 * The initialization algorithm is intentionally identical to tb_uvm_top.
 */
class dma_ref_model extends uvm_object;

    `uvm_object_utils(dma_ref_model)

    localparam int unsigned MEM_BYTES = 65536;
    byte unsigned mem [0:MEM_BYTES-1];

    localparam int INIT_XORSHIFT = 0;
    localparam int INIT_LEGACY_XOR = 1;

    function new(string name = "dma_ref_model");
        super.new(name);
    endfunction

    function automatic bit [31:0] initial_word(input int unsigned index);
        bit [31:0] value;
        value = 32'h9e37_79b9 ^ index;
        value = value ^ (value << 13);
        value = value ^ (value >> 17);
        value = value ^ (value << 5);
        return value;
    endfunction

    function void initialize(input int init_mode = INIT_XORSHIFT);
        bit [31:0] word;
        for (int unsigned word_index = 0;
             word_index < MEM_BYTES/4; word_index++) begin
            if (init_mode == INIT_LEGACY_XOR)
                word = 32'h5a00_0000 ^ word_index;
            else
                word = initial_word(word_index);
            for (int unsigned lane = 0; lane < 4; lane++)
                mem[word_index*4 + lane] = word[lane*8 +: 8];
        end
    endfunction

    function automatic int unsigned normalize_addr(
        input longint unsigned address
    );
        return address % MEM_BYTES;
    endfunction

    function byte unsigned read_byte(input longint unsigned address);
        return mem[normalize_addr(address)];
    endfunction

    function void write_byte(input longint unsigned address,
                             input byte unsigned value);
        mem[normalize_addr(address)] = value;
    endfunction

    /* Snapshot freezes the expected source bytes for the active descriptor. */
    function void snapshot(input longint unsigned address,
                           input int unsigned length,
                           ref byte unsigned data[$]);
        data.delete();
        for (int unsigned index = 0; index < length; index++)
            data.push_back(read_byte(address + index));
    endfunction

endclass
