PREF		?= /usr/bin/riscv64-linux-gnu

TARGET	:= main
SRCS		:=\
	startup.s\
	init_bss.c\
	main.c\
	lib.c
OBJS		:= $(addsuffix .o,$(basename $(SRCS))) bigdata.o
LNKSCR	:= rvapor.ld

CC			:= $(PREF)-gcc
AS			:= $(PREF)-as
LD			:= $(PREF)-ld
OD			:= $(PREF)-objdump
OC			:= $(PREF)-objcopy

ASFLAGS	?= -Wall -O2 -std=c11 -march=rv32i -mabi=ilp32 -nostdlib -fno-pic -static -g
CCFLAGS	?= -Wall -O2 -std=c11 -march=rv32i -mabi=ilp32 -nostdlib -fno-pic -static -g
LDFLAGS	?= -T $(LNKSCR) --format elf32-littleriscv -static
ODFLAGS	?= -mriscv:rv32
OCFLAGS	?=

all: image

$(TARGET): $(OBJS) $(LNKSCR)
	$(LD) $(LDFLAGS) $(OBJS) -o $@

%.o: %.c
	$(CC) $(CCFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(ASFLAGS) -c $< -o $@

datagen: datagen.c
	gcc -Wall datagen.c -o datagen
bigdata: datagen
	./datagen 300 3 > $@
bigdata.o: bigdata
	$(OC) -I binary -B riscv -O elf32-littleriscv $< $@

image: $(TARGET)
	$(OC) $(OCFLAGS) -O binary --pad-to 0x80000 \
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

dump: $(TARGET)
	$(OD) $(ODFLAGS) -D $(TARGET)
dumpc: $(TARGET)
	$(OD) $(ODFLAGS) -S $(TARGET)
dumpn: $(TARGET)
	$(OD) $(ODFLAGS) -D -Mno-aliases $(TARGET)

dumpimage: image
	$(OD) $(ODFLAGS) -D -b binary $<
od: image
	od -Ax -tx1z $<

check_data_symbol: bigdata.o
	$(OD) $(ODFLAGS) -x bigdata.o

# solve dependencies
$(foreach SRC,$(SRCS),$(eval $(subst \,,$(shell $(CC) -MM $(SRC)))))

clean:
	rm -f *.o bigdata $(TARGET) datagen *.dat image

