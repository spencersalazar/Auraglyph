//
//  SPMath.h
//  Auragraph
//
//  Created by Spencer Salazar on 10/23/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_SPMath_h
#define Auragraph_SPMath_h

#include <math.h>


/* normAngle()
 - Normalize angle to [0, 2*pi)
 */
float normAngle(float th)
{
    while(th > M_PI*2) th -= M_PI*2;
    while(th <= 0) th += M_PI*2;
    return th;
}


#endif
