#!/usr/bin/env bash

set -euo pipefail

# Run the dose-log scroll benchmark multiple times and persist results.
#
# Usage:
#   ./scripts/benchmark-dose-log-scroll-10x.sh <device_id> [runs]
#
# Examples:
#   ./scripts/benchmark-dose-log-scroll-10x.sh emulator-5554
#   ./scripts/benchmark-dose-log-scroll-10x.sh emulator-5554 20
#
# Output:
#   benchmark-results/dose-log-scroll/<timestamp>/
#     - run-01.log ... run-N.log   (full raw output per run)
#     - all-runs.log               (combined output)
#     - perf_results.ndjson        (one PERF_RESULT JSON per line)
#     - summary.csv                (parsed key metrics per run)

DEVICE_ID="${1:-}"
RUNS="${2:-10}"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "Usage: $0 <device_id> [runs]"
  echo "Tip: run 'flutter devices' to list available device IDs."
  exit 1
fi

if ! [[ "${RUNS}" =~ ^[0-9]+$ ]] || [[ "${RUNS}" -lt 1 ]]; then
  echo "Invalid run count: '${RUNS}'. Expected a positive integer."
  exit 1
fi

# For multi-run profiling, default to metrics collection mode (no threshold fail)
# unless explicitly overridden by the caller.
ENFORCE_PERF_BUDGETS="${ENFORCE_PERF_BUDGETS:-false}"
PERF_SABOTAGE="${PERF_SABOTAGE:-false}"
PERF_SABOTAGE_LEVEL="${PERF_SABOTAGE_LEVEL:-2}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="benchmark-results/dose-log-scroll/${TIMESTAMP}"
mkdir -p "${OUT_DIR}"

ALL_RUNS_LOG="${OUT_DIR}/all-runs.log"
NDJSON_FILE="${OUT_DIR}/perf_results.ndjson"
SUMMARY_CSV="${OUT_DIR}/summary.csv"

printf "run,frames,p90_build_ms,p90_raster_ms,worst_raster_ms,jank_over_16_pct,jank_over_32_pct\n" > "${SUMMARY_CSV}"

extract_metric() {
  local line="$1"
  local key="$2"
  echo "${line}" | sed -nE "s/.*\"${key}\":([0-9.]+).*/\\1/p"
}

echo "Running ${RUNS} benchmark iterations on device: ${DEVICE_ID}"
echo "ENFORCE_PERF_BUDGETS=${ENFORCE_PERF_BUDGETS}"
echo "PERF_SABOTAGE=${PERF_SABOTAGE} (level=${PERF_SABOTAGE_LEVEL})"
echo "Results directory: ${OUT_DIR}"
echo

for run in $(seq 1 "${RUNS}"); do
  RUN_LABEL="$(printf "%02d" "${run}")"
  RUN_LOG="${OUT_DIR}/run-${RUN_LABEL}.log"

  echo "=== Run ${run}/${RUNS} ===" | tee -a "${ALL_RUNS_LOG}"

  # Capture each run's full output so failed runs are still inspectable.
  ENFORCE_PERF_BUDGETS="${ENFORCE_PERF_BUDGETS}" \
    PERF_SABOTAGE="${PERF_SABOTAGE}" \
    PERF_SABOTAGE_LEVEL="${PERF_SABOTAGE_LEVEL}" \
    ./scripts/benchmark-dose-log-scroll.sh "${DEVICE_ID}" \
    2>&1 | tee "${RUN_LOG}" | tee -a "${ALL_RUNS_LOG}"

  PERF_LINE="$(rg --no-line-number --fixed-strings "PERF_RESULT:" "${RUN_LOG}" | tail -n 1 || true)"
  if [[ -z "${PERF_LINE}" ]]; then
    echo "Run ${run}: PERF_RESULT line not found in ${RUN_LOG}" | tee -a "${ALL_RUNS_LOG}"
    continue
  fi

  # Keep one JSON result per line for easy post-processing.
  echo "${PERF_LINE#PERF_RESULT:}" >> "${NDJSON_FILE}"

  frames="$(extract_metric "${PERF_LINE}" "frames")"
  p90_build="$(extract_metric "${PERF_LINE}" "p90BuildMs")"
  p90_raster="$(extract_metric "${PERF_LINE}" "p90RasterMs")"
  worst_raster="$(extract_metric "${PERF_LINE}" "worstRasterMs")"
  jank_16="$(extract_metric "${PERF_LINE}" "jankOver16msPct")"
  jank_32="$(extract_metric "${PERF_LINE}" "jankOver32msPct")"

  printf "%s,%s,%s,%s,%s,%s,%s\n" \
    "${run}" \
    "${frames:-}" \
    "${p90_build:-}" \
    "${p90_raster:-}" \
    "${worst_raster:-}" \
    "${jank_16:-}" \
    "${jank_32:-}" >> "${SUMMARY_CSV}"

  echo "Run ${run} parsed: p90_build=${p90_build}ms p90_raster=${p90_raster}ms jank16=${jank_16}%" | tee -a "${ALL_RUNS_LOG}"
  echo | tee -a "${ALL_RUNS_LOG}"
done

VALID_ROWS="$(awk 'NR>1 && $1 != "" {count++} END {print count+0}' "${SUMMARY_CSV}")"

if [[ "${VALID_ROWS}" -gt 0 ]]; then
  avg_p90_build="$(awk -F, 'NR>1 && $3 != "" {sum+=$3; n++} END {if(n>0) printf "%.3f", sum/n; else printf "n/a"}' "${SUMMARY_CSV}")"
  avg_p90_raster="$(awk -F, 'NR>1 && $4 != "" {sum+=$4; n++} END {if(n>0) printf "%.3f", sum/n; else printf "n/a"}' "${SUMMARY_CSV}")"
  max_jank_16="$(awk -F, 'NR>1 && $6 != "" {if($6>max) max=$6} END {if(NR>1) printf "%.3f", max; else printf "n/a"}' "${SUMMARY_CSV}")"

  echo "Completed ${VALID_ROWS}/${RUNS} runs with parsed metrics."
  echo "Average p90 build: ${avg_p90_build} ms"
  echo "Average p90 raster: ${avg_p90_raster} ms"
  echo "Worst jank>16ms: ${max_jank_16} %"
else
  echo "No parsed PERF_RESULT rows found. Check logs in ${OUT_DIR}."
fi

echo
echo "Saved files:"
echo "- ${ALL_RUNS_LOG}"
echo "- ${NDJSON_FILE}"
echo "- ${SUMMARY_CSV}"
