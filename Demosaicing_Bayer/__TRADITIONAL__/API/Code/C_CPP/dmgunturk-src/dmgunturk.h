/**
 * @file dmgunturk.h
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

#ifndef _DMGUNTURK_H_
#define _DMGUNTURK_H_

int GunturkDemosaic(float *Image, int Width, int Height, 
    int RedX, int RedY, int NumIter);

#endif /* _DMGUNTURK_H_ */
