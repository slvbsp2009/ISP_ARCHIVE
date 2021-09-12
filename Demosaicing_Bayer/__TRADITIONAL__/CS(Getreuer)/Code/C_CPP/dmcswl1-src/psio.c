/**
 * @file psio.c 
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

#include "psio.h"

/** @brief Buffer size to use for PS file I/O */
#define FILE_BUFFER_CAPACITY    (1024*4)


/** 
 * @brief Start writing a new PS level-2 file 
 * @param FileName the PS file name 
 * @param XMin, YMin, XMax, YMax the viewport
 * @return FILE* stdio file handle on success, NULL on failure
 * 
 * Creates file FileName and writes a PS level 2 header with bounding box 
 * (0, 0, XMax-Xmin, YMax-YMin).  The canvas is translated if XMin or YMin
 * is nonzero.
 */
FILE *PsOpen(const char *FileName, 
    int XMin, int YMin, int XMax, int YMax)
{
    FILE *File = NULL;
        
    if(!(File = fopen(FileName, "wb")))
        return NULL;
    
    /* Tell File to use buffering */
    setvbuf(File, 0, _IOFBF, FILE_BUFFER_CAPACITY);
    
    /* Adjust bounding box so that bottom-left is always (0,0) */
    XMax -= XMin;
    YMax -= YMin;
    
    if(fprintf(File, 
        "%%!PS-Adobe-2.0\n"
        "%%%%BoundingBox: 0 0 %d %d\n"
        "<< /PageSize [%d %d] >> setpagedevice\n", XMax, YMax, XMax, YMax) < 0
        || ((XMin != 0 || YMin != 0) && fprintf(File, 
        "gsave %d %d translate\n", -XMin, -YMin) < 0)
        || ferror(File))
        {
            fclose(File);
            File = NULL;
        }

    return File;
}


/** 
 * @brief Finish writing a PS file 
 * @param File the stdio file handle
 * @return 1 on success, 0 on failure
 * 
 * Issues the "showpage" command and closes the file.
 */
int PsClose(FILE *File)
{
    if(!File 
        || fprintf(File, "showpage\n") < 0
        || ferror(File)
        || fclose(File))
        return 0;
    
    return 1;
}


/** 
 * @brief Set distiller parameters for PDF conversion 
 * @param File the stdio file handle
 * @param Param distiller parameters string
 * @return 1 on success, 0 on failure
 * 
 * If the PS file is converted to PDF, the distiller parameters can be used
 * for example to specifiy the image compression.  The parameters 
 *   
 *    "/AutoFilterColorImages false /ColorImageFilter /FlateEncode"
 * 
 * instruct that color images are to be losslessly compressed with deflate.
 * That is, the color image data in the PS will be preserved exactly in the 
 * conversion to PDF.  The analogous parameters for grayscale images are
 * 
 *    "/AutoFilterGrayImages false /GrayImageFilter /FlateEncode"
 * 
 * Alternatively, the quality with lossy DCT compression can be controlled as
 * 
 *    "/ColorACSImageDict << /QFactor 0.15 /Blend 1 /ColorTransform 1
 *     /HSamples [1 1 1 1] /VSamples [1 1 1 1] >>"
 * 
 * where a smaller quantization factor ("QFactor") implies higher quality and
 * larger file size.  The QFactor value 0.15 above is equivalent to "Maximum 
 * Quality" in Adobe Distiller.
 * 
 * This function should be called immediately after PsOpen.
 */
int PsSetDistillerParams(FILE *File, const char *Params)
{
    if(!File
        || fprintf(File, 
        "systemdict /setdistillerparams known {\n"
        "<< %s >> setdistillerparams\n"
        "} if\n", Params) < 0)
        return 0;
    else
        return 1;
}


/** 
 * @brief Write ASCII85 encoded data 
 * @param File the stdio file handle
 * @param Data data to write
 * @param NumBytes size of the data
 */
static int WriteASCII85(FILE *File, const uint8_t *Data, int NumBytes)
{
    unsigned long Tuple, Plain[4];
    unsigned int Encoded[5];
    int i, k, LineCount, Padding;
    
    
    /* Write ASCII85-encoded data */
    for(i = 0, LineCount = 0; i < NumBytes; i += 4)
    {
        for(k = 0; k < 4; k++)  /* Get four bytes */
            Plain[k] = Data[i + k];
        
        Tuple = (Plain[0] << 24) | (Plain[1] << 16)
            | (Plain[2] << 8) | Plain[3];
        
        for(k = 4; k >= 0; k--) /* Convert to radix 85 */
        {            
            Encoded[k] = Tuple % 85;
            Tuple /= 85;
        }
        
        for(k = 0; k < 5; k++)  /* Write ASCII85 tuple */
            fputc(33 + Encoded[k], File);
        
        /* Periodically emit newlines */
        if(++LineCount >= 15)
        {
            LineCount = 0;
            
            if(fprintf(File, "\n") < 0)
                return 0;
        }
    }    
    
    /* Write final tuple */
    if(i < NumBytes)
    {
        for(k = 0; i + k < NumBytes; k++)
            Plain[k] = Data[i + k];
        
        for(Padding = 0; k < 4; k++, Padding++)
            Plain[k] = 0;
        
        Tuple = (Plain[0] << 24) | (Plain[1] << 16)
            | (Plain[2] << 8) | Plain[3];
        
        for(k = 4; k >= 0; k--) /* Convert to radix 85 */
        {            
            Encoded[k] = Tuple % 85;
            Tuple /= 85;
        }
        
        for(k = 0; k < 5 - Padding; k++)  /* Write ASCII85 tuple */
            fputc(33 + Encoded[k], File);
        
        if(++LineCount >= 15
            && fprintf(File, "\n") < 0)
            return 0;
    }
    
    if(fprintf(File, "~>\n") < 0 || ferror(File))
        return 0;
    
    return 1;
}


/** 
 * @brief Writes a grayscale image to a PS file 
 * @param File the PS file handle to write to
 * @param Image grayscale image data
 * @param Width, Height the image dimensions
 * @return 1 on success, 0 on failure
 * 
 * The image is plotted on the canvas in the rectangle 
 *     [0,Width] x [0,Height]
 * where the lower-left corner is at the origin.  This routine only writes the 
 * image data.  PsOpen should be called first, then this routine and other 
 * drawing commands, and finally PsClose.  If the PS file will be converted to
 * PDF, use PsSetDistillerParams to control how the image will be recompressed.
 * 
 * For relative simplicity, the image data is written uncompressed in ASCII85 
 * encoding.  The file size is approximately 25% larger than in the PGM file 
 * format.
 */
int PsWriteGrayImage(FILE *File,
    const uint8_t *Image, int Width, int Height)
{
    /* Specify ASCII85 sRGB 8-bit color image data */
    if(!File || !Image || fprintf(File, 
        "gsave\n"
        "/DeviceGray setcolorspace\n"
        "0 %d translate %d %d scale\n"
        "<< /ImageType 1\n"
        "   /Width %d\n"
        "   /Height %d\n"
        "   /ImageMatrix [%d 0 0 -%d 0 0]\n"
        "   /BitsPerComponent 8\n"
        "   /Decode [0 1]\n"
        "   /DataSource currentfile /ASCII85Decode filter\n"
        "   /Interpolate false\n"
        ">> image\n",
        Height, Width, Height,
        Width, Height, Width, Height) < 0
        || !WriteASCII85(File, Image, Width*Height)
        || fprintf(File, "grestore\n") < 0)
        return 0;
    else
        return 1;
}


/** 
 * @brief Writes an RGB color image to a PS file 
 * @param File the stdio file handle to write to
 * @param Image interleaved RGB color image data
 * @param Width, Height the image dimensions
 * @return 1 on success, 0 on failure
 * 
 * The image is plotted on the canvas in the rectangle 
 *     [0,Width] x [0,Height]
 * where the lower-left corner is at the origin.  This routine only writes the 
 * image data.  PsOpen should be called first, then this routine and other 
 * drawing commands, and finally PsClose.  If the PS file will be converted to
 * PDF, use PsSetDistillerParams to control how the image will be recompressed.
 * 
 * For relative simplicity, the image data is written uncompressed in ASCII85 
 * encoding.  The file size is approximately 25% larger than in the PPM file 
 * format.
 */
int PsWriteColorImage(FILE *File,
    const uint8_t *Image, int Width, int Height)
{
    /* Specify ASCII85 sRGB 8-bit color image data */
    if(!File || !Image || fprintf(File, 
        "gsave\n"
        "/DeviceRGB setcolorspace\n"
        "0 %d translate %d %d scale\n"
        "<< /ImageType 1\n"
        "   /Width %d\n"
        "   /Height %d\n"
        "   /ImageMatrix [%d 0 0 -%d 0 0]\n"
        "   /BitsPerComponent 8\n"
        "   /Decode [0 1 0 1 0 1]\n"
        "   /DataSource currentfile /ASCII85Decode filter\n"
        "   /Interpolate false\n"
        ">> image\n",
        Height, Width, Height,
        Width, Height, Width, Height) < 0
        || !WriteASCII85(File, Image, 3*Width*Height)
        || fprintf(File, "grestore\n") < 0)
        return 0;
    else
        return 1;
}
