/**
 * @file mosaic.c 
 * @brief Tool for mosaicing images with the Bayer CFA
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * 
 * Copyright (c) 2010-2011, Pascal Getreuer
 * All rights reserved.
 * 
 * This program is free software: you can use, modify and/or 
 * redistribute it under the terms of the simplified BSD License. You 
 * should have received a copy of this license along this program. If 
 * not, see <http://www.opensource.org/licenses/bsd-license.html>.
 */

#include <string.h>
#include <ctype.h>
#include "imageio.h"


typedef struct
{
    uint32_t *Data;
    int Width;
    int Height;
} image;

/** @brief struct of program parameters */
typedef struct
{
    /** @brief Input file name */
    char *InputFile;
    /** @brief Output file name */
    char *OutputFile;
    /** @brief Quality for saving JPEG images (0 to 100) */
    int JpegQuality;
    /** @brief CFA pattern upperleftmost red pixel x-coordinate */
    int RedX;
    /** @brief CFA pattern upperleftmost red pixel y-coordinate */
    int RedY;    
    /** @brief If nonzero, flatten result to a grayscale image */
    int Flatten;
    /** @brief Padding on all borders with whole-sample symmetric extension */
    int Padding;
    /** @brief Add one extra row on the top */
    int ExtraRow;
    /** @brief Add one extra column on the left */
    int ExtraColumn;
    /** @brief Verbose output */
    int Verbose;    
} programparams;


static int ParseParams(programparams *Param, int argc, char *argv[]);


/** @brief Print program usage help message */
static void PrintHelpMessage()
{
    printf("Image mosaicing utility, P. Getreuer 2010-2011\n\n");
    printf("Usage: mosaic [options] <input file> <output file>\n\n"
        "Only " READIMAGE_FORMATS_SUPPORTED " images are supported.\n\n");
    printf("Options:\n");
    printf("   -p <pattern>  CFA pattern, choices for <pattern> are\n");
    printf("                 RGGB        upperleftmost red pixel is at (0,0)\n");
    printf("                 GRBG        upperleftmost red pixel is at (1,0)\n");
    printf("                 GBRG        upperleftmost red pixel is at (0,1)\n");
    printf("                 BGGR        upperleftmost red pixel is at (1,1)\n\n");
    printf("   -f            Flatten result to a grayscale image\n");
    printf("   -r            Add one extra row to the top\n");
    printf("   -c            Add one extra column to the left\n");
    printf("   -e <padding>  Add <padding> pixels to each border of the image\n");    
    printf("   -v            Verbose output\n\n");
#ifdef LIBJPEG_SUPPORT
    printf("   -q <number>   Quality for saving JPEG images (0 to 100)\n\n");
#endif
    printf("Example: \n"
        "   mosaic -v -p RGGB frog.bmp frog-m.bmp\n");
}


/**
 * @brief Boundary handling function for whole-sample symmetric extension
 * @param N is the data length
 * @param n is an index into the data
 * @return an index that is always between 0 and N - 1
 */
static int WSymExtension(int N, int n)
{
    while(1)
    {
        if(n < 0)
            n = -n;
        else if(n >= N)        
            n = (2*N - 2) - n;
        else
            return n;
    }
}


int main(int argc, char *argv[])
{
    programparams Param;
    image u = {NULL, 0, 0}, f = {NULL, 0, 0};
    uint32_t Pixel;
    int i, x, y, xOffset, yOffset, Green, Status = 1;
    int MaxShow = 2;
    char FillNext = ' ';
   
    
    if(!ParseParams(&Param, argc, argv))
        return 0;
    
    Green = 1 - ((Param.RedX + Param.RedY) & 1);    
        
    /* Read the input image */
    if(!(u.Data = (uint32_t *)ReadImage(&u.Width, &u.Height, Param.InputFile, 
        IMAGEIO_U8 | IMAGEIO_RGBA)))
        goto Catch;
    
    f.Width = u.Width + 2*Param.Padding + Param.ExtraColumn;
    f.Height = u.Height + 2*Param.Padding + Param.ExtraRow;
    
    if(!(f.Data = (uint32_t *)Malloc(sizeof(uint32_t)*f.Width*f.Height)))
        goto Catch;
    
    xOffset = Param.Padding + Param.ExtraColumn;
    yOffset = Param.Padding + Param.ExtraRow;
    
    if(Param.Verbose)
        printf("Resampling with pattern\n\n");
        
    /* Mosaic the image */
    for(y = 0; y < f.Height; y++)
        for(x = 0; x < f.Width; x++)
        {
            Pixel = u.Data[WSymExtension(u.Width, x - xOffset)
                + u.Width*WSymExtension(u.Height, y - yOffset)];            
            
            if(Param.Verbose && x <= xOffset + 2 && y <= yOffset + 2)
            {
                if((x < MaxShow || x >= xOffset) 
                    && (y < MaxShow || y >= yOffset))
                {
                    if(y == yOffset && x == xOffset)
                    {
                        printf("[");
                        FillNext = ']';
                    }
                    else
                    {
                        printf("%c", FillNext);
                        FillNext = ' ';
                    }
                                    
                    if(((x + y) & 1) == Green)
                        printf("G");
                    else if((y & 1) == Param.RedY)
                        printf("R");
                    else
                        printf("B");
                        
                    if(x == xOffset + 2)
                    {
                        if(y == 0 || (yOffset > MaxShow && y == yOffset))
                            printf("...");
                        
                        printf("\n");
                                                
                        if(y == MaxShow - 1 && yOffset > MaxShow)
                        {
                            if(xOffset <= MaxShow)
                                i = xOffset + 3;
                            else
                                i = MaxShow + 4;
                            
                            while(i--)
                                printf(" :");
                            
                            printf("\n");
                        }
                    }
                        
                    
                    if(x == MaxShow - 1 && xOffset > MaxShow)
                    {
                        printf("..");
                        FillNext = '.';
                    }
                }
            }
            
            if(!Param.Flatten)
            {
                if(((x + y) & 1) == Green)
                    ((uint8_t *)&Pixel)[0] = ((uint8_t *)&Pixel)[2] = 0;
                else if((y & 1) == Param.RedY)
                    ((uint8_t *)&Pixel)[1] = ((uint8_t *)&Pixel)[2] = 0;
                else
                    ((uint8_t *)&Pixel)[0] = ((uint8_t *)&Pixel)[1] = 0;
            }
            else
            {
                if(((x + y) & 1) == Green)
                    ((uint8_t *)&Pixel)[0] = 
                    ((uint8_t *)&Pixel)[2] = ((uint8_t *)&Pixel)[1];
                else if((y & 1) == Param.RedY)
                    ((uint8_t *)&Pixel)[1] = 
                    ((uint8_t *)&Pixel)[2] = ((uint8_t *)&Pixel)[0];
                else
                    ((uint8_t *)&Pixel)[0] = 
                    ((uint8_t *)&Pixel)[1] = ((uint8_t *)&Pixel)[2];
            }
            
            ((uint8_t *)&Pixel)[3] = 255;
            
            f.Data[x + f.Width*y] = Pixel;
        }
        
    if(Param.Verbose)
    {
        printf(" ... ");
        
        if(xOffset > MaxShow)
        {
            i = MaxShow - 1;
            
            while(i--)
                printf("  ");
            
            printf("...");
        }
        
        printf("\n\n");
    }
    
    /* Write the output image */
    if(!WriteImage(f.Data, f.Width, f.Height, Param.OutputFile, 
        IMAGEIO_U8 | IMAGEIO_RGBA, Param.JpegQuality))
        goto Catch;
    else if(Param.Verbose)
        printf("Output written to \"%s\".\n", Param.OutputFile);
    
    Status = 0;
Catch:
    Free(f.Data);
    Free(u.Data);
    return Status;
}


static int ParseParams(programparams *Param, int argc, char *argv[])
{
    static char *DefaultOutputFile = (char *)"out.bmp";
    char *OptionString;
    char OptionChar;
    int i;

    
    if(argc < 2)
    {
        PrintHelpMessage();
        return 0;
    }

    /* Set parameter defaults */
    Param->InputFile = 0;
    Param->OutputFile = DefaultOutputFile;
    Param->JpegQuality = 100;
    Param->RedX = 0;
    Param->RedY = 0;
    Param->Flatten = 0;
    Param->Padding = 0;
    Param->ExtraRow = 0;
    Param->ExtraColumn = 0;
    Param->Verbose = 0;
    
    for(i = 1; i < argc;)
    {
        if(argv[i] && argv[i][0] == '-')
        {
            if((OptionChar = argv[i][1]) == 0)
            {
                ErrorMessage("Invalid parameter format.\n");
                return 0;
            }

            if(argv[i][2])
                OptionString = &argv[i][2];
            else if(++i < argc)
                OptionString = argv[i];
            else
            {
                ErrorMessage("Invalid parameter format.\n");
                return 0;
            }
            
            switch(OptionChar)
            {
            case 'p':
                if(!strcmp(OptionString, "RGGB") 
                    || !strcmp(OptionString, "rggb"))
                {
                    Param->RedX = 0;
                    Param->RedY = 0;
                }
                else if(!strcmp(OptionString, "GRBG") 
                    || !strcmp(OptionString, "grbg"))
                {
                    Param->RedX = 1;
                    Param->RedY = 0;
                }
                else if(!strcmp(OptionString, "GBRG") 
                    || !strcmp(OptionString, "gbrg"))
                {
                    Param->RedX = 0;
                    Param->RedY = 1;
                }
                else if(!strcmp(OptionString, "BGGR") 
                    || !strcmp(OptionString, "bggr"))
                {
                    Param->RedX = 1;
                    Param->RedY = 1;
                }
                else
                    ErrorMessage("CFA pattern must be RGGB, GRBG, GBRG, or BGGR\n");
                break;
            case 'f':
                Param->Flatten = 1;
                i--;
                break;
            case 'e':
                Param->Padding = atoi(OptionString);

                if(Param->Padding < 0)
                {
                    ErrorMessage("Padding must be nonnegative.\n");
                    return 0;
                }
                break;
            case 'r':
                Param->ExtraRow = 1;
                i--;
                break;
            case 'c':
                Param->ExtraColumn = 1;
                i--;
                break;
            case 'v':
                Param->Verbose = 1;
                i--;
                break;
            
#ifdef LIBJPEG_SUPPORT
            case 'q':
                Param->JpegQuality = atoi(OptionString);

                if(Param->JpegQuality <= 0 || Param->JpegQuality > 100)
                {
                    ErrorMessage("JPEG quality must be between 0 and 100.\n");
                    return 0;
                }
                break;
#endif
            case '-':
                PrintHelpMessage();
                return 0;
            default:
                if(isprint(OptionChar))
                    ErrorMessage("Unknown option \"-%c\".\n", OptionChar);
                else
                    ErrorMessage("Unknown option.\n");

                return 0;
            }

            i++;
        }
        else
        {
            if(!Param->InputFile)
                Param->InputFile = argv[i];
            else
                Param->OutputFile = argv[i];

            i++;
        }
    }
    
    if(!Param->InputFile)
    {
        PrintHelpMessage();
        return 0;
    }
    
    if(!Param->Verbose)
        return 1;

        
    return 1;
}
