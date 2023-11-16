# ZX Spectrum Compressed Tape Loader (ZXCTL)

Utility that take as input binary images for the ZX Spectrum and output a .tap image complete with loader.

## Compression

The input binary images are compressed using the ZX0 compression algorithm by Einar Saukas. The loader uncompresses the images after each block has loaded.

## Custom Tape Loader

The custom and turbo loader options do not use the ROM tape loader. This means that these images will not work when loading from DivMMC devices. These loaders are specifically for loading real cassette tapes.

## Turbo Loader

The turbo load is based on the ROM loader. The timings are mostly the same, the one exception is the timing for a '1' bit is 1710T on followed by 855T off rather than 1710T/1710T. This shortens the '1' bit by 25%. The more '1's in the binary image the more time saved loading.

Other differences from the ROM loader include, no flag byte at the beginning of a block and no party byte at the end.

At time of writing, it has not been tested on cassette. If you get chance, please give it a try.

## Usage

```
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

```
./zxctl -f -i -l 0x6000 -e 0x8BE2 -m ForestEscape.bin -0 ForestEscape_BANK_0.bin -4 ForestEscape_BANK_4.bin  -s loading_screen.scr -o ForestEscape_Cassette_Turbo.tap -t ForestEsc
```
