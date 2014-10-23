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
}

