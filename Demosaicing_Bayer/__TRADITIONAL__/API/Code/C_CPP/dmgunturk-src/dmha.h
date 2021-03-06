/**
 * @file dmha.h
 * @brief Hamilton-Adams demosaicing
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * 
 * Copyright (c) 2010-2011, Pascal Getreuer
 * All rights reserved.
 * 
 * This program is provided for scientific and educational only: you 
 * can use and/or modify it for these purposes, but you are not allowed
 * to redistribute this work or derivative works in source or 
 * executable form. A license must be obtained from the patent right 
 * holders for any other use.
 */

#ifndef _DMHA_H_
#define _DMHA_H_

int HamiltonAdamsDemosaic(float *Output, const float *Input, 
    int Width, int Height, int RedX, int RedY);

#endif /* _DMHA_H_ */
