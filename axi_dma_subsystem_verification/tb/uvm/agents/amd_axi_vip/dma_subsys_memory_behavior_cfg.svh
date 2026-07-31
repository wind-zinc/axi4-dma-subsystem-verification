// Configuration shared by the two AMD memory-slave VIPs.
//
// The stock AMD memory agent owns response generation.  This policy object
// controls the supported public knobs: READY behavior, response/data delay,
// and unwritten-memory fill.  SLVERR/DECERR injection is intentionally not
// represented here because it requires replacing the stock reactive response
// loop; that is a separate negative-test component, not a harmless knob.
class dma_subsys_memory_behavior_cfg extends uvm_object;
    `uvm_object_utils(dma_subsys_memory_behavior_cfg)

    bit no_backpressure[2];
    xil_axi_ready_gen_policy_t ready_policy[2];
    int unsigned ready_low_min[2];
    int unsigned ready_low_max[2];
    int unsigned ready_high_min[2];
    int unsigned ready_high_max[2];

    xil_axi_memory_delay_policy_t bresp_delay_policy[2];
    int unsigned bresp_delay_min[2];
    int unsigned bresp_delay_max[2];
    xil_axi_memory_delay_policy_t rdata_delay_policy[2];
    int unsigned rdata_delay_min[2];
    int unsigned rdata_delay_max[2];

    xil_axi_memory_fill_policy_t fill_policy[2];
    logic [AXI_DATA_WIDTH-1:0] default_fill_value[2];

    function new(string name = "dma_subsys_memory_behavior_cfg");
        super.new(name);
        foreach (no_backpressure[index]) begin
            no_backpressure[index] = 1'b1;
            ready_policy[index] = XIL_AXI_READY_GEN_OSC;
            ready_low_min[index] = 0;
            ready_low_max[index] = 0;
            ready_high_min[index] = 100;
            ready_high_max[index] = 100;

            bresp_delay_policy[index] = XIL_AXI_MEMORY_DELAY_FIXED;
            bresp_delay_min[index] = 0;
            bresp_delay_max[index] = 0;
            rdata_delay_policy[index] = XIL_AXI_MEMORY_DELAY_FIXED;
            rdata_delay_min[index] = 0;
            rdata_delay_max[index] = 0;

            fill_policy[index] = XIL_AXI_MEMORY_FILL_FIXED;
            default_fill_value[index] = {AXI_STRB_WIDTH{8'hA5}};
        end
    endfunction

    virtual function void validate();
        foreach (no_backpressure[index]) begin
            if (ready_low_min[index] > ready_low_max[index]) begin
                `uvm_fatal(
                    "MEM_CFG_READY_LOW",
                    $sformatf(
                        "MEM%0d READY low range [%0d:%0d] is invalid",
                        index, ready_low_min[index], ready_low_max[index]))
            end
            if (ready_high_min[index] > ready_high_max[index]) begin
                `uvm_fatal(
                    "MEM_CFG_READY_HIGH",
                    $sformatf(
                        "MEM%0d READY high range [%0d:%0d] is invalid",
                        index, ready_high_min[index], ready_high_max[index]))
            end
            if (bresp_delay_min[index] > bresp_delay_max[index]) begin
                `uvm_fatal(
                    "MEM_CFG_BRESP",
                    $sformatf(
                        "MEM%0d BRESP delay range [%0d:%0d] is invalid",
                        index,
                        bresp_delay_min[index], bresp_delay_max[index]))
            end
            if (rdata_delay_min[index] > rdata_delay_max[index]) begin
                `uvm_fatal(
                    "MEM_CFG_RDATA",
                    $sformatf(
                        "MEM%0d RDATA delay range [%0d:%0d] is invalid",
                        index,
                        rdata_delay_min[index], rdata_delay_max[index]))
            end
        end
    endfunction

endclass
