/**
 * @file dmcswl1.h
 * @brief Contour stencils weighted L1 demosaicing
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

#ifndef _DMCSWL1_H_
#define _DMCSWL1_H_

int CSWL1Demosaic(float *Image, int Width, int Height, 
    int RedX, int RedY, float Alpha, float Epsilon, float Sigma, 
    float Tol, int MaxIter, int ShowEnergy);

int DisplayContours(const float *Image, int Width, int Height, 
    int RedX, int RedY, const char *OutputFile);

void FitMosaicedStencils(int *Stencil, 
    const float *Input, int Width, int Height, int RedX, int RedY);

#endif /* _DMCSWL1_H_ */
