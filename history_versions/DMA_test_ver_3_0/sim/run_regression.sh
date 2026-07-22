#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")"

STAMP=$(date +%Y%m%d_%H%M%S)
COV_DIR=${COV_DIR:-regression_${STAMP}.vdb}
REPORT_DIR=${REPORT_DIR:-urgReport_${STAMP}}
BASE_SEED=${BASE_SEED:-1000}

TESTS=(
    dma_random_smoke_test
    dma_ral_smoke_test
    dma_wstrb_test
    dma_boundary_matrix_test
    dma_irq_mode_test
    dma_invalid_desc_test
    dma_length_sweep_test
)

mkdir -p regression_logs

vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -f run_uvm.f -top tb_uvm_top \
    -debug_access+all -kdb \
    -cm_hier cm_hier.cfg \
    -cm line+cond+tgl+fsm+branch -cm_dir "$COV_DIR" \
    -o simv

index=0
for test_name in "${TESTS[@]}"; do
    seed=$((BASE_SEED + index))
    ./simv \
        +UVM_TESTNAME="$test_name" \
        +ntb_random_seed="$seed" \
        -cm line+cond+tgl+fsm+branch \
        -cm_dir "$COV_DIR" \
        -cm_name "$test_name" \
        | tee "regression_logs/${test_name}.log"
    index=$((index + 1))
done

urg -dir "$COV_DIR" -report "$REPORT_DIR"

echo "Coverage database: $COV_DIR"
echo "URG report:        $REPORT_DIR"
