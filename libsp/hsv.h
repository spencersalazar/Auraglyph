//
//  hsv.h
//  MobileMusic
//
//  Created by Spencer Salazar on 7/1/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#ifndef MobileMusic_hsv_h
#define MobileMusic_hsv_h

#include "Geometry.h"

static GLcolor4f hsv2rgb(GLcolor4f hsv)
{
    GLcolor4f rgb;
    
    //    // thanks http://en.wikipedia.org/wiki/HSL_and_HSV#From_HSV !
    //    float C = hsv.v * hsv.s;
    //    float H_prime = hsv.h * 360 / 60;
    //    float X = C * (1 - fabs(((int)H_prime)%2 - 1));
    //    
    //    if     (in_range(H_prime, 0, 1)) { rgb.r = C; rgb.g = X; rgb.b = 0; }
    //    else if(in_range(H_prime, 1, 2)) { rgb.r = X; rgb.g = C; rgb.b = 0; }
    //    else if(in_range(H_prime, 2, 3)) { rgb.r = 0; rgb.g = C; rgb.b = X; }
    //    else if(in_range(H_prime, 3, 4)) { rgb.r = 0; rgb.g = X; rgb.b = C; }
    //    else if(in_range(H_prime, 4, 5)) { rgb.r = X; rgb.g = 0; rgb.b = C; }
    //    else if(in_range(H_prime, 5, 6)) { rgb.r = C; rgb.g = 0; rgb.b = X; }
    //    
    //    float m = hsv.v - C;
    //    
    //    rgb.r += m;
    //    rgb.g += m;
    //    rgb.b += m;
    
    // thanks http://www.alvyray.com/Papers/hsv2rgb.htm !
    
    float h = hsv.h*6, s = hsv.s, v = hsv.v, m, n, f;
	int i;
	
    //	if (h == UNDEFINED) RETURN_RGB(v, v, v);
	i = floor(h);
	f = h - i;
	if ( !(i&1) ) f = 1 - f; // if i is even
	m = v * (1 - s);
	n = v * (1 - s * f);
	switch (i) {
		case 6:
		case 0: rgb = GLcolor4f(v, n, m, 1.0); break;
		case 1: rgb = GLcolor4f(n, v, m, 1.0); break;
		case 2: rgb = GLcolor4f(m, v, n, 1.0); break;
		case 3: rgb = GLcolor4f(m, n, v, 1.0); break;
		case 4: rgb = GLcolor4f(n, m, v, 1.0); break;
		case 5: rgb = GLcolor4f(v, m, n, 1.0); break;
	} 
    
    return rgb;
}



#endif
