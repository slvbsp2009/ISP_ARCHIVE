/**
 * @file dmha.c
 * @brief Hamilton-Adams demosaicing
 * @author Pascal Getreuer <getreuer@gmail.com>
 *
 * 
 * Copyright (c) 2011, Pascal Getreuer <getreuer@gmail.com>
 * All rights reserved.
 *
 * This file implements an algorithm possibly linked to the patent
 * U.S. Patent 5629734, “Adaptive color plan interpolation in single 
 * sensor color electronic camera" by J. F. Hamilton, Jr. and J. E. 
 * Adams, Jr.
 * 
 * This file is made available for the exclusive aim of serving as 
 * scientific tool to verify the soundness and completeness of the 
 * algorithm description. Compilation, execution and redistribution of
 * this file may violate patents rights in certain countries.  The 
 * situation being different for every country and changing over time,
 * it is your responsibility to determine which patent rights 
 * restrictions apply to you before you compile, use, modify, or 
 * redistribute this file. A patent lawyer is qualified to make this 
 * determination.  If and only if they don't conflict with any patent 
 * terms, you can benefit from the following license terms attached to
 * this file.
 * 
 * This program is provided for scientific and educational only: you 
 * can use and/or modify it for these purposes, but you are not allowed
 * to redistribute this work or derivative works in source or 
 * executable form. A license must be obtained from the patent right 
 * holders for any other use.
 */

#include <math.h>
#include "basic.h"
#include "dmbilinear.h"


/** 
 * @brief Demosaicing with Hamilton-Adams
 * @param Output pointer to memory to store the demosaiced image
 * @param Input the input image
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-rightmost red pixel
 *
 * The Input image is a 2D float array of the input RGB values of size 
 * Width*Height in row-major order.  RedX, RedY are the coordinates of the 
 * upper-rightmost red pixel to specify the CFA pattern.
 */
int HamiltonAdamsDemosaic(float *Output, const float *Input, 
    int Width, int Height, int RedX, int RedY)
{
    const float Threshold = 2/255.0f;
    const int Green = 1 - ((RedX + RedY) & 1);
    const int Width2 = Width*2;
    const int NumPixels = Width*Height;
    float *OutputGreen = Output + NumPixels;
    float *Diff = NULL;
    float VariationH, VariationV;
    int i, x, y;

    
    if(!(Diff = (float *)Malloc(sizeof(float)*NumPixels)))
        return 0;
    
    /* Use bilinear demosaicing to interpolate pixels near the borders */
    BilinearDemosaic(Output, Input, Width, Height, RedX, RedY);

    for(y = 2; y < Height - 2; y++)
        for(x = 2; x < Width - 2; x++)
        {
            i = x + Width*y;
            
            if(((x + y) & 1) != Green)
            {
                VariationH = (float)(fabs(Input[i - 2]
                    - 2*Input[i] + Input[i + 2])
                    + fabs(Input[i - 1] - Input[i + 1]));
                VariationV = (float)(fabs(Input[i - Width*2]
                    - 2*Input[i] + Input[i + Width*2])
                    + fabs(Input[i - Width] - Input[i + Width]));

                if(fabs(VariationH - VariationV) < Threshold)
                    OutputGreen[i] = (4*Input[i]
                        + 2*(Input[i - Width] + Input[i + Width]
                        + Input[i - 1] + Input[i + 1])
                        - Input[i - Width2] - Input[i + Width2]
                        - Input[i - 2] - Input[i + 2]) / 8;
                else if(VariationH < VariationV)
                    OutputGreen[i] = 
                        (2*(Input[i - 1] + Input[i] + Input[i + 1])
                        - Input[i - 2] - Input[i + 2]) / 4;
                else
                    OutputGreen[i] = 
                        (2*(Input[i - Width] + Input[i] + Input[i + Width])
                        - Input[i - Width2] - Input[i + Width2]) / 4;
            }
            else
                OutputGreen[i] = Input[i];
        }
    
    for(i = 0; i < NumPixels; i++)
        Diff[i] = Input[i] - OutputGreen[i];
    
    /* Bilinearly interpolate (Red - Green) and (Blue - Green) differences */
    BilinearDifference(Output, Diff, Width, Height, RedX, RedY);
    
    Free(Diff);
    return 1;
}
