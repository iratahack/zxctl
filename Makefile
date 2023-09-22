PROJECT_NAME=zxctl
CFLAGS:=-Wall -O2
CSRC:=zxctl.c compress.c memory.c optimize.c
COBJS:=$(CSRC:.c=.o)
CXXSRC:=bin2rem.cpp
CXXOBJS:=$(CXXSRC:.cpp=.o)

.PHONY: all clean dis

all: $(PROJECT_NAME)

clean:
	rm -f $(PROJECT_NAME)
	rm -f *.tap *.bin *.[od]
	rm -f loader.h *.patch *.zx0 *.map

dis: loader.bin
	z88dk-dis -x loader.map -o start $^ | less

%.o: %.c loader.h
	c++ $(CFLAGS) -c -MMD $< -o $@

%.o: %.cpp
	c++ $(CFLAGS) -c -MMD $< -o $@

$(PROJECT_NAME): $(COBJS) $(CXXOBJS)
	c++  $^ -O2 -o $@

loader.bin: loader.asm ld_bytes.bin
	z88dk-z80asm -mz80 -m -b -o$@ $<

ld_bytes.bin: ld_bytes.asm
	z88dk-z80asm -mz80 -m -b -o$@ $<

loader.h: loader.bin
	xxd -i $< > $@

-include $(COBJS:.o=.d)
-include $(CXXOBJS:.o=.d)

