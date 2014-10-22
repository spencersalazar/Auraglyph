//
//  GeoGenerator.h
//  Auragraph
//
//  Created by Spencer Salazar on 10/21/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_GeoGenerator_h
#define Auragraph_GeoGenerator_

#include "Geometry.h"
#include <math.h>


namespace GeoGen
{
    /* makeCircle()
     - Generate vertices for circle centered at (0,0,0) and with specified radius
     - points must have sufficient
     - Draw as stroke with GL_LINE_LOOP (skip the first vertex)
     or fill with GL_TRIANGLE_FAN
     */
    void makeCircle(GLvertex3f *points, int numPoints, float radius)
    {
        for(int i = 0; i < numPoints; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(numPoints));
            points[i] = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
        }
    }
}


#endif
