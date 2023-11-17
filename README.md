# ZX Spectrum Compressed Tape Loader (ZXCTL)

Utility that take as input binary images for the ZX Spectrum and output a .tap image complete with loader.

## Compression

The input binary images are compressed using the ZX0 compression algorithm by Einar Saukas. The loader uncompresses the images after each block has loaded.

### Loading Screen

The loading screen, if present, is loaded first. The image is compressed forward which means it is uncompressed forward, i.e. from lowest address to highest address. The loader will set the border, paper, and ink color to black and since the screen attributes come after the bitmap, the watcher (you) will not see the bitmap being uncompressed to the screen memory. Rather, as the attributes are uncompressed to the screen memory the beautiful loading screen will be revealed.

### Other Blocks

All blocks except the loading screen are compressed/uncompressed backward, i.e. from highest address to lowest address. This is because these blocks are uncompressed in place. They are loaded to the lower portion of their destination memory bank and uncompressed starting from the upper portion of their destination memory bank. There is a small overlap into the memory address below the bank they are being loaded to called the 'delta'. ZXCTL will report the max delta across all blocks. This number of bytes must be reserved as it will be used by the uncompressor.

For example, if memory bank 0 is being loaded and the delta is 3, then 3 bytes below the loading address for memory bank 0 must be reserved, i.e. $bffd-$bfff

The lowest load address of the main bank (or bank 5) matches the end of the memory used by the loader, which accounts for this delta.

## Block Loading Order

The loader will detect if it is running on a 128K or 48K machine and load the appropriate blocks. For this reason, the 128K specific blocks are stored after the blocks for the main bank or memory banks 5, 2, and 0. If a 48K machine is detected, only the loading screen, if present, and the main bank or memory banks 5, 2, 0 are loaded. All blocks are loaded for a 128K machine.

## Custom Tape Loader

The custom and turbo loader options do not use the ROM tape loader. This means that these images will not work when loading from DivMMC devices. These loaders are specifically for loading from real cassette tapes.

The custom tape loader is relocated to $bf60 ($c000-$a0). $a0 bytes is enough space for the tape loader and some spare 'delta' bytes. This means you cannot overwrite this memory when bank 2 or the main bank is being loaded.

### Turbo Loader

The turbo load is based on the ROM loader. The timings are mostly the same, the one exception is the timing for a '1' bit is 1710T on followed by 855T off rather than 1710T/1710T. This shortens the '1' bit by 25%. The more '1's in the binary image the more time saved loading.

Other differences from the ROM loader include no flag byte at the beginning of a block and no party byte at the end.

At the time of writing, this loader had not been tested on a real cassette. If you get chance, please give it a try.

## Usage

```sh
	zxctl --load <address> --exec <address> --main <mainbank> [options]
Where:
	-l,--load <address>  Load address of the main bank (5,2,0), >= 0x6000
	-e,--exec <address>  Exec address in main bank
	-m,--main <mainbank> Binary file containing 'main' bank (5,2,0)
Options:
	-d,--debug           Enable debug logging
	-o,--output <file>   Output file name (.tap), defaults <mainbank>.tap
	-s,--screen <file>   Name of the SCREEN$ (.scr) file
	-t,--tape <file>     Name of the basic loader, defaults to 'Loader    '
	-q,--quick           Enable quick compress mode for ZX0
	-[0-7] <file>        Optional banks to include (1,3,4,6,7
	                     only loaded on 128K systems)
	-i,--info            Display compression info
	-c,--custom          Enable custom loader with fancy border colors
	                     Bank 0 cannot be part of <mainbank> it must be
	                     loaded with -0 and 160 bytes of from $bf60-$c000
	                     must be reserved in bank 2 for the loader
	-w,--wav             Convert the .tap file to a .wav file
	-f,--fast            Enable turbo loader, implies -w and -c
```

## Examples

```sh
./zxctl -f -i -l 0x6000 -e 0x8BE2 -m ForestEscape.bin -0 ForestEscape_BANK_0.bin -4 ForestEscape_BANK_4.bin  -s loading_screen.scr -o ForestEscape_Cassette_Turbo.tap -t ForestEsc
```

## Building Sources

Building the native sources is simple. However, the Z80 assembly source also need to be built. This should be done by installing z88dk. z88dk can be installed from the snap store with the commands below...

```sh
sudo snap install --edge z88dk

sudo snap alias z88dk.zcc zcc
sudo snap alias z88dk.z88dk-z80asm z88dk-z80asm
sudo snap alias z88dk.z88dk-asmstyle z88dk-asmstyle
sudo snap alias z88dk.z88dk-dis z88dk-dis
sudo snap alias z88dk.z88dk-zx0 z88dk-zx0
sudo snap alias z88dk.z88dk-appmake z88dk-appmake
```
