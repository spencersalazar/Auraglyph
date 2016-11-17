//
//  AGStyle.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGStyle.h"

const float AGStyle::open_squeezeHeight = 0.00125;
const float AGStyle::open_animTimeX = 0.4;
const float AGStyle::open_animTimeY = 0.15;

//const GLcolor4f AGStyle::foregroundColor = GLcolor4f(0.75f, 0.5f, 0.0f, 1.0f);
const GLcolor4f AGStyle::foregroundColor = GLcolor4f(1.0f, 1.0f, 1.0f, 1.0f);
const GLcolor4f AGStyle::backgroundColor = GLcolor4f(12.0f/255.0f, 16.0f/255.0f, 33.0f/255.0f, 1.0f);

const string &AGStyle::standardFontPath()
{
    static string s_path;
    if(s_path.length() == 0)
    {
        s_path = string([[[NSBundle mainBundle] pathForResource:@"Orbitron-Medium.ttf" ofType:@""] UTF8String]);
//        s_path = string([[[NSBundle mainBundle] pathForResource:@"bankgthd.ttf" ofType:@""] UTF8String]);
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

const GLcolor4f &AGStyle::lightColor()
{
    static GLcolor4f s_lightColor = GLcolor4f::white;
    return s_lightColor;
}

const GLcolor4f &AGStyle::darkColor()
{
    static GLcolor4f s_darkColor = GLcolor4f::black;
    return s_darkColor;
}

const GLcolor4f &AGStyle::frameBackgroundColor()
{
    static GLcolor4f s_frameBackgroundColor = GLcolor4f(0, 0, 0, 0.75);
    return s_frameBackgroundColor;
}

const GLcolor4f &AGStyle::errorColor()
{
    static GLcolor4f s_errorColor = GLcolor4f(1, 0, 0, 1);
    return s_errorColor;
}

