//
//  Geometry.cpp
//  Mood Globe
//
//  Created by Spencer Salazar on 6/26/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#include "Geometry.h"
#include <stdio.h>


static const GLcolor4f g_white(1, 1, 1, 1);
static const GLcolor4f g_red(1, 0, 0, 1);
static const GLcolor4f g_green(0, 1, 0, 1);
static const GLcolor4f g_blue(0, 0, 1, 1);
static const GLcolor4f g_black(0, 0, 0, 1);

const GLcolor4f &GLcolor4f::white() { return g_white; }
const GLcolor4f &GLcolor4f::red() { return g_red; }
const GLcolor4f &GLcolor4f::green() { return g_green; }
const GLcolor4f &GLcolor4f::blue() { return g_blue; }
const GLcolor4f &GLcolor4f::black() { return g_black; }

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

bool operator==(const GLvertex3f &v, const GLvertex3f &v2)
{
    return v.x == v2.x && v.y == v2.y && v.z == v2.z;
}

bool operator!=(const GLvertex3f &v, const GLvertex3f &v2)
{
    return v.x != v2.x || v.y != v2.y || v.z != v2.z;
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
