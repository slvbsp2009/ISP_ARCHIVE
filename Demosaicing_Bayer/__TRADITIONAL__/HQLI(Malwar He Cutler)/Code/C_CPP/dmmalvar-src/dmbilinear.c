/**
 * @file dmbilinear.c
 * @brief Bilinear demosaicing
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

#include "dmbilinear.h"


/**
 * @brief Flatten a CFA-filtered image to a 2D array
 * @param Flat the output 2D array of size Width by Height
 * @param Input the input RGB image in planar row-major order
 * @param Width, Height size of the image
 * @param RedX, RedY the coordinates of the upper-rightmost red pixel
 */
void CfaFlatten(float *Flat, const float *Input, int Width, int Height, 
    int RedX, int RedY)
{
    const float *InputRed = Input;
    const float *InputGreen = Input + Width*Height;
    const float *InputBlue = Input + 2*Width*Height;
    const int Green = 1 - ((RedX + RedY) & 1);
    int i, x, y;

    
    for(y = 0, i = 0; y < Height; y++)
        for(x = 0; x < Width; x++, i++)
        {
            if(((x + y) & 1) == Green)
                Flat[i] = InputGreen[i];
            else if((y & 1) == RedY)
                Flat[i] = InputRed[i];
            else 
                Flat[i] = InputBlue[i];
        }
}


/** 
 * @brief Bilinearly interpolate (Red - Green) and (Blue - Green) differences
 * @param Output output image with the green channel already filled
 * @param Diff 2D array of (Red - Green) and (Blue - Green) differences
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-rightmost red pixel
 */
void BilinearDifference(float *Output, const float *Diff,
    int Width, int Height, int RedX, int RedY)
{
    const int NumPixels = Width*Height;
    const int Green = 1 - ((RedX + RedY) & 1);
    float *OutputRed = Output;
    float *OutputGreen = Output + NumPixels;
    float *OutputBlue = Output + 2*NumPixels;
    float AverageH, AverageV, AverageX;
    int x, y, i;
    
    
    for(y = 0, i = 0; y < Height; y++)
    {
        for(x = 0; x < Width; x++, i++)
        {
            if(y == 0)
            {
                AverageV = Diff[i + Width];
                
                if(x == 0)
                {
                    AverageH = Diff[i + 1];
                    AverageX = Diff[i + 1 + Width];
                }
                else if(x < Width - 1)
                {
                    AverageH = (Diff[i - 1] + Diff[i + 1]) / 2;
                    AverageX = (Diff[i - 1 + Width] + Diff[i + 1 + Width]) / 2;
                }
                else 
                {
                    AverageH = Diff[i - 1];
                    AverageX = Diff[i - 1 + Width];
                }
                
            }
            else if(y < Height - 1)
            {
                AverageV = (Diff[i - Width] + Diff[i + Width]) / 2;
                
                if(x == 0)
                {
                    AverageH = Diff[i + 1];
                    AverageX = (Diff[i + 1 - Width] + Diff[i + 1 + Width]) / 2;
                }
                else if(x < Width - 1)
                {
                    AverageH = (Diff[i - 1] + Diff[i + 1]) / 2;
                    AverageX = (Diff[i - 1 - Width] + Diff[i + 1 - Width]
                        + Diff[i - 1 + Width] + Diff[i + 1 + Width]) / 4;
                }
                else 
                {
                    AverageH = Diff[i - 1];
                    AverageX = (Diff[i - 1 - Width] + Diff[i - 1 + Width]) / 2;
                }
            }
            else
            {
                AverageV = Diff[i - Width];
                
                if(x == 0)
                {
                    AverageH = Diff[i + 1];
                    AverageX = Diff[i + 1 - Width];
                }
                else if(x < Width - 1)
                {
                    AverageH = (Diff[i - 1] + Diff[i + 1]) / 2;
                    AverageX = (Diff[i - 1 - Width] + Diff[i + 1 - Width]) / 2;
                }
                else 
                {
                    AverageH = Diff[i - 1];
                    AverageX = Diff[i - 1 - Width];
                }
            }

            if(((x + y) & 1) == Green)
            {
                if((y & 1) == RedY)
                {
                    /* Left and right neighbors are red */
                    OutputRed[i] = OutputGreen[i] + AverageH;
                    OutputBlue[i] = OutputGreen[i] + AverageV;
                }
                else
                {
                    /* Left and right neighbors are blue */
                    OutputRed[i] = OutputGreen[i] + AverageV;
                    OutputBlue[i] = OutputGreen[i] + AverageH;
                }
            }
            else
            {
                if((y & 1) == RedY)
                {
                    /* Center pixel is red */
                    OutputRed[i] = OutputGreen[i] + Diff[i];
                    OutputBlue[i] = OutputGreen[i] + AverageX;
                }
                else
                {
                    /* Center pixel is blue */
                    OutputRed[i] = OutputGreen[i] + AverageX;
                    OutputBlue[i] = OutputGreen[i] + Diff[i];
                }
            }            
        }
    }
}


/** 
 * @brief Bilinear demosaicing
 * @param Output pointer to memory to store the demosaiced image
 * @param Input the input image as a flattened 2D array
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-rightmost red pixel
 *
 * Bilinear demosaicing is considered to be the simplest demosaicing method and
 * is used as a baseline for comparing more sophisticated methods.
 *
 * The Input image is a 2D float array of the input RGB values of size 
 * Width*Height in row-major order.  RedX, RedY are the coordinates of the 
 * upper-rightmost red pixel to specify the CFA pattern.
 */
void BilinearDemosaic(float *Output, const float *Input, int Width, int Height, 
    int RedX, int RedY)
{
    float *OutputRed = Output;
    float *OutputGreen = Output + Width*Height;
    float *OutputBlue = Output + 2*Width*Height;
    const int Green = 1 - ((RedX + RedY) & 1);
    float AverageH, AverageV, AverageC, AverageX;
    int i, x, y;
        

    for(y = 0, i = 0; y < Height; y++)
    {
        for(x = 0; x < Width; x++, i++)
        {
            if(y == 0)
            {
                AverageV = Input[i + Width];
                
                if(x == 0)
                {
                    AverageH = Input[i + 1];
                    AverageC = (Input[i + 1] + Input[i + Width])/2;
                    AverageX = Input[i + 1 + Width];
                }
                else if(x < Width - 1)
                {
                    AverageH = (Input[i - 1] + Input[i + 1]) / 2;
                    AverageC = (Input[i - 1] + Input[i + 1] 
                        + Input[i + Width])/3;
                    AverageX = (Input[i - 1 + Width] 
                        + Input[i + 1 + Width]) / 2;
                }
                else 
                {
                    AverageH = Input[i - 1];
                    AverageC = (Input[i - 1] + Input[i + Width])/2;
                    AverageX = Input[i - 1 + Width];
                }
            }
            else if(y < Height - 1)
            {
                AverageV = (Input[i - Width] + Input[i + Width]) / 2;
                
                if(x == 0)
                {
                    AverageH = Input[i + 1];
                    AverageC = (Input[i + 1] + 
                        Input[i - Width] + Input[i + Width]) / 3;
                    AverageX = (Input[i + 1 - Width] 
                        + Input[i + 1 + Width]) / 2;
                }
                else if(x < Width - 1)
                {
                    AverageH = (Input[i - 1] + Input[i + 1]) / 2;
                    AverageC = (AverageH + AverageV) / 2;
                    AverageX = (Input[i - 1 - Width] + Input[i + 1 - Width]
                        + Input[i - 1 + Width] + Input[i + 1 + Width]) / 4;
                }
                else 
                {
                    AverageH = Input[i - 1];
                    AverageC = (Input[i - 1] + 
                        Input[i - Width] + Input[i + Width]) / 3;
                    AverageX = (Input[i - 1 - Width] 
                        + Input[i - 1 + Width]) / 2;
                }
            }
            else
            {
                AverageV = Input[i - Width];
                
                if(x == 0)
                {
                    AverageH = Input[i + 1];
                    AverageC = (Input[i + 1] + Input[i - Width]) / 2;
                    AverageX = Input[i + 1 - Width];
                }
                else if(x < Width - 1)
                {
                    AverageH = (Input[i - 1] + Input[i + 1]) / 2;
                    AverageC = (Input[i - 1] 
                        + Input[i + 1] + Input[i - Width]) / 3;
                    AverageX = (Input[i - 1 - Width] 
                        + Input[i + 1 - Width]) / 2;
                }
                else 
                {
                    AverageH = Input[i - 1];
                    AverageC = (Input[i - 1] + Input[i - Width]) / 2;
                    AverageX = Input[i - 1 - Width];
                }
            }
            
            if(((x + y) & 1) == Green)
            {
                /* Center pixel is green */
                OutputGreen[i] = Input[i];
                
                if((y & 1) == RedY)
                {
                    /* Left and right neighbors are red */
                    OutputRed[i] = AverageH;
                    OutputBlue[i] = AverageV;
                }
                else
                {
                    /* Left and right neighbors are blue */
                    OutputRed[i] = AverageV;
                    OutputBlue[i] = AverageH;
                }
            }
            else
            {
                OutputGreen[i] = AverageC;
                
                if((y & 1) == RedY)
                {
                    /* Center pixel is red */
                    OutputRed[i] = Input[i];
                    OutputBlue[i] = AverageX;
                }
                else
                {
                    /* Center pixel is blue */
                    OutputRed[i] = AverageX;
                    OutputBlue[i] = Input[i];
                }
            }
        }
    }
}
