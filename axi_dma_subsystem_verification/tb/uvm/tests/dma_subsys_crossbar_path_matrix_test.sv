`default_nettype none
import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"
class dma_subsys_crossbar_path_matrix_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_crossbar_path_matrix_test)
    function new(string name="dma_subsys_crossbar_path_matrix_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction
    virtual task run_phase(uvm_phase phase);
        dma_subsys_crossbar_path_matrix_vseq sequence_h;
        phase.raise_objection(this);
        sequence_h = dma_subsys_crossbar_path_matrix_vseq::type_id::create("sequence_h");
        sequence_h.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask
endclass
`default_nettype wire
