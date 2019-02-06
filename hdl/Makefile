IMAGE			?= image
MAX_CYCLE	?= 100000
DUMP			?= 0
TIME			?= 0
PLOAD			?= 0

RISCV_PREFIX	?=riscv64-linux-gnu-
IVFLAGS		?= -Wall -g2005 -s TOP_SIM -DIVERILOG
VVFLAGS		?= -full64 -v2005 -Wall -LDFLAGS -no-pie
RUNFLAGS	?= +IMAGE=$(IMAGE) +MAX_CYCLE=$(MAX_CYCLE) +DUMP=$(DUMP) +TIME=$(TIME) +PLOAD=$(PLOAD)
BENCHMARK	?= dhrystone

OBJS			=\
	UTIL.v\
	INST.v\
	ALU.v\
	GPR.v\
	RAM.v\
	ROM.v\
	BARERAM.v\
	BAREROM.v\
	BIMODAL_PREDICTOR.v\
	CSR.v\
	PROCESSOR.v\
	PLOADER.v\
	M_7SEGCON.v\
	UART.v\
	PSEUDO.v\
	DRAM.v\
	DRAM_ARBITER.v\
	MMIO.v\
	ICACHE.v\
	DCACHE.v\
	LFSR.v\
	TOP_NEXYS4DDR.v\
	TOP_SIM.v

all:
	$(MAKE) isim

isim:	$(OBJS)
	iverilog $(OBJS) $(IVFLAGS) -o $@
vsim: $(OBJS)
	vcs $(OBJS) $(VVFLAGS) -o isim

run:	isim
	./$< $(RUNFLAGS)
run-trace:	isim
	./$< $(RUNFLAGS) +TRACE=1

benchmark:	isim
	$(RISCV_PREFIX)objcopy -Obinary -R .tohost -R .fromhost ../benchmarks/$(BENCHMARK).riscv /tmp/$(BENCHMARK).bin
	$(MAKE) run IMAGE=/tmp/$(BENCHMARK).bin MAX_CYCLE=3000000
benchmark-trace:	isim
	$(RISCV_PREFIX)objcopy -Obinary -R .tohost -R .fromhost ../benchmarks/$(BENCHMARK).riscv /tmp/$(BENCHMARK).bin
	$(MAKE) run-trace IMAGE=/tmp/$(BENCHMARK).bin MAX_CYCLE=3000000

clean:
	rm -f isim*
