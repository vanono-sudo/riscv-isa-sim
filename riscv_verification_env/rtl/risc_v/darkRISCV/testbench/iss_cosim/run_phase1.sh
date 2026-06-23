#!/usr/bin/env bash
# Phase 1: xrun DPI smoke test (no RTL).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../../../../.." && pwd)"
TOOLS="${ROOT}/riscv_verification_env/tools"
COSIM_DIR="${SCRIPT_DIR}"

MEM="${ISS_MEM:-${COSIM_DIR}/../iss_phase0/phase0.mem}"
LIB="${COSIM_DIR}/libiss_wrapper.so"

find_xrun() {
  local candidate

  if [[ -n "${XRUN:-}" ]]; then
    if [[ -x "${XRUN}" ]]; then
      echo "${XRUN}"
      return 0
    fi
    echo "error: XRUN=${XRUN} is not executable" >&2
    return 1
  fi

  if candidate="$(command -v xrun 2>/dev/null)" && [[ -x "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  local -a candidates=(
    /tools/cdnc/xcelium/23.09.001/tools.lnx86/inca/bin/64bit/xrun
    /tools/cdnc/xcelium/23.09-s001/tools.lnx86/inca/bin/64bit/xrun
    /tools/cdnc/xcelium/23.09.001/tools/bin/xrun
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  echo "error: xrun not found." >&2
  echo "  Set XRUN to your 64-bit xrun, e.g.:" >&2
  echo "    export XRUN=/tools/cdnc/xcelium/23.09.001/tools.lnx86/inca/bin/64bit/xrun" >&2
  echo "  (tools/bin/xrun is often a 32-bit stub that fails on RHEL8+)" >&2
  return 1
}

if [[ ! -f "${LIB}" ]]; then
  echo "error: ${LIB} not found — run 'make lib' first" >&2
  exit 1
fi

if [[ ! -f "${MEM}" ]]; then
  echo "error: ${MEM} not found — run 'make -C ../iss_phase0 rtl' first" >&2
  exit 1
fi

XRUN_BIN="$(find_xrun)"

export LD_LIBRARY_PATH="${TOOLS}/lib:${LD_LIBRARY_PATH:-}"

cd "${COSIM_DIR}"

echo "--- Phase 1: xrun + DPI + libriscv ---"
echo "XRUN=${XRUN_BIN}"
echo "MEM=${MEM}"
echo "LIB=${LIB}"

"${XRUN_BIN}" -64bit -licqueue -sv \
  "${COSIM_DIR}/iss_dpi.sv" \
  "${COSIM_DIR}/iss_phase1_tb.sv" \
  -sv_lib "${COSIM_DIR}/libiss_wrapper" \
  "+ISS_MEM=${MEM}" \
  -timescale 1ns/1ps \
  -access +r

echo "--- Phase 1 complete ---"
