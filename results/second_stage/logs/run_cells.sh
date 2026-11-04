#!/bin/bash
# Run second-stage cells in parallel: one process per (station, arch, pca).
# Usage: bash results/second_stage/logs/run_cells.sh <cells file> <n parallel>
cd "$(dirname "$0")/../../.."
RS="C:/Program Files/R/R-4.5.2/bin/Rscript.exe"
run_one() {
  set -- $1
  "$RS" run_second_stage.R --stage=run --station=$1 --archs=$2 --pca=$3 \
    > "results/second_stage/logs/cell_$1_$2_$3.log" 2>&1
  echo "finished $1 $2 $3 (exit $?)"
}
export -f run_one; export RS
grep -v '^#' "$1" | xargs -P "$2" -I{} bash -c 'run_one "{}"'
