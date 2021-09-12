/**
 * @file dmcswl1.c
 * @brief Contour stencils weighted L1 demosaicing
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * This file implements the image demosaicing method as described in IPOL 
 * article "Image Demosaicking with Contour Stencils."  The main computation
 * is in routine CSWL1Demosaic.
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

#include <math.h>
#include <string.h>
#include "basic.h"
#include "conv.h"
#include "inv3x3.h"
#include "dmbilinear.h"
#include "mstencils.h"
#include "dmcswl1.h"


/** @brief Penalty term weight to enforce \f$ d_{m,n} = C(u_m - u_n) \f$ */
#define GAMMA1          4
/** @brief Penalty term weight to enforce observation constraint */
#define GAMMA2          256
/** 
 * @brief How many adjacent neighbors a node has 
 * @note Changing this constant requires revision of the code
 */
#define NUMNEIGH        8
/** 
 * @brief How many distinct orientations are detected
 * @note Changing this constant requires revision of the code
 */
#define NUMORIENTATIONS 8

/** @brief mu = gamma_2 / (2 NUMNEIGH gamma_1) */
#define MU        (GAMMA2/(2*NUMNEIGH*GAMMA1))


#ifndef DOXYGEN_SHOULD_SKIP_THIS

/* Color transformation matrix */
#define CMAT_YR   (5.773502691896258e-1)
#define CMAT_YG   (5.773502691896258e-1)
#define CMAT_YB   (5.773502691896258e-1)
#define CMAT_UR   (M_1_SQRT2)
#define CMAT_UG   (0.0)
#define CMAT_UB   (-M_1_SQRT2)
#define CMAT_VR   (4.08248290463863e-1)
#define CMAT_VG   (-8.16496580927726e-1)
#define CMAT_VB   (4.08248290463863e-1)

/* === Construction of inverse matrices ===
 *
 * The following performs compile-time evaluation of the 3x3 inverse matrices
 * 
 *    (C^* C + mu e_m^T e_m)^-1,
 *    
 *  where e_m is (1,0,0)^T, (0,1,0)^T, or (0,0,1)^T for m = R, G, B and 
 *  mu = gamma_2 / (2 NUMNEIGH gamma_1).  The macros UR_, UB_, and UG_ 
 *  represent the matrices C^* C + mu e_m^T e_m.  The actual matrix inverse
 *  computation is done by the INV3X3_ macros defined in inv3x3.h.  
 */

/* Compute CCMAT = C^* C   */
#define CCMAT_RR    (CMAT_YR*CMAT_YR + CMAT_UR*CMAT_UR + CMAT_VR*CMAT_VR)
#define CCMAT_RG    (CMAT_YR*CMAT_YG + CMAT_UR*CMAT_UG + CMAT_VR*CMAT_VG)
#define CCMAT_RB    (CMAT_YR*CMAT_YB + CMAT_UR*CMAT_UB + CMAT_VR*CMAT_VB)
#define CCMAT_GR    (CMAT_YG*CMAT_YR + CMAT_UG*CMAT_UR + CMAT_VG*CMAT_VR)
#define CCMAT_GG    (CMAT_YG*CMAT_YG + CMAT_UG*CMAT_UG + CMAT_VG*CMAT_VG)
#define CCMAT_GB    (CMAT_YG*CMAT_YB + CMAT_UG*CMAT_UB + CMAT_VG*CMAT_VB)
#define CCMAT_BR    (CMAT_YB*CMAT_YR + CMAT_UB*CMAT_UR + CMAT_VB*CMAT_VR)
#define CCMAT_BG    (CMAT_YB*CMAT_YG + CMAT_UB*CMAT_UG + CMAT_VB*CMAT_VG)
#define CCMAT_BB    (CMAT_YB*CMAT_YB + CMAT_UB*CMAT_UB + CMAT_VB*CMAT_VB)

/* The matrices C^* C + mu e_m^T e_m   */
#define UR_(A)      ((float)A(CCMAT_RR + MU, CCMAT_RG, CCMAT_RB, \
                              CCMAT_GR,      CCMAT_GG, CCMAT_GB, \
                              CCMAT_BR,      CCMAT_BG, CCMAT_BB))
#define UG_(A)      ((float)A(CCMAT_RR, CCMAT_RG,      CCMAT_RB, \
                              CCMAT_GR, CCMAT_GG + MU, CCMAT_GB, \
                              CCMAT_BR, CCMAT_BG,      CCMAT_BB))
#define UB_(A)      ((float)A(CCMAT_RR, CCMAT_RG, CCMAT_RB, \
                              CCMAT_GR, CCMAT_GG, CCMAT_GB, \
                              CCMAT_BR, CCMAT_BG, CCMAT_BB + MU))

#define UINVR_RR    (UR_(INV3X3_11))
#define UINVR_RG    (UR_(INV3X3_12))
#define UINVR_RB    (UR_(INV3X3_13))
#define UINVR_GR    (UR_(INV3X3_21))
#define UINVR_GG    (UR_(INV3X3_22))
#define UINVR_GB    (UR_(INV3X3_23))
#define UINVR_BR    (UR_(INV3X3_31))
#define UINVR_BG    (UR_(INV3X3_32))
#define UINVR_BB    (UR_(INV3X3_33))

#define UINVG_RR    (UG_(INV3X3_11))
#define UINVG_RG    (UG_(INV3X3_12))
#define UINVG_RB    (UG_(INV3X3_13))
#define UINVG_GR    (UG_(INV3X3_21))
#define UINVG_GG    (UG_(INV3X3_22))
#define UINVG_GB    (UG_(INV3X3_23))
#define UINVG_BR    (UG_(INV3X3_31))
#define UINVG_BG    (UG_(INV3X3_32))
#define UINVG_BB    (UG_(INV3X3_33))

#define UINVB_RR    (UB_(INV3X3_11))
#define UINVB_RG    (UB_(INV3X3_12))
#define UINVB_RB    (UB_(INV3X3_13))
#define UINVB_GR    (UB_(INV3X3_21))
#define UINVB_GG    (UB_(INV3X3_22))
#define UINVB_GB    (UB_(INV3X3_23))
#define UINVB_BR    (UB_(INV3X3_31))
#define UINVB_BG    (UB_(INV3X3_32))
#define UINVB_BB    (UB_(INV3X3_33))

#endif /* DOXYGEN_SHOULD_SKIP_THIS */


/** 
 * @brief X coordinates of pixel neighbors 
 * 
 * There are eight neighbors.  The neighborhood is enumerated in counter-
 * clockwise order beginning with the right adjacent neighbor.
@verbatim
 3      2      1
   `.   |   .` 
     `. | .`
 4 -----+----- 0
     .` | `.
   .`   |   `.
 5      6      7
@endverbatim
 */
static const int NeighX[NUMNEIGH] = {1, 1, 0, -1, -1, -1, 0, 1};
/** @brief Y coordinates of pixel neighbors */
static const int NeighY[NUMNEIGH] = {0, -1, -1, -1, 0, 1, 1, 1};
/** @brief Indices for corresponding adjoint neighbors */
static const int NeighAdj[NUMNEIGH] = {4, 5, 6, 7, 0, 1, 2, 3};
/** @brief Graph weights to add depending on detected contour orientation */
static const float NeighWeights[NUMORIENTATIONS][NUMNEIGH] = 
    { /* 0       1       2       3       4       5       6       7 */
        /* Horizontal orientation */
        {1,      0,      0,      0,      1,      0,      0,      0},
        /* pi/8 orientation       */
        {2.0f/3, 1.0f/3, 0,      0,      2.0f/3, 1.0f/3, 0,      0},
        /* pi 2/8 orientation     */
        {0,      1,      0,      0,      0,      1,      0,      0},
        /* pi 3/8 orientation     */
        {0,      1.0f/3, 2.0f/3, 0,      0,      1.0f/3, 2.0f/3, 0},
        /* Vertical orientation   */
        {0,      0,      1,      0,      0,      0,      1,      0},
        /* pi 5/8 orientation     */
        {0,      0,      2.0f/3, 1.0f/3, 0,      0,      2.0f/3, 1.0f/3},
        /* pi 6/8 orientation     */
        {0,      0,      0,      1,      0,      0,      0,      1},
        /* pi 7/8 orientation     */
        {2.0f/3, 0,      0,      1.0f/3, 2.0f/3, 0,      0,      1.0f/3}
    };


/** 
 * @brief Square 
 * @param x the input value
 * @return square value of x
 */
static ATTRIBUTE_ALWAYSINLINE float sqr(float x)
{
    return x*x;
}


/**
 * @brief Compute Y luminance component from an RGB color
 * @param R,G,B the input color
 * @return the Y component
 */
static ATTRIBUTE_ALWAYSINLINE float GetYComponent(float R, float G, float B)
{
    return ((float)CMAT_YR)*R + ((float)CMAT_YG)*G + ((float)CMAT_YB)*B;
}

/**
 * @brief Compute U chromatic component from an RGB color
 * @param R,G,B the input color
 * @return the U component
 */
static ATTRIBUTE_ALWAYSINLINE float GetUComponent(float R, float G, float B)
{
    return ((float)CMAT_UR)*R + ((float)CMAT_UG)*G + ((float)CMAT_UB)*B;
}

/**
 * @brief Compute V chromatic component from an RGB color
 * @param R,G,B the input color
 * @return the V component
 */
static ATTRIBUTE_ALWAYSINLINE float GetVComponent(float R, float G, float B)
{
    return ((float)CMAT_VR)*R + ((float)CMAT_VG)*G + ((float)CMAT_VB)*B;
}


/** 
 * @brief Solves the d-subproblem 
 * @param d the previous solution of d, updated by this routine
 * @param dtilde the previous dtilde, updated by this routine
 * @param Image the current solution of the demosaiced image
 * @param Weight the edge weights of the graph
 * @param Width, Height the image dimensions
 * @param Alpha weight on the chromatic term
 * 
 * The d variable subproblem is
 * 
 * \f[ \begin{aligned}
 * \operatorname*{arg\,min}_{d} & \sum_m \Bigl(\sum_n \bigl(w_{m,n}
 * d^L_{m,n} \bigr)^2\Bigr)^{1/2}  + \alpha \sum_m \Bigl(\sum_n \Bigl(w_{m,n}
 * \sqrt{(d^{C1}_{m,n})^2 + (d^{C2}_{m,n})^2} \,\Bigr)^2\Bigr)^{1/2} \\
 * & {+}\,\, \frac{\gamma_1}{2} \sum_{m,n} \|\tilde{d}_{m,n} 
 * - C(u_m - u_n)\|_2^2
 * \end{aligned} \f]
 * 
 * where \f$ C \f$ is the color transform matrix, and \f$ w_{m,n} \f$ denote
 * the graph weights between pixels \f$ m \f$ and \f$ n \f$.  The problem 
 * decouples over m and also decouples between the luminosity channel L and 
 * the chromatic channels C1 and C2. This leads to subproblems of the form
 *
 * \f[ \operatorname*{arg\,min}_{x\in\mathbb{R}^N} \, \Bigl( \sum_{n=1}^N 
 * (w_n x_n)^2 \Bigr)^{1/2} + \frac{\gamma}{2} \sum_{n=1}^N (x_n - y_n)^2. \f]
 * 
 * The minimizer of this problem satisfies
 *
 * \f[ w_m^2 x_m = \gamma (y_m - x_m) \lVert x \rVert_w, \quad 
 *     \lVert x \rVert_w := \Bigl( \sum_{n=1}^N (w_n x_n)^2 \Bigr)^{1/2}. \f]
 * 
 * We can approximate the solution by fixed point iteration,
 *
 * \f[ x_m^\text{next} = y_m \frac{\gamma \lVert x \rVert_w}
 *    {w_m^2 + \gamma \lVert x \rVert_w}, \f]
 *
 * where \f$ \|x\|_w \f$ is computed using on the solution from the previous 
 * Bregman iteration or, if it is the first iteration or the previous solution 
 * was 0, as \f$ \|y\|_w \f$.
 * 
 * The update of \f$ \tilde{d} \f$ is computed as
 * 
 * \f[ \tilde{d}_{m,n}^\text{next} = \tilde{d}_{m,n} - C(u_m - u_n) 
 *     + 2d_{m,n}^\text{next} - d_{m,n}. \f]
 */
void DShrink(float (*d)[NUMNEIGH][3], float (*dtilde)[NUMNEIGH][3], 
    const float *Image, float (*Weight)[NUMNEIGH], int Width, int Height,
    float Alpha)
{
    const int NumPixels = Width*Height;
    const float *Red = Image;
    const float *Green = Image + NumPixels;    
    const float *Blue = Image + 2*NumPixels;
    float RedDiff, GreenDiff, BlueDiff;
    float dmag, dnew[NUMNEIGH][3], Cu[NUMNEIGH][3];
    int Channel, m, x, y, n, nOffset[NUMNEIGH];
    
    /* Precompute offsets for refering to pixel neighbors */
    for(n = 0; n < NUMNEIGH; n++)
        nOffset[n] = NeighX[n] + Width*NeighY[n];    
    
    for(y = 1; y < Height - 1; y++)
        for(x = 1; x < Width - 1; x++)
        {
            m = x + Width*y;
            
            for(n = 0; n < NUMNEIGH; n++)
            {
                RedDiff = Red[m] - Red[m + nOffset[n]];
                GreenDiff = Green[m] - Green[m + nOffset[n]];
                BlueDiff = Blue[m] - Blue[m + nOffset[n]];                
                
                /* Convert difference from RGB to transformed colorspace */
                Cu[n][0] = GetYComponent(RedDiff, GreenDiff, BlueDiff);
                Cu[n][1] = GetUComponent(RedDiff, GreenDiff, BlueDiff);
                Cu[n][2] = GetVComponent(RedDiff, GreenDiff, BlueDiff);
            }
            
            /* The d-subproblem decouples over space, and decouples between
             * the luminance component and the two chromatic components.  In
             * the following, we first solve the subproblem for the chromatic
             * components.
             */
            
            /* Compute dnew = y and dmag = ||x||_w. */
            for(n = 0, dmag = 0; n < NUMNEIGH; n++)
                for(Channel = 1; Channel < 3; Channel++)
                {
                    dnew[n][Channel] = Cu[n][Channel] 
                        + d[m][n][Channel] - dtilde[m][n][Channel];
                    dmag += sqr(Weight[m][n]*d[m][n][Channel]);
                }
            
            /* If ||x||_w is zero, use dmag = ||y||_w instead. */
            if(dmag == 0)
                for(n = 0; n < NUMNEIGH; n++)
                    for(Channel = 1; Channel < 3; Channel++)
                        dmag += sqr(Weight[m][n]*dnew[n][Channel]);
                    
            dmag = (float)sqrt(dmag);           
            
            for(n = 0; n < NUMNEIGH; n++)
                for(Channel = 1; Channel < 3; Channel++)
                {
                    /* Compute new d value by the fixed point formula. */
                    dnew[n][Channel] *= dmag
                        /(Weight[m][n]*Weight[m][n]*Alpha/GAMMA1 + dmag);
                    /* Update dtilde
                        = dtilde - C(u_m - u-N) + d_m,n + Delta d_m,n 
                        = dtilde - Cu + 2*dnew - d.                   */
                    dtilde[m][n][Channel] += 2*dnew[n][Channel]
                        - d[m][n][Channel] - Cu[n][Channel];
                    /* Update d */
                    d[m][n][Channel] = dnew[n][Channel];
                }
            
            /* Now we solve the subproblem corresponding to the luminance 
             * component.  The solution has the same form as for the 
             * chrominance, so the code is nearly the same.
             */
            for(n = 0, dmag = 0; n < NUMNEIGH; n++)
            {
                dnew[n][0] = Cu[n][0] + d[m][n][0] - dtilde[m][n][0];
                dmag += sqr(Weight[m][n]*d[m][n][0]);
            }
            
            if(dmag == 0)
                for(n = 0; n < NUMNEIGH; n++)
                    dmag += sqr(Weight[m][n]*dnew[n][0]);
                    
            dmag = (float)sqrt(dmag);
            
            for(n = 0; n < NUMNEIGH; n++)
            {
                dnew[n][0] *= dmag/(Weight[m][n]*Weight[m][n]/GAMMA1 + dmag);
                dtilde[m][n][0] += 2*dnew[n][0] - Cu[n][0] - d[m][n][0];
                d[m][n][0] = dnew[n][0];
            }
        }
}


/** 
 * @brief Solves the u-subproblem 
 * @param Image the demosaiced image solution (u), updated by this routine
 * @param b the Bregman auxiliary variable, updated by this routine
 * @param dtilde current dtilde 
 * @param Mosaic the input mosaiced image
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-leftmost red pixel
 * @return L^2 difference between the previous Image and updated Image
 * 
 * The current demosaicking solution, Image (u), is updated by approximately 
 * solving the u subproblem using Gauss-Seidel.  The solution satisfies
 * 
 * \f[ \begin{aligned}
 * & (2\cdot 8\gamma_1 C^*C + \gamma_2 e_m e_m^T) u_m^\text{next} =  \\
 * & \quad \gamma_1 \sum_n C^*(2C u_n + \tilde{d}_{m,n} - \tilde{d}_{n,m}) 
 *     + \gamma_2 e_m (f_m - b_m),
 * \end{aligned} \f]
 * 
 * where \f$ C \f$ is the color transform matrix, \f$ f \f$ is the input 
 * mosaiced image (\c Mosaic), and \f$ e_m \f$ is \f$ (1,0,0)^T, (0,1,0)^T, 
 * (0,0,1)^T \f$ respectively at red, green, and blue locations.  Inverses of
 * the matrices 
 * 
 * \f[ (2\cdot 8\gamma_1 C^*C + \gamma_2 e_m e_m^T) \f]
 * 
 * are precomputed.
 */
float UGaussSeidel(float *Image, float *b, float (*dtilde)[NUMNEIGH][3],
    const float *Mosaic, int Width, int Height, int RedX, int RedY)
{
    const int NumPixels = Width*Height;
    const int GreenPos = 1 - ((RedX + RedY) & 1);
    float *Red = Image;
    float *Green = Image + NumPixels;    
    float *Blue = Image + 2*NumPixels;
    float DiffNorm = 0, Rhs[3], Sum[3], NewRed, NewGreen, NewBlue;
    int Channel, m, x, y, n, NumNeigh, nOffset[NUMNEIGH];
    
    for(n = 0; n < NUMNEIGH; n++)
        nOffset[n] = NeighX[n] + Width*NeighY[n];
    
    for(y = 0, m = 0; y < Height; y++)
    {
        for(x = 0; x < Width; x++, m++)
        {            
            Rhs[0] = Rhs[1] = Rhs[2] = 0;
            Sum[0] = Sum[1] = Sum[2] = 0;
            
            /* With m = (x,y) as the current pixel, the following computes
                Sum = sum_n (dtilde_m,n - dtilde_n,m),
                Rhs = sum_n u_n.                                           */
            if(0 < x && x < Width - 1 && 0 < y && y < Height - 1)
            {       /* Current pixel (x,y) is an interior pixel */
                NumNeigh = NUMNEIGH;
                
                for(n = 0; n < NUMNEIGH; n++)
                {
                    Rhs[0] += Red[m + nOffset[n]];
                    Rhs[1] += Green[m + nOffset[n]];
                    Rhs[2] += Blue[m + nOffset[n]];
                    
                    for(Channel = 0; Channel < 3; Channel++)
                        Sum[Channel] += dtilde[m][n][Channel]
                            - dtilde[m + nOffset[n]][NeighAdj[n]][Channel];
                }
            }
            else    /* Current pixel (x,y) is a border pixel */
                for(n = 0, NumNeigh = 0; n < NUMNEIGH; n++)
                    if(0 <= x + NeighX[n] && x + NeighX[n] < Width 
                        && 0 <= y + NeighY[n] && y + NeighY[n] < Height)
                    {   
                        NumNeigh++;
                        Rhs[0] += Red[m + nOffset[n]];
                        Rhs[1] += Green[m + nOffset[n]];
                        Rhs[2] += Blue[m + nOffset[n]];
                        
                        for(Channel = 0; Channel < 3; Channel++)
                            Sum[Channel] += dtilde[m][n][Channel]
                                - dtilde[m + nOffset[n]][NeighAdj[n]][Channel];
                    }
            
            /* Now use Sum and Rhs computed above to obtain
                Sum = (Sum/2 + C Rhs) / NumNeigh
                = sum_n (2C u_n + (dtilde_m,n - dtilde_n,m)) / (2NumNeigh). */                
            Sum[0] = (Sum[0]/2 + GetYComponent(Rhs[0], Rhs[1], Rhs[2]))
                / NumNeigh;
            Sum[1] = (Sum[1]/2 + GetUComponent(Rhs[0], Rhs[1], Rhs[2]))
                / NumNeigh;
            Sum[2] = (Sum[2]/2 + GetVComponent(Rhs[0], Rhs[1], Rhs[2]))
                / NumNeigh;
            
            /* Multiply by C*, the adjoint of C, so that
                Rhs = sum_n C* (2C u_n + (dtilde_m,n - dtilde_n,m)) 
                        / (2NumNeigh).                                      */
            Rhs[0] = (float)(CMAT_YR*Sum[0] + CMAT_UR*Sum[1] + CMAT_VR*Sum[2]);
            Rhs[1] = (float)(CMAT_YG*Sum[0] + CMAT_UG*Sum[1] + CMAT_VG*Sum[2]);
            Rhs[2] = (float)(CMAT_YB*Sum[0] + CMAT_UB*Sum[1] + CMAT_VB*Sum[2]);
            
            /* The following depends on whether (x,y) is a green, red, or blue
             * location in the Bayer CFA.  We finish computing the right-hand 
             * side as
             *
             *      Rhs += mu e_m (f_m - b_m),
             * 
             * where mu = gamma_2 / (2 NUMNEIGH gamma_1) and e_m is (1,0,0)^T,
             * (0,1,0)^T, or (0,0,1)^T respectively at red, green, and blue 
             * locations.  We obtain the next value of u_n by multiplication
             * with a 3x3 inverse matrix,
             * 
             *      u^next = (C* C + mu e_m e_m^T)^-1 Rhs.
             * 
             * The Bregman auxiliary variable is then updated as
             * 
             *      b_m += u^next_m - f_m.
             */
            if(((x + y) & 1) == GreenPos)   /* (x,y) is a green location */
            {
                Rhs[1] += MU*(Mosaic[m] - b[m]);
                NewRed   = UINVG_RR*Rhs[0] + UINVG_RG*Rhs[1] + UINVG_RB*Rhs[2];
                NewGreen = UINVG_GR*Rhs[0] + UINVG_GG*Rhs[1] + UINVG_GB*Rhs[2];
                NewBlue  = UINVG_BR*Rhs[0] + UINVG_BG*Rhs[1] + UINVG_BB*Rhs[2];
                b[m] += NewGreen - Mosaic[m];
            }
            else if((y & 1) == RedY)        /* (x,y) is red location */
            {
                Rhs[0] += MU*(Mosaic[m] - b[m]);
                NewRed   = UINVR_RR*Rhs[0] + UINVR_RG*Rhs[1] + UINVR_RB*Rhs[2];
                NewGreen = UINVR_GR*Rhs[0] + UINVR_GG*Rhs[1] + UINVR_GB*Rhs[2];
                NewBlue  = UINVR_BR*Rhs[0] + UINVR_BG*Rhs[1] + UINVR_BB*Rhs[2];
                b[m] += NewRed - Mosaic[m];
            }
            else                            /* (x,y) is blue location */
            {
                Rhs[2] += MU*(Mosaic[m] - b[m]);
                NewRed   = UINVB_RR*Rhs[0] + UINVB_RG*Rhs[1] + UINVB_RB*Rhs[2];
                NewGreen = UINVB_GR*Rhs[0] + UINVB_GG*Rhs[1] + UINVB_GB*Rhs[2];
                NewBlue  = UINVB_BR*Rhs[0] + UINVB_BG*Rhs[1] + UINVB_BB*Rhs[2];
                b[m] += NewBlue - Mosaic[m];
            }
            
            /* Computation of DiffNorm = ||u^next - u^prev|| */
            DiffNorm += sqr(NewRed - Red[m]);
            DiffNorm += sqr(NewGreen - Green[m]);
            DiffNorm += sqr(NewBlue - Blue[m]);
            
            Red[m] = NewRed;
            Green[m] = NewGreen;
            Blue[m] = NewBlue;
        }   
    }
    
    return (float)sqrt(DiffNorm);
}


/** @brief Compute index for constant extension boundary handling */
static int ConstantExtension(int n, int N)
{
    return (n < 0) ? 0 : ((n >= N) ? (N-1) : n);
}


/**
 * @brief Construct the weighted graph according to contour orientations
 * @param Weight the edge weights of the graph
 * @param Mosaic the input mosaiced image
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-leftmost red pixel
 * @param Epsilon edge weight for weak links in the graph
 * @param Sigma graph filtering parameter
 * 
 * This function constructs the weighted graph that will be used for the graph
 * regularization in the contour stencil demosaicking.
 * 
 * Each interior pixel has eight neighbors.  The neighborhood is enumerated in 
 * counter-clockwise order beginning with the right adjacent neighbor.
@verbatim
 3      2      1
   `.   |   .` 
     `. | .`
 4 -----+----- 0
     .` | `.
   .`   |   `.
 5      6      7
@endverbatim
 * The graph edge weights over this neighborhood for different local contour 
 * orientations are stored in NeighWeights.
 */
int ConstructGraph(float (*Weight)[NUMNEIGH], const float *Mosaic, 
    int Width, int Height, int RedX, int RedY, float Epsilon, float Sigma)
{
    const int NumPixels = Width*Height;
    boundaryext Boundary = GetBoundaryExt("wsym");
    filter SmoothFilter = {NULL, 0, 0};
    float *ConvTemp = NULL;
    int *Stencil = NULL;
    int i, j, n, x, y, Success = 0;
    
    if(!(ConvTemp = (float *)Malloc(sizeof(float)*NumPixels))
        || !(Stencil = (int *)Malloc(sizeof(int)*NumPixels))
        || IsNullFilter(SmoothFilter 
            = GaussianFilter(Sigma, (int)ceil(4*Sigma))))
        goto Catch;
    
    /* Estimate the contour orientations using mosaiced contour stencils */
    FitMosaicedStencils(Stencil, Mosaic, Width, Height, RedX, RedY);
    
    /* Build initial graph according to the detected contours */
    for(y = 0, i = 0; y < Height; y++)
        for(x = 0; x < Width; x++, i++)
            for(n = 0; n < NUMNEIGH; n++)
                Weight[i][n] = Epsilon + NeighWeights[Stencil[i]][n];
    
    /* Average shared edges */
    for(y = 0, i = 0; y < Height; y++)
        for(x = 0; x < Width; x++, i++)
            for(n = 0; n < 4; n++)
            {
                j = ConstantExtension(x + NeighX[n], Width) 
                    + Width*ConstantExtension(y + NeighY[n], Height);
                Weight[i][n] = (Weight[i][n] + Weight[j][NeighAdj[n]])/2;
            }
        
    for(y = 0, i = 0; y < Height; y++)
        for(x = 0; x < Width; x++, i++)
            for(n = 4; n < NUMNEIGH; n++)
            {
                j = ConstantExtension(x + NeighX[n], Width) 
                    + Width*ConstantExtension(y + NeighY[n], Height);
                Weight[i][n] = Weight[j][NeighAdj[n]];
            }
    
    /* Spatially smooth the weights with Gaussian filtering */
    for(n = 0; n < NUMNEIGH; n++)
    {
        for(y = 0; y < Height; y++)
            Conv1D(ConvTemp + Width*y, 1,
                (float *)Weight + n + NUMNEIGH*Width*y, NUMNEIGH, 
                SmoothFilter, Boundary, Width);
        
        for(x = 0; x < Width; x++)
            Conv1D((float *)Weight + n + NUMNEIGH*x, NUMNEIGH*Width,
                ConvTemp + x, Width, 
                SmoothFilter, Boundary, Height);
    }
    
    Success = 1;
Catch:
    FreeFilter(SmoothFilter);    
    Free(Stencil);
    Free(ConvTemp);
    return Success;
}


/**
 * @brief Copy image components that are known from the input mosaiced data
 * @param Image the input RGB image in planar row-major order
 * @param Mosaic the input mosaiced image
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-leftmost red pixel
 * 
 * This function is used to set the components of Image equal to the values
 * that are known from the input mosaiced image, 
 * 
 * \f[ u_m^k = f_m, m \in \Omega^k, k \in \{R,G,B\}. \f]
 */
void CopyCfaValues(float *Image, const float *Mosaic, int Width, int Height,
    int RedX, int RedY)
{
    const int NumPixels = Width*Height;
    const int GreenPos = 1 - ((RedX + RedY) & 1);
    float *Red = Image;
    float *Green = Image + NumPixels;
    float *Blue = Image + 2*NumPixels;
    int x, y, m;
    
    for(y = 0, m = 0; y < Height; y++)
        for(x = 0; x < Width; x++, m++)
            if(((x + y) & 1) == GreenPos)   /* Green location */
                Green[m] = Mosaic[m];
            else if((y & 1) == RedY)        /* Red location   */
                Red[m] = Mosaic[m];
            else                            /* Blue location  */
                Blue[m] = Mosaic[m];
}


/**
 * @brief Evaluate the contour stencils demosaicking energy function
 * @param Image the input RGB image in planar row-major order
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-leftmost red pixel
 * @param Alpha weight on the chromatic term
 * @param Weight the edge weights of the graph
 * @param Mosaic the input mosaiced image
 * @return Energy value
 * 
 * This routine evaluates the energy function to be minimized by the contour
 * stencil weighted-L1 demosaicking,
 * 
 * \f[ E(u) = \sum_m \Bigl(\sum_n \bigl(w_{m,n}
 * \lVert u_m - u_n \rVert_L \bigr)^2\Bigr)^{1/2} +
 * \alpha \sum_m \Bigl(\sum_n \bigl(w_{m,n}
 * \lVert u_m - u_n \rVert_C \bigr)^2\Bigr)^{1/2}, \f]
 * 
 * where in this computation, u is forced to agree with the mosaiced input 
 * data on the CFA, \f$ u_m^k = f_m, m \in \Omega^k, k \in \{R,G,B\} \f$.
 * 
 * When the CSWL1Demosaic() is called with ShowEnergy set to a nonzero value, 
 * the energy value is displayed after each Bregman iteration.  This can be 
 * used to check the convergence of the minimization. 
 */
float EvaluateCSWL1Energy(const float *Image, int Width, int Height,
    int RedX, int RedY, float Alpha, float (*Weight)[NUMNEIGH],
    const float *Mosaic)
{
    const int NumPixels = Width*Height;
    float *Red = NULL, *Green, *Blue;
    float Energy = 0, EnergyL, EnergyC, Diff[3], CDiff[3];
    int x, y, m, n, nOffset[NUMNEIGH];

    if(!(Red = (float *)Malloc(sizeof(float)*3*NumPixels)))
        return -1;

    memcpy(Red, Image, sizeof(float)*3*NumPixels);
    CopyCfaValues(Red, Mosaic, Width, Height, RedX, RedY);
    Green = Red + NumPixels;
    Blue = Red + 2*NumPixels;
    
    /* Precompute offsets for refering to pixel neighbors */
    for(n = 0; n < NUMNEIGH; n++)
        nOffset[n] = NeighX[n] + Width*NeighY[n];
    
    for(y = 0, m = 0; y < Height; y++)
        for(x = 0; x < Width; x++, m++)
        {
            EnergyL = EnergyC = 0;
            
            for(n = 0; n < NUMNEIGH; n++)
                if(0 <= x + NeighX[n] && x + NeighX[n] < Width 
                    && 0 <= y + NeighY[n] && y + NeighY[n] < Height)
                {
                    Diff[0] = Red[m] - Red[m + nOffset[n]];
                    Diff[1] = Green[m] - Green[m + nOffset[n]];
                    Diff[2] = Blue[m] - Blue[m + nOffset[n]];
                
                    /* Convert from RGB to transformed colorspace */
                    CDiff[0] = GetYComponent(Diff[0], Diff[1], Diff[2]);
                    CDiff[1] = GetUComponent(Diff[0], Diff[1], Diff[2]);
                    CDiff[2] = GetVComponent(Diff[0], Diff[1], Diff[2]);

                    /* Energy in the luminance "L" term */
                    EnergyL += Weight[m][n]*CDiff[0]*CDiff[0];
                    /* Energy in the chromatic "C" term */
                    EnergyC += Weight[m][n]*(
                        CDiff[1]*CDiff[1] + CDiff[2]*CDiff[2]);
                }
            
            Energy += (float)(sqrt(EnergyL) + Alpha*sqrt(EnergyC));
        }
    
    Free(Red);
    return Energy;
}


/** 
 * @brief Contour stencils weighted L1 demosaicing
 * @param Image the input RGB image in planar row-major order
 * @param Width, Height the image dimensions
 * @param RedX, RedY the coordinates of the upper-leftmost red pixel
 * @param Alpha weight on the chromatic term
 * @param Epsilon edge weight for weak links in the graph
 * @param Sigma graph filtering parameter
 * @param Tol stopping tolerance
 * @param MaxIter maximum number of iterations
 * @param ShowEnergy if nonzero, display the energy value after each iteration
 * @return 1 on success, 0 on failure
 * 
 * This is the main computation routine for contour stencils demosaicing.  It 
 * solves the minimization 
 * 
 * \f[ \left\{ \begin{aligned} \operatorname*{arg\,min}_{d,u} & \sum_m 
 * \Bigl(\sum_n \bigl(w_{m,n} d^L_{m,n} \bigr)^2\Bigr)^{1/2} + \alpha \sum_m 
 * \Bigl(\sum_n \Bigl(w_{m,n} \sqrt{(d^{C1}_{m,n})^2 + (d^{C2}_{m,n})^2} 
 * \,\Bigr)^2\Bigr)^{1/2} \\ \text{subject to} \; & d_{m,n} = C(u_m - u_n), 
 * \; m,n\in\mathbb{Z}^2, \\ & u_m^{k} = f_m, \; m\in\Omega^k, k\in\{R,G,B\}, 
 * \end{aligned}\right. \f]
 * 
 * by Bregman iteration.  This is done by alternatingly solving the 
 * D-subproblem with DShrink and the U-subproblem with UGaussSeidel.
 */
int CSWL1Demosaic(float *Image, int Width, int Height, 
    int RedX, int RedY, float Alpha, float Epsilon, float Sigma,
    float Tol, int MaxIter, int ShowEnergy)
{
    const int NumPixels = Width*Height;
    const int NumEl = 3*NumPixels;
    float *Mosaic = NULL, (*Weight)[NUMNEIGH] = NULL, *b = NULL;
    float (*d)[NUMNEIGH][3] = NULL, (*dtilde)[NUMNEIGH][3] = NULL;
    double InputNorm;
    unsigned long StartTime;
    float DiffNorm = 0;     
    int *Stencil = NULL;
    int Iter, Channel, i, n, Success = 0;
    
    /* Allocate memory */
    if(!(Weight = (float (*)[NUMNEIGH])
            Malloc(sizeof(float)*NUMNEIGH*NumPixels))
        || !(d = (float (*)[NUMNEIGH][3])
            Malloc(sizeof(float)*NUMNEIGH*NumEl))
        || !(dtilde = (float (*)[NUMNEIGH][3])
            Malloc(sizeof(float)*NUMNEIGH*NumEl))
        || !(b = (float *)Malloc(sizeof(float)*NumPixels))
        || !(Mosaic = (float *)Malloc(sizeof(float)*NumPixels)))
        goto Catch;
    
    /* Start the timer */
    StartTime = Clock();
    
    /* Flatten the input mosaiced image into a 2D array */
    CfaFlatten(Mosaic, Image, Width, Height, RedX, RedY);
    
    /* Build the graph */
    if(!ConstructGraph(Weight, Mosaic, Width, Height, 
        RedX, RedY, Epsilon, Sigma))
        goto Catch;
    
    /* Scale Tol by the norm of the mosaiced image */
    for(i = 0, InputNorm = 0; i < NumPixels; i++)
        InputNorm += Mosaic[i]*Mosaic[i];
    
    Tol *= (float)sqrt(InputNorm);
    
    /* Use bilinear demosaicking as the initial solution */
    BilinearDemosaic(Image, Mosaic, Width, Height, RedX, RedY);
    
    /* Initialize d, dtilde, and b to zero.  Note that it is not safely
       portable to use calloc or memset for this purpose.
       http://c-faq.com/malloc/calloc.html  */
    for(i = 0; i < NumPixels; i++)
        for(n = 0; n < NUMNEIGH; n++)
            for(Channel = 0; Channel < 3; Channel++)
                d[i][n][Channel] = 0;
            
    for(i = 0; i < NumPixels; i++)
        for(n = 0; n < NUMNEIGH; n++)
            for(Channel = 0; Channel < 3; Channel++)
                dtilde[i][n][Channel] = 0;           
            
    for(i = 0; i < NumPixels; i++)
        b[i] = 0;
    
    /* If the ShowEnergy flag is nonzero, we display a table with the 
     * iteration count in the first column and energy in the second column. 
     * Computing the energy value is unnecessary for the optimization itself 
     * and it is somewhat expensive, so we only compute it if ShowEnergy is
     * enabled.
     */
    if(ShowEnergy)
    {
        printf(" Iter     Energy\n");
        printf("%5d %10.1f\n", 0, 
                EvaluateCSWL1Energy(Image, Width, Height,
                    RedX, RedY, Alpha, Weight, Mosaic));
    }
    
    /* Bregman iterations */
    for(Iter = 1; Iter <= MaxIter; Iter++)
    {   
        /* Solve the D-subproblem (updates d and dtilde) */
        DShrink(d, dtilde, Image, Weight, Width, Height, Alpha);
        /* Solve the U-subproblem (updates u and b) */
        DiffNorm = UGaussSeidel(Image, b, dtilde, Mosaic, 
            Width, Height, RedX, RedY);
        
        if(ShowEnergy)
            printf("%5d %10.1f\n", Iter, 
                EvaluateCSWL1Energy(Image, Width, Height,
                    RedX, RedY, Alpha, Weight, Mosaic));
        
        if(DiffNorm <= Tol && Iter > 2)
        {
            printf("Converged in %d iterations.\n", Iter);
            break;
        }
    }
    
    if(Iter > MaxIter && !(DiffNorm <= Tol))
        printf("Maximum number of iterations exceeded.\n");
    
    /* Ensure that final solution matches input data on the CFA. */
    CopyCfaValues(Image, Mosaic, Width, Height, RedX, RedY);
    
    /* Print the time it took to perform the demosaicking */
    printf("CPU Time: %.3f s\n", 0.001f*(Clock() - StartTime));
    
    Success = 1;
Catch:
    Free(Stencil);
    Free(b);
    Free(Mosaic);
    Free(dtilde);
    Free(d);
    Free(Weight);
    return Success;
}
