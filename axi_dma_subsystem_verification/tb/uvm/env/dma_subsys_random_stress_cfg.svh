`timescale 1ns / 1ps

class dma_subsys_random_stress_cfg extends uvm_object;
    `uvm_object_utils(dma_subsys_random_stress_cfg)

    int unsigned commands_per_channel = 200;
    int unsigned error_pairs = 24;
    int unsigned max_bytes = 4096;
    int unsigned rdata_delay_max = 7;
    int unsigned bresp_delay_max = 15;
    int unsigned external_gap_max = 8;

    function new(string name = "dma_subsys_random_stress_cfg");
        super.new(name);
    endfunction

    function void validate();
        if (!(commands_per_channel inside {[16:2000]})
                || !(error_pairs inside {[8:500]})
                || !(max_bytes inside {[512:4096]})
                || !(rdata_delay_max inside {[0:31]})
                || !(bresp_delay_max inside {[0:63]})
                || !(external_gap_max inside {[0:128]})) begin
            `uvm_fatal("STRESS_CONFIG",
                $sformatf("commands=%0d error_pairs=%0d max_bytes=%0d rdelay=%0d bdelay=%0d ext_gap=%0d",
                    commands_per_channel, error_pairs, max_bytes,
                    rdata_delay_max, bresp_delay_max, external_gap_max))
        end
    endfunction
endclass
