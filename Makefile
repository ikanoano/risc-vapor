OBJS	=\
	ALU.v\
	GPR.v\
	INST.v\
	PROCESSOR.v\
	RAM.v\
	ROM.v\
	TOP.v\
	UTIL.v
IVFLAGS	= -Wall -g2005 -s TOP -PTOP.MAX_CYCLE=50000000

all:
	$(MAKE) isim

isim:	$(OBJS)
	iverilog $(OBJS) $(IVFLAGS) -PTOP.TRACE=0 -o $@
isim-trace:	$(OBJS)
	iverilog $(OBJS) $(IVFLAGS) -PTOP.TRACE=1 -o $@

run:	isim
	./$<
run-trace:	isim-trace
	./$<
