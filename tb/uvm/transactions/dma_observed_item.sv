typedef enum int unsigned {
    DMA_OBS_RESET,
    DMA_OBS_DESCRIPTOR,
    DMA_OBS_AR,
    DMA_OBS_AW,
    DMA_OBS_W,
    DMA_OBS_COMPLETION
} dma_observed_kind_e;

/* One passive event emitted by dma_observer_monitor. */
class dma_observed_item extends uvm_sequence_item;

    dma_observed_kind_e kind;

    bit [31:0] src_addr;
    bit [31:0] dst_addr;
    bit [31:0] length;
    bit [7:0]  tag;

    bit [31:0] axi_addr;
    bit [7:0]  axi_len;
    bit [2:0]  axi_size;
    bit [1:0]  axi_burst;
    bit [31:0] data;
    bit [3:0]  strb;
    bit        last;

    bit [2:0] flags;
    bit [3:0] read_error;
    bit [3:0] write_error;

    `uvm_object_utils_begin(dma_observed_item)
        `uvm_field_enum(dma_observed_kind_e, kind, UVM_DEFAULT)
        `uvm_field_int(src_addr, UVM_HEX)
        `uvm_field_int(dst_addr, UVM_HEX)
        `uvm_field_int(length, UVM_DEC)
        `uvm_field_int(tag, UVM_HEX)
        `uvm_field_int(axi_addr, UVM_HEX)
        `uvm_field_int(axi_len, UVM_DEC)
        `uvm_field_int(axi_size, UVM_DEC)
        `uvm_field_int(axi_burst, UVM_BIN)
        `uvm_field_int(data, UVM_HEX)
        `uvm_field_int(strb, UVM_BIN)
        `uvm_field_int(last, UVM_BIN)
        `uvm_field_int(flags, UVM_BIN)
        `uvm_field_int(read_error, UVM_HEX)
        `uvm_field_int(write_error, UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "dma_observed_item");
        super.new(name);
    endfunction

endclass
