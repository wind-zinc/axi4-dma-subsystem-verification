`default_nettype none

import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"

class dma_subsys_ch0_to_ch1_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_ch0_to_ch1_test)

    function new(
        string        name   = "dma_subsys_ch0_to_ch1_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_ch0_to_ch1_vseq vseq;

        phase.raise_objection(this);
        vseq = dma_subsys_ch0_to_ch1_vseq::type_id::create("vseq");
        vseq.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask

endclass

`default_nettype wire
