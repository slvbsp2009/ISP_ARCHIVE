/**
 * @file temsub.h
 * @brief Template substitution
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

#ifndef _TEMSUB_H_
#define _TEMSUB_H_

#include <stdarg.h>

int FillTemplate(const char *OutputFilename, const char *TemplateFilename,
    char *Keys[], char *Subs[]);

char **AddPair(char **Keys[], char **Subs[], char *Key, char *SubFormat, ...);
void StringAppend(char **Str, const char *Format, ...);
void VStringAppend(char **Str, const char *Format, va_list Args);
void FreeStringArray(char *Strs[]);

#endif /* _TEMSUB_H_ */
