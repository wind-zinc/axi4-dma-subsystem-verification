/*
 * The sequencer arbitrates axil_item requests from one or more sequences.
 * It contains no protocol timing; that responsibility belongs to the driver.
 */
class axil_sequencer extends uvm_sequencer #(axil_item);

    `uvm_component_utils(axil_sequencer)

    function new(string name = "axil_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

