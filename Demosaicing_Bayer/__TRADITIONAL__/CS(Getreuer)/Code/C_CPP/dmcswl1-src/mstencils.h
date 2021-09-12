/**
 * @file mstencils.h
 * @brief Mosaiced contour stencils
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

#ifndef _MSTENCILS_H_
#define _MSTENCILS_H_

void FitMosaicedStencils(int *Stencil, 
    const float *Input, int Width, int Height, int RedX, int RedY);

int DisplayContours(const float *Image, int Width, int Height, 
    int RedX, int RedY, const char *OutputFile);

#endif /* _MSTENCILS_H_ */
