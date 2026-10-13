#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${IRQ_MODEL_BUILD_DIR:-${project_root}/build/irq_model}"
vcs_bin="${VCS:-vcs}"
seed_list="${IRQ_MODEL_SEEDS:-17 81 2026}"
mkdir -p "${build_dir}"
cd "${project_root}/sim"

"${vcs_bin}" -full64 -sverilog -f run_irq_model.f \
  -top tb_dma_irq_model -debug_access+all \
  -Mdir="${build_dir}/csrc" -o "${build_dir}/simv" \
  -l "${build_dir}/compile.log"

for seed in ${seed_list}; do
  log="${build_dir}/seed_${seed}.log"
  "${build_dir}/simv" -no_save +ntb_random_seed="${seed}" +SEED="${seed}" >"${log}" 2>&1
  if ! grep -Fq '[IRQ_MODEL_PASS]' "${log}" ||
     grep -Eiq '^[[:space:]]*(error|fatal)(:|-\[)' "${log}"; then
    echo "FAIL: IRQ model seed ${seed}; see ${log}" >&2
    exit 1
  fi
  echo "PASS: IRQ model seed ${seed}"
done

for mutation in drop_done drop_enable fault_code read_data write_response; do
  case "${mutation}" in
    drop_done) expected_mask=1 ;;
    drop_enable) expected_mask=4 ;;
    fault_code) expected_mask=16 ;;
    read_data) expected_mask=32768 ;;
    write_response) expected_mask=8192 ;;
  esac
  log="${build_dir}/mutation_${mutation}.log"
  set +e
  "${build_dir}/simv" -no_save +ntb_random_seed=17 +SEED=17 \
    +MUTATION="${mutation}" >"${log}" 2>&1
  status=$?
  set -e
  if ! grep -Eiq '^[[:space:]]*fatal(:|-\[)' "${log}" ||
     ! grep -Fq '[IRQ_MODEL_MISMATCH]' "${log}" ||
     grep -Eq '\[(IRQ_MUTATION_MISSED|IRQ_MODEL_PASS|IRQ_TEST_TIMEOUT|IRQ_TEST_CONFIG|IRQ_TEST_EXPECT|IRQ_RULE_FAILURE)\]' "${log}"; then
    echo "FAIL: mutation ${mutation} did not produce the expected checker fatal (status ${status}); see ${log}" >&2
    exit 1
  fi
  mismatch_line="$(grep -m1 -F '[IRQ_MODEL_MISMATCH]' "${log}")"
  if [[ ! "${mismatch_line}" =~ mask=0x([[:xdigit:]]+) ]]; then
    echo "FAIL: mutation ${mutation} has no mismatch mask; see ${log}" >&2
    exit 1
  fi
  observed_mask=$((16#${BASH_REMATCH[1]}))
  if (( (observed_mask & expected_mask) == 0 )); then
    echo "FAIL: mutation ${mutation} has the wrong mismatch mask; see ${log}" >&2
    exit 1
  fi
  echo "PASS: checker detected ${mutation}"
done

echo "PASS: IRQ model regression and all five mutations"
