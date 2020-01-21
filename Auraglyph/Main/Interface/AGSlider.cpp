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
#include "Animation.h"

#include <sstream>

#define AGSlider_TextScale (0.61f)
#define AGSlider_TextMargin (4)
#define AGSlider_HitOffset (10)

AGSlider::AGSlider(const GLvertex3f &position, float value)
: m_value(value),
m_update([](float){}), m_start([](float){}), m_stop([](float, float){}),
m_validator([](float _old, float _new) { return _new; }),
m_enableBlink(false),
m_blink(powcurvef(1, 0, 1.1, 0.75))
{
    setPosition(position);
    _updateValue(value);
}

AGSlider::~AGSlider()
{ }

void AGSlider::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
    
    if (m_enableBlink) {
        m_blink.update(dt);
        if (m_blink.isFinished()) {
            m_blink.reset();
        }
    }
}

void AGSlider::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    GLcolor4f valueColor;
    
    if (!m_active && m_enableBlink) {
        // handle blink
        AGStyle::foregroundColor().withAlpha(m_blink).set();
        
        fillRect(m_pos.x, m_pos.y, m_size.x, m_size.y);
        
        float alpha = easeInOut(m_blink, 3.25f, 0.3f);
        auto fgColor = AGStyle::foregroundColor();
        auto bgColor = AGStyle::frameBackgroundColor();
        
        valueColor = fgColor.alphaBlend(bgColor, alpha).withAlpha(m_renderState.alpha);
    } else {
        valueColor = AGStyle::foregroundColor().withAlpha(m_renderState.alpha);
    }
    
    Matrix4 valueMV = modelview().translate(m_pos.x, m_pos.y, m_pos.z);
    if (m_alignment == ALIGN_CENTER) {
        valueMV.translateInPlace(-m_textSize.x/2, -m_textSize.y/2, 0);
    } else if (m_alignment == ALIGN_RIGHT) {
        valueMV.translateInPlace(m_size.x/2-m_textSize.x/2-AGSlider_TextMargin, -m_textSize.y/2, 0);
    } else if (m_alignment == ALIGN_LEFT) {
        valueMV.translateInPlace(-m_size.x/2+AGSlider_TextMargin, -m_textSize.y/2, 0);
    }
    valueMV.scaleInPlace(AGSlider_TextScale, AGSlider_TextScale, AGSlider_TextScale);
    text->render(m_str, valueColor, valueMV, projection());
    
    if (m_active) {
        // shade bounding box
        AGStyle::foregroundColor().withAlpha(0.25).set();
        fillRect(m_pos.x, m_pos.y, m_size.x, m_size.y);
    }
}

void AGSlider::touchDown(const AGTouchInfo &t)
{
    dbgprint("touchDown %f %f\n", t.screenPosition.x, t.screenPosition.y);
    
    m_firstFinger = t;
    m_lastPosition = t;
    m_ytravel = 0;
    m_active = true;
    
    m_startValue = m_value;
    
    m_start(m_value);
}

void AGSlider::touchMove(const AGTouchInfo &t)
{
    dbgprint("touchMove %f %f\n", t.screenPosition.x, t.screenPosition.y);
    
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
        float val = m_value;
        if(val == 0) val = 0.1;
        float log = log10f(fabs(val))-0.1;
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
    m_stop(m_startValue, m_value);
}

AGInteractiveObject *AGSlider::hitTest(const GLvertex3f &t)
{
    return AGInteractiveObject::hitTest(t);
}

GLvertex2f AGSlider::size()
{
    return m_size;
}

void AGSlider::setSize(const GLvertex2f &size)
{
    m_size = size;
}

void AGSlider::setValue(float value)
{
    m_value = value;
    _updateValue(m_value);
}

void AGSlider::setType(Type type)
{
    m_type = type;
    _updateValue(m_value);
}

void AGSlider::onUpdate(const std::function<void (float)> &update)
{
    m_update = update;
}

void AGSlider::onStartStopUpdating(const std::function<void (float)> &start, const std::function<void (float, float)> &stop)
{
    m_start = start;
    m_stop = stop;
}

void AGSlider::setValidator(const std::function<float (float, float)> &validator)
{
    m_validator = validator;
}

void AGSlider::_updateValue(float value)
{
    TexFont *text = AGStyle::standardFont64();

    m_value = m_validator(m_value, value);
    
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

void AGSlider::blink(bool enableBlink)
{
    m_enableBlink = enableBlink;
    if (enableBlink) {
        m_blink.reset();
    }
}
