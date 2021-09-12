/**
 * @file gen_mstencil.c
 * @brief Generator for mstencil.c
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * This program generates the source file mstencil.c by filling the 
 * template mstencil.tem.
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
#include <string.h>
#include "basic.h"
#include "edge.h"
#include "temsub.h"

/** @brief Number of stencils */
#define NUMSTENCILS     8

/** @brief The constant 1 + (cot(pi/6) - 1)/sqrt(2) */
#define WEIGHT_PI_8_FACTOR  3.847759065022573512


typedef enum {COLOR_RED, COLOR_GREEN, COLOR_BLUE} cfa_color;

/** @brief A mosaiced contour stencil */
typedef edgelist mstencil;


/** @brief Determine the Bayer CFA color at (x,y) */
cfa_color GetBayerColor(int RedX, int RedY, int x, int y)
{    
    return ((y & 1) == RedY) ? 
        (((x & 1) == RedX) ? COLOR_RED : COLOR_GREEN)
        : (((x & 1) == RedX) ? COLOR_GREEN : COLOR_BLUE);
}


/** @brief Determine whether a stencil edge is valid */
static int IsValidEdge(int RedX, int RedY, float Radius,
    int x1, int y1, int x2, int y2)
{
    const int SqrRadius = (int)(Radius*Radius);
    cfa_color Color1 = GetBayerColor(RedX, RedY, x1, y1);
    int MaxDistSqr = (Color1 == COLOR_GREEN) ? 4 : 8;
    
    return (
        /* Make sure endpoints have the same color */
        (Color1 == GetBayerColor(RedX, RedY, x2, y2))
        /* (x1,y1) must be in the neighborhood */
        && (x1*x1 + y1*y1 <= SqrRadius)
        /* (x2,y2) must be in the neighborhood */
        && (x2*x2 + y2*y2 <= SqrRadius)
        /* Endpoints must be close to each other */
        && ((x1 - x2)*(x1 - x2) 
            + (y1 - y2)*(y1 - y2) <= MaxDistSqr)
        ) ? 1 : 0;
}


/** @brief Compute the length of an edge */
double EdgeLength(edge Edge)
{
    double DiffX = Edge.x1 - Edge.x2;
    double DiffY = Edge.y1 - Edge.y2;
    return sqrt(DiffX*DiffX + DiffY*DiffY);
}


/** @brief Compute the arc length sum of a stencil */
double StencilArcSum(mstencil Stencil)
{
    edge *Edge;
    double Sum = 0;    
    
    for(Edge = Stencil.Head; Edge != NULL; Edge = Edge->NextEdge)
        Sum += Edge->Weight * EdgeLength(*Edge);
 
    return Sum;
}


/** @brief Free an mstencil */
void FreeStencils(mstencil *Stencils)
{
    int j;
    
    if(Stencils)
    {
        for(j = 0; j < 4; j++)
            FreeEdgeList(&Stencils[j]);
        
        Free(Stencils);
    }
}


/** @brief Test if two stencils are equal */
int StencilEquals(mstencil A, mstencil B)
{
    edge *EdgeA = A.Head, *EdgeB = B.Head;
    
    while(EdgeA && EdgeB)
    {
        if(EdgeA->x1 != EdgeB->x1 || EdgeA->y1 != EdgeB->y1
            || EdgeA->x2 != EdgeB->x2 || EdgeA->y2 != EdgeB->y2)
            return 0;
        
        EdgeA = EdgeA->NextEdge;
        EdgeB = EdgeB->NextEdge;
    }
    
    return !(EdgeA || EdgeB) ? 1 : 0;
}


/** 
 * @brief Construct mosaiced stencils 
 * @param Radius the radius of the neighborhood
 * @param CenterPixel cfa_color of the center pixel
 */
mstencil *ConstructMosaicedStencils(double Radius, cfa_color CenterPixel)
{    
    const int NeighX[4] = { 1,  1,  0, -1};
    const int NeighY[4] = { 0, -1, -1, -1};
    mstencil *Stencils;
    int RedX, RedY; 
    int j, x1, y1, x2, y2, Dist;
    
    if(!(Stencils = (mstencil *)Malloc(sizeof(mstencil)*4)))
        exit(1);
    
    switch(CenterPixel)
    {
        case COLOR_RED:
            RedX = 0;
            RedY = 0;
            break;
        case COLOR_GREEN:
            RedX = 1;
            RedY = 0;
            break;
        case COLOR_BLUE:
            RedX = 1;
            RedY = 1;
            break;
        default:
            exit(1);
    }
    
    for(j = 0; j < 4; j++)
        Stencils[j] = NullEdgeList;
    
    /* Fill the stencils */
    for(j = 0; j < 4; j++)
        for(y1 = -(int)Radius; y1 <= (int)Radius; y1++)
            for(x1 = -(int)Radius; x1 <= (int)Radius; x1++)            
                for(Dist = 1; Dist <= 2; Dist++)
                {
                    x2 = x1 + Dist*NeighX[j];
                    y2 = y1 + Dist*NeighY[j];
                    
                    /* If the edge from (x1,y1) to (x2,y2) is valid, add it
                       to Stencil[j] (edge has weight = 1).                */
                    if(IsValidEdge(RedX, RedY, Radius, x1, y1, x2, y2)
                        && !AddEdge(&Stencils[j], x1, y1, x2, y2))
                        exit(1);
                }
    
    return Stencils;
}

/**
 * @brief Write TV computation code for an mstencil
 * @param Str the string to which to append
 * @param Stencils the mstencil array
 * @param j index of the mstencil to write
 * 
 * Writes code for computing the TV of Stencils[j].
 */
void WriteTVComputation(char **Str, mstencil *Stencils, int j)
{
    edge *Edge = Stencils[j].Head;
    
    if(Edge)
        StringAppend(Str, "TV[%d] = TVEDGE(%2d,%2d,  %2d,%2d)",
            2*j, Edge->x1, Edge->y1, Edge->x2, Edge->y2);
    
    for(Edge = Edge->NextEdge; Edge != NULL; Edge = Edge->NextEdge)
        StringAppend(Str, "\n      + TVEDGE(%2d,%2d,  %2d,%2d)",
            Edge->x1, Edge->y1, Edge->x2, Edge->y2);
    
    StringAppend(Str, ";");
}



int main(int argc, char *argv[])
{
    double Radius, AxialSum, DiagonalSum;
    char *TemplateFilename, *OutputFilename;
    char **Keys = NULL, **Subs = NULL, **Sub;
    mstencil *GreenStencils = NULL, *RedBlueStencils = NULL;
    int Status = 1;        
    
    if(argc != 4)
    {
        fprintf(stderr, "Syntax: gen-mstencil <radius> <template> <output>\n");
        return 1;
    }
    else if((Radius = atof(argv[1])) <= 0)
        fprintf(stderr, "Radius must be positive.\n");
    
    TemplateFilename = argv[2];
    OutputFilename = argv[3];
    
    /* Construct stencils */
    GreenStencils = ConstructMosaicedStencils(Radius, COLOR_GREEN);
    RedBlueStencils = ConstructMosaicedStencils(Radius, COLOR_RED);    
    
    /* Make sure that RedBlue axial stencils are the same as Green versions */
    if(!StencilEquals(RedBlueStencils[0], GreenStencils[0])
        || !StencilEquals(RedBlueStencils[2], GreenStencils[2]))
    {
        fprintf(stderr, "Assertion failed:\n"
            "RedBlue axial stencils == Green axial stencils\n");
        goto Catch;
    }
    
    /* Create the key-substitution pairs for the template */
    AddPair(&Keys, &Subs, "RADIUS", "%d", (int)floor(Radius));
    
    AxialSum = StencilArcSum(GreenStencils[0]);
    DiagonalSum = StencilArcSum(GreenStencils[1]); 
    
    Sub = AddPair(&Keys, &Subs, "AXIAL_TVS", "");
    WriteTVComputation(Sub, GreenStencils, 0);
    StringAppend(Sub, "\n");
    WriteTVComputation(Sub, GreenStencils, 2);
    
    Sub = AddPair(&Keys, &Subs, "GREEN_DIAGONAL_TVS", "");
    WriteTVComputation(Sub, GreenStencils, 1);
    StringAppend(Sub, "\n");
    WriteTVComputation(Sub, GreenStencils, 3);
    
    AddPair(&Keys, &Subs, 
        "WEIGHT_AXIAL", "%.15e", 1/AxialSum);
    AddPair(&Keys, &Subs, 
        "WEIGHT_PI_8", "%.15e", 1/(AxialSum*WEIGHT_PI_8_FACTOR));
    AddPair(&Keys, &Subs, 
        "WEIGHT_GREEN_MU", "%.15e", AxialSum/DiagonalSum);
    AddPair(&Keys, &Subs, 
        "WEIGHT_GREEN_DIAGONAL", "%.15e", 1/DiagonalSum);
            
    AxialSum = StencilArcSum(RedBlueStencils[0]);
    DiagonalSum = StencilArcSum(RedBlueStencils[1]);
    
    Sub = AddPair(&Keys, &Subs, "REDBLUE_DIAGONAL_TVS", "");
    WriteTVComputation(Sub, RedBlueStencils, 1);
    StringAppend(Sub, "\n");
    WriteTVComputation(Sub, RedBlueStencils, 3);
    
    AddPair(&Keys, &Subs, 
        "WEIGHT_REDBLUE_MU", "%.15e", AxialSum/DiagonalSum);
    AddPair(&Keys, &Subs, 
        "WEIGHT_REDBLUE_DIAGONAL", "%.15e", 1/DiagonalSum);
    
    /* Fill the template */
    FillTemplate(OutputFilename, TemplateFilename, Keys, Subs);
    
    Status = 0;
Catch:
    FreeStringArray(Subs);
    FreeStringArray(Keys);    
    FreeStencils(GreenStencils);
    FreeStencils(RedBlueStencils);
    return Status;
}
