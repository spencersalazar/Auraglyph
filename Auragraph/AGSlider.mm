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
    valueMV = GLKMatrix4Translate(valueMV, -m_size.x/2.0f, -m_size.y/2, 0);
    text->render(m_valueStream.str(), valueColor, valueMV, proj);
}

void AGSlider::touchDown(const AGTouchInfo &t)
{
    NSLog(@"touchDown %f %f", t.screenPosition.x, t.screenPosition.y);
    
    m_firstFinger = t;
    m_lastPosition = t;
    m_startValue = m_value;
}

void AGSlider::touchMove(const AGTouchInfo &t)
{
    NSLog(@"touchMove %f %f", t.screenPosition.x, t.screenPosition.y);
    
    float ytravel = m_firstFinger.screenPosition.y - t.screenPosition.y;
    
    _updateValue(m_startValue * powf(10.0f, (ytravel/100.0f) ));
    
    // linear
    // _updateValue(m_startValue + (int)(ytravel/5.0f));
    
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
    m_valueStream << m_value;
    
    m_size.x = text->width(m_valueStream.str());
    m_size.y = text->height();
}
