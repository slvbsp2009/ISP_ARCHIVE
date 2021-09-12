/**
 * @file inv3x3.h
 * @brief Macro for 3x3 matrix inverse
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * Computes 3x3 matrix inverse as a macro using Cramer's rule.  If the matrix
 * elements are constant, this macro should allow the inverse to be determined
 * at compile time.
 * 
 * A convenient way to use these macros is to define a macro that evaluates
 * a function with your matrix as the arguments, then call it repeatedly to 
 * construct the inverse matrix.
@code
    #define _MYMAT(A)     A(12.5, -3.3, 0.1, \
                             0.1, 32.1, 0.0, \
                             0.0,  0.0, 5.1)
    
    #define INVMYMAT_11   _MYMAT(INV3X3_11)
    #define INVMYMAT_12   _MYMAT(INV3X3_12)
    #define INVMYMAT_13   _MYMAT(INV3X3_13)    
    
    #define INVMYMAT_21   _MYMAT(INV3X3_21)
    #define INVMYMAT_22   _MYMAT(INV3X3_22)
    #define INVMYMAT_23   _MYMAT(INV3X3_23)    
    
    #define INVMYMAT_31   _MYMAT(INV3X3_31)
    #define INVMYMAT_32   _MYMAT(INV3X3_32)
    #define INVMYMAT_33   _MYMAT(INV3X3_33)        
@endcode
 */
#ifndef _INV3X3_H_
#define _INV3X3_H_

#ifndef DOXYGEN_SHOULD_SKIP_THIS

#define DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    ((M_11)*((M_22)*(M_33) - (M_32)*(M_23)) \
    - (M_12)*((M_21)*(M_33) - (M_31)*(M_23)) \
    + (M_13)*((M_21)*(M_32) - (M_31)*(M_22)))

#define INV3X3_11(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_22)*(M_33) - (M_32)*(M_23)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))
#define INV3X3_12(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_13)*(M_32) - (M_33)*(M_12)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))
#define INV3X3_13(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_12)*(M_23) - (M_22)*(M_13)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))
#define INV3X3_21(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_23)*(M_31) - (M_33)*(M_21)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))        
#define INV3X3_22(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_11)*(M_33) - (M_13)*(M_31)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))        
#define INV3X3_23(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_13)*(M_21) - (M_23)*(M_11)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))        
#define INV3X3_31(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_21)*(M_32) - (M_31)*(M_22)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))        
#define INV3X3_32(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_12)*(M_31) - (M_32)*(M_11)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))        
#define INV3X3_33(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33) \
    (((M_11)*(M_22) - (M_21)*(M_12)) \
        / DET3X3(M_11, M_12, M_13, M_21, M_22, M_23, M_31, M_32, M_33))

#endif /* DOXYGEN_SHOULD_SKIP_THIS */

#endif /* _INV3X3_H_ */
