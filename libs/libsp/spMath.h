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
    if(th == INFINITY || th == -INFINITY || th == NAN)
        return th;
    
    // fmodf(x,y) is negative if x is negative
    // so add 2pi if its negative
    return fmodf(th, 2.0f*M_PI) + (th<0)*2.0f*M_PI;
}


#endif
