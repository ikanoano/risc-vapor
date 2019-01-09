#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include "syscalls.h"

#undef strcmp

volatile       uint32_t * const cpu_halt        = (volatile       uint32_t * const)0xf0000000;
volatile       uint32_t * const cpu_tohost      = (volatile       uint32_t * const)0xf0000100;
volatile       uint32_t * const cpu_fromhost    = (volatile       uint32_t * const)0xf0000200;
volatile       uint32_t * const cpu_led         = (volatile       uint32_t * const)0xf0000300;
volatile       uint32_t * const cpu_seg7        = (volatile       uint32_t * const)0xf0000400;
volatile const uint32_t * const cpu_btn         = (volatile const uint32_t * const)0xf0000500;
volatile const uint32_t * const cpu_sw          = (volatile const uint32_t * const)0xf0000600;
volatile const uint32_t * const cpu_lfsr        = (volatile const uint32_t * const)0xf0000700;

volatile const uint32_t * const cpu_freq        = (volatile const uint32_t * const)0xf0002000;
volatile const uint32_t * const cpu_bp_hit      = (volatile const uint32_t * const)0xf0002100;
volatile const uint32_t * const cpu_bp_pred     = (volatile const uint32_t * const)0xf0002200;
volatile const uint32_t * const cpu_dc_hit      = (volatile const uint32_t * const)0xf0002300;
volatile const uint32_t * const cpu_dc_access   = (volatile const uint32_t * const)0xf0002400;

void write_tohost(const char* s, size_t len)
{
  for(size_t i=0; i<len; i++) {
    while(!*cpu_tohost);
    *cpu_tohost = *s++;
  }
}

void printstr(const char* s)
{
  write_tohost(s, strlen(s));
}

int __attribute__((weak)) main()
{
  // single-threaded programs override this function.
  printstr("Implement main(), foo!\n");
  return -1;
}

static void init_bss()
{
  extern char __bss_start, __bss_end;
  size_t bss_size = &__bss_end - &__bss_start;
  memset(&__bss_start, 0, bss_size);
}

int _init()
{
  init_bss();

  // only single-threaded programs should ever get here.
  int ret = main();

  return ret;
}

#undef putchar
int putchar(int ch)
{
  static char buf[64] __attribute__((aligned(64)));
  static int buflen = 0;

  buf[buflen++] = ch;

  if (ch == '\n' || buflen == sizeof(buf))
  {
    write_tohost(buf, buflen);
    buflen = 0;
  }

  return 0;
}

void printhex(uint64_t x)
{
  char str[17];
  int i;
  for (i = 0; i < 16; i++)
  {
    str[15-i] = (x & 0xF) + ((x & 0xF) < 10 ? '0' : 'a'-10);
    x >>= 4;
  }
  str[16] = 0;

  printstr(str);
}

static inline void printnum(void (*putch)(int, void**), void **putdat,
                    unsigned long long num, unsigned base, int width, int padc)
{
  unsigned digs[sizeof(num)*CHAR_BIT];
  int pos = 0;

  while (1)
  {
    digs[pos++] = num % base;
    if (num < base)
      break;
    num /= base;
  }

  while (width-- > pos)
    putch(padc, putdat);

  while (pos-- > 0)
    putch(digs[pos] + (digs[pos] >= 10 ? 'a' - 10 : '0'), putdat);
}

static unsigned long long getuint(va_list *ap, int lflag)
{
  if (lflag >= 2)
    return va_arg(*ap, unsigned long long);
  else if (lflag)
    return va_arg(*ap, unsigned long);
  else
    return va_arg(*ap, unsigned int);
}

static long long getint(va_list *ap, int lflag)
{
  if (lflag >= 2)
    return va_arg(*ap, long long);
  else if (lflag)
    return va_arg(*ap, long);
  else
    return va_arg(*ap, int);
}

static void vprintfmt(void (*putch)(int, void**), void **putdat, const char *fmt, va_list ap)
{
  register const char* p;
  const char* last_fmt;
  register int ch;
  unsigned long long num;
  int base, lflag, width, precision;
  char padc;

  while (1) {
    while ((ch = *(unsigned char *) fmt) != '%') {
      if (ch == '\0')
        return;
      fmt++;
      putch(ch, putdat);
    }
    fmt++;

    // Process a %-escape sequence
    last_fmt = fmt;
    padc = ' ';
    width = -1;
    precision = -1;
    lflag = 0;
  reswitch:
    switch (ch = *(unsigned char *) fmt++) {

    // flag to pad on the right
    case '-':
      padc = '-';
      goto reswitch;
      
    // flag to pad with 0's instead of spaces
    case '0':
      padc = '0';
      goto reswitch;

    // width field
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      for (precision = 0; ; ++fmt) {
        precision = precision * 10 + ch - '0';
        ch = *fmt;
        if (ch < '0' || ch > '9')
          break;
      }
      goto process_precision;

    case '*':
      precision = va_arg(ap, int);
      goto process_precision;

    case '.':
      if (width < 0)
        width = 0;
      goto reswitch;

    case '#':
      goto reswitch;

    process_precision:
      if (width < 0)
        width = precision, precision = -1;
      goto reswitch;

    // long flag (doubled for long long)
    case 'l':
      lflag++;
      goto reswitch;

    // character
    case 'c':
      putch(va_arg(ap, int), putdat);
      break;

    // string
    case 's':
      if ((p = va_arg(ap, char *)) == NULL)
        p = "(null)";
      if (width > 0 && padc != '-')
        for (width -= strnlen(p, precision); width > 0; width--)
          putch(padc, putdat);
      for (; (ch = *p) != '\0' && (precision < 0 || --precision >= 0); width--) {
        putch(ch, putdat);
        p++;
      }
      for (; width > 0; width--)
        putch(' ', putdat);
      break;

    // (signed) decimal
    case 'd':
      num = getint(&ap, lflag);
      if ((long long) num < 0) {
        putch('-', putdat);
        num = -(long long) num;
      }
      base = 10;
      goto signed_number;

    // unsigned decimal
    case 'u':
      base = 10;
      goto unsigned_number;

    // (unsigned) octal
    case 'o':
      // should do something with padding so it's always 3 octits
      base = 8;
      goto unsigned_number;

    // pointer
    case 'p':
      static_assert(sizeof(long) == sizeof(void*));
      lflag = 1;
      putch('0', putdat);
      putch('x', putdat);
      /* fall through to 'x' */

    // (unsigned) hexadecimal
    case 'x':
      base = 16;
    unsigned_number:
      num = getuint(&ap, lflag);
    signed_number:
      printnum(putch, putdat, num, base, width, padc);
      break;

    // escaped '%' character
    case '%':
      putch(ch, putdat);
      break;
      
    // unrecognized escape sequence - just print it literally
    default:
      putch('%', putdat);
      fmt = last_fmt;
      break;
    }
  }
}

int printf(const char* fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);

  vprintfmt((void*)putchar, 0, fmt, ap);

  va_end(ap);
  return 0; // incorrect return value, but who cares, anyway?
}

int sprintf(char* str, const char* fmt, ...)
{
  va_list ap;
  char* str0 = str;
  va_start(ap, fmt);

  void sprintf_putch(int ch, void** data)
  {
    char** pstr = (char**)data;
    **pstr = ch;
    (*pstr)++;
  }

  vprintfmt(sprintf_putch, (void**)&str, fmt, ap);
  *str = 0;

  va_end(ap);
  return str - str0;
}

size_t strnlen(const char *s, size_t n)
{
  const char *p = s;
  while (n-- && *p)
    p++;
  return p - s;
}

uint64_t read_cycle()
{
  uint32_t mcycleh, mcyclehv, mcycle;
  do {
    mcycleh  = read_csr(mcycleh);
    mcycle   = read_csr(mcycle);
    mcyclehv = read_csr(mcycleh);
  } while (mcycleh != mcyclehv);
  uint64_t rslt = mcycleh;
  rslt = (rslt << 32) | mcycle;
  return rslt;
}
