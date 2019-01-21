#include <stddef.h>
#include <stdint.h>

#define static_assert(cond) switch(0) { case 0: case !!(long)(cond): ; }

extern volatile       uint32_t * const cpu_halt;
extern volatile       uint32_t * const cpu_tohost;
extern volatile       uint32_t * const cpu_fromhost;
extern volatile       uint32_t * const cpu_led;
extern volatile       uint32_t * const cpu_seg7;
extern volatile const uint32_t * const cpu_btn;
extern volatile const uint32_t * const cpu_sw;
extern volatile const uint32_t * const cpu_lfsr;

extern volatile const uint32_t * const cpu_freq;
extern volatile const uint32_t * const cpu_bp_hit;
extern volatile const uint32_t * const cpu_bp_pred;
extern volatile const uint32_t * const cpu_dc_hit;
extern volatile const uint32_t * const cpu_dc_access;

enum  btn_mask {
  btn_mask_down   = 1<<5,
  btn_mask_right  = 1<<4,
  btn_mask_left   = 1<<3,
  btn_mask_up     = 1<<2,
  btn_mask_center = 1<<1
};

void write_tohost(const char* s, size_t len);
int putchar(int ch);
void printhex(uint64_t x);
int printf(const char* fmt, ...);
int sprintf(char* str, const char* fmt, ...);
size_t strnlen(const char *s, size_t n);
uint64_t read_cycle();
void halt();
void print_stat();
uint32_t get_time_ms();

#define read_csr(reg) ({ unsigned long __tmp; \
  __asm__ __volatile__ ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

#define write_csr(reg, val) ({ \
  __asm__ __volatile__ ("csrw " #reg ", %0" :: "rK"(val)); })

#define swap_csr(reg, val) ({ unsigned long __tmp; \
  __asm__ __volatile__ ("csrrw %0, " #reg ", %1" : "=r"(__tmp) : "rK"(val)); \
  __tmp; })

#define set_csr(reg, bit) ({ unsigned long __tmp; \
  __asm__ __volatile__ ("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); \
  __tmp; })

#define clear_csr(reg, bit) ({ unsigned long __tmp; \
  __asm__ __volatile__ ("csrrc %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); \
  __tmp; })
