//
//  AGStyle.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGStyle.h"


const string &AGStyle::standardFontPath()
{
    static string s_path;
    if(s_path.length() == 0)
    {
        s_path = string([[[NSBundle mainBundle] pathForResource:@"Orbitron-Medium.ttf" ofType:@""] UTF8String]);
    }
    
    return s_path;
}

TexFont *AGStyle::standardFont64()
{
    static TexFont *texFont64 = NULL;
    
    if(texFont64 == NULL)
    {
        texFont64 = new TexFont(standardFontPath(), 64);
    }
    
    return texFont64;
}

