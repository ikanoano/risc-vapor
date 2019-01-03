#define DIGIT_DEC (256)
#define DIGIT_HEX (8)
#include "lib.h"

void mylib_wait_tx() {
  volatile int* const e_tx_available = (volatile int*)0xf0000004; // memory mapped I/O
  while(!(*e_tx_available));
}

void mylib_display_hex(int val) {
  int str[8];
  for(int i=0; i<DIGIT_HEX; i++) {
    int lsb4 = val & 0xf;
    str[i] = lsb4 < 10 ? '0'+lsb4 : 'a'+lsb4-10;
    val >>= 4;
  }
  for(int i=0; i<DIGIT_HEX; i++) {
    mylib_display_char(str[7-i]);
  }
}

void mylib_display_char(int val) {
  volatile int* const e_tx = (volatile int*)0xf0000004; // memory mapped I/O
  mylib_wait_tx();
  *e_tx = val;
}

void mylib_display_newline() {
  mylib_display_char('\n');
  mylib_display_char('\r');
}

void mylib_finalize() {
  volatile int* const e_halt = (volatile int*)0xf0000000; // memory mapped I/O

  mylib_display_newline();
  mylib_display_char('E');
  mylib_display_char('N');
  mylib_display_char('D');
  mylib_display_newline();

  *e_halt = 1;
  while(1);
}
