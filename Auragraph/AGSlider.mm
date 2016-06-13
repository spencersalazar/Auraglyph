//
//  AGSlider.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 4/22/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGSlider.h"

#include "TexFont.h"
#include "AGStyle.h"
#include <sstream>

AGSlider::AGSlider(GLvertex3f position, float value)
: m_value(value), m_position(position)
{
    _updateValue(value);
}

AGSlider::~AGSlider()
{
    
}

void AGSlider::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
}

void AGSlider::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    GLKMatrix4 modelView = globalModelViewMatrix();
    GLKMatrix4 proj = projectionMatrix();
    
    GLcolor4f valueColor = GLcolor4f::white;
    valueColor.a = m_renderState.alpha;
    
    GLKMatrix4 valueMV = modelView;
    valueMV = GLKMatrix4Translate(valueMV, position().x, position().y, position().z);
    valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
//    valueMV = GLKMatrix4Translate(valueMV, -m_size.x/2.0f, -m_size.y/2, 0);
    text->render(m_valueStream.str(), valueColor, valueMV, proj);
}

void AGSlider::touchDown(const AGTouchInfo &t)
{
    NSLog(@"touchDown %f %f", t.screenPosition.x, t.screenPosition.y);
    
    m_firstFinger = t;
    m_lastPosition = t;
    m_ytravel = 0;
}

void AGSlider::touchMove(const AGTouchInfo &t)
{
    NSLog(@"touchMove %f %f", t.screenPosition.x, t.screenPosition.y);
    
    m_ytravel += m_lastPosition.screenPosition.y - t.screenPosition.y;
    
    float travelFactor = 0.0;
    if(m_scale == LINEAR)
        travelFactor = 12;
    else if(m_scale == EXPONENTIAL)
        travelFactor = 4;
    
    float amount = floorf(m_ytravel/travelFactor);
    m_ytravel = fmodf(m_ytravel, travelFactor);
    
    double inc;
    
    if(m_scale == EXPONENTIAL)
    {
        float log = log10f(m_value)-0.1;
        int oom = (int)floorf(log);
        inc = powf(10, oom-1);
        
        if(m_type == DISCRETE)
            inc = std::max(1.0, inc);
    }
    else
    {
        inc = 1;
    }
    
//    fprintf(stderr, "log %f oom %i inc %f ", log, oom, inc);
//    fprintf(stderr, "ytravel %f ", m_ytravel);
    
//    fprintf(stderr, "amount %f m_ytravel' %f\n", amount, m_ytravel);
    
    _updateValue(m_value + amount*inc);
    
    // linear
    // _updateValue(m_value + amount);
    
    m_lastPosition = t;
}

void AGSlider::touchUp(const AGTouchInfo &t)
{
    
}

AGInteractiveObject *AGSlider::hitTest(const GLvertex3f &t)
{
    return AGInteractiveObject::hitTest(t);
}

GLvertex3f AGSlider::position()
{
    return m_position;
}

GLvertex2f AGSlider::size()
{
    return m_size;
}

void AGSlider::_updateValue(float value)
{
    TexFont *text = AGStyle::standardFont64();

    m_value = value;
    
    m_valueStream = std::stringstream();
    if(m_type == CONTINUOUS)
        m_valueStream << m_value;
    else
        m_valueStream << (int) m_value;
    
    m_size.x = text->width(m_valueStream.str());
    m_size.y = text->height();
}
