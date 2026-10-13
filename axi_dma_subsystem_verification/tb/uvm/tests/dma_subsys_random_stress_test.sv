`timescale 1ns / 1ps
`default_nettype none

import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"

class dma_subsys_random_stress_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_random_stress_test)

    dma_subsys_random_stress_cfg stress_cfg;

    function new(string name = "dma_subsys_random_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void configure();
        stress_cfg = dma_subsys_random_stress_cfg::type_id::create("stress_cfg");
        void'($value$plusargs("STRESS_DMA_PER_CH=%d", stress_cfg.commands_per_channel));
        void'($value$plusargs("STRESS_ERROR_PAIRS=%d", stress_cfg.error_pairs));
        void'($value$plusargs("STRESS_MAX_BYTES=%d", stress_cfg.max_bytes));
        void'($value$plusargs("STRESS_RDELAY_MAX=%d", stress_cfg.rdata_delay_max));
        void'($value$plusargs("STRESS_BDELAY_MAX=%d", stress_cfg.bresp_delay_max));
        void'($value$plusargs("STRESS_EXT_GAP_MAX=%d", stress_cfg.external_gap_max));
        stress_cfg.validate();
        uvm_config_db#(dma_subsys_random_stress_cfg)::set(this, "env*", "dma_subsys_random_stress_cfg", stress_cfg);
        env_cfg.vip_timeout_cycles = 200000;
        env_cfg.status_poll_limit = 50000;
        env_cfg.max_route_wait_cycles = 100000;
        env_cfg.global_watchdog_cycles = 200000
            + (2 * stress_cfg.commands_per_channel + 2 * stress_cfg.error_pairs + 2) * 40000;
        foreach (memory_cfg.no_backpressure[index]) begin
            memory_cfg.no_backpressure[index] = 1'b0;
            memory_cfg.ready_low_min[index] = 0;
            memory_cfg.ready_low_max[index] = 4;
            memory_cfg.ready_high_min[index] = 1;
            memory_cfg.ready_high_max[index] = 6;
            memory_cfg.rdata_delay_min[index] = $urandom_range(0, stress_cfg.rdata_delay_max);
            memory_cfg.rdata_delay_max[index] = memory_cfg.rdata_delay_min[index];
            memory_cfg.bresp_delay_min[index] = $urandom_range(0, stress_cfg.bresp_delay_max);
            memory_cfg.bresp_delay_max[index] = memory_cfg.bresp_delay_min[index];
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_random_stress_vseq vseq;
        phase.raise_objection(this);
        vseq = dma_subsys_random_stress_vseq::type_id::create("vseq");
        vseq.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask
endclass

`default_nettype wire
