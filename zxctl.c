#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <byteswap.h>
#include "zx0.h"

#include "loader.h"

#define MAX_OFFSET_ZX0 32640
#define MAX_OFFSET_ZX7 2176
#define MAX_INPUT 0x10000

extern void bin2rem(unsigned char *loader, int size, char *fileName, char *tapeName);
extern void appendTap(unsigned char *outputData, int outputSize, char *fileName);

static int debug = 0;
static int loadAddress = -1;
static int execAddress = -1;
static char mainBank[128] = {0};
static char outputFile[128] = {0};
static char screenName[128] = {0};
static char tapeName[128] = "Loader";

void usage(void)
{
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "\tzxctl [--debug] --load <address> --exec <address> --main <file>\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "\t--debug            Enable debug logging\n");
    fprintf(stderr, "\t--load <address>   Load address of the main bank (5, 2, 0)\n");
    fprintf(stderr, "\t--exec <address>   Exec address in main bank\n");
    fprintf(stderr, "\t--main <file>      Binary file containing 'main' bank (5, 2, 0)\n");
    fprintf(stderr, "\t--output <file>    Output file name (.tap)\n");
    fprintf(stderr, "\t--screen <file>    Name of the SCREEN$ (.scr) file\n");
    fprintf(stderr, "\t--tape <file>      Name of the basic loader, defaults to 'Loader'\n");
    fprintf(stderr, "\n");

    exit(1);
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

unsigned char *doCompression(unsigned char *input_data, int input_size, int *output_size, int *delta)
{
    int skip = 0;
    unsigned char *output_data;
    int quick_mode = TRUE;
    int backwards_mode = TRUE;
    int classic_mode = TRUE;
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

unsigned char *addBank(char *fileName, int *inputSize, int *outputSize, int *delta)
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

    if (debug)
    {
        printf("\n");
        fprintf(stderr, "Compressing %s ", fileName);
    }
    // Compress data
    outputData = doCompression(inputData, *inputSize, outputSize, delta);
    if (debug)
    {
        printf("Input size        : %d (0x%04x)\n", *inputSize, *inputSize);
        printf("Output size       : %d (0x%04x)\n", *outputSize, *outputSize);
        printf("Delta             : %d\n", *delta);
        printf("Compressed by     : %f%%\n", 100 - (((float)*outputSize / (float)*inputSize) * 100));
        printf("\n");
    }

    return (outputData);
}

int main(int argc, char **argv)
{
    int inputSize;
    int outputSize[7] = {0};
    int delta;
    unsigned char *outputData[7] = {0};
    uint16_t *shortPtr;

    if (argc < 7)
        usage();

    for (int arg = 1; arg < argc; arg++)
    {
        if (strcmp(argv[arg], "--debug") == 0)
        {
            debug = 1;
        }
        else if (strcmp(argv[arg], "--load") == 0)
        {
            if (++arg < argc)
            {
                // get load address
                loadAddress = strtol(argv[arg], NULL, 0);
            }

            if (debug)
                printf("Load address: %-5d (0x%04x)\n", loadAddress, loadAddress);

            if (loadAddress < 0 || loadAddress > 65535)
            {
                fprintf(stderr, "Invalid load address (%d)\n", loadAddress);
                exit(1);
            }
        }
        else if (strcmp(argv[arg], "--exec") == 0)
        {
            if (++arg < argc)
            {
                // get exec address
                execAddress = strtol(argv[arg], NULL, 0);
            }

            if (debug)
                printf("Exec address: %-5d (0x%04x)\n", execAddress, execAddress);

            if (execAddress < 0 || execAddress > 65535)
            {
                fprintf(stderr, "Invalid exec address (%d)\n", execAddress);
                exit(1);
            }
        }
        else if (strcmp(argv[arg], "--main") == 0)
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
        else if (strcmp(argv[arg], "--output") == 0)
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
        else if (strcmp(argv[arg], "--screen") == 0)
        {
            if (++arg < argc)
            {
                strcpy(screenName, argv[arg]);
            }

            if (debug)
                printf("Screen file : %s\n", screenName);

            if (screenName[0] == 0)
            {
                fprintf(stderr, "Invalid screen file name\n");
                exit(1);
            }
        }
        else if (strcmp(argv[arg], "--tape") == 0)
        {
            if (++arg < argc)
            {
                strcpy(tapeName, argv[arg]);
            }

            if (debug)
                printf("Tape name   : %s\n", tapeName);

            if (tapeName[0] == 0)
            {
                fprintf(stderr, "Invalid tape name\n");
                exit(1);
            }
        }
    }

    if (screenName[0])
    {
        outputData[0] = addBank(screenName, &inputSize, &outputSize[0], &delta);
        shortPtr = (uint16_t *)&loader_bin[loader_bin_len - 42];
        // loadSize
        *shortPtr++ = bswap_16(htons(outputSize[0]));
        // loadAddr
        *shortPtr++ = bswap_16(htons(0xc000 - delta));
        // destEnd
        *shortPtr++ = bswap_16(htons(0x4000 + inputSize - 1));
    }

    if (mainBank[0])
    {
        outputData[6] = addBank(mainBank, &inputSize, &outputSize[6], &delta);
        // Main bank (5, 2, 0)
        shortPtr = (uint16_t *)&loader_bin[loader_bin_len - 6];
        // loadSize
        *shortPtr++ = bswap_16(htons(outputSize[6]));
        // loadAddr
        *shortPtr++ = bswap_16(htons(loadAddress - delta));
        // destEnd
        *shortPtr++ = bswap_16(htons(loadAddress + inputSize - 1));
    }

    // Patch the loader for this bank
    shortPtr = (uint16_t *)&loader_bin[loader_bin_len - 44];
    // execAddr
    *shortPtr++ = bswap_16(htons(execAddress));

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

    for (int n = 0; n < 7; n++)
    {
        if (outputData[n])
        {
            // Append the compressed data to the end of the tap file
            appendTap(outputData[n], outputSize[n], outputFile);
            //
            free(outputData[n]);
        }
    }
    return (0);
}