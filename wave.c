#include    <stdio.h>
#include    <string.h>
#include    <stdarg.h>
#include    <stdlib.h>
#include    <unistd.h>

#define WAV_FREQ    (44100)

#define TSTATES(num)     ((WAV_FREQ*(num))/3500000)

#define TRUE    1
#define FALSE   0

// These values are set accordingly with the turbo loader timing and should not be changed
#define TPERIOD0    TSTATES(855)
#define TPERIOD1    TSTATES(1710)
#define TPILOT_P    TSTATES(2168)
#define TEOF        TSTATES(6000)

#define PERIOD0     TSTATES(855)
#define PERIOD1     TSTATES(1710)
#define PILOT_P     TSTATES(2168)

#define SYNC_OFF_P  TSTATES(667)
#define SYNC_ON_P   TSTATES(735)

void writeword(unsigned int i, FILE *fp)
{
    fputc(i % 256, fp);
    fputc(i / 256, fp);
}

/* Writing routines */
void writebyte(unsigned char c, FILE *fp)
{
    fputc(c, fp);
}

void writestring(char *mystring, FILE *fp)
{
    size_t c;

    for (c = 0; c < strlen(mystring); c++)
    {
        writebyte(mystring[c], fp);
    }
}

void writelong(unsigned long i, FILE *fp)
{
    writeword(i % 65536, fp);
    writeword(i / 65536, fp);
}

int zcc_strrcspn(char *s, char *reject)
{
    int index, i;

    index = 0;

    for (i = 1; *s; ++i)
    {
        if (strchr(reject, *s++))
            index = i;
    }

    return index;
}

/* Generic change suffix routine - make sure name is long enough to hold the suffix */
void suffix_change(char *name, const char *suffix)
{
    int index;

    if ((index = zcc_strrcspn(name, "./\\")) && (name[index - 1] == '.'))
        name[index - 1] = 0;

    strcat(name, suffix);
}

/* Useful functions used by many targets */
void exit_log(int code, char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    if (fmt != NULL)
    {
        vfprintf(stderr, fmt, ap);
    }

    va_end(ap);
    exit(code);
}

/* Pilot lenght in standard mode is about 2000 */
void zx_pilot(int pilot_len, int period, FILE *fpout)
{
    int i, j;

    /* Then the beeeep */
    for (j = 0; j < pilot_len; j++)
    {
        for (i = 0; i < period; i++)
            fputc(0xe0, fpout);

        for (i = 0; i < period; i++)
            fputc(0x20, fpout);
    }

    // Sync off
    for (i = 0; i < SYNC_OFF_P; i++)
        fputc(0xe0, fpout);

    // Sync on
    for (i = 0; i < SYNC_ON_P; i++)
        fputc(0x20, fpout);

}

void zx_rawbit(FILE *fpout, int period)
{
    int i;

    for (i = 0; i < period; i++)
        fputc(0xe0, fpout);

    for (i = 0; i < period; i++)
        fputc(0x20, fpout);
}

void zx_rawout(FILE *fpout, unsigned char b)
{
    static unsigned char c[8] =
    { 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01 };
    int i, period;

    for (i = 0; i < 8; i++)
    {
        if (b & c[i])
        {
            /* Experimental MIN limit is 17 */
            period = PERIOD1;
        }
        else
        {
            /* Experimental MIN limit is 7 */
            period = PERIOD0;
        }
        zx_rawbit(fpout, period);
    }
}

/* Add the WAV header to a 44100 Khz RAW sound file */
void raw2wav(char *wavfile)
{
    char rawfilename[FILENAME_MAX + 1];
    FILE *fpin, *fpout;
    int c;
    long i, len;

    strncpy(rawfilename, wavfile, FILENAME_MAX);

    if ((fpin = fopen(wavfile, "rb")) == NULL)
    {
        exit_log(1, "Can't open file %s for wave conversion\n", wavfile);
    }

    if (fseek(fpin, 0, SEEK_END))
    {
        fclose(fpin);
        exit_log(1, "Couldn't determine size of file\n", 1);
    }

    len = ftell(fpin);
    fseek(fpin, 0L, SEEK_SET);
    suffix_change(wavfile, ".wav");

    if ((fpout = fopen(wavfile, "wb")) == NULL)
    {
        exit_log(1, "Can't open output raw audio file %s\n", wavfile);
    }

    /* Now let's think at the WAV file */
    writestring("RIFF", fpout);
    writelong(len + 36, fpout);
    writestring("WAVEfmt ", fpout);
    writelong(0x10, fpout);
    writeword(1, fpout);
    writeword(1, fpout);
    writelong(44100, fpout);
    writelong(44100, fpout);
    writeword(1, fpout);
    writeword(8, fpout);
    writestring("data", fpout);
    writelong(len, fpout);

    for (i = 0; i < len; i++)
    {
        // Small alteration of the square wave to make it look analogue
        // It should be enough for all the emulators to accept it as a valid feed
        // still permitting a good compression rate to the LZ algorithms
        c = getc(fpin);
#if 1
        // Boost volume
        if (c > 0x81)
            fputc(0xff, fpout);
        else if (c < 0x7f)
            fputc(0x00, fpout);
        else
            fputc(c, fpout);  // Add some noise to the silence
#else
        fputc(c, fpout);
#endif
    }

    fclose(fpin);
    fclose(fpout);

    if (unlink(rawfilename) != 0)
        fprintf(stderr, "Warning: Couldn't remove: %s\n", rawfilename);

}

void turbo_one(FILE *fpout)
{
    int i;

    for (i = 0; i < TPERIOD1; i++)
        fputc(0xe0, fpout);
    for (i = 0; i < TPERIOD0; i++)
        fputc(0x20, fpout);
}

void turbo_rawout(FILE *fpout, unsigned char b, int extreme)
{
    static unsigned char c[8] =
    { 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01 };
    int i;

    if (!b && (extreme))
    {
        /* if byte is zero then we shortcut to a single bit ! */
        // Experimental min limit is 14
        zx_rawbit(fpout, TPERIOD1);
        turbo_one(fpout);
    }
    else
    {

        for (i = 0; i < 8; i++)
        {
            if (b & c[i])
                // Experimental min limit is 7
                turbo_one(fpout);
            else
                zx_rawbit(fpout, TPERIOD0);
        }
    }
}

int tap2wav(char *tapFileName, int ROMLoader)
{
    char wavfile[FILENAME_MAX + 1];
    FILE *fpin, *fpout;
    int c, previous;
    int i, blocklen;
    int len;
    int blockcount = 0;
    int turbo = 0;
    int warping = 0;

    /* ***************************************** */
    /*  Now, if requested, create the audio file */
    /* ***************************************** */
    if ((fpin = fopen(tapFileName, "rb")) == NULL)
    {
        exit_log(1, "Can't open file %s for wave conversion\n", tapFileName);
    }

    if (fseek(fpin, 0, SEEK_END))
    {
        fclose(fpin);
        exit_log(1, "Couldn't determine size of file\n");
    }
    len = ftell(fpin);
    fseek(fpin, 0L, SEEK_SET);

    strcpy(wavfile, tapFileName);
    suffix_change(wavfile, ".RAW");
    if ((fpout = fopen(wavfile, "wb")) == NULL)
    {
        exit_log(1, "Can't open output raw audio file %s\n", wavfile);
    }

    /* Data blocks */
    while (ftell(fpin) < len)
    {
        blocklen = (getc(fpin) + 256 * getc(fpin));

        if (blocklen == 19)
            printf("Header found, length : %-5d Byte(s) ", blocklen);
        else
            printf("Block found, length  : %-5d Byte(s) ", blocklen);

        if (blockcount < 2 || ROMLoader)
        {
            printf("- Not turbo");
            turbo = 0;
        }
        else
        {
            printf("- Turbo");
            turbo = 1;
        }
#if 0
        // Drop the flag and update size for turbo mode
        if (turbo)
        {
            c = getc(fpin);
            // No flag or parity bytes for turbo mode
            blocklen -= 2;
        }

        if (turbo)
            zx_pilot(500, TPILOT_P, fpout);
        else
#endif
            zx_pilot(2500, PILOT_P, fpout);

        previous = -1;

        for (i = 0; (i < blocklen); i++)
        {
            c = getc(fpin);

            if (turbo)
            {
#if 0
                if (previous == c)
                {
                    if (!warping)
                    {
                        warping = TRUE;
                        zx_rawbit(fpout, TPERIOD1);
                        zx_rawbit(fpout, TPERIOD0);
                    }
                    else
                        zx_rawbit(fpout, TPERIOD0);
                }
                else
                {
                    if (warping)
                    {
                        turbo_one(fpout);
                        warping = FALSE;
                    }
                    turbo_rawout(fpout, c, 1);
                }
#else
                turbo_rawout(fpout, c, 0);
#endif
            }
            else
                zx_rawout(fpout, c);

            previous = c;
        }

        // Drop parity byte for turbo mode
#if 0
        if (turbo)
        {
            zx_rawbit(fpout, TPERIOD0);
            zx_rawbit(fpout, TEOF);
            c = getc(fpin);
        }
#endif

        // Trailing silence, larger time may be needed for decompression
        for (i = 0; i < 44100 / 2; i++)
            fputc(0x80, fpout);

        printf("\n");
        blockcount++;
    }

    fclose(fpin);
    fclose(fpout);

    /* Now complete with the WAV header */
    raw2wav(wavfile);

    return 0;
}
