// Phase 1: DPI wrapper around libriscv for DarkRISCV BRAM @ 0x0.
// Exported as libiss_wrapper.so for xrun -sv_lib iss_wrapper.

#include "riscv/cfg.h"
#include "riscv/devices.h"
#include "riscv/mmu.h"
#include "riscv/processor.h"
#include "riscv/simif.h"

#include <cstdio>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <unordered_map>

static const reg_t BRAM_BASE = 0x00000000;
static const reg_t BRAM_SIZE = 0x00002000;
static const reg_t IO_BASE   = 0x40000000;
static const reg_t APB_BASE  = 0xC0000000;

class io_stub_t : public abstract_device_t {
 public:
  bool load(reg_t addr, size_t len, uint8_t* bytes) override {
    if (addr + len > size())
      return false;
    std::memset(bytes, 0, len);
    for (size_t i = 0; i < len; i++) {
      if (addr + i < sizeof(regs))
        bytes[i] = regs[addr + i];
    }
    if (addr <= 0x04 && addr + len > 0x04)
      bytes[0x04 - addr] = 0;
    return true;
  }

  bool store(reg_t addr, size_t len, const uint8_t* bytes) override {
    if (addr + len > size())
      return false;
    for (size_t i = 0; i < len; i++) {
      reg_t off = addr + i;
      if (off == 0x05) {
        char c = static_cast<char>(bytes[i]);
        if (c)
          std::fwrite(&c, 1, 1, stdout);
      } else if (off < sizeof(regs)) {
        regs[off] = bytes[i];
      }
    }
    return true;
  }

  reg_t size() override { return 0x1000; }

 private:
  uint8_t regs[0x20] = {};
};

class apb_stub_t : public abstract_device_t {
 public:
  bool load(reg_t addr, size_t len, uint8_t* bytes) override {
    if (addr + len > size())
      return false;
    std::memset(bytes, 0, len);
    for (size_t i = 0; i < len; i++) {
      reg_t off = addr + i;
      if (off < sizeof(regs))
        bytes[i] = regs[off];
    }
    return true;
  }

  bool store(reg_t addr, size_t len, const uint8_t* bytes) override {
    if (addr + len > size())
      return false;
    for (size_t i = 0; i < len; i++) {
      reg_t off = addr + i;
      if (off < sizeof(regs))
        regs[off] = bytes[i];
    }
    return true;
  }

  reg_t size() override { return 0x1000; }

 private:
  uint8_t regs[0x1000] = {};
};

class dark_simif_t : public simif_t {
 public:
  dark_simif_t()
    : bram(BRAM_SIZE), io_stub(), apb_stub() {
    debug_mmu = nullptr;
    bus.add_device(BRAM_BASE, &bram);
    bus.add_device(IO_BASE, &io_stub);
    bus.add_device(APB_BASE, &apb_stub);
    cfg.isa = "rv32i_zicsr";
    cfg.priv = "m";
    cfg.mem_layout = {mem_cfg_t(BRAM_BASE, BRAM_SIZE)};
    cfg.start_pc.set_global(BRAM_BASE);
  }

  char* addr_to_mem(reg_t paddr) override {
    auto page_offset = paddr % PGSIZE;
    auto page_addr = paddr - page_offset;

    if (auto it = addr_to_mem_cache.find(page_addr); it != addr_to_mem_cache.end())
      return it->second + page_offset;

    auto desc = bus.find_device(page_addr, PGSIZE);
    if (auto mem = dynamic_cast<abstract_mem_t*>(desc.second)) {
      auto res = mem->contents(page_addr - desc.first);
      addr_to_mem_cache.insert({page_addr, res});
      return res + page_offset;
    }
    return nullptr;
  }

  bool mmio_load(reg_t paddr, size_t len, uint8_t* bytes) override {
    if (paddr + len < paddr)
      return false;
    return bus.load(paddr, len, bytes);
  }

  bool mmio_store(reg_t paddr, size_t len, const uint8_t* bytes) override {
    if (paddr + len < paddr)
      return false;
    return bus.store(paddr, len, bytes);
  }

  void proc_reset(unsigned) override {}

  const cfg_t& get_cfg() const override { return cfg; }

  const std::map<size_t, processor_t*>& get_harts() const override { return harts; }

  const char* get_symbol(uint64_t) override { return nullptr; }

  mem_t bram;
  io_stub_t io_stub;
  apb_stub_t apb_stub;
  bus_t bus;
  cfg_t cfg;
  std::map<size_t, processor_t*> harts;

 private:
  std::unordered_map<reg_t, char*> addr_to_mem_cache;
};

static std::unique_ptr<dark_simif_t> g_sim;
static std::unique_ptr<processor_t> g_proc;

static bool load_mem_file(mem_t* mem, const char* path) {
  FILE* f = std::fopen(path, "r");
  if (!f) {
    std::fprintf(stderr, "iss_init: fopen(%s) failed\n", path ? path : "(null)");
    return false;
  }

  reg_t addr = 0;
  char line[256];
  while (std::fgets(line, sizeof line, f)) {
    unsigned word = 0;
    if (std::sscanf(line, "%8x", &word) != 1)
      continue;
    uint8_t bytes[4] = {
      static_cast<uint8_t>(word & 0xff),
      static_cast<uint8_t>((word >> 8) & 0xff),
      static_cast<uint8_t>((word >> 16) & 0xff),
      static_cast<uint8_t>((word >> 24) & 0xff),
    };
    if (!mem->store(addr, 4, bytes)) {
      std::fclose(f);
      return false;
    }
    addr += 4;
  }

  std::fclose(f);
  return addr > 0;
}

static void iss_teardown() {
  g_proc.reset();
  g_sim.reset();
}

extern "C" {

int iss_version() { return 1; }

int iss_init(const char* mem_file) {
  iss_teardown();

  const char* path = mem_file;
  const char* env_path = std::getenv("ISS_MEM_ABS");
  if (env_path && env_path[0])
    path = env_path;

  if (!path || !path[0])
    return -1;

  g_sim = std::make_unique<dark_simif_t>();
  if (!load_mem_file(&g_sim->bram, path))
    return -2;

  g_proc = std::make_unique<processor_t>(
      g_sim->cfg.isa, g_sim->cfg.priv, &g_sim->cfg, g_sim.get(),
      0, false, nullptr, std::cerr);
  g_sim->harts[0] = g_proc.get();
  g_proc->get_state()->pc = BRAM_BASE;

  return 0;
}

void iss_shutdown() { iss_teardown(); }

int iss_reset() {
  if (!g_proc)
    return -1;
  g_proc->reset();
  g_proc->get_state()->pc = BRAM_BASE;
  return 0;
}

int iss_step(int n) {
  if (!g_proc || n < 0)
    return -1;
  if (n == 0)
    return 0;
  g_proc->step(static_cast<size_t>(n));
  return 0;
}

unsigned int iss_get_pc() {
  if (!g_proc)
    return 0;
  return static_cast<unsigned int>(g_proc->get_state()->pc);
}

unsigned int iss_get_reg(int regnum) {
  if (!g_proc || regnum < 0 || regnum > 31)
    return 0;
  return static_cast<unsigned int>(g_proc->get_state()->XPR[regnum]);
}

}  // extern "C"
