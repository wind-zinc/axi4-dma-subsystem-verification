#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")"

TEST=${TEST:-dma_sva_activation_test}
SEED=${SEED:-automatic}
STAMP=$(date +%Y%m%d_%H%M%S)
COV_DIR=${COV_DIR:-sva_${STAMP}.vdb}
REPORT_DIR=${REPORT_DIR:-urgReport_sva_${STAMP}}

if [[ "$SEED" == "automatic" ]]; then
    SEED_OPTION=+ntb_random_seed_automatic
else
    SEED_OPTION=+ntb_random_seed="$SEED"
fi

vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -f run_uvm.f -top tb_uvm_top \
    -debug_access+all -kdb \
    -cm_hier cm_hier_final.cfg \
    -cm_assert_hier cm_assert_hier.cfg \
    -cm line+cond+tgl+fsm+branch+assert -cm_noconst -cm_dir "$COV_DIR" \
    -o simv

./simv \
    +UVM_TESTNAME="$TEST" \
    "$SEED_OPTION" \
    -cm line+cond+tgl+fsm+branch+assert -cm_dir "$COV_DIR" \
    | tee "${TEST}.log"

COND_EL=${COND_EL:-exclusions/final_cond.el}
if [[ -s "$COND_EL" ]]; then
    urg -dir "$COV_DIR" -elfile "$COND_EL" -excl_strict -report "$REPORT_DIR"
else
    urg -dir "$COV_DIR" -report "$REPORT_DIR"
    echo "COND exclusions not loaded: $COND_EL is absent"
fi

echo "Coverage database: $COV_DIR"
echo "URG report:        $REPORT_DIR"
