#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")"
vcs -full64 -sverilog -debug_access+all -kdb -f run.f -top tb_axi_dma_multi_desc_smoke -o simv
./simv
verdi -dbdir simv.daidir -ssf axi_dma_multi_desc_smoke.fsdb
