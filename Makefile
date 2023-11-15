PROJECT_NAME=zxctl
CFLAGS:=-Wall -O2 -MMD -c
LDFLAGS:=-O2
CSRC:=$(wildcard *.c)
CXXSRC:=$(wildcard *.cpp)
OBJS:=$(CSRC:.c=.o) $(CXXSRC:.cpp=.o)

.PHONY: all clean dis

all: $(PROJECT_NAME)

clean:
	rm -f $(PROJECT_NAME)
	rm -f *.tap *.bin *.[od]
	rm -f loader.h *.patch *.zx0 *.map

dis: loader.bin
	z88dk-dis -x loader.map -o start $^ | less

%.o: %.c loader.h ld_bytes.h turbo1.h
	$(CC) $(CFLAGS) $< -o $@

%.o: %.cpp
	$(CXX) $(CFLAGS) $< -o $@

$(PROJECT_NAME): $(OBJS)
	$(CXX) $(LDFLAGS) $^ -o $@

%.bin: %.asm
	z88dk-z80asm -mz80 -m -b -o$@ $<

%.bin: %.asm
	z88dk-z80asm -mz80 -m -b -o$@ $<

loader.h: loader.bin
	xxd -i $< > $@

ld_bytes.h: ld_bytes.bin
	xxd -i $< > $@

turbo.h: turbo.bin
	xxd -i $< > $@

turbo1.h: turbo1.bin
	xxd -i $< > $@

-include $(OBJS:.o=.d)
