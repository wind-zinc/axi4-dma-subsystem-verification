`timescale 1ns / 1ps

class dma_subsys_random_stress_item extends uvm_object;
    `uvm_object_utils(dma_subsys_random_stress_item)

    localparam int unsigned POOL_BYTES = 32'h3000;
    int unsigned owner;
    int unsigned max_bytes = 4096;
    rand bit source_ram;
    rand bit destination_ram;
    rand bit destination_channel;
    rand int unsigned byte_count;
    rand int unsigned source_word;
    rand int unsigned destination_word;
    rand int unsigned descriptor_kind;
    rand int unsigned launch_gap;
    rand bit [7:0] software_tag;
    rand bit [7:0] payload_seed;

    constraint c_length {
        byte_count inside {[1:4096]};
        byte_count <= max_bytes;
        byte_count dist {
            1 := 2, 2 := 2, 3 := 2, 4 := 2,
            [5:14] :/ 2, 15 := 1, 16 := 2, [17:62] :/ 2,
            63 := 2, 64 := 2, 65 := 2, [66:126] :/ 2,
            127 := 1, 128 := 2, 129 := 1, [130:254] :/ 2,
            255 := 1, 256 := 2, 257 := 1, [258:510] :/ 2,
            511 := 1, 512 := 2, 513 := 1, [514:1022] :/ 3,
            1023 := 1, 1024 := 2, 1025 := 1, [1026:2046] :/ 3,
            2047 := 1, 2048 := 2, 2049 := 1, [2050:4094] :/ 4,
            4095 := 2, 4096 := 2
        };
    }
    constraint c_address {
        source_word >= 1;
        destination_word >= 1;
        source_word <= (POOL_BYTES - ((byte_count + 3) / 4) * 4 - 4) / 4;
        destination_word <= (POOL_BYTES - ((byte_count + 3) / 4) * 4 - 4) / 4;
    }
    constraint c_command {
        descriptor_kind dist {0 := 90, [1:3] :/ 10};
        launch_gap inside {[0:31]};
    }

    function new(string name = "dma_subsys_random_stress_item");
        super.new(name);
    endfunction

    function logic [31:0] source_address();
        return (source_ram ? RAM1_BASE_ADDR : RAM0_BASE_ADDR)
            + 32'h1000 + owner * POOL_BYTES + source_word * 4;
    endfunction

    function logic [31:0] destination_address();
        return (destination_ram ? RAM1_BASE_ADDR : RAM0_BASE_ADDR)
            + 32'h8000 + owner * POOL_BYTES + destination_word * 4;
    endfunction

    function dma_error_e descriptor_error();
        case (descriptor_kind)
            1: return DMA_ERR_LEN_ZERO;
            2: return DMA_ERR_SRC_ALIGN;
            3: return DMA_ERR_DST_ALIGN;
            default: return DMA_ERR_NONE;
        endcase
    endfunction
endclass
