IMAGE			?= image
MAX_CYCLE	?= 100000
DUMP			?= 0
OBJS			?=\
	ALU.v\
	GPR.v\
	INST.v\
	PROCESSOR.v\
	RAM.v\
	ROM.v\
	TOP.v\
	UTIL.v
IVFLAGS		?= -Wall -g2005 -s TOP
RUNFLAGS	?= +IMAGE=$(IMAGE) +MAX_CYCLE=$(MAX_CYCLE) +DUMP=$(DUMP)
BENCHMARK	?= dhrystone

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

clean:
	rm -f isim*
