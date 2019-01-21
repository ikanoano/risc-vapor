OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
  PROG (rx)   : ORIGIN = 0x00000000, LENGTH = 64K
  INIT (rw)   : ORIGIN = 0x00010000, LENGTH = 448K
  USER (rw)   : ORIGIN = 0x00080000, LENGTH = 130560K
}

SECTIONS {
  . = 0x0000;

  .startup  : {
    startup.o(.text)
  } > PROG

  .init     : {
    KEEP (*(.init .text.init))
  } > PROG

  .text     : {
    *(.text.* .text .stub .gnu.linkonce.t.*)
  } > PROG

  .fini     : {
    KEEP (*(.fini))
  } > PROG

  _etext = .;

  .rodata   : {
    *(.rodata .rodata.* .gnu.linkonce.r.*)
    *(.rodata1)
  } > INIT

  . = ALIGN(4);

  .ctors    : {
    __preinit_array_start = .;
    KEEP (*(.preinit_array))
    __preinit_array_end = .;

    __init_array_start = .;
    KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
    KEEP (*(.init_array .ctors))
    __init_array_end = .;
  } > INIT

  .dtors    : {
    __fini_array_start = .;
    KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
    KEEP (*(.fini_array .dtors))
    __fini_array_end = .;
  } > INIT

  .data     : {
    /* data */
    *(.data .data.* .gnu.linkonce.d.*)
    SORT(CONSTRUCTORS)
    *(.data1)
    *(.tdata .tdata.* .gnu.linkonce.td.*)

    /* sdata */
    . = ALIGN(4);
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata .srodata.*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    *(.sdata2 .sdata2.* .gnu.linkonce.s2.*)
  } > INIT

  . = ALIGN(4);
  _edata = .;
  __bss_start = .;

  .bss      : {
    /* sbss */
    . = ALIGN(4);
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)

    /* bss */
    . = ALIGN(4);
    *(.bss .bss.* .gnu.linkonce.b.*)
    *(COMMON)
    *(.sbss2 .sbss2.* .gnu.linkonce.sb2.*)
    *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon)
  } > INIT

  . = ALIGN(4);
  __bss_end = .;
  _end = .;
}
