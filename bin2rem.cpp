// bin2rem version 2.1 - Jan 2008
// by Paolo Ferraris pieffe8_at_libero.it
// public domain

#include <stdio.h>
#include <iostream>
#include <string>

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
    for (unsigned int z = 0; z < st.size(); z++)
        putc(st[z], fil);
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
    string output((const char *)outputData, outputSize);
    string outputFile((const char *)fileName);

    FILE *fout = fopen(outputFile.c_str(), "a");
    if (!fout)
        error("Error opening the output file `" + outputFile + "'");

    writeBlock(output, 255, fout);

    fclose(fout);
}

void bin2rem(unsigned char *loader, int size, char *fileName, char *tapeName)
{
    char name[11];

    tapeName[10] = 0;
    sprintf(name, "%-10s", tapeName);

    string basicHeader = "";
    string output = "";
    string lineNumberLength = string(4, 0);
    string machineCode((const char *)loader, size);

    basicHeader += 0xde; // OVER
    basicHeader += 0xc0; // USR
    basicHeader += '7';
    basicHeader += 14; // number begins

    // we need to compute a FP number that, when rounded, gives jump.
    // normally we have 4 bytes for the mantissa, but 2 bytes are actually
    // sufficient to get any integer <65536.
    int exp = 128 + 16; // exp = exponent
    int mant = 23766;   // mant = two most significant bytes of mantissa
    while (mant < 32768)
    {
        exp--;
        mant *= 2;
    }
    mant -= 32768; // discard the most significant bit of mantissa
    // write the number
    basicHeader += exp;
    basicHeader += mant / 256;
    basicHeader += mant % 256;
    output = lineNumberLength + basicHeader + machineCode;

    writeTap(output, name, fileName);
}
