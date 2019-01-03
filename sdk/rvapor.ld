ENTRY(_start)

MEMORY {
  PROG (rwx)  : ORIGIN = 0x00000000, LENGTH = 64K
  INIT (rw)   : ORIGIN = 0x00010000, LENGTH = 448K
  USER (rw)   : ORIGIN = 0x00080000, LENGTH = 130560K
}

SECTIONS {
  . = 0x0000;
  .startup         : { startup.o(.text) } > PROG
  . = 0x0200;

  .init            : { KEEP (*(.init)) } > PROG
  .text            : { *(.text .stub .text.* .gnu.linkonce.t.*)
                       KEEP (*(.text)) } > PROG
  .fini            : { KEEP (*(.fini)) } > PROG
  .ctors           : { __ctors_start = .;
                       KEEP (*(SORT(.ctors.*)))
                       KEEP (*(.ctors))
	                     __ctors_end = .; } > PROG
  .dtors           : { __dtors_start = .;
                       KEEP (*(SORT(.dtors.*)))
                       KEEP (*(.dtors))
                       __dtors_end = .; } > PROG
  .rodata          : { *(.rodata .rodata.* .gnu.linkonce.r.*) } > INIT
  .data            : { *(.data .data.* .gnu.linkonce.d.*)
                       SORT(CONSTRUCTORS) } > INIT
  .bss             : { . = ALIGN(4);
                       __bss_start = .;
                       *(.dynbss)
                       *(.bss .bss.* .gnu.linkonce.b.*)
                       *(COMMON)
                       . = ALIGN(4);
                       __bss_end = .; } > INIT
}
