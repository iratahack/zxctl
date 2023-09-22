// bin2rem version 2.1 - Jan 2008
// by Paolo Ferraris pieffe8_at_libero.it
// public domain

#include <stdio.h>
#include <iostream>
#include <string>

extern "C" void bin2rem(unsigned char *loader, int size, char *fileName, char *tapeName);
extern "C" void appendTap(unsigned char *outputData, int outputSize, char *fileName);

using namespace std;

void error(string s)
{
    cerr << s << endl;
    exit(1);
}

string word2chars(int num)
{
    return string(1, num % 256) + char(num / 256);
}

void writeBlock(string stringa, int tipo, FILE *fil)
{
    string st = string(1, tipo) + stringa;
    int chksum = 0;

    for (unsigned int z = 0; z < st.size(); z++)
        chksum = chksum ^ st[z];

    st = word2chars(st.size() + 1) + st + char(chksum);
    fwrite(st.c_str(), 1, st.size(), fil);
}

void writeTap(string output, string filename, string outputFile)
{
    int autorun = 0;

    FILE *fout = fopen(outputFile.c_str(), "wb");
    if (!fout)
        error("Error opening the output file `" + outputFile + "'");

    string header = string(1, 0) + filename + word2chars(output.size()) + word2chars(autorun) + word2chars(output.size());
    writeBlock(header, 0, fout);
    writeBlock(output, 255, fout);

    fclose(fout);
}

void appendTap(unsigned char *outputData, int outputSize, char *fileName)
{
    string output((const char*) outputData, outputSize);
    string outputFile((const char*) fileName);

    FILE *fout = fopen(outputFile.c_str(), "a");
    if (!fout)
        error("Error opening the output file `" + outputFile + "'");

    writeBlock(output, 255, fout);

    fclose(fout);
}

void bin2rem(unsigned char *loader, int size, char *fileName, char *tapeName)
{
//
//    --------------------------------------------------------------------------
//    byte  | addresses | value                  | comment
//    --------------------------------------------------------------------------
//     0-3                0                        Line number and length
//      4      23759      OVER
//      5      23760      USR
//      6      23761      char '7'                 visible number,
//      7      23762      byte 14                  FP number follows
//     8-10   23763-65    23766 as a truncated
//                        FP number (see below)
//
//    A few comments about this BASIC command.
//
//    1) Number 23766 shows just as digit 7 in BASIC editor. Showing just a digit
//       is a well-known "camouflaging" technique, and also saves memory.
//    2) Bytes 8-10 form, with bytes 11-12 that come from the input, a floating
//       point number that, when rounded, equals 23766.
//
    unsigned char basic[] =
    { 0x00, 0x00, 0x00, 0x00, 0xde, 0xc0, 0x37, 0x0e, 0x8f, 0x39, 0xac };

    // Pad tape name to 10 characters
    string name(tapeName);
    while (name.length() < 10)
        name += ' ';

    string machineCode((const char*) loader, size);
    string basicHeader = string((const char*) basic, 11);
    string output = basicHeader + machineCode;

    writeTap(output, name, fileName);
}
