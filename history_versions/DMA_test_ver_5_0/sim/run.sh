#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")"

TEST=${TEST:-dma_ral_smoke_test}
SEED=${SEED:-automatic}

if [[ "$SEED" == "automatic" ]]; then
    SEED_OPTION=+ntb_random_seed_automatic
else
    SEED_OPTION=+ntb_random_seed="$SEED"
fi

vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -f run_uvm.f -top tb_uvm_top \
    -debug_access+all -kdb \
    -cm_hier cm_hier.cfg \
    -cm line+cond+tgl+fsm+branch+assert -cm_dir simv.vdb \
    -o simv

./simv \
    +UVM_TESTNAME="$TEST" \
    "$SEED_OPTION" \
    -cm line+cond+tgl+fsm+branch+assert -cm_dir simv.vdb

urg -dir simv.vdb -report urgReport
