`default_nettype none

// First runtime test for the externally generated AMD AXI VIP bundle.
// It proves all five agents can be started and that both AXI external paths
// reach their corresponding reactive-memory VIP.
import uvm_pkg::*;
import axi_vip_pkg::*;
import axil_cpu_vip_pkg::*;
import ext_m0_vip_pkg::*;
import ext_m1_vip_pkg::*;
import mem0_vip_pkg::*;
import mem1_vip_pkg::*;
`include "uvm_macros.svh"

class amd_axi_vip_smoke_test extends uvm_test;
    `uvm_component_utils(amd_axi_vip_smoke_test)

    axil_cpu_vip_mst_t axil_cpu;
    ext_m0_vip_mst_t ext_m0;
    ext_m1_vip_mst_t ext_m1;
    mem0_vip_slv_mem_t mem0;
    mem1_vip_slv_mem_t mem1;

    function new(string name = "amd_axi_vip_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        bit [8*8-1:0] axil_data;
        bit [8*4096-1:0] write_data;
        bit [8*4096-1:0] read_data;
        xil_axi_data_beat [255:0] write_user;
        xil_axi_data_beat [255:0] read_user;
        xil_axi_resp_t axil_resp;
        xil_axi_resp_t write_resp;
        xil_axi_resp_t [255:0] read_resp;

        phase.raise_objection(this);

        axil_cpu = new("axil_cpu", tb_axi_dma_core_amd_vip.u_axil_cpu_vip.inst.IF);
        ext_m0   = new("ext_m0",   tb_axi_dma_core_amd_vip.u_ext_m0_vip.inst.IF);
        ext_m1   = new("ext_m1",   tb_axi_dma_core_amd_vip.u_ext_m1_vip.inst.IF);
        mem0     = new("mem0",     tb_axi_dma_core_amd_vip.u_mem0_vip.inst.IF);
        mem1     = new("mem1",     tb_axi_dma_core_amd_vip.u_mem1_vip.inst.IF);

        axil_cpu.start_master();
        ext_m0.start_master();
        ext_m1.start_master();
        mem0.start_slave();
        mem1.start_slave();

        axil_cpu.set_nobackpressure_readies();
        ext_m0.set_nobackpressure_readies();
        ext_m1.set_nobackpressure_readies();

        @(negedge tb_axi_dma_core_amd_vip.rst);

        // AXI-Lite master path: one register in each channel window.
        axil_cpu.AXI4LITE_READ_BURST(32'h0000_0000,
            XIL_AXI_PROT_NORMAL_ACCESS_MASK, axil_data, axil_resp);
        if (axil_resp != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal("AXIL_SMOKE", $sformatf("channel 0 read response: %0d", axil_resp))
        end

        axil_cpu.AXI4LITE_READ_BURST(32'h0000_1000,
            XIL_AXI_PROT_NORMAL_ACCESS_MASK, axil_data, axil_resp);
        if (axil_resp != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal("AXIL_SMOKE", $sformatf("channel 1 read response: %0d", axil_resp))
        end

        // ext_m0 -> RAM0: write then read the same aligned 32-bit location.
        write_data = '0;
        write_data[31:0] = 32'hA5A5_0000;
        foreach (write_user[i]) write_user[i] = '0;
        ext_m0.AXI4_WRITE_BURST(0, 32'h0000_0100, 0, XIL_AXI_SIZE_4BYTE,
            XIL_AXI_BURST_TYPE_INCR, XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
            XIL_AXI_PROT_NORMAL_ACCESS_MASK, xil_axi_region_t'(0), xil_axi_qos_t'(0),
            '0, write_data, write_user, write_resp);
        if (write_resp != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal("EXT_M0_SMOKE", $sformatf("RAM0 write response: %0d", write_resp))
        end

        ext_m0.AXI4_READ_BURST(0, 32'h0000_0100, 0, XIL_AXI_SIZE_4BYTE,
            XIL_AXI_BURST_TYPE_INCR, XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
            XIL_AXI_PROT_NORMAL_ACCESS_MASK, xil_axi_region_t'(0), xil_axi_qos_t'(0),
            '0, read_data, read_resp, read_user);
        if ((read_resp[0] != XIL_AXI_RESP_OKAY) || (read_data[31:0] != 32'hA5A5_0000)) begin
            `uvm_fatal("EXT_M0_SMOKE", "RAM0 readback mismatch")
        end

        // ext_m1 -> RAM1: this independently exercises the second master and
        // second slave VIP through the same crossbar.
        write_data = '0;
        write_data[31:0] = 32'h5A5A_0001;
        foreach (write_user[i]) write_user[i] = '0;
        ext_m1.AXI4_WRITE_BURST(0, 32'h1000_0100, 0, XIL_AXI_SIZE_4BYTE,
            XIL_AXI_BURST_TYPE_INCR, XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
            XIL_AXI_PROT_NORMAL_ACCESS_MASK, xil_axi_region_t'(0), xil_axi_qos_t'(0),
            '0, write_data, write_user, write_resp);
        if (write_resp != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal("EXT_M1_SMOKE", $sformatf("RAM1 write response: %0d", write_resp))
        end

        ext_m1.AXI4_READ_BURST(0, 32'h1000_0100, 0, XIL_AXI_SIZE_4BYTE,
            XIL_AXI_BURST_TYPE_INCR, XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
            XIL_AXI_PROT_NORMAL_ACCESS_MASK, xil_axi_region_t'(0), xil_axi_qos_t'(0),
            '0, read_data, read_resp, read_user);
        if ((read_resp[0] != XIL_AXI_RESP_OKAY) || (read_data[31:0] != 32'h5A5A_0001)) begin
            `uvm_fatal("EXT_M1_SMOKE", "RAM1 readback mismatch")
        end

        `uvm_info("AMD_AXI_VIP_SMOKE", "All five AMD AXI VIP agents passed the first smoke test", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass

`default_nettype wire
