#!/usr/bin/env bash
# Compile the RAM-free DMA core with the five externally supplied AMD AXI VIPs.
# The AMD-generated sources are deliberately not part of this Git repository.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vip_home="${AXI_VIP_HOME:-${HOME}/Desktop/verify_study/vip}"
build_dir="${VCS_BUILD_DIR:-${project_root}/build/vcs_core_amd_vip}"
vcs_bin="${VCS:-vcs}"

required=(
  "${vip_home}/vendor/xilinx_vip/hdl/axi_vip_pkg.sv"
  "${vip_home}/vendor/xilinx_vip/hdl/axi_vip_if.sv"
  "${vip_home}/ipstatic/hdl/axi_infrastructure_v1_1_0.vh"
  "${vip_home}/ipstatic/hdl/axi_infrastructure_v1_1_vl_rfs.v"
  "${vip_home}/ipstatic/hdl/axi_vip_v1_1_vl_rfs.sv"
  "${vip_home}/generated/axil_cpu_vip/sim/axil_cpu_vip_pkg.sv"
  "${vip_home}/generated/ext_m0_vip/sim/ext_m0_vip_pkg.sv"
  "${vip_home}/generated/ext_m1_vip/sim/ext_m1_vip_pkg.sv"
  "${vip_home}/generated/mem0_vip/sim/mem0_vip_pkg.sv"
  "${vip_home}/generated/mem1_vip/sim/mem1_vip_pkg.sv"
)

for item in "${required[@]}"; do
  if [[ ! -f "${item}" ]]; then
    echo "ERROR: AXI VIP bundle is incomplete: ${item}" >&2
    echo "Set AXI_VIP_HOME to the exported VIP bundle." >&2
    exit 2
  fi
done

mkdir -p "${build_dir}"
cd "${project_root}/sim"

vip_inc=(
  "+incdir+${vip_home}/ipstatic/hdl"
  "+incdir+${vip_home}/vendor/xilinx_vip/include"
)

vip_sources=(
  "${vip_home}/vendor/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/axi_vip_pkg.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/axi4stream_vip_if.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/axi_vip_if.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/clk_vip_if.sv" \
  "${vip_home}/vendor/xilinx_vip/hdl/rst_vip_if.sv" \
  "${vip_home}/ipstatic/hdl/axi_infrastructure_v1_1_vl_rfs.v" \
  "${vip_home}/generated/axil_cpu_vip/sim/axil_cpu_vip_pkg.sv" \
  "${vip_home}/generated/ext_m0_vip/sim/ext_m0_vip_pkg.sv" \
  "${vip_home}/generated/ext_m1_vip/sim/ext_m1_vip_pkg.sv" \
  "${vip_home}/generated/mem0_vip/sim/mem0_vip_pkg.sv" \
  "${vip_home}/generated/mem1_vip/sim/mem1_vip_pkg.sv" \
  "${vip_home}/ipstatic/hdl/axi_vip_v1_1_vl_rfs.sv" \
  "${vip_home}/generated/axil_cpu_vip/sim/axil_cpu_vip.sv" \
  "${vip_home}/generated/ext_m0_vip/sim/ext_m0_vip.sv" \
  "${vip_home}/generated/ext_m1_vip/sim/ext_m1_vip.sv" \
  "${vip_home}/generated/mem0_vip/sim/mem0_vip.sv" \
  "${vip_home}/generated/mem1_vip/sim/mem1_vip.sv"
)

# Use the same one-pass compilation model as the known-good UVM regression
# flow.  In this VCS setup, -ntb_opts uvm-1.2 is applied by vcs itself; a
# separate vlogan phase leaves uvm_pkg unavailable to the later sources.
"${vcs_bin}" -full64 -sverilog -ntb_opts uvm-1.2 \
  -override_timescale=1ns/1ps \
  "${vip_inc[@]}" "${vip_sources[@]}" \
  -f run_core_amd_vip.f -top tb_axi_dma_core_amd_vip \
  -debug_access+all -kdb -l "${build_dir}/compile.log" \
  -o "${build_dir}/simv"

"${build_dir}/simv" "$@"
