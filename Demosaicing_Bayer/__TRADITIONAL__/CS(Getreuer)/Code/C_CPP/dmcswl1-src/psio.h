/**
 * @file psio.h 
 * @brief Postscript level-2.0 file writing
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

#ifndef _PSIO_H_
#define _PSIO_H_

#include <stdio.h>
#include "basic.h"


FILE *PsOpen(const char *FileName,
    int XMin, int YMin, int XMax, int YMax);

int PsClose(FILE *File);

int PsSetDistillerParams(FILE *File, const char *Params);

int PsWriteGrayImage(FILE *File,
    const uint8_t *Image, int Width, int Height);

int PsWriteColorImage(FILE *File,
    const uint8_t *Image, int Width, int Height);

#endif /* _PSIO_H_ */
