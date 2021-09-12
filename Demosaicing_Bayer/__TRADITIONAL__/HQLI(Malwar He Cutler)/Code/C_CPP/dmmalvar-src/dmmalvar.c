/**
 * @file dmmalvar.c
 * @brief Malvar-He-Cutler demosaicing
 * @author Pascal Getreuer <getreuer@gmail.com>
 *
 * 
 * Copyright (c) 2011, Pascal Getreuer <getreuer@gmail.com>
 * All rights reserved.
 *
 * This file implements an algorithm possibly linked to the patent
 * U.S. Patent 7502505, “High-quality gradient-corrected linear 
 * interpolation for demosaicing of color images."
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


/** 
 * @brief Demosaicing using the 5x5 linear method of Malvar et al.
 * @param Output pointer to memory to store the demosaiced image
 * @param Input the input image as a flattened 2D array
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-rightmost red pixel
 *
 * Malvar, He, and Cutler considered the design of a high quality linear
 * demosaicing method using 5x5 filters.  The method is essentially the 
 * bilinear demosaicing method that is "gradient-corrected" by adding the
 * Laplacian from another channel.  This enables the method to take 
 * advantage of correlation among the RGB channels.
 *
 * The Input image is a 2D float array of the input RGB values of size 
 * Width*Height in row-major order.  RedX, RedY are the coordinates of the 
 * upper-rightmost red pixel to specify the CFA pattern.
 */
void MalvarDemosaic(float *Output, const float *Input, int Width, int Height, 
    int RedX, int RedY)
{
    const int BlueX = 1 - RedX;
    const int BlueY = 1 - RedY;
    float *OutputRed = Output;
    float *OutputGreen = Output + Width*Height;
    float *OutputBlue = Output + 2*Width*Height;
    /* Neigh holds a copy of the 5x5 neighborhood around the current point */
    float Neigh[5][5];
    /* NeighPresence is used for boundary handling.  It is set to 0 if the 
       neighbor is beyond the boundaries of the image and 1 otherwise. */
    int NeighPresence[5][5];
    int i, j, x, y, nx, ny;
    
    
    for(y = 0, i = 0; y < Height; y++)
    {
        for(x = 0; x < Width; x++, i++)
        {
            /* 5x5 neighborhood around the point (x,y) is copied into Neigh */
            for(ny = -2, j = x + Width*(y - 2); ny <= 2; ny++, j += Width)
            {
                for(nx = -2; nx <= 2; nx++)
                {
                    if(0 <= x + nx && x + nx < Width 
                        && 0 <= y + ny && y + ny < Height)
                    {
                        Neigh[2 + nx][2 + ny] = Input[j + nx];
                        NeighPresence[2 + nx][2 + ny] = 1;
                    }
                    else
                    {
                        Neigh[2 + nx][2 + ny] = 0;
                        NeighPresence[2 + nx][2 + ny] = 0;
                    }
                }
            }

            if((x & 1) == RedX && (y & 1) == RedY)
            {
                /* Center pixel is red */
                OutputRed[i] = Input[i];
                OutputGreen[i] = (2*(Neigh[2][1] + Neigh[1][2]
                    + Neigh[3][2] + Neigh[2][3])
                    + (NeighPresence[0][2] + NeighPresence[4][2]
                    + NeighPresence[2][0] + NeighPresence[2][4])*Neigh[2][2] 
                    - Neigh[0][2] - Neigh[4][2]
                    - Neigh[2][0] - Neigh[2][4])
                    / (2*(NeighPresence[2][1] + NeighPresence[1][2]
                    + NeighPresence[3][2] + NeighPresence[2][3]));
                OutputBlue[i] = (4*(Neigh[1][1] + Neigh[3][1]
                    + Neigh[1][3] + Neigh[3][3]) +
                    3*((NeighPresence[0][2] + NeighPresence[4][2]
                    + NeighPresence[2][0] + NeighPresence[2][4])*Neigh[2][2] 
                    - Neigh[0][2] - Neigh[4][2]
                    - Neigh[2][0] - Neigh[2][4])) 
                    / (4*(NeighPresence[1][1] + NeighPresence[3][1]
                    + NeighPresence[1][3] + NeighPresence[3][3]));
            }
            else if((x & 1) == BlueX && (y & 1) == BlueY)
            {
                /* Center pixel is blue */
                OutputBlue[i] = Input[i];
                OutputGreen[i] = (2*(Neigh[2][1] + Neigh[1][2]
                    + Neigh[3][2] + Neigh[2][3])
                    + (NeighPresence[0][2] + NeighPresence[4][2]
                    + NeighPresence[2][0] + NeighPresence[2][4])*Neigh[2][2] 
                    - Neigh[0][2] - Neigh[4][2]
                    - Neigh[2][0] - Neigh[2][4])
                    / (2*(NeighPresence[2][1] + NeighPresence[1][2]
                    + NeighPresence[3][2] + NeighPresence[2][3]));
                OutputRed[i] = (4*(Neigh[1][1] + Neigh[3][1]
                    + Neigh[1][3] + Neigh[3][3]) +
                    3*((NeighPresence[0][2] + NeighPresence[4][2]
                    + NeighPresence[2][0] + NeighPresence[2][4])*Neigh[2][2] 
                    - Neigh[0][2] - Neigh[4][2]
                    - Neigh[2][0] - Neigh[2][4])) 
                    / (4*(NeighPresence[1][1] + NeighPresence[3][1]
                    + NeighPresence[1][3] + NeighPresence[3][3]));
            }
            else
            {
                /* Center pixel is green */
                OutputGreen[i] = Input[i];
                
                if((y & 1) == RedY)
                {
                    /* Left and right neighbors are red */
                    OutputRed[i] = (8*(Neigh[1][2] + Neigh[3][2])
                        + (2*(NeighPresence[1][1] + NeighPresence[3][1]
                        + NeighPresence[0][2] + NeighPresence[4][2]
                        + NeighPresence[1][3] + NeighPresence[3][3])
                        - NeighPresence[2][0] - NeighPresence[2][4])*Neigh[2][2]
                        - 2*(Neigh[1][1] + Neigh[3][1]
                        + Neigh[0][2] + Neigh[4][2]
                        + Neigh[1][3] + Neigh[3][3])
                        + Neigh[2][0] + Neigh[2][4]) 
                        / (8*(NeighPresence[1][2] + NeighPresence[3][2]));
                    OutputBlue[i] = (8*(Neigh[2][1] + Neigh[2][3])
                        + (2*(NeighPresence[1][1] + NeighPresence[3][1]
                        + NeighPresence[2][0] + NeighPresence[2][4]
                        + NeighPresence[1][3] + NeighPresence[3][3])
                        - NeighPresence[0][2] - NeighPresence[4][2])*Neigh[2][2]
                        - 2*(Neigh[1][1] + Neigh[3][1]
                        + Neigh[2][0] + Neigh[2][4]
                        + Neigh[1][3] + Neigh[3][3])
                        + Neigh[0][2] + Neigh[4][2]) 
                        / (8*(NeighPresence[2][1] + NeighPresence[2][3]));
                }
                else
                {
                    /* Left and right neighbors are blue */
                    OutputRed[i] = (8*(Neigh[2][1] + Neigh[2][3])
                        + (2*(NeighPresence[1][1] + NeighPresence[3][1]
                        + NeighPresence[2][0] + NeighPresence[2][4]
                        + NeighPresence[1][3] + NeighPresence[3][3])
                        - NeighPresence[0][2] - NeighPresence[4][2])*Neigh[2][2]
                        - 2*(Neigh[1][1] + Neigh[3][1]
                        + Neigh[2][0] + Neigh[2][4]
                        + Neigh[1][3] + Neigh[3][3])
                        + Neigh[0][2] + Neigh[4][2]) 
                        / (8*(NeighPresence[2][1] + NeighPresence[2][3]));
                    OutputBlue[i] = (8*(Neigh[1][2] + Neigh[3][2])
                        + (2*(NeighPresence[1][1] + NeighPresence[3][1]
                        + NeighPresence[0][2] + NeighPresence[4][2]
                        + NeighPresence[1][3] + NeighPresence[3][3])
                        - NeighPresence[2][0] - NeighPresence[2][4])*Neigh[2][2]
                        - 2*(Neigh[1][1] + Neigh[3][1]
                        + Neigh[0][2] + Neigh[4][2]
                        + Neigh[1][3] + Neigh[3][3])
                        + Neigh[2][0] + Neigh[2][4]) 
                        / (8*(NeighPresence[1][2] + NeighPresence[3][2]));
                }
            }
        }
    }
}
