/**
 * @file displaycontours.c
 * @brief Display contours detected by mosaiced contour stencils as EPS
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * Copyright (c) 2010-2011, Pascal Getreuer
 * All rights reserved.
 * 
 * This program is free software: you can use, modify and/or 
 * redistribute it under the terms of the simplified BSD License. You 
 * should have received a copy of this license along this program. If 
 * not, see <http://www.opensource.org/licenses/bsd-license.html>.
 */

#include <stdio.h>
#include <math.h>
#include "basic.h"
#include "imageio.h"
#include "dmbilinear.h"
#include "mstencils.h"
#include "psio.h"

/** @brief Round and clamp float X and scale from [0,1] to [0,255] */
#define ROUNDCLAMP(X) (((X) < 0) ? 0 : (((X) > 1) ? 255 : floor(X*255 + 0.5f)))


/** 
 * @brief Display orientations estimated by mosaiced contour stencils
 * @param Image the input RGB image in planar row-major order
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-leftmost red pixel
 * @param OutputFile EPS file to write
 * @return 1 on success, 0 on failure
 * 
 * @warning For larger images (e.g., over 300x300), the output EPS file is 
 * very large.  Some measures are taken for efficient encoding, but
 * compression is not performed.
 * 
 * This routine writes an EPS file of Image superimposed with the orientations
 * detected by mosaiced contour stencils at each pixel.  This function is
 * called when running the command line program with the -s option.
 * 
 * For visualization purposes, it is recommended to pass an image that has 
 * full color information rather than a mosaiced image (i.e., use the original
 * image or a demosaiced image).  The estimated contour orientations are the 
 * same regardless of whether the input is mosaiced.
 * 
 * Using the Ghostscript program, the EPS output (say, "contours.eps") can be
 * converted to PDF as
@code
gs -dSAFER -q -P- -dCompatibilityLevel=1.4 -dNOPAUSE -dBATCH \
    -sDEVICE=pdfwrite -sOutputFile=contours.pdf -c .setpdfwrite \
    -f contours.eps
@endcode
 * Distiller commands are included within the EPS to preserve the bounding box.
 * PDF conversion applies (lossless) deflate compression to the image data, 
 * which significantly decreases the file size.
 */
int DisplayContours(const float *Image, int Width, int Height, 
    int RedX, int RedY, const char *OutputFile)
{
    const int NumPixels = Width*Height;
    FILE *File = NULL;
    float *Mosaic = NULL;
    int *Stencil = NULL;
    uint8_t *ImageU8 = NULL;
    float Temp, x1, y1, x2, y2;
    int i, x, y, DimScale = 5, Success = 0;
    
    if(!(Mosaic = (float *)Malloc(sizeof(float)*NumPixels))
        || !(Stencil = (int *)Malloc(sizeof(int)*NumPixels))
        || !(ImageU8 = (uint8_t *)Malloc(sizeof(uint8_t)*3*NumPixels))
        /* Start an EPS file with DimScale*Width by DimScale*Height canvas */
        || !(File = PsOpen(OutputFile, 0, 0, 
            DimScale*Width, DimScale*Height)))
        goto Catch;

    CfaFlatten(Mosaic, Image, Width, Height, RedX, RedY);
    /* Estimate the contour orientations */
    FitMosaicedStencils(Stencil, Mosaic, Width, Height, RedX, RedY);

    /* Lighten the image according to 0.5 + 0.5*Image and convert to
       unsigned 8-bit data.                                          */
    for(i = 0; i < NumPixels; i++)
    {
        Temp = 0.5f + 0.5f*Image[i];
        ImageU8[3*i + 0] = (uint8_t)ROUNDCLAMP(Temp);
        Temp = 0.5f + 0.5f*Image[i + NumPixels];
        ImageU8[3*i + 1] = (uint8_t)ROUNDCLAMP(Temp);
        Temp = 0.5f + 0.5f*Image[i + 2*NumPixels];
        ImageU8[3*i + 2] = (uint8_t)ROUNDCLAMP(Temp);
    }

    /* Set distiller parameters for PDF conversion */
    if(!PsSetDistillerParams(File,"/AutoFilterColorImages false "
        "/ColorImageFilter /FlateEncode"))
        goto Catch;
    /* Define PS macros and rescale canvas by DimScale */
    fprintf(File,"/bdef {bind def} bind def\n"
        "/m1 {moveto rlineto stroke} bdef\n"
        "0.08 setlinewidth\n"
        "%d %d scale\n", DimScale, DimScale);
    
    /* Write the image data ImageU8 into the EPS file */
    if(!PsWriteColorImage(File, ImageU8, Width, Height))
        goto Catch;
    
    /* Draw the contour orientations on top of the image */
    for(y = 0, i = 0; y < Height; y++)
        for(x = 0; x < Width; x++, i++)
        {
            x2 = (float)(cos(Stencil[i]*M_PI_8)*0.45);
            y2 = (float)(sin(Stencil[i]*M_PI_8)*0.45);
            x1 = -x2;
            y1 = -y2;
            /* Draw a line from (x + x1 + 0.5, y1 + (Height - y - 0.5))
               to (x + x2 + 0.5, y2 + (Height - y - 0.5)) */
            fprintf(File, "%.2f %.2f %.2f %.2f m1\n",
                x2 - x1, y2 - y1,
                x + x1 + 0.5f, y1 + (Height - y - 0.5f));
        }
    
    /* Finish writing the EPS file */
    if(!PsClose(File))
        goto Catch;
        
    Success = 1;
Catch:
    Free(ImageU8);
    Free(Stencil);
    Free(Mosaic);
    return Success;
}
