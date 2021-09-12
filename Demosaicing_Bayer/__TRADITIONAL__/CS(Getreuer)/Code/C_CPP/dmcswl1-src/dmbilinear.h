/**
 * @file dmbilinear.h
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

#ifndef _DMBILINEAR_H_
#define _DMBILINEAR_H_

void CfaFlatten(float *Cfa, const float *Input, int Width, int Height, 
    int RedX, int RedY);

void BilinearDifference(float *Output, const float *Diff,
    int Width, int Height, int RedX, int RedY);

void BilinearDemosaic(float *Output, const float *Input, 
    int Width, int Height, int RedX, int RedY);

#endif /* _DMBILINEAR_H_ */
