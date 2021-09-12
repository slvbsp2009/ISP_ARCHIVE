/**
 * @file dmcswl1cli.c
 * @brief Contour stencils weighted L1 demosaicing command line program
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
#include "dmcswl1.h"
#include "displaycontours.h"

/* Program defaults */
#define DEFAULT_ALPHA           1.8
#define DEFAULT_EPSILON         0.15
#define DEFAULT_SIGMA           0.6
#define DEFAULT_TOL             0.001
#define DEFAULT_MAXITER         250

/* Print verbose information if nonzero */
#define VERBOSE 1


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
    /** @brief If nonzero, show estimated contours instead of demosaicing */
    int ShowContours;
    /** @brief If nonzero, show energy value after each iteration */
    int ShowEnergy;
    /** @brief Chroma weight */
    float Alpha;
    /** @brief Graph weight */
    float Epsilon;
    /** @brief Graph spatial filtering parameter */
    float Sigma;
    /** @brief Convergence tolerance */
    float Tol;
    /** @brief Maximum number of iterations */
    int MaxIter;
} programparams;


static int ParseParams(programparams *Param, int argc, char *argv[]);


/** @brief Print program usage help message */
static void PrintHelpMessage()
{
    printf("Contour stencils weighted L1 demosaicing demo, P. Getreuer 2010-2011\n\n");
    printf("Usage: dmcswl1 [options] <input file> <output file>\n\n"
           "Only " READIMAGE_FORMATS_SUPPORTED " images are supported.\n\n");
    printf("Options:\n");
    printf("   -p <pattern>  CFA pattern, choices for <pattern> are\n");
    printf("                 RGGB        upperleftmost red pixel is at (0,0)\n");
    printf("                 GRBG        upperleftmost red pixel is at (1,0)\n");
    printf("                 GBRG        upperleftmost red pixel is at (0,1)\n");
    printf("                 BGGR        upperleftmost red pixel is at (1,1)\n\n");
    printf("   -s            Show estimated contours instead of demosaicing.\n"
           "                 The output is written as an EPS file.\n");
    printf("   -E            Display energy value after each iteration.\n\n");
    printf("   -a <number>   alpha, chroma weight (default 1.8)\n");
    printf("   -e <number>   epsilon, graph weight (default 0.15)\n");
    printf("   -f <number>   sigma, graph spatial filtering parameter (default 0.6)\n");
    printf("   -t <number>   convergence tolerance (default 0.001)\n");
    printf("   -m <number>   maximum number of iterations (default 250)\n\n");    
#ifdef LIBJPEG_SUPPORT
    printf("   -q <number>   Quality for saving JPEG images (0 to 100)\n\n");
#endif
    printf("Examples: \n"
        "   dmcswl1 -p RGGB frog.bmp frog-dm.bmp\n"
        "   dmcswl1 -p RGGB -s frog.bmp frog-contours.eps\n");
}


int main(int argc, char *argv[])
{
    programparams Param;
    float *Image = NULL;
    int Width, Height, Status = 1;
        
    if(!ParseParams(&Param, argc, argv))
        return 0;

    /* Read the input image */
    if(!(Image = (float *)ReadImage(&Width, &Height, 
        Param.InputFile, IMAGEIO_FLOAT | IMAGEIO_RGB | IMAGEIO_PLANAR)))
        goto Catch;
    
    if(Width < 4 || Height < 4)
    {
        ErrorMessage("Image is too small (%dx%d).\n", Width, Height);
        goto Catch;
    }
    
    if(Param.ShowContours)
    {    
        if(!(DisplayContours(Image, Width, Height, 
            Param.RedX, Param.RedY, Param.OutputFile)))
            goto Catch;
#if VERBOSE > 0
        else
            printf("Output written to \"%s\".\n", Param.OutputFile);
#endif            
    }
    else
    {   
        /* Perform demosaicing */
        if(!(CSWL1Demosaic(Image, Width, Height, Param.RedX, Param.RedY,
            Param.Alpha, Param.Epsilon, Param.Sigma, 
            Param.Tol, Param.MaxIter, Param.ShowEnergy)))
        {
            ErrorMessage("Error in computation.\n");
            goto Catch;
        }
        
        /* Write the output image */
        if(!WriteImage(Image, Width, Height, Param.OutputFile, 
            IMAGEIO_FLOAT | IMAGEIO_RGB | IMAGEIO_PLANAR, Param.JpegQuality))
        {
            ErrorMessage("Error writing \"%s\".\n", Param.OutputFile);
            goto Catch;
        }
#if VERBOSE > 0
        else
            printf("Output written to \"%s\".\n", Param.OutputFile);
#endif    
    }
    
    Status = 0; /* Finished successfully, set exit status to zero. */
Catch:
    Free(Image);
    return Status;
}


/** @brief Parse program parameters from command line arguments */
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
    Param->JpegQuality = 80;
    Param->RedX = 0;
    Param->RedY = 0;
    Param->ShowContours = 0;
    Param->ShowEnergy = 0;
    Param->Alpha = (float)DEFAULT_ALPHA;
    Param->Epsilon = (float)DEFAULT_EPSILON;
    Param->Sigma = (float)DEFAULT_SIGMA;
    Param->Tol = (float)DEFAULT_TOL;
    Param->MaxIter = DEFAULT_MAXITER;
    
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
            
            switch(OptionChar)  /* Parse option flag */
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
            case 's':
                Param->ShowContours = 1;
                i--;
                break;
            case 'E':
                Param->ShowEnergy = 1;
                i--;
                break;
            case 'a':
                Param->Alpha = (float)atof(OptionString);

                if(Param->Alpha <= 0)
                {
                    ErrorMessage("Chroma weight must be positive.\n");
                    return 0;
                }
                break;
            case 'e':
                Param->Epsilon = (float)atof(OptionString);

                if(Param->Epsilon <= 0)
                {
                    ErrorMessage("Epsilon must be positive.\n");
                    return 0;
                }
                break;
            case 'f':
                Param->Sigma = (float)atof(OptionString);

                if(Param->Sigma < 0)
                {
                    ErrorMessage("Sigma must be nonnegative.\n");
                    return 0;
                }
                break;
            case 't':
                Param->Tol = (float)atof(OptionString);

                if(Param->Tol <= 0)
                {
                    ErrorMessage("Convergence tolerance must be positive.\n");
                    return 0;
                }
                break;
            case 'm':
                Param->MaxIter = atoi(OptionString);

                if(Param->MaxIter < 0)
                {
                    ErrorMessage("Maximum number of iterations must be nonnegative.\n");
                    return 0;
                }
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
