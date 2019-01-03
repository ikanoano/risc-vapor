#include <stddef.h>
#include <stdint.h>

void write_tohost(const char* s, size_t len);
int putchar(int ch);
void printhex(uint64_t x);
int printf(const char* fmt, ...);
int sprintf(char* str, const char* fmt, ...);
size_t strnlen(const char *s, size_t n);

