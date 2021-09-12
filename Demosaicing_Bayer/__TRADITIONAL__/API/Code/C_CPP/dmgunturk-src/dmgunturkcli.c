/**
 * @file dmgunturkcli.c 
 * @brief Gunturk et al. wavelet POCS demosaicing command line program
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

/**
 * @mainpage
 * @htmlinclude readme.html
 */

#include <math.h>
#include <string.h>
#include <ctype.h>

#include "imageio.h"
#include "dmbilinear.h"
#include "dmgunturk.h"


/** @brief struct of program parameters */
typedef struct
{
    /** @brief Input file name */
    const char *InputFile;
    /** @brief Output file name */
    const char *OutputFile;
    /** @brief Quality for saving JPEG images (0 to 100) */
    int JpegQuality;
    /** @brief Name of the initialization method */
    const char *Initialization;
    /** @brief Name of the CFA pattern */
    const char *PatternName;
    /** @brief CFA pattern upperleftmost red pixel x-coordinate */
    int RedX;
    /** @brief CFA pattern upperleftmost red pixel y-coordinate */
    int RedY;
    /** @brief Number of POCS iterations to perform */
    int NumIter;
} programparams;


static int ParseParams(programparams *Param, int argc, char *argv[]);


/** @brief Print program usage help message */
static void PrintHelpMessage()
{
    printf("Gunturk demosaicing demo, P. Getreuer 2010-2011\n\n");
    printf("Usage: dmgunturk [options] <input file> <output file>\n\n"
        "Only " READIMAGE_FORMATS_SUPPORTED " images are supported.\n\n");
    printf("Options:\n");
    printf("   -p <pattern>  CFA pattern, choices for <pattern> are\n");
    printf("                 RGGB        upperleftmost red pixel is at (0,0)\n");
    printf("                 GRBG        upperleftmost red pixel is at (1,0)\n");
    printf("                 GBRG        upperleftmost red pixel is at (0,1)\n");
    printf("                 BGGR        upperleftmost red pixel is at (1,1)\n");
    printf("   -i <init>     initialization, choices for <init> are \n");
    printf("                 ha          Hamilton-Adams (default, requires dmha)\n");
    printf("                 bilinear    simple bilinear interpolation\n");
    printf("                 input       input file is used as initial demosaicing\n");
    printf("   -n <number>   number of POCS iterations to perform (default 8)\n");
#ifdef LIBJPEG_SUPPORT
    printf("   -q <number>   Quality for saving JPEG images (0 to 100)\n\n");
#endif
    printf("Example: \n"
        "   dmgunturk -p RGGB frog.bmp frog-dm.bmp\n");
}


int main(int argc, char *argv[])
{
    const char *TempFile = "_dmtemp.bmp";
    programparams Param;
    float *Image = NULL, *Flat = NULL;
    char *BinPath = argv[0], *Command = NULL, *Ptr;
    int Width, Height, Status = 1;
    
    
    if(!ParseParams(&Param, argc, argv))
        return 0;

    if(!strcmp(Param.Initialization, "ha"))
    {   /* Initialize with Hamilton-Adams 
         *
         * The following attempts to execute the dmha program.  We test if a
         * command processor is available, allocate and write a command string,
         * then execute the command.  The file TempFile is used to store the
         * intermediate demosaicing produced by dmha.
         */    
         
        /* Test whether a command processor is available */
        if(!system(NULL))   
        {
            ErrorMessage("No command processor available.\n");
            return 0;
        }
        
        /* Guess the path of dmha from argv[0] */
        if((Ptr = strrchr(BinPath, '\\')) || (Ptr = strrchr(BinPath, '/')))
            Ptr[1] = '\0';
        else
            BinPath[0] = '\0';
        
        /* Allocate and write the command string */
        if(!(Command = (char *)Malloc(sizeof(char)*( 14
            + strlen(BinPath) + strlen(Param.PatternName) 
            + strlen(Param.InputFile) + strlen(TempFile)))))
            return 0;
        
        sprintf(Command, "%sdmha -p%s \"%s\" \"%s\"", 
                BinPath, Param.PatternName, Param.InputFile, TempFile);
        
        /* Execute dmha */
        if(system(Command))
        {
            ErrorMessage("Initialization with dmha unsuccessful.\n");
            goto Catch;
        }
        
        /* Read the Hamilton-Adams demosaiced image from TempFile */
        if(!(Image = (float *)ReadImage(&Width, &Height, 
            TempFile, IMAGEIO_FLOAT | IMAGEIO_RGB | IMAGEIO_PLANAR)))
            goto Catch;
        
        /* Delete TempFile (it is unimportant whether remove is successful) */
        remove(TempFile);
    }
    else if(!strcmp(Param.Initialization, "bilinear"))
    {   /* Initialize with bilinear */
        /* Read the mosaic image and allocate array Flat */
        if(!(Image = (float *)ReadImage(&Width, &Height, 
            Param.InputFile, IMAGEIO_FLOAT | IMAGEIO_RGB | IMAGEIO_PLANAR))
            || !(Flat = (float *)Malloc(sizeof(float)*Width*Height)))
            goto Catch;
        
        if(Width < 4 || Height < 4)
        {
            ErrorMessage("Image is too small (%dx%d).\n", Width, Height);
            goto Catch;
        }
        
        /* Flatten the input to a 2D array */
        CfaFlatten(Flat, Image, Width, Height, Param.RedX, Param.RedY);
        /* Perform demosaicing */
        BilinearDemosaic(Image, Flat, Width, Height, Param.RedX, Param.RedY);
    }
    else if(!strcmp(Param.Initialization, "input"))
    {   /* Input file is used as the initial demosaicing */
        if(!(Image = (float *)ReadImage(&Width, &Height, 
            Param.InputFile, IMAGEIO_FLOAT | IMAGEIO_RGB | IMAGEIO_PLANAR)))
            goto Catch;
    }
    else
    {
        ErrorMessage("Unknown initialization, \"%s\".\n", 
            Param.Initialization);
        goto Catch;
    }
    
    if(Width < 4 || Height < 4)
    {
        ErrorMessage("Image is too small (%dx%d).\n", Width, Height);
        goto Catch;
    }
       
    /* Perform Gunturk demosaicing */
    if(!(GunturkDemosaic(Image, Width, Height, 
        Param.RedX, Param.RedY, Param.NumIter)))
        goto Catch;
    
    /* Write the output image */
    if(!WriteImage(Image, Width, Height, Param.OutputFile, 
        IMAGEIO_FLOAT | IMAGEIO_RGB | IMAGEIO_PLANAR, Param.JpegQuality))
        goto Catch; 
    
    Status = 0; /* Finished successfully, set exit status to zero. */
Catch:    
    Free(Flat);
    Free(Image);
    Free(Command);
    return Status;
}


static int ParseParams(programparams *Param, int argc, char *argv[])
{
    static const char *DefaultOutputFile = (char *)"out.bmp";
    static const char *DefaultInitialization = (char *)"ha";
    static const char *DefaultPattern = (char *)"RGGB";    
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
    Param->JpegQuality = 80;
    Param->Initialization = DefaultInitialization;
    Param->PatternName = DefaultPattern;
    Param->RedX = 0;
    Param->RedY = 0;    
    Param->NumIter = 8;
    
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
                
                Param->PatternName = OptionString;
                break;
            case 'n':
                Param->NumIter = atoi(OptionString);

                if(Param->NumIter <= 0)
                {
                    ErrorMessage("Number of iterations must be positive.\n");
                    return 0;
                }
                break;
            case 'i':
                Param->Initialization = OptionString;
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
    
    return 1;
}
