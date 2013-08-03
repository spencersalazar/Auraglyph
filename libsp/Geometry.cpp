//
//  Geometry.cpp
//  Mood Globe
//
//  Created by Spencer Salazar on 6/26/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#include "Geometry.h"
#include <stdio.h>


GLvertex3f::GLvertex3f(const GLvertex2f &v)
{
    x = v.x;
    y = v.y;
    z = 0;
}

GLvertex2f GLvertex3f::toLatLong()
{
    GLvertex2f ll;
    ll.x = (atan2f(y,x) / M_PI + 1.0f) * 0.5f;
    ll.y = asinf(z) / M_PI + 0.5f;
    
    return ll;
}

GLvertex3f operator+(const GLvertex3f &v1, const GLvertex3f &v2)
{
    GLvertex3f v3 = GLvertex3f(v1.x+v2.x, v1.y+v2.y, v1.z+v2.z);
    return v3;
}

GLvertex3f operator-(const GLvertex3f &v1, const GLvertex3f &v2)
{
    GLvertex3f v3 = GLvertex3f(v1.x-v2.x, v1.y-v2.y, v1.z-v2.z);
    return v3;
}

GLvertex3f operator*(const GLvertex3f &v, const GLfloat &s)
{
    GLvertex3f v2 = GLvertex3f(v.x*s, v.y*s, v.z*s);
    return v2;
}

GLvertex3f operator/(const GLvertex3f &v, const GLfloat &s)
{
    GLvertex3f v2 = GLvertex3f(v.x/s, v.y/s, v.z/s);
    return v2;
}
