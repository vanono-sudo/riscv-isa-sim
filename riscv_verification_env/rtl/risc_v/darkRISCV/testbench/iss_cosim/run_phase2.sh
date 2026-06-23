#!/usr/bin/env bash
# Phase 2: RTL + ISS lockstep on phase0.mem
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../../../../.." && pwd)"
ENV="${ROOT}/riscv_verification_env"
RTL="${ENV}/rtl/risc_v/darkRISCV"
TOOLS="${ENV}/tools"
COSIM="${SCRIPT_DIR}"

find_xrun() {
  local candidate
  if [[ -n "${XRUN:-}" && -x "${XRUN}" ]]; then echo "${XRUN}"; return 0; fi
  if candidate="$(command -v xrun 2>/dev/null)" && [[ -x "${candidate}" ]]; then echo "${candidate}"; return 0; fi
  for candidate in \
    /tools/cdnc/xcelium/23.09.001/tools.lnx86/inca/bin/64bit/xrun \
    /tools/cdnc/xcelium/23.09.001/tools/bin/64bit/xrun \
    /tools/cdnc/xcelium/23.09.001/tools/bin/xrun; do
    if [[ -x "${candidate}" ]]; then echo "${candidate}"; return 0; fi
  done
  echo "error: xrun not found — set XRUN" >&2
  return 1
}

MEM_ABS="${ISS_MEM:-${ENV}/rtl/risc_v/darkRISCV/testbench/iss_phase0/phase0.mem}"
# xrun plusargs: absolute paths like +FOO=/project/... break (/project parsed as flag).
MEM_REL="${MEM_REL:-rtl/risc_v/darkRISCV/testbench/iss_phase0/phase0.mem}"
MAX="${ISS_MAX_RETIRE:-40}"
LIB="${COSIM}/libiss_wrapper.so"
XRUN_BIN="$(find_xrun)"

if [[ ! -f "${LIB}" ]]; then
  echo "error: ${LIB} missing — run 'make lib' in iss_cosim" >&2
  exit 1
fi
if [[ ! -f "${MEM_ABS}" ]]; then
  echo "error: ${MEM_ABS} missing — run 'make -C iss_phase0 rtl'" >&2
  exit 1
fi
if [[ ! -f "${ENV}/${MEM_REL}" ]]; then
  echo "error: ${ENV}/${MEM_REL} missing (MEM_REL)" >&2
  exit 1
fi

export LD_LIBRARY_PATH="${TOOLS}/lib:${LD_LIBRARY_PATH:-}"
export ISS_MEM_ABS="${ENV}/${MEM_REL}"

cd "${ENV}"

echo "--- Phase 2: RTL lockstep vs ISS ---"
echo "XRUN=${XRUN_BIN}"
echo "MEM=${MEM_REL} (from ${ENV})"
echo "ISS_MEM_ABS=${ISS_MEM_ABS}"
echo "ISS_MAX_RETIRE=${MAX}"

"${XRUN_BIN}" -64bit -licqueue -sv \
  +define+SIMULATION \
  +incdir+"${RTL}/rtl_v" \
  "${RTL}/testbench/darksimv.v" \
  "${COSIM}/iss_dpi.sv" \
  "${COSIM}/iss_lockstep.sv" \
  "${RTL}"/rtl_v/*.v \
  "${RTL}/rtl_v/lib/spi/spi_master.v" \
  +DARKSOCV_MEM="${MEM_REL}" \
  +ISS_MEM="${MEM_REL}" \
  +ISS_MAX_RETIRE="${MAX}" \
  -sv_lib "${COSIM}/libiss_wrapper" \
  -timescale 1ns/1ps \
  -access +r

echo "--- Phase 2 complete ---"
