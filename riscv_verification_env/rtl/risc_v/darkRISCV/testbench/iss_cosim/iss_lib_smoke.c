// Fallback Phase 1 smoke test when xrun is unavailable.
// Loads libiss_wrapper.so and exercises the same DPI entry points.

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

typedef int (*iss_version_fn)(void);
typedef int (*iss_init_fn)(const char*);
typedef void (*iss_shutdown_fn)(void);
typedef int (*iss_step_fn)(int);
typedef unsigned int (*iss_get_pc_fn)(void);
typedef unsigned int (*iss_get_reg_fn)(int);

int main(int argc, char** argv) {
  const char* lib = argc > 1 ? argv[1] : "./libiss_wrapper.so";
  const char* mem = argc > 2 ? argv[2] : "../iss_phase0/phase0.mem";

  void* handle = dlopen(lib, RTLD_NOW);
  if (!handle) {
    fprintf(stderr, "dlopen(%s): %s\n", lib, dlerror());
    return 1;
  }

  auto iss_version = (iss_version_fn)dlsym(handle, "iss_version");
  auto iss_init = (iss_init_fn)dlsym(handle, "iss_init");
  auto iss_shutdown = (iss_shutdown_fn)dlsym(handle, "iss_shutdown");
  auto iss_step = (iss_step_fn)dlsym(handle, "iss_step");
  auto iss_get_pc = (iss_get_pc_fn)dlsym(handle, "iss_get_pc");
  auto iss_get_reg = (iss_get_reg_fn)dlsym(handle, "iss_get_reg");

  if (!iss_version || !iss_init || !iss_shutdown || !iss_step || !iss_get_pc || !iss_get_reg) {
    fprintf(stderr, "dlsym failed: %s\n", dlerror());
    dlclose(handle);
    return 1;
  }

  printf("iss_lib_smoke: version=%d\n", iss_version());

  if (iss_init(mem) != 0) {
    fprintf(stderr, "iss_init(%s) failed\n", mem);
    dlclose(handle);
    return 1;
  }

  if (iss_get_pc() != 0) {
    fprintf(stderr, "reset PC mismatch\n");
    iss_shutdown();
    dlclose(handle);
    return 1;
  }

  iss_step(8);

  unsigned a0 = iss_get_reg(10);
  unsigned a1 = iss_get_reg(11);
  printf("iss_lib_smoke: a0=%u a1=%u pc=0x%x\n", a0, a1, iss_get_pc());

  iss_shutdown();
  dlclose(handle);

  if (a0 != 30 || a1 != 60) {
    fprintf(stderr, "iss_lib_smoke: FAIL\n");
    return 1;
  }

  printf("iss_lib_smoke: PASS\n");
  return 0;
}
