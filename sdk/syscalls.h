#include <stddef.h>
#include <stdint.h>

#define static_assert(cond) switch(0) { case 0: case !!(long)(cond): ; }

extern __volatile__ uint32_t * const cpu_halt;
extern __volatile__ uint32_t * const cpu_tohost;
extern __volatile__ uint32_t * const cpu_fromhost;
extern __volatile__ uint32_t * const cpu_led;
extern __volatile__ uint32_t * const cpu_seg7;
extern __volatile__ uint32_t * const cpu_btn;
extern __volatile__ uint32_t * const cpu_sw;
extern __volatile__ uint32_t * const cpu_lfsr;
extern __volatile__ uint32_t * const cpu_freq;

void write_tohost(const char* s, size_t len);
int putchar(int ch);
void printhex(uint64_t x);
int printf(const char* fmt, ...);
int sprintf(char* str, const char* fmt, ...);
size_t strnlen(const char *s, size_t n);
uint64_t read_cycle();

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
