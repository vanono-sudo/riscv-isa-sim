# Phase 1 — DPI link smoke test

Connects SystemVerilog (xrun) to Spike `libriscv` via DPI. No RTL yet.

## Files

| File | Role |
|------|------|
| `iss_wrapper.cpp` | `libiss_wrapper.so` — BRAM @ 0x0, `iss_init/step/get_reg` |
| `iss_dpi.sv` | `iss_pkg` DPI imports |
| `iss_phase1_tb.sv` | Standalone SV test (loads `phase0.mem`, checks a0/a1) |
| `run_phase1.sh` | xrun launcher |
| `iss_lib_smoke.c` | C fallback test (dlopen same `.so`) |

## Build & run

```bash
cd riscv_verification_env/rtl/risc_v/darkRISCV/testbench/iss_cosim

# Library + C smoke (works without Cadence)
make smoke

# Full DPI via xrun (needs Cadence)
make run
# if needed:
# export XRUN=/tools/cdnc/xcelium/23.09.001/tools.lnx86/inca/bin/64bit/xrun
# make run
```

### Expected PASS

```
iss_lib_smoke: PASS
```

or from xrun:

```
iss_phase1: PASS — DPI link to libriscv OK
```

## xrun command (reference)

```bash
export LD_LIBRARY_PATH=$ROOT/riscv_verification_env/tools/lib:$LD_LIBRARY_PATH
# Use 64-bit xrun (same as your darksimv flow):
xrun -64bit -sv iss_dpi.sv iss_phase1_tb.sv \
  -sv_lib $PWD/libiss_wrapper \
  +ISS_MEM=../iss_phase0/phase0.mem
```

Phase 2 will hook this ISS into `darksimv` retirement compare.

## Phase 2 — RTL lockstep

```bash
make phase2
# or: ISS_MAX_RETIRE=40 make phase2
```

Runs `darksimv` with `iss_lockstep.sv` bound into `darkriscv`. Same `phase0.mem`
loaded into BRAM (`+DARKSOCV_MEM`) and ISS (`+ISS_MEM`). **Use paths relative to
`riscv_verification_env`** (xrun breaks `+FOO=/absolute/...` plusargs).

Expected:

```
iss_lockstep: PASS — 40 retirements, pc=0x...
```
