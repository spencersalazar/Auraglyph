//
//  AGSlider.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 4/22/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGSlider_h
#define AGSlider_h

#include "AGRenderObject.h"
#include <sstream>

class AGSlider : public AGInteractiveObject
{
public:
    AGSlider(GLvertex3f position, float value = 0);
    ~AGSlider();
    
    virtual void update(float t, float dt);
    virtual void render();

    virtual void touchDown(const AGTouchInfo &t);
    virtual void touchMove(const AGTouchInfo &t);
    virtual void touchUp(const AGTouchInfo &t);
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);
    
    virtual GLvertex3f position();
    virtual GLvertex2f size();
    
    float value() { return m_value; }
    void setValue(float value) { m_value = value; }

    enum Scale
    {
        LINEAR,
        EXPONENTIAL
    };
    
    Scale scale() { return m_scale; }
    void setScale(Scale scale) { m_scale = scale; }
    
    enum Type
    {
        DISCRETE,
        CONTINUOUS
    };
    
    Type type() { return m_type; }
    void setType(Type type) { m_type = type; }
    
    void onUpdate(void (^update)(float value));
    
private:
    
    void _updateValue(float value);
    
    GLvertex3f m_position;
    GLvertex2f m_size;
    
    double m_value = 0;
    Scale m_scale = LINEAR;
    Type m_type = DISCRETE;
    
    constexpr const static size_t BUF_SIZE = 32;
    char m_str[BUF_SIZE];
    float m_ytravel = 0;
    
    int m_numTouches = 0;
    AGTouchInfo m_firstFinger;
    AGTouchInfo m_lastPosition;
};


#endif /* AGSlider_h */
