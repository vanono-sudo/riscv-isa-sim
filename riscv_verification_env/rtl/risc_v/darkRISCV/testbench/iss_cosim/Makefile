# Phase 1: build DPI shared library and run xrun smoke test.

ROOT      ?= ../../../../../..
TOOLS     ?= $(ROOT)/riscv_verification_env/tools
COSIM_DIR ?= $(abspath .)
PHASE0    ?= $(COSIM_DIR)/../iss_phase0
ISS_MEM   ?= $(PHASE0)/phase0.mem

CXX       ?= g++
XRUN      ?= xrun

CXXFLAGS  := -std=c++17 -fPIC -O2 -Wall -I$(TOOLS)/include
LDFLAGS   := -shared -L$(TOOLS)/lib -Wl,-rpath,$(TOOLS)/lib
LIBS      := -lriscv -lfesvr -ldl -lpthread

LIB       := libiss_wrapper.so
LIB_ABS   := $(COSIM_DIR)/$(LIB)
SV_SRCS   := iss_dpi.sv iss_phase1_tb.sv

.PHONY: all phase0_mem lib run smoke phase2 clean

all: smoke

phase0_mem:
	$(MAKE) -C $(PHASE0) rtl

$(LIB): iss_wrapper.cpp Makefile
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS) $(LIBS)

lib: $(LIB)

smoke: phase0_mem $(LIB)
	$(CXX) -O2 iss_lib_smoke.c -o iss_lib_smoke -ldl
	LD_LIBRARY_PATH=$(TOOLS)/lib:$$LD_LIBRARY_PATH ./iss_lib_smoke $(LIB_ABS) $(ISS_MEM)

run: phase0_mem $(LIB)
	ISS_MEM=$(ISS_MEM) ./run_phase1.sh

phase2: phase0_mem $(LIB)
	chmod +x run_phase2.sh
	ISS_MEM=$(ISS_MEM) ./run_phase2.sh

clean:
	rm -f $(LIB) iss_lib_smoke
	rm -rf xrun.log xcelium.d
	$(MAKE) -C $(PHASE0) clean
