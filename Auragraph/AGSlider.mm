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
#include "AGGenericShader.h"
#include "GeoGenerator.h"
#include <sstream>

#define AGSlider_TextScale (0.61f)
#define AGSlider_HitOffset (10)

AGSlider::AGSlider(GLvertex3f position, float value)
: m_value(value), m_position(position), m_update([](float){})
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
    
    GLKMatrix4 modelView;
    GLKMatrix4 proj;

    if(parent())
    {
        modelView = parent()->m_renderState.modelview;
        proj = parent()->m_renderState.projection;
    }
    else
    {
        modelView = globalModelViewMatrix();
        proj = projectionMatrix();
    }
    
    GLcolor4f valueColor = GLcolor4f::white;
    valueColor.a = m_renderState.alpha;
    
    GLKMatrix4 valueMV = modelView;
    valueMV = GLKMatrix4Translate(valueMV, m_position.x, m_position.y, m_position.z);
    valueMV = GLKMatrix4Translate(valueMV, -m_textSize.x/2, -m_textSize.y/2, 0);
    valueMV = GLKMatrix4Scale(valueMV, AGSlider_TextScale, AGSlider_TextScale, AGSlider_TextScale);
    text->render(m_str, valueColor, valueMV, proj);
    
    if(m_active)
    {
        // shade bounding box
        
        AGGenericShader &shader = AGGenericShader::instance();
        shader.useProgram();
        
        shader.setModelViewMatrix(modelView);
        shader.setProjectionMatrix(proj);
        
        GLvertex3f geo[4];
        GeoGen::makeRect(geo, m_position.x, m_position.y, m_size.x, m_size.y);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glVertexAttrib4f(GLKVertexAttribColor, 1, 1, 1, 0.25);
        glDisableVertexAttribArray(GLKVertexAttribColor);
        
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }
}

void AGSlider::touchDown(const AGTouchInfo &t)
{
    NSLog(@"touchDown %f %f", t.screenPosition.x, t.screenPosition.y);
    
    m_firstFinger = t;
    m_lastPosition = t;
    m_ytravel = 0;
    m_active = true;
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
        float log = log10f(fabs(m_value))-0.1;
        int oom = (int)floorf(log);
        inc = powf(10, oom-1);
        
        if(m_type == DISCRETE)
            inc = std::max(1.0, inc);
        
        dbgprint("log %f oom %i inc %f ", log, oom, inc);
        dbgprint("ytravel %f ", m_ytravel);
    }
    else
    {
        inc = 1;
    }
    
    dbgprint("amount %f m_ytravel' %f\n", amount, m_ytravel);
    
    _updateValue(m_value + amount*inc);
    
    // linear
    // _updateValue(m_value + amount);
    
    m_lastPosition = t;
}

void AGSlider::touchUp(const AGTouchInfo &t)
{
    m_active = false;
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

void AGSlider::setSize(const GLvertex2f &size)
{
    m_size = size;
}

void AGSlider::onUpdate(const std::function<void (float)> &update)
{
    m_update = update;
}

void AGSlider::_updateValue(float value)
{
    TexFont *text = AGStyle::standardFont64();

    m_value = value;
    
    if(m_type == CONTINUOUS)
        snprintf(m_str, BUF_SIZE-1, "%.3lG", m_value);
    else
        snprintf(m_str, BUF_SIZE-1, "%li", (long int) m_value);
    
    m_textSize.x = text->width(m_str)*AGSlider_TextScale;
    m_textSize.y = text->height()*AGSlider_TextScale;
    
    m_update(m_value);
    
//    dbgprint("[ ");
//    for(char c : m_valueStream.str())
//        dbgprint("%02X ", c);
//    dbgprint("]");
}
