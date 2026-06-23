// Phase 2: lockstep monitor bound into darkriscv.
// Retires when !RES && !XRES && !HLT && flush==0 (same as __TRACE__).

`timescale 1ns / 1ps

module iss_lockstep_monitor (
  input  wire        clk,
  input  wire        res,
  input  wire        core_xres,
  input  wire        core_hlt,
  input  wire [1:0]  core_flush,
  input  wire [31:0] core_pc,
  input  wire [31:0] core_regs [0:31]
);

  import iss_pkg::*;

  string mem_file;
  int    max_retire;
  int    retire_cnt;
  bit    iss_armed;

  function automatic string trim_leading(input string s);
    int i;
    for (i = 0; i < s.len(); i++)
      if (s[i] != " " && s[i] != "\t")
        break;
    if (i >= s.len())
      return "";
    return s.substr(i, s.len() - i);
  endfunction

  initial begin
    mem_file   = "rtl/risc_v/darkRISCV/testbench/iss_phase0/phase0.mem";
    max_retire = 40;
    void'($value$plusargs("ISS_MEM=%s", mem_file));
    void'($value$plusargs("ISS_MAX_RETIRE=%d", max_retire));
    mem_file   = trim_leading(mem_file);
    if (mem_file.len() == 0)
      mem_file = "rtl/risc_v/darkRISCV/testbench/iss_phase0/phase0.mem";
    iss_armed  = 1'b0;
    retire_cnt = 0;

    // DPI/plusargs may not be ready at time 0 FS; init while still in reset.
    @(posedge clk);
    if (iss_init(mem_file) != 0)
      $fatal(1, "iss_lockstep: iss_init(%s) failed (set ISS_MEM_ABS for C++)", mem_file);
    $display("iss_lockstep: ISS loaded %s", mem_file);
  end

  always @(posedge clk) begin
    int unsigned iss_pc;
    int unsigned rtl_pc;
    int          r;
    int unsigned iss_r;
    int unsigned rtl_r;

    if (res) begin
      void'(iss_reset());
      iss_armed  = 1'b0;
      retire_cnt = 0;
    end else begin
      if (!iss_armed) begin
        void'(iss_reset());
        iss_armed = 1'b1;
        $display("iss_lockstep: armed (RTL reset released), max_retire=%0d", max_retire);
      end

      if (iss_armed && !core_xres && !core_hlt && (core_flush == 2'd0)) begin
        if (iss_step(1) != 0) begin
          $display("iss_lockstep: FAIL iss_step at retire #%0d", retire_cnt);
          $finish(1);
        end

        #1step;

        rtl_pc = core_pc;
        iss_pc = iss_get_pc();
        if (iss_pc !== rtl_pc) begin
          $display("iss_lockstep: FAIL PC mismatch at retire #%0d rtl=0x%08x iss=0x%08x",
                   retire_cnt, rtl_pc, iss_pc);
          $finish(1);
        end

        for (r = 1; r < 32; r++) begin
          iss_r = iss_get_reg(r);
          rtl_r = core_regs[r];
          if (iss_r !== rtl_r) begin
            $display("iss_lockstep: FAIL x%0d mismatch at retire #%0d rtl=0x%08x iss=0x%08x pc=0x%08x",
                     r, retire_cnt, rtl_r, iss_r, rtl_pc);
            $finish(1);
          end
        end

        if (retire_cnt + 1 >= max_retire) begin
          $display("iss_lockstep: PASS — %0d retirements, pc=0x%08x", retire_cnt + 1, rtl_pc);
          iss_shutdown();
          $finish(0);
        end

        retire_cnt <= retire_cnt + 1;
      end
    end
  end

endmodule

bind darkriscv iss_lockstep_monitor u_iss_lockstep (
  .clk        (CLK),
  .res        (RES),
  .core_xres  (XRES),
  .core_hlt   (HLT),
  .core_flush (FLUSH),
  .core_pc    (PC),
  .core_regs  (REGS)
);
