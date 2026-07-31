// Shared policy for the reusable subsystem environment.
//
// Tests override this object before the environment is built.  Sequences and
// components consume the same limits so timeout behavior is consistent.
class dma_subsys_env_cfg extends uvm_object;
    `uvm_object_utils_begin(dma_subsys_env_cfg)
        `uvm_field_int(vip_timeout_cycles, UVM_DEFAULT)
        `uvm_field_int(status_poll_limit, UVM_DEFAULT)
        `uvm_field_int(global_watchdog_cycles, UVM_DEFAULT)
        `uvm_field_int(max_route_wait_cycles, UVM_DEFAULT)
        `uvm_field_int(enable_global_watchdog, UVM_DEFAULT)
        `uvm_field_int(enable_route_wait_check, UVM_DEFAULT)
    `uvm_object_utils_end

    int unsigned vip_timeout_cycles       = 2000;
    int unsigned status_poll_limit        = 1000;
    int unsigned global_watchdog_cycles   = 200000;
    int unsigned max_route_wait_cycles    = 4096;
    bit          enable_global_watchdog   = 1'b1;
    bit          enable_route_wait_check  = 1'b1;

    function new(string name = "dma_subsys_env_cfg");
        super.new(name);
    endfunction

endclass
