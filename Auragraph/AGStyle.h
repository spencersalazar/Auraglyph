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
    static TexFont *standardFont96();
    constexpr static const float standardFontScale = 0.61f;
    constexpr static const float smallFontScale = standardFontScale*0.61f;
    
    inline static const GLcolor4f &lightColor()
    {
        static GLcolor4f s_lightColor = GLcolor4f::white;
        return s_lightColor;
    }
    
    inline static const GLcolor4f &darkColor()
    {
        static GLcolor4f s_darkColor = GLcolor4f::black;
        return s_darkColor;
    }
    
    inline static const GLcolor4f &frameBackgroundColor()
    {
        static GLcolor4f s_frameBackgroundColor = GLcolor4f(0, 0, 0, 0.75);
        return s_frameBackgroundColor;
    }
    
    inline static const GLcolor4f &errorColor()
    {
        static GLcolor4f s_errorColor = GLcolor4f(1, 0, 0, 1);
        return s_errorColor;
    }
    
    inline static const GLcolor4f &proceedColor()
    {
        static GLcolor4f s_errorColor = GLcolor4f(0, 1, 0, 1);
        return s_errorColor;
    }

    static const float open_squeezeHeight;
    static const float open_animTimeX;
    static const float open_animTimeY;
    
    static const GLvertex2f editor_titleInset;
    
    inline static const GLcolor4f &foregroundColor()
    {
        static GLcolor4f s_foregroundColor = GLcolor4f(1.0f, 1.0f, 1.0f, 1.0f);
        return s_foregroundColor;
    }
    
    static const GLcolor4f &backgroundColor()
    {
        static GLcolor4f s_backgroundColor = GLcolor4f(12.0f/255.0f, 16.0f/255.0f, 33.0f/255.0f, 1.0f);
        return s_backgroundColor;
    }
    
    constexpr static const float aspect16_9 = 16.0f/9.0f;
    
    constexpr static const float oldGlobalScale = 5000.0f;
    
    constexpr static const float maxTravel = 5.0f;
    
private:
    
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
    
    GLKMatrix4 apply(const GLKMatrix4 &m)
    {
        return GLKMatrix4Scale(m,
                               m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
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
