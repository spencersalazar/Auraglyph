//
//  Matrix.h
//  Auraglyph
//
//  Created by Spencer Salazar on 1/1/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "Geometry.h"

#if defined(__APPLE__)
#define ENABLE_GLKIT (1)
#else
#error only works on apple
#endif // defined(__APPLE__)

#if ENABLE_GLKIT
#include <GLKit/GLKMath.h>
#endif

class Matrix4
{
public:
    
    static const Matrix4 identity;
    static Matrix4 makeTranslation(float tx, float ty, float tz);
    static Matrix4 makeScale(float sx, float sy, float sz);
    static Matrix4 makeRotation(float radians, float rx, float ry, float rz);

    Matrix4();
    Matrix4(const GLKMatrix4 &mat);

    Matrix4 translate(float tx, float ty, float tz) const;
    Matrix4 translate(const GLvertex3f &vec) const;
    Matrix4 scale(float sx, float sy, float sz) const;
    Matrix4 scale(float s) const;
    Matrix4 rotate(float radians, float rx, float ry, float rz) const;
    Matrix4 multiply(const Matrix4 &mat) const;
    
    Matrix4 &translateInPlace(float tx, float ty, float tz);
    Matrix4 &translateInPlace(const GLvertex3f &vec);
    Matrix4 &scaleInPlace(float sx, float sy, float sz);
    Matrix4 &scaleInPlace(float s);
    Matrix4 &rotateInPlace(float radians, float rx, float ry, float rz);
    Matrix4 &multiplyInPlace(const Matrix4 &mat);
    
    const float *data() const;
    
    operator GLKMatrix4 () const;
    
private:
    GLKMatrix4 m_mat;
};


