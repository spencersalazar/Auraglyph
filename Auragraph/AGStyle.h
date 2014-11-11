//
//  AGStyle.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGStyle__
#define __Auragraph__AGStyle__

#include "TexFont.h"
#include <string>

using namespace std;

class AGStyle
{
public:
    static const string &standardFontPath();
    static TexFont *standardFont64();
    
    static const GLcolor4f &lightColor();
    static const GLcolor4f &darkColor();
    static const GLcolor4f &frameBackgroundColor();
    static const GLcolor4f &errorColor();
    
    static const float open_squeezeHeight;
    static const float open_animTimeX;
    static const float open_animTimeY;
};

#endif /* defined(__Auragraph__AGStyle__) */
