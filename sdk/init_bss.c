extern volatile int _bss_start;
extern volatile int _bss_end;
extern int main(void);

int init_bss(void) {
  volatile int *p    = &_bss_start;
  volatile int *end  = &_bss_end;
  while(p<end) *p++ = 0;

  main();

  return 0;
}
