// DPI imports for libriscv ISS wrapper (Phase 1+).

package iss_pkg;

  import "DPI-C" function int iss_version();
  import "DPI-C" function int iss_init(input string mem_file);
  import "DPI-C" function void iss_shutdown();
  import "DPI-C" function int iss_reset();
  import "DPI-C" function int iss_step(input int n);
  import "DPI-C" function int unsigned iss_get_pc();
  import "DPI-C" function int unsigned iss_get_reg(input int regnum);

endpackage
