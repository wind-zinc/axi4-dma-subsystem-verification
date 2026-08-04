#!/usr/bin/env bash
# Compile the RAM-free DMA core with the five externally supplied AMD AXI VIPs.
# The AMD-generated sources are deliberately not part of this Git repository.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vip_home="${AXI_VIP_HOME:-${HOME}/Desktop/verify_study/vip}"
build_dir="${VCS_BUILD_DIR:-${project_root}/build/vcs_core_amd_vip}"
vcs_bin="${VCS:-vcs}"
urg_bin="${URG:-urg}"
coverage_enabled="${COVERAGE:-1}"
coverage_metrics="${COVERAGE_METRICS:-line+cond+tgl+fsm+branch+assert}"
urg_only="${URG_ONLY:-0}"
# Code coverage is selected explicitly, so add the SystemVerilog functional
# coverage metric here as well.  Without "group", URG creates an empty Groups
# page even though the UVM covergroups sampled correctly in simulation.
urg_metrics="${URG_METRICS:-${coverage_metrics}+group}"
cm_hier_file="${CM_HIER_FILE:-${project_root}/sim/cm_hier.cfg}"
compile_only="${COMPILE_ONLY:-0}"
reuse_compiled_simv="${REUSE_COMPILED_SIMV:-0}"
skip_urg="${SKIP_URG:-0}"

case "${coverage_enabled}" in
  0|1) ;;
  *)
    echo "ERROR: COVERAGE must be 0 or 1, got '${coverage_enabled}'." >&2
    exit 2
    ;;
esac

case "${urg_only}" in
  0|1) ;;
  *)
    echo "ERROR: URG_ONLY must be 0 or 1, got '${urg_only}'." >&2
    exit 2
    ;;
esac

case "${compile_only}" in
  0|1) ;;
  *)
    echo "ERROR: COMPILE_ONLY must be 0 or 1, got '${compile_only}'." >&2
    exit 2
    ;;
esac

case "${reuse_compiled_simv}" in
  0|1) ;;
  *)
    echo "ERROR: REUSE_COMPILED_SIMV must be 0 or 1, got '${reuse_compiled_simv}'." >&2
    exit 2
    ;;
esac

case "${skip_urg}" in
  0|1) ;;
  *)
    echo "ERROR: SKIP_URG must be 0 or 1, got '${skip_urg}'." >&2
    exit 2
    ;;
esac

if [[ -z "${urg_metrics}" ]]; then
  echo "ERROR: URG_METRICS must not be empty." >&2
  exit 2
fi

# Keep this list synchronized with every concrete test added to
# tb/uvm/tests and sim/run_core_amd_vip.f.  dma_subsys_base_test is a base
# class and must not be placed in this regression list.
regression_tests=(
  "amd_axi_vip_smoke_test"
  "dma_subsys_vip_manager_smoke_test"
  "dma_subsys_env_smoke_test"
  "dma_subsys_ral_smoke_test"
  "dma_subsys_ch0_to_ch1_test"
  "dma_subsys_completion_reorder_test"
)

vip_smoke_test="amd_axi_vip_smoke_test"
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
  if [[ "${urg_only}" == "1" ]]; then
    echo "ERROR: URG_ONLY=1 requires an explicit +UVM_TESTNAME." >&2
    echo "Run the default regression without URG_ONLY to generate its merged report." >&2
    exit 2
  fi
  if [[ "${reuse_compiled_simv}" == "1" ]]; then
    echo "ERROR: REUSE_COMPILED_SIMV=1 requires an explicit +UVM_TESTNAME." >&2
    exit 2
  fi

  script_path="${project_root}/sim/$(basename "${BASH_SOURCE[0]}")"
  regression_stamp="${RUN_STAMP_OVERRIDE:-$(date +%Y%m%d_%H%M%S)}"
  regression_dir="${REGRESSION_DIR:-${build_dir}/regression/${regression_stamp}}"
  regression_log_dir="${REGRESSION_LOG_DIR:-${regression_dir}/logs}"
  regression_cov_dir="${COV_DIR:-${build_dir}/coverage/regression_${regression_stamp}.vdb}"
  regression_report_dir="${REPORT_DIR:-${build_dir}/coverage/urg_regression_${regression_stamp}}"
  regression_urg_log="${URG_LOG:-${build_dir}/coverage/urg_regression_${regression_stamp}.log}"

  mkdir -p "${regression_log_dir}"

  echo "No +UVM_TESTNAME supplied; running the maintained regression list."
  echo "Regression tests (${#regression_tests[@]}):"
  printf '  %s\n' "${regression_tests[@]}"
  echo "Compiling once before running the regression..."

  if RUN_STAMP_OVERRIDE="${regression_stamp}" \
     COV_DIR="${regression_cov_dir}" \
     COMPILE_ONLY=1 REUSE_COMPILED_SIMV=0 SKIP_URG=1 \
     "${script_path}" "$@" \
     "+UVM_TESTNAME=${regression_tests[0]}"; then
    :
  else
    compile_status="$?"
    echo "ERROR: regression compilation failed with status ${compile_status}." >&2
    exit "${compile_status}"
  fi

  if [[ "${compile_only}" == "1" ]]; then
    echo "Compile-only regression setup complete: ${build_dir}/simv"
    exit 0
  fi

  regression_statuses=()
  regression_failed=0

  for regression_test in "${regression_tests[@]}"; do
    safe_regression_test="${regression_test//[^[:alnum:]_.-]/_}"
    regression_sim_log="${regression_log_dir}/sim_${safe_regression_test}.log"

    echo
    echo "================================================================"
    echo "REGRESSION TEST: ${regression_test}"
    echo "================================================================"

    if RUN_STAMP_OVERRIDE="${regression_stamp}" \
       COV_DIR="${regression_cov_dir}" \
       SIM_LOG="${regression_sim_log}" \
       COMPILE_ONLY=0 REUSE_COMPILED_SIMV=1 SKIP_URG=1 \
       "${script_path}" "$@" \
       "+UVM_TESTNAME=${regression_test}"; then
      regression_statuses+=(0)
    else
      test_status="$?"
      regression_statuses+=("${test_status}")
      regression_failed=1
    fi
  done

  regression_urg_status=0
  if [[ "${coverage_enabled}" == "1" ]]; then
    echo
    echo "Generating one cumulative URG report for the regression VDB..."
    if RUN_STAMP_OVERRIDE="${regression_stamp}" \
       COV_DIR="${regression_cov_dir}" \
       REPORT_DIR="${regression_report_dir}" \
       URG_LOG="${regression_urg_log}" \
       URG_ONLY=1 COMPILE_ONLY=0 REUSE_COMPILED_SIMV=0 SKIP_URG=0 \
       "${script_path}" "+UVM_TESTNAME=${regression_tests[0]}"; then
      :
    else
      regression_urg_status="$?"
      regression_failed=1
    fi
  fi

  echo
  echo "================ REGRESSION SUMMARY ================"
  for index in "${!regression_tests[@]}"; do
    if (( regression_statuses[index] == 0 )); then
      printf 'PASS  %s\n' "${regression_tests[index]}"
    else
      printf 'FAIL  %s (status %s)\n' \
        "${regression_tests[index]}" "${regression_statuses[index]}"
    fi
  done
  echo "Logs: ${regression_log_dir}"
  if [[ "${coverage_enabled}" == "1" ]]; then
    echo "Coverage database: ${regression_cov_dir}"
    if (( regression_urg_status == 0 )); then
      echo "URG dashboard:     ${regression_report_dir}/dashboard.html"
    else
      echo "URG report failed with status ${regression_urg_status}." >&2
    fi
  fi

  if (( regression_failed != 0 )); then
    echo "REGRESSION FAIL: one or more tests/reports failed." >&2
    exit 1
  fi

  echo "REGRESSION PASS: all ${#regression_tests[@]} tests passed."
  exit 0
fi

safe_test_name="${test_name//[^[:alnum:]_.-]/_}"
run_stamp="${RUN_STAMP_OVERRIDE:-$(date +%Y%m%d_%H%M%S)}"
sim_log="${SIM_LOG:-${build_dir}/sim_${safe_test_name}.log}"
cov_dir="${COV_DIR:-${build_dir}/coverage/${safe_test_name}_${run_stamp}.vdb}"
report_dir="${REPORT_DIR:-${build_dir}/coverage/urg_${safe_test_name}_${run_stamp}}"
urg_log="${URG_LOG:-${build_dir}/coverage/urg_${safe_test_name}_${run_stamp}.log}"

final_report_dir="${report_dir}"
final_urg_log="${urg_log}"

# V-2023.12-SP2 can crash while building the all-metric DSL pool for a VDB
# containing the subsystem UVM environment.  Ask URG for only the selected
# metrics instead of letting it traverse every metric stored in the database.
run_urg_report() {
  local selected_metrics="$1"
  local selected_report_dir="$2"
  local selected_log="$3"
  local status

  mkdir -p "$(dirname "${selected_report_dir}")"
  mkdir -p "$(dirname "${selected_log}")"

  set +e
  "${urg_bin}" -dir "${cov_dir}" -metric "${selected_metrics}" \
    -report "${selected_report_dir}" 2>&1 | tee "${selected_log}"
  status="${PIPESTATUS[0]}"
  set -e
  return "${status}"
}

run_urg_with_line_fallback() {
  local status
  local line_group_report_dir
  local line_group_log
  local line_report_dir
  local line_log

  if ! command -v "${urg_bin}" >/dev/null 2>&1; then
    echo "ERROR: URG executable was not found: ${urg_bin}" >&2
    return 7
  fi
  if [[ ! -d "${cov_dir}" ]]; then
    echo "ERROR: coverage database does not exist: ${cov_dir}" >&2
    return 7
  fi

  echo "URG selected metrics: ${urg_metrics}"
  if run_urg_report "${urg_metrics}" "${report_dir}" "${urg_log}"; then
    final_report_dir="${report_dir}"
    final_urg_log="${urg_log}"
    return 0
  else
    status="$?"
  fi

  if (( status == 139 )) &&
     [[ "${urg_metrics}" != "line+group" ]] &&
     [[ "${urg_metrics}" != "line" ]]; then
    line_group_report_dir="${report_dir}_line_group"
    line_group_log="${urg_log}.line_group.log"
    final_report_dir="${line_group_report_dir}"
    final_urg_log="${line_group_log}"
    echo "WARNING: URG crashed with status 139 while reporting '${urg_metrics}'." >&2
    echo "WARNING: retrying the preserved VDB with line and group coverage." >&2
    if run_urg_report "line+group" \
         "${line_group_report_dir}" "${line_group_log}"; then
      final_report_dir="${line_group_report_dir}"
      final_urg_log="${line_group_log}"
      echo "WARNING: the fallback report contains line and group coverage only." >&2
      return 0
    else
      status="$?"
    fi
  fi

  if (( status == 139 )) && [[ "${urg_metrics}" != "line" ]]; then
    line_report_dir="${report_dir}_line_only"
    line_log="${urg_log}.line_only.log"
    final_report_dir="${line_report_dir}"
    final_urg_log="${line_log}"
    echo "WARNING: retrying the preserved VDB with line coverage only." >&2
    if run_urg_report "line" "${line_report_dir}" "${line_log}"; then
      final_report_dir="${line_report_dir}"
      final_urg_log="${line_log}"
      echo "WARNING: the fallback report contains line coverage only." >&2
      return 0
    else
      status="$?"
    fi
  fi

  return "${status}"
}

if [[ "${urg_only}" == "1" ]]; then
  if [[ "${coverage_enabled}" != "1" ]]; then
    echo "ERROR: URG_ONLY=1 requires COVERAGE=1." >&2
    exit 2
  fi

  echo "URG-only mode: simulation and compilation are skipped."
  echo "Coverage database : ${cov_dir}"
  echo "URG report        : ${report_dir}"
  echo "URG log           : ${urg_log}"
  if run_urg_with_line_fallback; then
    echo "Coverage database: ${cov_dir}"
    echo "URG dashboard:     ${final_report_dir}/dashboard.html"
    echo "URG log:           ${final_urg_log}"
    exit 0
  else
    urg_status="$?"
    echo "ERROR: URG exited with status ${urg_status}." >&2
    echo "Coverage database was preserved at ${cov_dir}" >&2
    echo "URG diagnostics were preserved at ${final_urg_log}" >&2
    exit 8
  fi
fi

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
mkdir -p "$(dirname "${sim_log}")"
if [[ "${coverage_enabled}" == "1" ]]; then
  if [[ ! -f "${cm_hier_file}" ]]; then
    echo "ERROR: coverage hierarchy file is missing: ${cm_hier_file}" >&2
    exit 2
  fi
  mkdir -p "$(dirname "${cov_dir}")"
  mkdir -p "$(dirname "${report_dir}")"
  mkdir -p "$(dirname "${urg_log}")"
fi
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
compile_design() {
  "${vcs_bin}" -full64 -sverilog -ntb_opts uvm-1.2 \
    -override_timescale=1ns/1ps \
    "${vip_inc[@]}" "${vip_sources[@]}" \
    -f run_core_amd_vip.f -top tb_axi_dma_core_amd_vip \
    -debug_access+all -kdb "$@" \
    -l "${build_dir}/compile.log" \
    -o "${build_dir}/simv"
}

if [[ "${reuse_compiled_simv}" == "1" ]]; then
  if [[ ! -x "${build_dir}/simv" ]]; then
    echo "ERROR: REUSE_COMPILED_SIMV=1, but no executable simv was found:" >&2
    echo "       ${build_dir}/simv" >&2
    exit 2
  fi
  echo "Reusing compiled simulator: ${build_dir}/simv"
else
  if [[ "${coverage_enabled}" == "1" ]]; then
    compile_design \
      -cm "${coverage_metrics}" \
      -cm_noconst \
      -cm_hier "${cm_hier_file}" \
      -cm_dir "${cov_dir}"
  else
    compile_design
  fi
fi

if [[ "${compile_only}" == "1" ]]; then
  echo "Compile-only mode complete: ${build_dir}/simv"
  if [[ "${coverage_enabled}" == "1" ]]; then
    echo "Coverage instrumentation enabled; run simv before invoking URG."
  fi
  exit 0
fi

echo "Selected UVM test : ${test_name}"
echo "Compile log       : ${build_dir}/compile.log"
echo "Simulation log    : ${sim_log}"
if [[ "${coverage_enabled}" == "1" ]]; then
  echo "Coverage metrics  : ${coverage_metrics}"
  echo "URG metrics       : ${urg_metrics}"
  echo "Coverage database : ${cov_dir}"
  echo "URG report        : ${report_dir}"
  echo "URG log           : ${urg_log}"
else
  echo "Coverage          : disabled by COVERAGE=0"
fi

# Mirror the complete runtime transcript to a dedicated simulation log.  Keep
# the simulator's real exit status instead of tee's status.
set +e
if [[ "${coverage_enabled}" == "1" ]]; then
  "${build_dir}/simv" "${sim_args[@]}" \
    -cm "${coverage_metrics}" \
    -cm_dir "${cov_dir}" \
    -cm_name "${safe_test_name}" \
    2>&1 | tee "${sim_log}"
else
  "${build_dir}/simv" "${sim_args[@]}" 2>&1 | tee "${sim_log}"
fi
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

if [[ "${test_name}" == "${vip_smoke_test}" ]] &&
   ! grep -Fq "All five AMD AXI VIP agents passed the first smoke test" "${sim_log}"; then
  echo "ERROR: ${vip_smoke_test} started, but its final success marker is missing." >&2
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

if [[ "${coverage_enabled}" == "1" && "${skip_urg}" == "0" ]]; then
  if run_urg_with_line_fallback; then
    urg_status=0
  else
    urg_status="$?"
  fi

  if (( urg_status != 0 )); then
    echo "ERROR: URG exited with status ${urg_status}." >&2
    echo "Coverage database was preserved at ${cov_dir}" >&2
    echo "URG diagnostics were preserved at ${final_urg_log}" >&2
    exit 8
  fi

  echo "Coverage database: ${cov_dir}"
  echo "URG dashboard:     ${final_report_dir}/dashboard.html"
  echo "URG log:           ${final_urg_log}"
elif [[ "${coverage_enabled}" == "1" ]]; then
  echo "URG generation deferred to the regression-level report."
fi
