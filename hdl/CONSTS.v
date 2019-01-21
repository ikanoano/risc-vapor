// addresses for memory mapped io
`define MMIO_HALT           16'h0000
`define MMIO_TO_HOST        16'h0100
`define MMIO_FROM_HOST      16'h0200
`define MMIO_LED            16'h0300
`define MMIO_SEG7           16'h0400
`define MMIO_BTN            16'h0500
`define MMIO_SW             16'h0600
`define MMIO_LFSR           16'h0700

`define MMIO_CPU_FREQ       16'h2000
`define MMIO_BP_HIT         16'h2100
`define MMIO_BP_PRED        16'h2200
`define MMIO_DC_HIT         16'h2300
`define MMIO_DC_ACCESS      16'h2400

`define BOOT                32'h00000000
