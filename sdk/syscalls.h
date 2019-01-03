#include <stddef.h>
#include <stdint.h>

void write_tohost(const char* s, size_t len);
int putchar(int ch);
void printhex(uint64_t x);
int printf(const char* fmt, ...);
int sprintf(char* str, const char* fmt, ...);
void* memcpy(void* dest, const void* src, size_t len);
void* memmove(void* dest, const void* src, size_t len);
void* memset(void* dest, int byte, size_t len);
int memcmp(const void* p1, const void* p2, size_t len);
size_t strlen(const char *s);
size_t strnlen(const char *s, size_t n);
int strcmp(const char* s1, const char* s2);
char* strcpy(char* dest, const char* src);
long atol(const char* str);
