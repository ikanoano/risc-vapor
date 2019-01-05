PREFIX		?= /usr/bin/riscv64-unknown-elf

TARGET		?= main
ELF_TRG		:= $(TARGET).elf
IMG_TRG		:= $(TARGET).img
SRCS			:=\
	startup.s\
	syscalls.c\
	$(TARGET).c
OBJS			:= $(addsuffix .o,$(basename $(SRCS))) bigdata.o
LNKSCR		:= rvapor.ld

CC				:= $(PREFIX)-gcc
LD				:= $(PREFIX)-gcc #ld cannot find udivdi (in libgcc) on my enviroment
OD				:= $(PREFIX)-objdump
OC				:= $(PREFIX)-objcopy

CMNFLAGS	?= -Wall -march=rv32i -mabi=ilp32 -mstrict-align -nostartfiles -fno-pic -static
CCFLAGS		?= -g -O2 -std=c11 -ffast-math -fno-common -fno-builtin-printf -ffunction-sections -fdata-sections
LDFLAGS		?= -T $(LNKSCR) -Wl,--gc-sections
ODFLAGS		?= -mriscv:rv32
OCFLAGS		?= -O binary --pad-to 0x80000

all: $(IMG_TRG)

$(ELF_TRG): $(OBJS) $(LNKSCR)
	$(LD) $(CMNFLAGS) $(LDFLAGS) $(OBJS) -o $@
%.o: %.c
	$(CC) $(CMNFLAGS) $(CCFLAGS) -c $< -o $@
%.o: %.s
	$(CC) $(CMNFLAGS) $(CCFLAGS) -c $< -o $@

datagen: datagen.c
	gcc -Wall datagen.c -o datagen
bigdata: datagen
	./datagen 300 3 > $@
bigdata.o: bigdata
	$(OC) -I binary -B riscv -O elf32-littleriscv $< $@

$(IMG_TRG): $(ELF_TRG)
	$(OC) $(OCFLAGS) \
		-j .startup \
		-j .init \
		-j .text \
		-j .fini \
		-j .ctors \
		-j .dtors \
		-j .rodata \
		-j .data \
		-j .bss \
		$< $@

dump: $(ELF_TRG)
	$(OD) $(ODFLAGS) -D $<
dumpc: $(ELF_TRG)
	$(OD) $(ODFLAGS) -S $<
dumpn: $(ELF_TRG)
	$(OD) $(ODFLAGS) -D -Mno-aliases $<

dumpimage: $(IMG_TRG)
	$(OD) $(ODFLAGS) -D -b binary $<
od: $(IMG_TRG)
	od -Ax -tx1z $<

check_data_symbol: bigdata.o
	$(OD) $(ODFLAGS) -x $<

# solve dependencies
$(foreach SRC,$(SRCS),$(eval $(subst \,,$(shell $(CC) -MM $(SRC)))))

clean:
	rm -f $(OBJS) *.elf *.img bigdata datagen

