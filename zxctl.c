#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "zx0.h"

#include "loader.h"

typedef struct __packed__
{
    uint16_t loadSize;
    uint16_t loadAddr;
    uint16_t destAddr;
} blocks_t;

#define VERSION "v0.5"
#define MAX_OFFSET_ZX0 32640
#define MAX_OFFSET_ZX7 2176
#define MAX_INPUT 0x10000
#define MAX_BLOCKS 10
#define MAX_FILENAME 128

extern void bin2rem(unsigned char *loader, int size, char *fileName, char *tapeName);
extern void appendTap(unsigned char *outputData, int outputSize, char *fileName);

static int debug = 0;
static int info = 0;
static char mainBank[MAX_FILENAME] =
{ 0 };
static char outputFile[MAX_FILENAME] =
{ 0 };
static char screenName[MAX_FILENAME] =
{ 0 };
static char tapeName[MAX_FILENAME] = "Loader";

void usage(void)
{
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "\tzxctl --load <address> --exec <address> --main <file> [options]\n");
    fprintf(stderr, "Where:\n");
    fprintf(stderr, "\t-l,--load <address>  Load address of the main bank (5,2,0), >= 0x6000\n");
    fprintf(stderr, "\t-e,--exec <address>  Exec address in main bank\n");
    fprintf(stderr, "\t-m,--main <mainbank> Binary file containing 'main' bank (5,2,0)\n");
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "\t-d,--debug           Enable debug logging\n");
    fprintf(stderr, "\t-o,--output <file>   Output file name (.tap), defaults <mainbank>.tap\n");
    fprintf(stderr, "\t-s,--screen <file>   Name of the SCREEN$ (.scr) file\n");
    fprintf(stderr, "\t-t,--tape <file>     Name of the basic loader, defaults to 'Loader    '\n");
    fprintf(stderr, "\t-q,--quick           Enable quick compress mode for ZX0\n");
    fprintf(stderr, "\t-[1,3,4,6,7] <file>  Optional 128K banks to include\n");
    fprintf(stderr, "\t                       (Only loaded on 128K systems)\n");
    fprintf(stderr, "\t-i,--info            Display compression info\n");
    fprintf(stderr, "\n");

    exit(1);
}

// Convert host short to little endian
// Use our own since its cross-platform
static uint16_t _htole16(uint16_t value)
{
    uint16_t test = 0x55aa;

    if ((*(unsigned char*) &test) != 0xaa)
        value = ((value >> 8) | (value << 8));
    return (value);
}

void reverse(unsigned char *first, unsigned char *last)
{
    unsigned char c;

    while (first < last)
    {
        c = *first;
        *first++ = *last;
        *last-- = c;
    }
}

unsigned char* doCompression(unsigned char *input_data, int input_size, int *output_size, int *delta, int quick_mode,
        int backwards_mode)
{
    int skip = 0;
    unsigned char *output_data;
    int classic_mode = FALSE;
    void *blockStart = NULL;

    /* conditionally reverse input file */
    if (backwards_mode)
        reverse(input_data, input_data + input_size - 1);

    output_data = compress(optimize(input_data, input_size, skip, quick_mode ? MAX_OFFSET_ZX7 : MAX_OFFSET_ZX0, &blockStart),
            input_data, input_size, skip, backwards_mode, !classic_mode && !backwards_mode, output_size, delta);

    /* conditionally reverse output file */
    if (backwards_mode)
        reverse(output_data, &output_data[*output_size - 1]);

    free(blockStart);
    return (output_data);
}

unsigned char* addBank(char *fileName, int *inputSize, int *outputSize, int *delta, int quick, int backwards)
{
    FILE *inFile;
    unsigned char *outputData;
    unsigned char inputData[MAX_INPUT];

    // Read from the input file
    if ((inFile = fopen(fileName, "r")) == NULL)
    {
        fprintf(stderr, "Error opening '%s'\n", fileName);
        exit(1);
    }
    *inputSize = fread(inputData, 1, MAX_INPUT, inFile);
    fclose(inFile);

    printf("Compressing %s\n", fileName);

    // Compress data
    outputData = doCompression(inputData, *inputSize, outputSize, delta, quick, backwards);
    if (info)
    {
        printf("Input size        : %d (0x%04x)\n", *inputSize, *inputSize);
        printf("Output size       : %d (0x%04x)\n", *outputSize, *outputSize);
        printf("Delta             : %d\n", *delta);
        printf("Compressed by     : %f%%\n", 100 - (((float) *outputSize / (float) *inputSize) * 100));
    }

    return (outputData);
}

int main(int argc, char **argv)
{
    blocks_t *blocks = (blocks_t*) &loader_bin[loader_bin_len - (MAX_BLOCKS * sizeof(blocks_t))];
    char bankNames[MAX_BLOCKS][MAX_FILENAME] =
    { 0 };
    int loadAddress = -1;
    int execAddress = -1;
    int quick = 0;
    int inputSize;
    int outputSize[MAX_BLOCKS] =
    { 0 };
    int delta;
    int maxDelta = 0;
    unsigned char *outputData[MAX_BLOCKS] =
    { 0 };
    uint16_t *shortPtr;

    printf("ZX Spectrum Compressed Tape Loader (ZXCTL)\n");
    printf("Version %s, (C) 2023 IrataHack, All Rights Reserved.\n\n", VERSION);

    if (argc < 7)
        usage();

    for (int arg = 1; arg < argc; arg++)
    {
        if ((strcmp(argv[arg], "--debug") == 0) || strcmp(argv[arg], "-d") == 0)
        {
            info = debug = 1;
        }
        else if ((strcmp(argv[arg], "--info") == 0) || strcmp(argv[arg], "-i") == 0)
        {
            info = 1;
        }
        else if ((strcmp(argv[arg], "--load") == 0) || (strcmp(argv[arg], "-l") == 0))
        {
            if (++arg < argc)
            {
                // get load address
                loadAddress = strtol(argv[arg], NULL, 0);
            }

            if (debug)
                printf("Load address: %-5d (0x%04x)\n", loadAddress, loadAddress);

            if (loadAddress < 0 || loadAddress >= MAX_INPUT)
            {
                fprintf(stderr, "Invalid load address (%d)\n", loadAddress);
                exit(1);
            }
        }
        else if ((strcmp(argv[arg], "--exec") == 0) || (strcmp(argv[arg], "-e") == 0))
        {
            if (++arg < argc)
            {
                // get exec address
                execAddress = strtol(argv[arg], NULL, 0);
            }

            if (debug)
                printf("Exec address: %-5d (0x%04x)\n", execAddress, execAddress);

            if (execAddress < 0 || execAddress >= MAX_INPUT)
            {
                fprintf(stderr, "Invalid exec address (%d)\n", execAddress);
                exit(1);
            }
        }
        else if ((strcmp(argv[arg], "--main") == 0) || (strcmp(argv[arg], "-m") == 0))
        {
            if (++arg < argc)
            {
                // get main bank file name
                strcpy(mainBank, argv[arg]);
            }

            if (debug)
                printf("Main bank   : %s\n", mainBank);

            if (mainBank[0] == 0)
            {
                fprintf(stderr, "Invalid main bank file name\n");
                exit(1);
            }
        }
        else if ((strcmp(argv[arg], "--output") == 0) || (strcmp(argv[arg], "-o") == 0))
        {
            if (++arg < argc)
            {
                // get main bank file name
                strcpy(outputFile, argv[arg]);
            }

            if (debug)
                printf("Output file : %s\n", outputFile);

            if (outputFile[0] == 0)
            {
                fprintf(stderr, "Invalid output file name\n");
                exit(1);
            }
        }
        else if ((strcmp(argv[arg], "--screen") == 0) || (strcmp(argv[arg], "-s") == 0))
        {
            if (++arg < argc)
            {
                strcpy(screenName, argv[arg]);
            }

            if (debug)
                printf("Screen file : %s\n", screenName);

            if (!strlen(screenName))
            {
                fprintf(stderr, "Invalid screen file name\n");
                exit(1);
            }
        }
        else if ((strcmp(argv[arg], "--tape") == 0) || (strcmp(argv[arg], "-t") == 0))
        {
            if (++arg < argc)
            {
                strcpy(tapeName, argv[arg]);
            }

            if (debug)
                printf("Tape name   : %s\n", tapeName);

            if ((!strlen(tapeName)) || (strlen(tapeName) > 10))
            {
                fprintf(stderr, "Invalid tape name\n");
                exit(1);
            }
        }
        else if ((strcmp(argv[arg], "--quick") == 0) || (strcmp(argv[arg], "-q") == 0))
        {
            quick = 1;
        }
        else if ((strcmp(argv[arg], "-0") == 0) || (strcmp(argv[arg], "-1") == 0) || (strcmp(argv[arg], "-2") == 0)
                || (strcmp(argv[arg], "-3") == 0) || (strcmp(argv[arg], "-4") == 0) || (strcmp(argv[arg], "-5") == 0)
                || (strcmp(argv[arg], "-6") == 0) || (strcmp(argv[arg], "-7") == 0))
        {
            int bankNum;
            bankNum = strtol(&argv[arg][1], NULL, 0);

            if (++arg < argc)
            {
                strcpy(bankNames[bankNum], argv[arg]);
            }

            if (debug)
            {
                printf("Including bank %d (%s)\n", bankNum, bankNames[bankNum]);
            }

            if (!strlen(bankNames[bankNum]))
            {
                fprintf(stderr, "Invalid bank file name\n");
                exit(1);
            }
        }
        else
        {
            fprintf(stderr, "Unknown parameter '%s'\n", argv[arg]);
        }
    }

    if (!strlen(outputFile))
    {
        strcpy(outputFile, mainBank);
        strcat(outputFile, ".tap");
    }

    if (strlen(screenName))
    {
        outputData[0] = addBank(screenName, &inputSize, &outputSize[0], &delta, quick, 0);
        blocks[0].loadSize = _htole16(outputSize[0]);
        blocks[0].loadAddr = _htole16(0xc000);
        blocks[0].destAddr = _htole16(0x4000);
        maxDelta = delta > maxDelta ? delta : maxDelta;
    }

    if (strlen(mainBank))
    {
        // Setup the main bank
        outputData[1] = addBank(mainBank, &inputSize, &outputSize[1], &delta, quick, 1);
        blocks[1].loadSize = _htole16(outputSize[1]);
        blocks[1].loadAddr = _htole16(loadAddress - delta);
        blocks[1].destAddr = _htole16(loadAddress + inputSize - 1);
        maxDelta = delta > maxDelta ? delta : maxDelta;
    }

    for (int n = 2; n < MAX_BLOCKS; n++)
    {
        if (strlen(bankNames[n - 2]))
        {
            outputData[n] = addBank(bankNames[n - 2], &inputSize, &outputSize[n], &delta, quick, 1);
            blocks[n].loadSize = _htole16(outputSize[n]);
            blocks[n].loadAddr = _htole16(0xc000 - delta);
            blocks[n].destAddr = _htole16(0xc000 + inputSize - 1);
            maxDelta = delta > maxDelta ? delta : maxDelta;
        }
    }

    // Patch the loader for this bank
    shortPtr = (uint16_t*) &loader_bin[loader_bin_len - (MAX_BLOCKS * sizeof(blocks_t)) - 2];
    // execAddr
    *shortPtr++ = _htole16(execAddress);

    if (debug)
    {
        FILE *op;
        if ((op = fopen("loader.patch", "w+")) == NULL)
        {
            fprintf(stderr, "Couldn't create loader patch\n");
            exit(1);
        }
        fwrite(loader_bin, 1, loader_bin_len, op);
        fclose(op);
    }

    // Use bin2rem to generate the loader tap file
    bin2rem(loader_bin, loader_bin_len, outputFile, tapeName);

    // Output the rest of the blocks
    for (int n = 0; n < MAX_BLOCKS; n++)
    {
        if (outputData[n])
        {
            // Append the compressed data to the end of the tap file
            appendTap(outputData[n], outputSize[n], outputFile);
            //
            free(outputData[n]);
        }
    }

    printf("** Max delta across all blocks: %d bytes **\n", maxDelta);

    return (0);
}
