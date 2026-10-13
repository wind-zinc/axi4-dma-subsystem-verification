#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
launcher="${project_root}/sim/run_vcs_core_amd_vip.sh"
test_name="dma_subsys_random_stress_test"
build_dir="${VCS_BUILD_DIR:-${project_root}/build/vcs_random_stress}"
run_stamp="${RUN_STAMP_OVERRIDE:-$(date +%Y%m%d_%H%M%S)}"
run_dir="${STRESS_RUN_DIR:-${build_dir}/runs/${run_stamp}}"
coverage_enabled="${COVERAGE:-0}"
cov_dir="${COV_DIR:-${run_dir}/coverage.vdb}"
report_dir="${REPORT_DIR:-${run_dir}/urg}"
urg_log="${URG_LOG:-${run_dir}/urg.log}"
read -r -a seeds <<< "${STRESS_SEEDS:-17 81 2026 4096 65537}"

if (( ${#seeds[@]} == 0 )); then
  echo "ERROR: STRESS_SEEDS must contain at least one numeric seed." >&2
  exit 2
fi

declare -A seen_seeds=()
for seed in "${seeds[@]}"; do
  if [[ ! "${seed}" =~ ^[0-9]+$ ]] || (( ${#seed} > 10 )); then
    echo "ERROR: invalid random seed '${seed}'." >&2
    exit 2
  fi
  seed_value=$((10#${seed}))
  if (( seed_value < 1 || seed_value > 4294967295 )); then
    echo "ERROR: random seed must be in [1, 4294967295], got '${seed}'." >&2
    exit 2
  fi
  if [[ -n "${seen_seeds[${seed_value}]:-}" ]]; then
    echo "ERROR: duplicate random seed '${seed_value}'." >&2
    exit 2
  fi
  seen_seeds[${seed_value}]=1
done

for arg in "$@"; do
  case "${arg}" in
    +UVM_TESTNAME=*|+ntb_random_seed=*|+ntb_random_seed_automatic)
      echo "ERROR: use STRESS_SEEDS to select seeds; this launcher selects its UVM test." >&2
      exit 2
      ;;
  esac
done

mkdir -p "${run_dir}/logs"
printf 'seed\tstatus\tlog\n' > "${run_dir}/results.tsv"
echo "Random stress seeds: ${seeds[*]}"
echo "Results: ${run_dir}"

VCS_BUILD_DIR="${build_dir}" COVERAGE="${coverage_enabled}" \
  COV_DIR="${cov_dir}" COMPILE_ONLY=1 REUSE_COMPILED_SIMV=0 \
  URG_ONLY=0 SKIP_URG=1 \
  bash "${launcher}" "+UVM_TESTNAME=${test_name}"

failed=0
for seed in "${seeds[@]}"; do
  seed_value=$((10#${seed}))
  sim_log="${run_dir}/logs/seed_${seed_value}.log"
  echo "Running random stress seed ${seed_value}"
  if VCS_BUILD_DIR="${build_dir}" COVERAGE="${coverage_enabled}" \
     COV_DIR="${cov_dir}" COV_NAME="stress_seed_${seed_value}" \
     SIM_LOG="${sim_log}" COMPILE_ONLY=0 REUSE_COMPILED_SIMV=1 \
     URG_ONLY=0 SKIP_URG=1 \
     bash "${launcher}" "+UVM_TESTNAME=${test_name}" \
       "+ntb_random_seed=${seed_value}" "$@"; then
    printf '%s\tPASS\t%s\n' "${seed_value}" "${sim_log}" >> "${run_dir}/results.tsv"
  else
    status="$?"
    failed=1
    printf '%s\tFAIL(%s)\t%s\n' "${seed_value}" "${status}" "${sim_log}" >> "${run_dir}/results.tsv"
  fi
done

if [[ "${coverage_enabled}" == "1" ]]; then
  if VCS_BUILD_DIR="${build_dir}" COVERAGE=1 COV_DIR="${cov_dir}" \
     REPORT_DIR="${report_dir}" URG_LOG="${urg_log}" \
     URG_ONLY=1 COMPILE_ONLY=0 REUSE_COMPILED_SIMV=0 SKIP_URG=0 \
     bash "${launcher}" "+UVM_TESTNAME=${test_name}"; then
    echo "Coverage report: ${report_dir}"
  else
    failed=1
    echo "ERROR: random stress coverage report failed." >&2
  fi
fi

cat "${run_dir}/results.tsv"
if (( failed != 0 )); then
  echo "RANDOM STRESS FAIL: one or more seeds or reports failed." >&2
  exit 1
fi
echo "RANDOM STRESS PASS: all ${#seeds[@]} seeds passed."
