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

if [[ "${COMPILE_ONLY:-0}" == "1" ]]; then
  echo "Compile-only mode complete: ${build_dir}/simv"
  exit 0
fi

default_test="amd_axi_vip_smoke_test"
sim_args=("$@")
test_name=""

for arg in "$@"; do
  if [[ "${arg}" == +UVM_TESTNAME=* ]]; then
    selected_name="${arg#+UVM_TESTNAME=}"
    if [[ -z "${selected_name}" ]]; then
      echo "ERROR: +UVM_TESTNAME requires a non-empty test name." >&2
      exit 2
    fi
    if [[ -n "${test_name}" ]]; then
      echo "ERROR: pass exactly one +UVM_TESTNAME argument." >&2
      exit 2
    fi
    test_name="${selected_name}"
  fi
done

if [[ -z "${test_name}" ]]; then
  test_name="${default_test}"
  sim_args+=("+UVM_TESTNAME=${test_name}")
  echo "No +UVM_TESTNAME supplied; defaulting to ${test_name}"
fi

safe_test_name="${test_name//[^[:alnum:]_.-]/_}"
sim_log="${SIM_LOG:-${build_dir}/sim_${safe_test_name}.log}"
mkdir -p "$(dirname "${sim_log}")"

echo "Selected UVM test : ${test_name}"
echo "Compile log       : ${build_dir}/compile.log"
echo "Simulation log    : ${sim_log}"

# Mirror the complete runtime transcript to a dedicated simulation log.  Keep
# the simulator's real exit status instead of tee's status.
set +e
"${build_dir}/simv" "${sim_args[@]}" 2>&1 | tee "${sim_log}"
sim_status="${PIPESTATUS[0]}"
set -e

if (( sim_status != 0 )); then
  echo "ERROR: simv exited with status ${sim_status}; see ${sim_log}" >&2
  exit "${sim_status}"
fi

if ! grep -Fq "Running test ${test_name}" "${sim_log}"; then
  echo "ERROR: no UVM [RNTST] evidence for ${test_name} was found in ${sim_log}" >&2
  exit 3
fi

if [[ "${test_name}" == "${default_test}" ]] &&
   ! grep -Fq "All five AMD AXI VIP agents passed the first smoke test" "${sim_log}"; then
  echo "ERROR: ${default_test} started, but its final success marker is missing." >&2
  exit 4
fi

if ! grep -Eq '^[[:space:]]*UVM_ERROR[[:space:]]*:[[:space:]]*0([[:space:]]|$)' "${sim_log}"; then
  echo "ERROR: the UVM report does not show UVM_ERROR : 0." >&2
  exit 5
fi

if ! grep -Eq '^[[:space:]]*UVM_FATAL[[:space:]]*:[[:space:]]*0([[:space:]]|$)' "${sim_log}"; then
  echo "ERROR: the UVM report does not show UVM_FATAL : 0." >&2
  exit 6
fi

echo "PASS: ${test_name} ran to completion with UVM_ERROR=0 and UVM_FATAL=0."
echo "PASS evidence: ${sim_log}"
