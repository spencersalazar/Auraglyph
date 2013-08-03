//
//  Geometry.h
//  Mood Globe
//
//  Created by Spencer Salazar on 6/26/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#ifndef Mood_Globe_Geometry_h
#define Mood_Globe_Geometry_h

#import <math.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

struct GLvertex2f;

struct GLvertex3f
{
    GLfloat x;
    GLfloat y;
    GLfloat z;
    
    GLvertex3f()
    {
        x = y = z = 0;
    }
    
    GLvertex3f(const GLvertex2f &v);
    
    GLvertex3f(GLfloat x, GLfloat y, GLfloat z)
    {
        this->x = x;
        this->y = y;
        this->z = z;
    }
    
    GLfloat magnitude() { return sqrtf(x*x+y*y+z*z); }
    GLfloat magnitudeSquared() { return x*x+y*y+z*z; }
    
    GLvertex2f toLatLong();
} __attribute__((packed));

GLvertex3f operator+(const GLvertex3f &v1, const GLvertex3f &v2);
GLvertex3f operator-(const GLvertex3f &v1, const GLvertex3f &v2);
GLvertex3f operator*(const GLvertex3f &v, const GLfloat &s);
GLvertex3f operator/(const GLvertex3f &v, const GLfloat &s);

struct GLcolor4f
{
    union
    {
        GLfloat r;
        GLfloat h;
    };
    
    union
    {
        GLfloat g;
        GLfloat s;
    };
    
    union
    {
        GLfloat b;
        GLfloat v;
    };
    
    GLfloat a;
    
    
    GLcolor4f()
    {
        r = g = b = a = 1;
    }
    
    GLcolor4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a)
    {
        this->r = r;
        this->g = g;
        this->b = b;
        this->a = a;
    }
    
} __attribute__((packed));

struct GLvertex2f
{
    GLfloat x;
    GLfloat y;
    
    GLvertex2f()
    {
        x = y = 0;
    }
    
    GLvertex2f(GLfloat x, GLfloat y)
    {
        this->x = x;
        this->y = y;
    }

    GLfloat magnitude() { return sqrtf(x*x+y*y); }
    GLfloat magnitudeSquared() { return x*x+y*y; }

} __attribute__((packed));

// geometry primitve, i.e. vertex/normal/uv/color
struct GLgeoprimf
{
    GLvertex3f vertex;
    GLvertex3f normal;
    GLvertex2f texcoord;
    GLcolor4f color;
} __attribute__((packed));

// vertex + color primitve, i.e. vertex/color
struct GLvcprimf
{
    GLvertex3f vertex;
    GLcolor4f color;
} __attribute__((packed));


// vertex + normal + color primitve, i.e. vertex/normal/color
struct GLvncprimf
{
    GLvertex3f vertex;
    GLvertex3f normal;
    GLcolor4f color;
} __attribute__((packed));

// triangle primitive -- 3 vertex primitives
struct GLtrif
{
    GLgeoprimf a;
    GLgeoprimf b;
    GLgeoprimf c;
} __attribute__((packed));



#endif
