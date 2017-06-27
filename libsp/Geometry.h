//
//  Geometry.h
//  Mood Globe
//
//  Created by Spencer Salazar on 6/26/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#ifndef Mood_Globe_Geometry_h
#define Mood_Globe_Geometry_h

#include <math.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <CoreGraphics/CoreGraphics.h>
#include "gfx.h"

#if defined(__APPLE__)
#define ENABLE_GLKIT (1)
#else
#error only works on apple 
#endif // defined(__APPLE__)

#if ENABLE_GLKIT
#include <GLKit/GLKMath.h>
#endif


struct GLvertex2f;
struct GLvertex3f;


GLvertex3f operator+(const GLvertex3f &v1, const GLvertex3f &v2);
GLvertex3f operator-(const GLvertex3f &v1, const GLvertex3f &v2);
GLvertex3f operator*(const GLvertex3f &v, const GLfloat &s);
GLvertex3f operator/(const GLvertex3f &v, const GLfloat &s);
bool operator==(const GLvertex3f &v, const GLvertex3f &v2);
bool operator!=(const GLvertex3f &v, const GLvertex3f &v2);
GLvertex3f lerp(float d, const GLvertex3f &a, const GLvertex3f &b);

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
    
#if ENABLE_GLKIT
    
    GLvertex3f(const GLKVector3 &vec)
    {
        x = vec.x;
        y = vec.y;
        z = vec.z;
    }
    
    GLvertex3f(const GLKVector4 &vec)
    {
        x = vec.x/vec.w;
        y = vec.y/vec.w;
        z = vec.z/vec.w;
    }
    
    GLKVector3 asGLKVector3() const { return GLKVector3Make(x, y, z); }
    GLKVector4 asGLKVector4() const { return GLKVector4Make(x, y, z, 1); }
    
#endif // ENABLE_GLKIT
    
} __attribute__((aligned(4),packed));


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
    
#if ENABLE_GLKIT
    inline void set(AGVertexAttrib attrib = AGVertexAttribColor) const
    {
        glVertexAttrib4fv(attrib, (const GLfloat *) this);
    }
#endif // ENABLE_GLKIT
    
    static const GLcolor4f white;
    static const GLcolor4f red;
    static const GLcolor4f green;
    static const GLcolor4f blue;
    static const GLcolor4f black;
    
} __attribute__((aligned(4),packed));


GLcolor4f lerp(float d, const GLcolor4f &a, const GLcolor4f &b);


GLvertex2f operator+(const GLvertex2f &v1, const GLvertex2f &v2);
GLvertex2f operator-(const GLvertex2f &v1, const GLvertex2f &v2);
GLvertex2f operator*(const GLvertex2f &v, const GLfloat &s);
GLvertex2f operator/(const GLvertex2f &v, const GLfloat &s);
bool operator==(const GLvertex2f &v, const GLvertex2f &v2);
bool operator!=(const GLvertex2f &v, const GLvertex2f &v2);
GLvertex2f rotateZ(const GLvertex2f &v, GLfloat rads);
GLvertex3f rotateZ(const GLvertex3f &v, GLfloat rads);

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
    
} __attribute__((aligned(4),packed));


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

// TODO: point-by-point amortized version of this
static inline float area(const GLvertex3f *points, int N)
{
    // via http://stackoverflow.com/questions/451426/how-do-i-calculate-the-area-of-a-2d-polygon
    
    float area = 0;
    for(size_t i = 1; i <= N; ++i)
        area += points[i%N].x*(points[(i+1)%N].y - points[(i-1)%N].y);
    area /= 2;
    
    return fabsf(area);
}

// point in polygon methods

// Copyright 2000 softSurfer, 2012 Dan Sunday
// This code may be freely used and modified for any purpose
// providing that this copyright notice is included with it.
// SoftSurfer makes no warranty for this code, and cannot be held
// liable for any real or imagined damage resulting from its use.
// Users of this code must verify correctness for their application.


// a Point is defined by its coordinates {int x, y;}
//===================================================================


// isLeft(): tests if a point is Left|On|Right of an infinite line.
//    Input:  three points P0, P1, and P2
//    Return: >0 for P2 left of the line through P0 and P1
//            =0 for P2  on the line
//            <0 for P2  right of the line
//    See: Algorithm 1 "Area of Triangles and Polygons"
static inline int
isLeft( GLvertex3f P0, GLvertex3f P1, GLvertex3f P2 )
{
    return ( (P1.x - P0.x) * (P2.y - P0.y)
            - (P2.x -  P0.x) * (P1.y - P0.y) );
}
//===================================================================


// cn_PnPoly(): crossing number test for a point in a polygon
//      Input:   P = a point,
//               V[] = vertex points of a polygon V[n+1] with V[n]=V[0]
//      Return:  0 = outside, 1 = inside
// This code is patterned after [Franklin, 2000]
static int
cn_PnPoly( GLvertex3f P, const GLvertex3f* V, int n )
{
    int    cn = 0;    // the  crossing number counter
    
    // loop through all edges of the polygon
    for (int i=0; i<n; i++) {    // edge from V[i]  to V[i+1]
        if (((V[i].y <= P.y) && (V[(i+1)%n].y > P.y))     // an upward crossing
            || ((V[i].y > P.y) && (V[(i+1)%n].y <=  P.y))) { // a downward crossing
            // compute  the actual edge-ray intersect x-coordinate
            float vt = (float)(P.y  - V[i].y) / (V[(i+1)%n].y - V[i].y);
            if (P.x <  V[i].x + vt * (V[(i+1)%n].x - V[i].x)) // P.x < intersect
                ++cn;   // a valid crossing of y=P.y right of P.x
        }
    }
    return (cn&1);    // 0 if even (out), and 1 if  odd (in)
    
}
//===================================================================


// wn_PnPoly(): winding number test for a point in a polygon
//      Input:   P = a point,
//               V[] = vertex points of a polygon V[n+1] with V[n]=V[0]
//      Return:  wn = the winding number (=0 only when P is outside)
static int
wn_PnPoly( GLvertex3f P, const GLvertex3f* V, int n )
{
    int    wn = 0;    // the  winding number counter
    
    // loop through all edges of the polygon
    for (int i=0; i<n; i++) {   // edge from V[i] to  V[i+1]
        if (V[i].y <= P.y) {          // start y <= P.y
            if (V[(i+1)%n].y  > P.y)      // an upward crossing
                if (isLeft( V[i], V[(i+1)%n], P) > 0)  // P left of  edge
                    ++wn;            // have  a valid up intersect
        }
        else {                        // start y > P.y (no test needed)
            if (V[(i+1)%n].y  <= P.y)     // a downward crossing
                if (isLeft( V[i], V[(i+1)%n], P) < 0)  // P right of  edge
                    --wn;            // have  a valid down intersect
        }
    }
    return wn;
}
//===================================================================


static inline bool pointInPolygon(GLvertex3f p, const GLvertex3f *poly, int N)
{
    return wn_PnPoly(p, poly, N) != 0;
}


#if ENABLE_GLKIT

static inline GLvertex3f operator*(GLKMatrix4 m, GLvertex3f v)
{
    GLKVector3 v2 = GLKMatrix4MultiplyVector3(m, GLKVector3Make(v.x, v.y, v.z));
    return GLvertex3f(v2.x, v2.y, v2.z);
}

#endif // ENABLE_GLKIT


#endif
