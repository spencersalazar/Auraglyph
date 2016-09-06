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
#include "Animation.h"


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
    
    static const GLcolor4f foregroundColor;
    static const GLcolor4f backgroundColor;
    
    constexpr static const float oldGlobalScale = 5000.0f;
};


class AGSqueezeAnimation
{
public:
    AGSqueezeAnimation()
    {
        open();
    }
    
    void open()
    {
        m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
        m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
    }
    
    void close()
    {
        m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
        m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
    }
    
    bool finishedClosing()
    {
        return m_xScale <= AGStyle::open_squeezeHeight;
    }
    
    bool isHorzOpen()
    {
        return m_xScale >= 0.99;
    }
    
    GLKMatrix4 matrix()
    {
        return GLKMatrix4MakeScale(m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                   m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                   1.0f);
    }
    
    void update(float t, float dt)
    {
        if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
        if(m_xScale >= 0.99f) m_yScale.update(dt);
    }
    
private:
    lincurvef m_xScale;
    lincurvef m_yScale;
};


#endif /* defined(__Auragraph__AGStyle__) */
