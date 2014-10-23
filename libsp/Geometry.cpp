//
//  Geometry.cpp
//  Mood Globe
//
//  Created by Spencer Salazar on 6/26/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#include "Geometry.h"
#include <stdio.h>


const GLcolor4f GLcolor4f::white(1, 1, 1, 1);
const GLcolor4f GLcolor4f::red(1, 0, 0, 1);
const GLcolor4f GLcolor4f::green(0, 1, 0, 1);
const GLcolor4f GLcolor4f::blue(0, 0, 1, 1);
const GLcolor4f GLcolor4f::black(0, 0, 0, 1);

//GLcolor4f GLcolor4f::white() { return GLcolor4f(1, 1, 1, 1); }
//GLcolor4f GLcolor4f::red() { return GLcolor4f(1, 0, 0, 1); }
//GLcolor4f GLcolor4f::green() { return GLcolor4f(0, 1, 0, 1); }
//GLcolor4f GLcolor4f::blue() { return GLcolor4f(0, 0, 1, 1); }
//GLcolor4f GLcolor4f::black() { return GLcolor4f(0, 0, 0, 1); }

GLvertex3f::GLvertex3f(const GLvertex2f &v)
{
    x = v.x;
    y = v.y;
    z = 0;
}

GLvertex2f GLvertex3f::toLatLong() const
{
    GLvertex2f ll;
    ll.x = (atan2f(y,x) / M_PI + 1.0f) * 0.5f;
    ll.y = asinf(z) / M_PI + 0.5f;
    
    return ll;
}

GLvertex2f GLvertex3f::xy() const
{
    return GLvertex2f(x, y);
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

bool operator==(const GLvertex3f &v, const GLvertex3f &v2)
{
    return v.x == v2.x && v.y == v2.y && v.z == v2.z;
}

bool operator!=(const GLvertex3f &v, const GLvertex3f &v2)
{
    return v.x != v2.x || v.y != v2.y || v.z != v2.z;
}

GLvertex3f lerp(float d, const GLvertex3f &a, const GLvertex3f &b)
{
    return GLvertex3f(a.x*(1-d)+b.x*d, a.y*(1-d)+b.y*d, a.z*(1-d)+b.z*d);
}

GLvertex2f operator+(const GLvertex2f &v1, const GLvertex2f &v2)
{
    GLvertex2f v3 = GLvertex2f(v1.x+v2.x, v1.y+v2.y);
    return v3;
}

GLvertex2f operator-(const GLvertex2f &v1, const GLvertex2f &v2)
{
    GLvertex2f v3 = GLvertex2f(v1.x-v2.x, v1.y-v2.y);
    return v3;
}

GLvertex2f operator*(const GLvertex2f &v, const GLfloat &s)
{
    GLvertex2f v2 = GLvertex2f(v.x*s, v.y*s);
    return v2;
}

GLvertex2f operator/(const GLvertex2f &v, const GLfloat &s)
{
    GLvertex2f v2 = GLvertex2f(v.x/s, v.y/s);
    return v2;
}

bool operator==(const GLvertex2f &v, const GLvertex2f &v2)
{
    return v.x == v2.x && v.y == v2.y;
}

bool operator!=(const GLvertex2f &v, const GLvertex2f &v2)
{
    return v.x != v2.x || v.y != v2.y;
}
