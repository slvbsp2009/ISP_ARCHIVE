/**
 * @file dmgunturk.c
 * @brief Gunturk et al. wavelet POCS demosaicing
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
#include <math.h>
#include "basic.h"
#include "dmbilinear.h"
#include "conv.h"


static void SepConv2(float *Dest, float *Temp, 
    int DestPixelStride, int DestRowStride,
    const float *Src, int SrcPixelStride, int SrcRowStride, 
    int Width, int Height, const filter Horiz, const filter Vert)
{
    boundaryext Boundary = GetBoundaryExt("symw");
    int i;
    
    for(i = 0; i < Height; i++)
        Conv1D(Temp + Width*i, 1, Src + SrcRowStride*i, SrcPixelStride,
            Horiz, Boundary, Width);
    
    for(i = 0; i < Width; i++)
        Conv1D(Dest + DestPixelStride*i, DestRowStride, Temp + i, Width,
            Vert, Boundary, Height);
}


static void WaveletTransform(float *CA, float *CH, float *CV, float *CD,
    float *ConvTemp, const float *SrcLow, const float *SrcHigh, 
    int SrcPixelStride, int SrcRowStride, int Width, int Height, 
    const filter h0, const filter h1)
{
    SepConv2(CA, ConvTemp, 1, Width, 
        SrcLow, SrcPixelStride, SrcRowStride,
        Width, Height, h0, h0);
        
    SepConv2(CH, ConvTemp, 1, Width, 
        SrcHigh, SrcPixelStride, SrcRowStride,
        Width, Height, h1, h0);
        
    SepConv2(CV, ConvTemp, 1, Width, 
        SrcHigh, SrcPixelStride, SrcRowStride,
        Width, Height, h0, h1);
        
    SepConv2(CD, ConvTemp, 1, Width, 
        SrcHigh, SrcPixelStride, SrcRowStride,
        Width, Height, h1, h1);
}


static void InverseWaveletTransform(float *Synthesis,
    float *SumTemp, float *ConvTemp, int DestPixelStride, int DestRowStride,
    const float *CA, const float *CH, const float *CV, const float *CD,
    int Width, int Height, const filter g0, const filter g1)
{
    int x, y;
    
    
    SepConv2(SumTemp, ConvTemp, 1, Width, 
        CA, 1, Width, Width, Height, g0, g0);
        
    for(y = 0; y < Height; y++)
        for(x = 0; x < Width; x++)
            Synthesis[DestPixelStride*x + DestRowStride*y] 
                = SumTemp[x + Width*y];
        
    SepConv2(SumTemp, ConvTemp, 1, Width, 
        CH, 1, Width, Width, Height, g1, g0);
    
    for(y = 0; y < Height; y++)
        for(x = 0; x < Width; x++)
            Synthesis[DestPixelStride*x + DestRowStride*y] 
                += SumTemp[x + Width*y];
    
    SepConv2(SumTemp, ConvTemp, 1, Width, 
        CV, 1, Width, Width, Height, g0, g1);
    
    for(y = 0; y < Height; y++)
        for(x = 0; x < Width; x++)
            Synthesis[DestPixelStride*x + DestRowStride*y] 
                += SumTemp[x + Width*y];
    
    SepConv2(SumTemp, ConvTemp, 1, Width, 
        CD, 1, Width, Width, Height, g1, g1);
    
    for(y = 0; y < Height; y++)
        for(x = 0; x < Width; x++)
            Synthesis[DestPixelStride*x + DestRowStride*y] 
                += SumTemp[x + Width*y];
}


/** 
 * @brief Demosaicing using the wavelet POCS method of Gunturk et al.
 *
 * @param Image an initial demosaicing of the image
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-rightmost red pixel
 * @param NumIter number of iterations to perform
 *
 * Image is a float array of the input RGB values of size 
 * 3*Width*Height in planar row-major order.  RedX, RedY are the coordinates
 * of the upper-rightmost red pixel to specify the CFA pattern.
 */
int GunturkDemosaic(float *Image, int Width, int Height, 
    int RedX, int RedY, int NumIter)
{
    /* The wavelet filters */
    static float h0Coeff[3] = {0.25f, 0.5f, 0.25f};    
    static float h1Coeff[3] = {0.25f, -0.5f, 0.25f};
    static float g0Coeff[5] = {-0.125f, 0.25f, 0.75f, 0.25f, -0.125f};
    static float g1Coeff[5] = {0.125f, 0.25f, -0.75f, 0.25f, 0.125f};
    filter h0, h1, g0, g1;
    const int Green = 1 - ((RedX + RedY) & 1);
    const int NumPixels = Width*Height;
    const int RedWidth = (Width + 1 - RedX)/2;
    const int RedHeight = (Height + 1 - RedY)/2;
    const int BlueX = 1 - RedX;
    const int BlueY = 1 - RedY;
    const int BlueWidth = (Width + 1 - BlueX)/2;
    const int BlueHeight = (Height + 1 - BlueY)/2;
    float *OutputRed = Image;
    float *OutputGreen = Image + Width*Height;
    float *OutputBlue = Image + 2*Width*Height;
    float *Mosaiced = NULL, *CA = NULL, *CH = NULL, *CV = NULL, *CD = NULL;
    float *SumTemp = NULL, *ConvTemp = NULL;    
    int i, x, y, Iter, Success = 0;
    
    
    h0 = MakeFilter(h0Coeff, -1, 3);
    h1 = MakeFilter(h1Coeff, -1, 3);
    g0 = MakeFilter(g0Coeff, -2, 5);
    g1 = MakeFilter(g1Coeff, -2, 5);
    
    if(!(Mosaiced = (float *)Malloc(sizeof(float)*NumPixels))
        || !(CA = (float *)Malloc(sizeof(float)*NumPixels))
        || !(CH = (float *)Malloc(sizeof(float)*NumPixels))
        || !(CV = (float *)Malloc(sizeof(float)*NumPixels))
        || !(CD = (float *)Malloc(sizeof(float)*NumPixels))
        || !(SumTemp = (float *)Malloc(sizeof(float)*NumPixels))
        || !(ConvTemp = (float *)Malloc(sizeof(float)*NumPixels)))
        goto Catch;
    
    /* Save a copy of the input mosaiced data as a flattened 2D array */
    CfaFlatten(Mosaiced, Image, Width, Height, RedX, RedY);
    
    /* Copy the wavelet details from the red and blue sublattices */
    WaveletTransform(CA, CH, CV, CD, ConvTemp, 
        OutputGreen + RedX + Width*RedY,
        OutputRed + RedX + Width*RedY,
        2, 2*Width, RedWidth, RedHeight, h0, h1);
    
    InverseWaveletTransform(OutputGreen + RedX + Width*RedY, 
        SumTemp, ConvTemp, 2, 2*Width,
        CA, CH, CV, CD, RedWidth, RedHeight, g0, g1);
    
    WaveletTransform(CA, CH, CV, CD, ConvTemp,
        OutputGreen + BlueX + Width*BlueY,
        OutputBlue + BlueX + Width*BlueY,
        2, 2*Width, BlueWidth, BlueHeight, h0, h1);
    
    InverseWaveletTransform(OutputGreen + BlueX + Width*BlueY, 
        SumTemp, ConvTemp, 2, 2*Width,
        CA, CH, CV, CD, BlueWidth, BlueHeight, g0, g1);
    
    for(Iter = 0; Iter < NumIter; Iter++)
    {
        /* Detail projection, copy green channel details */
        WaveletTransform(CA, CH, CV, CD, ConvTemp,
            OutputRed, OutputGreen,
            1, Width, Width, Height, h0, h1);
        
        InverseWaveletTransform(OutputRed, 
            SumTemp, ConvTemp, 1, Width,
            CA, CH, CV, CD, Width, Height, g0, g1);
        
        WaveletTransform(CA, CH, CV, CD, ConvTemp,
            OutputBlue, OutputGreen,
            1, Width, Width, Height, h0, h1);
        
        InverseWaveletTransform(OutputBlue, 
            SumTemp, ConvTemp, 1, Width,
            CA, CH, CV, CD, Width, Height, g0, g1);
        
        /* Observation projection */
        for(y = 0, i = 0; y < Height; y++)
            for(x = 0; x < Width; x++, i++)
            {
                if(((x + y) & 1) != Green)
                {
                    if((y & 1) == RedY)
                        OutputRed[i] = Mosaiced[i];
                    else
                        OutputBlue[i] = Mosaiced[i];
                }
            }
    }
    
    Success = 1;
Catch:  
    Free(ConvTemp);
    Free(SumTemp);
    Free(CD);
    Free(CV);
    Free(CH);
    Free(CA);
    Free(Mosaiced);
    return Success;
}
