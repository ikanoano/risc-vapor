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

all:
	$(MAKE) isim

isim:	$(OBJS)
	iverilog $(OBJS) $(IVFLAGS) -o $@

run:	isim
	./$< $(RUNFLAGS)
run-trace:	isim
	./$< $(RUNFLAGS) +TRACE=1

clean:
	rm -f isim*
