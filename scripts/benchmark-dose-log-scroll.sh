#!/usr/bin/env bash

set -euo pipefail

# CLI benchmark runner for dose-log scrolling performance.
#
# Usage:
#   ./scripts/benchmark-dose-log-scroll.sh <device_id>
#
# Example:
#   ./scripts/benchmark-dose-log-scroll.sh emulator-5554
#
# Optional env vars:
#   ENFORCE_PERF_BUDGETS=true|false (default: true)
#   P90_BUILD_BUDGET_MS=16
#   P90_RASTER_BUDGET_MS=16
#   JANK_16MS_BUDGET_PCT=20
#   PERF_SABOTAGE=true|false (default: false)
#   PERF_SABOTAGE_LEVEL=2 (higher = intentionally worse)

DEVICE_ID="${1:-}"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "Usage: $0 <device_id>"
  echo "Tip: run 'flutter devices' to list available device IDs."
  exit 1
fi

ENFORCE_PERF_BUDGETS="${ENFORCE_PERF_BUDGETS:-true}"
P90_BUILD_BUDGET_MS="${P90_BUILD_BUDGET_MS:-16}"
P90_RASTER_BUDGET_MS="${P90_RASTER_BUDGET_MS:-16}"
JANK_16MS_BUDGET_PCT="${JANK_16MS_BUDGET_PCT:-20}"
PERF_SABOTAGE="${PERF_SABOTAGE:-false}"
PERF_SABOTAGE_LEVEL="${PERF_SABOTAGE_LEVEL:-2}"

echo "Running dose-log scroll benchmark on device: ${DEVICE_ID}"
echo "Budgets: enforce=${ENFORCE_PERF_BUDGETS}, p90_build<=${P90_BUILD_BUDGET_MS}ms, p90_raster<=${P90_RASTER_BUDGET_MS}ms, jank16<=${JANK_16MS_BUDGET_PCT}%"
echo "Sabotage: enabled=${PERF_SABOTAGE}, level=${PERF_SABOTAGE_LEVEL}"

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/perf/dose_log_scroll_perf_test.dart \
  --profile \
  -d "${DEVICE_ID}" \
  --dart-define=ENFORCE_PERF_BUDGETS="${ENFORCE_PERF_BUDGETS}" \
  --dart-define=P90_BUILD_BUDGET_MS="${P90_BUILD_BUDGET_MS}" \
  --dart-define=P90_RASTER_BUDGET_MS="${P90_RASTER_BUDGET_MS}" \
  --dart-define=JANK_16MS_BUDGET_PCT="${JANK_16MS_BUDGET_PCT}" \
  --dart-define=PERF_SABOTAGE="${PERF_SABOTAGE}" \
  --dart-define=PERF_SABOTAGE_LEVEL="${PERF_SABOTAGE_LEVEL}"
