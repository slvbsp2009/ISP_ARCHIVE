/**
 * @file temsub.c
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "temsub.h"

/** @brief Size of the line buffer for template substitution */
#define LINE_BUFFER_SIZE    256


static void WriteSub(FILE *Output, char *Sub, int Column);

/**
 * @brief Fill a template file according to key-substitution pairs
 * @param OutputFilename the name of the filled output file
 * @param TemplateFilename the name of the template file
 * @param Keys the template keys, an array of strings
 * @param Subs the corresponding substitutions, an array of strings
 * @return 1 on success, 0 on failure
 * 
 * Fills a template file by replacing strings of the form "${KEYNAME}" with
 * the substitution specified in Subs.  The functions AddPair() and 
 * StringAppend() can be used to build the Keys and Subs arrays.
 * 
 * Several key-substitution pairs are provided by default: 
 * - ${OUTPUT_FILENAME} expands to OutputFilename,
 * - ${TEMPLATE_FILENAME} expands to TemplateFilename,
 * - ${TIME} expands to the current date and time
 */
int FillTemplate(const char *OutputFilename, const char *TemplateFilename,
    char *Keys[], char *Subs[])
{
    FILE *Template = NULL, *Output = NULL;
    char *Token, *NextPos;
    time_t CurrentTime;
    struct tm *CurrentTimeInfo;
    char TimeString[64], Line[LINE_BUFFER_SIZE];
    int LineNumber = 0, Success = 0, k, Column;
    
    if(!(Template = fopen(TemplateFilename, "rt")))
    {
        fprintf(stderr, "Unable to open template \"%s\".\n", 
            TemplateFilename);
        goto Catch;
    }
    else if(!(Output = fopen(OutputFilename, "wt")))
    {
        fprintf(stderr, "Unable to open \"%s\" for writing.\n",
            OutputFilename);
        goto Catch;
    }
    
    /* Get the current time */
    time(&CurrentTime);
    CurrentTimeInfo = localtime (&CurrentTime);
    strftime(TimeString, 64, "%Y-%m-%d %H:%M:%S", CurrentTimeInfo);
    
    /* Parse the template file line-by-line */
    while(fgets(Line, LINE_BUFFER_SIZE, Template))
    {
        LineNumber++;
        Token = Line;
        
        while((NextPos = strstr(Token, "${")))  /* Found "${" */
        {
            /* Write the text from Token to NextPos */
            *NextPos = '\0';
            fputs(Token, Output);
            
            Column = NextPos - Line;
            Token = NextPos + 2;
            
            if(!(NextPos = strchr(Token, '}'))) /* Get matching '}' */
            {
                fprintf(stderr, "Line %d: Missing '}'.\n", LineNumber);
                goto Catch;
            }
            
            *NextPos = '\0';            
            
            if(!strcmp(Token, "TIME"))
                fputs(TimeString, Output);
            else if(!strcmp(Token, "TEMPLATE_FILENAME"))
                fputs(TemplateFilename, Output);
            else if(!strcmp(Token, "OUTPUT_FILENAME"))
                fputs(OutputFilename, Output);
            else
                /* Search for a key equal to Token */
                for(k = 0;; k++)
                    if(!Keys[k] || !Subs[k])
                    {
                        fprintf(stderr, "Line %d: Unknown key \"%s\".\n",
                            LineNumber, Token);
                        goto Catch;
                    }
                    else if(!strcmp(Token, Keys[k]))
                    {
                        /* Write Subs[k] to the output file */
                        WriteSub(Output, Subs[k], Column);
                        break;
                    }
            
            Token = NextPos + 1;
        }
        
        /* Write the remainder of the line */
        fputs(Token, Output);
    }
    
    if(ferror(Template))
    {
        fprintf(stderr, "Error reading \"%s\".\n", TemplateFilename);
        goto Catch;
    }
    else if(ferror(Output))
    {
        fprintf(stderr, "Error writing \"%s\".\n", OutputFilename);
        goto Catch;
    }
    
    Success = 1;
Catch:
    if(Output)
        fclose(Output);
    if(Template)
        fclose(Template);
    return Success;
}


/**
 * @brief Write string to file with indentation 
 * @param Output the output file
 * @param Sub the string to write
 * @param Column the number of spaces to indent
 * 
 * This routine writes Sub to Output, writing Column number of spaces after 
 * each newline character.
 */
static void WriteSub(FILE *Output, char *Sub, int Column)
{
    char *Token = Sub;
    char *NextPos;
    int k;
    
    for(Token = Sub; (NextPos = strchr(Token, '\n')); Token = NextPos + 1)
    {
        /* Write the text from Token up to and including the next newline */
        fwrite(Token, sizeof(char), NextPos - Token + 1, Output);
        
        /* Write Column number of spaces to indent the next line */
        for(k = 0; k < Column; k++)
            putc(' ', Output);
    }
    
    /* Write the remaining text */
    fputs(Token, Output);
}


/**
 * @brief Add a key-substitution pair to a key-substitution table 
 * @param Keys the template keys, an array of strings
 * @param Subs the corresponding substitutions, an array of strings
 * @param Key the new key to add
 * @param SubFormat format string for the corresponding substitution
 * @return pointer to the new Subs string
 * 
 * This routine allocates memory for adding the new strings.  Use 
 * FreeStringArray() to free the memory.
 */
char **AddPair(char **Keys[], char **Subs[], char *Key, char *SubFormat, ...)
{    
    va_list Args;
    int i = 0;
    
    /* Search for Key in Keys */
    if(*Keys && *Subs)
        for(; (*Keys)[i]; i++)
            if(!strcmp((*Keys)[i], Key))
                goto Done;
    
    /* After the loop, i = current number of keys.  Now we allocate
       space for i+2 elements (= current keys + the new key + sentinel). */
    if(!(*Keys = (char **)realloc(*Keys, sizeof(char *)*(i + 2)))
        || !(*Subs = (char **)realloc(*Subs, sizeof(char *)*(i + 2)))
    /* Allocate space to copy Key */
        || !((*Keys)[i] = (char *)malloc(strlen(Key) + 1)))
    {
        fprintf(stderr, "Out of memory.");
        exit(1);
    }
        
    strcpy((*Keys)[i], Key);  /* Copy Key */
    (*Subs)[i] = NULL;
    (*Keys)[i + 1] = NULL;  /* Set null sentinel */
    (*Subs)[i + 1] = NULL;
    
Done:    
    va_start(Args, SubFormat);
    VStringAppend(&(*Subs)[i], SubFormat, Args);
    va_end(Args);
    return &(*Subs)[i];
}


/**
 * @brief Append to a string with a printf format string
 * @param Str the string on which to append
 * @param Format the format string for what to append
 */
void StringAppend(char **Str, const char *Format, ...)
{
    va_list Args;
    
    va_start(Args, Format);
    VStringAppend(Str, Format, Args);
    va_end(Args);
}


/** @brief Variable argument list (va_list) version of StringAppend() */
void VStringAppend(char **Str, const char *Format, va_list Args)
{
    char *NewStr;
    char Buffer[LINE_BUFFER_SIZE];
    
    vsprintf(Buffer, Format, Args);
    
    /* Reallocate string with enough space to hold the result */
    if(!(NewStr = (char *)realloc(*Str, 
        ((*Str) ? strlen(*Str) : 0) + strlen(Buffer) + 1)))
    {
        fprintf(stderr, "Out of memory.");
        exit(1);
    }
    
    if(*Str) 
        strcat(NewStr, Buffer);
    else
        strcpy(NewStr, Buffer);
    
    *Str = NewStr;
}


/** 
 * @brief Free an array of strings created with AddPair() 
 * @param Strs pointer to the string array
 */
void FreeStringArray(char *Strs[])
{
    if(Strs)
    {
        int i;
        
        for(i = 0; Strs[i]; i++)
            if(Strs[i])
                free(Strs[i]);
        
        free(Strs);
    }
}

