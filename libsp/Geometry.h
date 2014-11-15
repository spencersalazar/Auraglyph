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
#import <CoreGraphics/CoreGraphics.h>

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
    
    GLfloat magnitude() const { return sqrtf(x*x+y*y+z*z); }
    GLfloat magnitudeSquared() const { return x*x+y*y+z*z; }
    
    GLvertex2f xy() const;
    
    GLvertex2f toLatLong() const;
} __attribute__((packed));

GLvertex3f operator+(const GLvertex3f &v1, const GLvertex3f &v2);
GLvertex3f operator-(const GLvertex3f &v1, const GLvertex3f &v2);
GLvertex3f operator*(const GLvertex3f &v, const GLfloat &s);
GLvertex3f operator/(const GLvertex3f &v, const GLfloat &s);
bool operator==(const GLvertex3f &v, const GLvertex3f &v2);
bool operator!=(const GLvertex3f &v, const GLvertex3f &v2);
GLvertex3f lerp(float d, const GLvertex3f &a, const GLvertex3f &b);

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
    
    static const GLcolor4f white;
    static const GLcolor4f red;
    static const GLcolor4f green;
    static const GLcolor4f blue;
    static const GLcolor4f black;
    
} __attribute__((packed));


GLvertex2f operator+(const GLvertex2f &v1, const GLvertex2f &v2);
GLvertex2f operator-(const GLvertex2f &v1, const GLvertex2f &v2);
GLvertex2f operator*(const GLvertex2f &v, const GLfloat &s);
GLvertex2f operator/(const GLvertex2f &v, const GLfloat &s);
bool operator==(const GLvertex2f &v, const GLvertex2f &v2);
bool operator!=(const GLvertex2f &v, const GLvertex2f &v2);
GLcolor4f lerp(float d, const GLcolor4f &a, const GLcolor4f &b);


struct GLvertex2f
{
    GLfloat x;
    GLfloat y;
    
    GLvertex2f()
    {
        x = y = 0;
    }
    
    GLvertex2f(const CGPoint &p)
    {
        x = p.x;
        y = p.y;
    }
    
    GLvertex2f(GLfloat x, GLfloat y)
    {
        this->x = x;
        this->y = y;
    }

    GLfloat magnitude() const { return sqrtf(x*x+y*y); }
    GLfloat magnitudeSquared() const { return x*x+y*y; }
    GLfloat angle() const { return atan2f(y, x); }

    GLfloat distanceTo(const GLvertex2f &p) const { return sqrtf((x-p.x)*(x-p.x)+(y-p.y)*(y-p.y)); }
    GLfloat distanceSquaredTo(const GLvertex2f &p) const { return (x-p.x)*(x-p.x)+(y-p.y)*(y-p.y); }
    
    GLfloat dot(const GLvertex2f &v) const { return x*v.x + y*v.y; }
    
    GLvertex2f normalize() const
    {
        return GLvertex2f(x,y)/magnitude();
    }
    
} __attribute__((packed));


// geometry primitve, i.e. vertex/normal/uv/color
struct GLgeoprimf
{
    GLgeoprimf() :
    vertex(GLvertex3f(0, 0, 0)), normal(GLvertex3f(0, 0, 1)),
    texcoord(GLvertex2f(0, 0)), color(GLcolor4f(1, 1, 1, 1))
    { }
    
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
    GLvncprimf() :
    vertex(GLvertex3f(0, 0, 0)), normal(GLvertex3f(0, 0, 1)), color(GLcolor4f(1, 1, 1, 1))
    { }

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

// rect primitive -- 4 vertex primitives
// fill directly as GL_TRIANGLE_FAN or stroke as GL_LINE_LOOP
struct GLvrectf
{
    GLvrectf() :
    bl(GLvertex3f(0, 0, 0)), br(GLvertex3f(0, 0, 0)), ul(GLvertex3f(0, 0, 0)), ur(GLvertex3f(0, 0, 0))
    { }
    
    GLvrectf(const GLvertex3f &_bl, const GLvertex3f &_ur) :
    bl(_bl), ur(_ur), br(GLvertex3f(_ur.x, _bl.y, 0.5*(_ur.z+_bl.z))), ul(GLvertex3f(_bl.x, _ur.y, 0.5*(_ur.z+_bl.z)))
    { }
    
    bool contains(const GLvertex3f &p);
    
    GLvertex3f bl; // bottom left
    GLvertex3f br; // bottom right
    GLvertex3f ur; // upper right
    GLvertex3f ul; // upper left
} __attribute__((packed));


static bool pointOnLine(const GLvertex2f &point, const GLvertex2f &line0, const GLvertex2f &line1, float thres)
{
    GLvertex2f normal = GLvertex2f(line1.y - line0.y, line0.x - line1.x).normalize();
    GLvertex2f bound1 = line1 - line0;
    GLvertex2f bound2 = line0 - line1;
    
    if(fabsf(normal.dot(point-line0)) < thres &&
       bound1.dot(point-line0) > 0 &&
       bound2.dot(point-line1) > 0)
        return true;
    
    return false;
}

static inline float distanceToLine(const GLvertex2f &point, const GLvertex2f &line0, const GLvertex2f &line1)
{
    GLvertex2f normal = GLvertex2f(line1.y - line0.y, line0.x - line1.x).normalize();
    return normal.dot(point-line0);
}

static inline bool pointInTriangle(const GLvertex2f &point, const GLvertex2f &v0, const GLvertex2f &v1, const GLvertex2f &v2)
{
    /* points should be in clockwise order */
    if(distanceToLine(point, v0, v1) >= 0 &&
       distanceToLine(point, v1, v2) >= 0 &&
       distanceToLine(point, v2, v0) >= 0)
        return true;
    return false;
}

static inline bool pointInRectangle(const GLvertex2f &point, const GLvertex2f &bottomLeft, const GLvertex2f &topRight)
{
    if(point.x >= bottomLeft.x && point.x <= topRight.x &&
       point.y >= bottomLeft.y && point.y <= topRight.y)
        return true;
    return false;
}

static inline bool pointInCircle(const GLvertex2f &point, const GLvertex2f &center, float radius)
{
    if(GLvertex2f(point.x - center.x, point.y - center.y).magnitudeSquared() <= radius*radius)
        return true;
    return false;
}


#endif
