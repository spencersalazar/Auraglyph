//
//  GeoGenerator.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 10/22/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "GeoGenerator.h"

namespace GeoGen
{
    void makeCircle(GLvertex3f *points, int numPoints, float radius)
    {
        points[0] = GLvertex3f(0, 0, 0);
        for(int i = 0; i < numPoints-1; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(numPoints-2));
            points[1+i] = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
        }
    }
    
    void makeCircleStroke(GLvertex3f *points, int numPoints, float radius)
    {
        for(int i = 0; i < numPoints; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(numPoints-1));
            points[i] = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
        }
    }
    
    
    GLvertex3f *circle64()
    {
        static GLvertex3f *s_geo = NULL;
        
        if(s_geo == NULL)
        {
            s_geo = new GLvertex3f[64];
            makeCircle(s_geo, 64, 1);
        }
        
        return s_geo;
    }
    
    
    void makeRect(GLvertex3f *points, float width, float height)
    {
        points[0] = GLvertex3f(-width/2.0f,  height/2.0f, 0);
        points[1] = GLvertex3f(-width/2.0f, -height/2.0f, 0);
        points[2] = GLvertex3f( width/2.0f, -height/2.0f, 0);
        points[3] = GLvertex3f( width/2.0f,  height/2.0f, 0);
    }
    
    void makeRect(GLvertex3f *points, float x, float y, float width, float height)
    {
        points[0] = GLvertex3f(x-width/2.0f, y+height/2.0f, 0);
        points[1] = GLvertex3f(x-width/2.0f, y-height/2.0f, 0);
        points[2] = GLvertex3f(x+width/2.0f, y-height/2.0f, 0);
        points[3] = GLvertex3f(x+width/2.0f, y+height/2.0f, 0);
    }
    
    void makeRectUV(GLvertex2f *points)
    {
        points[0] = GLvertex2f(0, 1);
        points[1] = GLvertex2f(0, 0);
        points[2] = GLvertex2f(1, 0);
        points[3] = GLvertex2f(1, 1);
    }
}

