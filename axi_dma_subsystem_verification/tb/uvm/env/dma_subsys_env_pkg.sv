`default_nettype none

package dma_subsys_env_pkg;

    import uvm_pkg::*;
    import dma_subsystem_pkg::*;
    import dma_subsys_tr_pkg::*;
    import dma_subsys_vip_pkg::*;
    import axi_vip_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_intent)
    `uvm_analysis_imp_decl(_cmd)
    `uvm_analysis_imp_decl(_reg)
    `uvm_analysis_imp_decl(_mem)
    `uvm_analysis_imp_decl(_route)
    `uvm_analysis_imp_decl(_completion)
    `uvm_analysis_imp_decl(_irq)
    `uvm_analysis_imp_decl(_fault)
    `uvm_analysis_imp_decl(_reset)

    `include "dma_subsys_env_cfg.svh"
    `include "dma_subsys_probe_monitor_base.svh"
    `include "dma_subsys_cmd_monitor.svh"
    `include "dma_subsys_route_monitor.svh"
    `include "dma_subsys_irq_monitor.svh"
    `include "dma_subsys_vip_transaction_adapter.svh"
    `include "dma_subsys_memory_behavior_controller.svh"
    `include "dma_subsys_axil_sequencer.svh"
    `include "dma_subsys_axil_driver.svh"
    `include "dma_subsys_reg_model.svh"
    `include "dma_subsys_reg_adapter.svh"
    `include "dma_subsys_ref_model.svh"
    `include "dma_subsys_scoreboard.svh"
    `include "dma_subsys_coverage.svh"
    `include "dma_subsys_watchdog.svh"
    `include "dma_subsys_virtual_sequencer.svh"
    `include "dma_subsys_vseq_base.svh"
    `include "dma_subsys_ral_smoke_vseq.svh"
    `include "dma_subsys_ch0_to_ch1_vseq.svh"
    `include "dma_subsys_completion_reorder_vseq.svh"
    `include "dma_subsys_ch1_to_ch0_vseq.svh"
    `include "dma_subsys_crossbar_path_matrix_vseq.svh"
    `include "dma_subsys_transfer_length_boundary_vseq.svh"
    `include "dma_subsys_register_access_policy_vseq.svh"
    `include "dma_subsys_axi_burst_shape_vseq.svh"
    `include "dma_subsys_route_contention_vseq.svh"
    `include "dma_subsys_completion_order_reverse_vseq.svh"
    `include "dma_subsys_irq_mask_multi_pending_vseq.svh"
    `include "dma_subsys_descriptor_error_vseq.svh"
    `include "dma_subsys_abort_timing_vseq.svh"
    `include "dma_subsys_reset_recovery_vseq.svh"
    `include "dma_subsys_memory_response_error_vseq.svh"
    `include "dma_subsys_status_fault_injection_vseq.svh"
    `include "dma_subsys_axil_protocol_timing_vseq.svh"
    `include "dma_subsys_irq_status_separation_vseq.svh"
    `include "dma_subsys_status_fault_expansion_vseq.svh"
    `include "dma_subsys_abort_phase_matrix_vseq.svh"
    `include "dma_subsys_toggle_value_sweep_vseq.svh"
    `include "dma_subsys_env.svh"
    `include "dma_subsys_base_test.svh"

endpackage

`default_nettype wire
