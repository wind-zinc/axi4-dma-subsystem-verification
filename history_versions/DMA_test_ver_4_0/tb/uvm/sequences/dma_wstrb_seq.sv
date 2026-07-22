/* Exhaustively checks all 16 WSTRB patterns on each staging register. */
class dma_wstrb_seq extends dma_base_seq;

    `uvm_object_utils(dma_wstrb_seq)

    function new(string name = "dma_wstrb_seq");
        super.new(name);
    endfunction

    function automatic bit [31:0] apply_wstrb(
        bit [31:0] old_value,
        bit [31:0] new_value,
        bit [3:0]  wstrb
    );
        bit [31:0] result;
        result = old_value;
        for (int lane = 0; lane < 4; lane++)
            if (wstrb[lane])
                result[lane*8 +: 8] = new_value[lane*8 +: 8];
        return result;
    endfunction

    virtual task body();
        bit [7:0]  addresses[4];
        bit [31:0] expected;
        bit [31:0] observed;
        bit [31:0] write_data;

        addresses[0] = REG_SRC_ADDR;
        addresses[1] = REG_DST_ADDR;
        addresses[2] = REG_LENGTH;
        addresses[3] = REG_TAG;

        for (int reg_index = 0; reg_index < 4; reg_index++) begin
            expected = 32'h1020_3040 ^ (reg_index * 32'h1111_1111);
            write_reg(addresses[reg_index], expected, 4'hf);

            for (int pattern = 0; pattern < 16; pattern++) begin
                write_data = 32'ha5c3_5a3c ^
                             (reg_index * 32'h0101_0101) ^ pattern;
                expected = apply_wstrb(
                    expected, write_data, pattern[3:0]);

                write_reg(addresses[reg_index],
                          write_data, pattern[3:0]);
                read_reg(addresses[reg_index], observed);

                if (observed != expected)
                    `uvm_error("WSTRB_READBACK",
                        $sformatf(
                            "addr=0x%02h strb=0x%0h got=0x%08h expected=0x%08h",
                            addresses[reg_index], pattern[3:0],
                            observed, expected))
            end

            write_reg(addresses[reg_index], 32'h0, 4'hf);
        end

        `uvm_info("DMA_WSTRB",
            "all staging-register WSTRB patterns completed", UVM_LOW)
    endtask

endclass
