// Phase 1 smoke test: xrun + DPI + libriscv, no RTL.
//
// Loads phase0.mem, steps the ISS, checks ALU results match phase0.S.

`timescale 1ns / 1ps

import iss_pkg::*;

module iss_phase1_tb;

  string mem_file;
  int    rc;
  int unsigned pc;
  int unsigned a0;
  int unsigned a1;

  initial begin
    mem_file = "../iss_phase0/phase0.mem";
    if (!$value$plusargs("ISS_MEM=%s", mem_file)) begin
      // default above
    end

    $display("iss_phase1: DPI smoke test");
    $display("iss_phase1: iss_version() = %0d", iss_version());

    rc = iss_init(mem_file);
    if (rc != 0) begin
      $display("iss_phase1: FAIL iss_init(%s) rc=%0d", mem_file, rc);
      $finish(1);
    end
    $display("iss_phase1: loaded %s", mem_file);

    pc = iss_get_pc();
    if (pc !== 32'h0) begin
      $display("iss_phase1: FAIL reset PC=0x%08x (expected 0)", pc);
      iss_shutdown();
      $finish(1);
    end

    // phase0.S: add a0<=30, slli a1<=60 (8 insns to complete slli)
    rc = iss_step(8);
    if (rc != 0) begin
      $display("iss_phase1: FAIL iss_step rc=%0d", rc);
      iss_shutdown();
      $finish(1);
    end

    a0 = iss_get_reg(10);
    a1 = iss_get_reg(11);
    pc = iss_get_pc();

    $display("iss_phase1: after 8 steps pc=0x%08x a0=%0d a1=%0d", pc, a0, a1);

    if (a0 !== 32'd30 || a1 !== 32'd60) begin
      $display("iss_phase1: FAIL register mismatch (expected a0=30 a1=60)");
      iss_shutdown();
      $finish(1);
    end

    iss_shutdown();
    $display("iss_phase1: PASS — DPI link to libriscv OK");
    $finish(0);
  end

endmodule
