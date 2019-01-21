#include <limits.h>
#include "syscalls.h"

int main() {

  while(1) {
    uint32_t  btn = *cpu_btn;
    if(btn & btn_mask_down) {
      *cpu_seg7 = (uint32_t)read_cycle();
      putchar('d');
    } else if(btn & btn_mask_right) {
      *cpu_seg7 = *cpu_sw;
      putchar('r');
    } else if(btn & btn_mask_left) {
      *cpu_seg7 = *cpu_lfsr;
      putchar('l');
    } else if(btn & btn_mask_up) {
      *cpu_seg7 = *cpu_freq;
      putchar('u');
    } else if(btn & btn_mask_center) {
      *cpu_seg7 = 0xBEEFBEEF;
      putchar('c');
    }
  }

  return 0;
}
