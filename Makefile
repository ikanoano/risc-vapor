IMAGE			?= image
MAX_CYCLE	?= 100000
DUMP			?= 0

IVFLAGS		?= -Wall -g2005 -s TOP_SIM
RUNFLAGS	?= +IMAGE=$(IMAGE) +MAX_CYCLE=$(MAX_CYCLE) +DUMP=$(DUMP)
BENCHMARK	?= dhrystone

OBJS			=\
	UTIL.v\
	INST.v\
	ALU.v\
	GPR.v\
	RAM.v\
	ROM.v\
	PROCESSOR.v\
	PLOADER.v\
	M_7SEGCON.v\
	UART.v\
	PSEUDO.v\
	TOP_NEXYS4DDR.v\
	TOP_SIM.v

all:
	$(MAKE) isim

isim:	$(OBJS)
	iverilog $(OBJS) $(IVFLAGS) -o $@

run:	isim
	./$< $(RUNFLAGS)
run-trace:	isim
	./$< $(RUNFLAGS) +TRACE=1

benchmark:	isim
	riscv64-linux-gnu-objcopy -Obinary -R .tohost -R .fromhost ./benchmarks/$(BENCHMARK).riscv /tmp/$(BENCHMARK).bin
	$(MAKE) run IMAGE=/tmp/$(BENCHMARK).bin MAX_CYCLE=1000000
benchmark-trace:	isim
	riscv64-linux-gnu-objcopy -Obinary -R .tohost -R .fromhost ./benchmarks/$(BENCHMARK).riscv /tmp/$(BENCHMARK).bin
	$(MAKE) run-trace IMAGE=/tmp/$(BENCHMARK).bin MAX_CYCLE=1000000

clean:
	rm -f isim*
