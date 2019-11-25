//
//  AGSlider.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 4/22/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGSlider_h
#define AGSlider_h

#include "AGInteractiveObject.h"
#include <functional>

class AGSlider : public AGInteractiveObject
{
public:
    AGSlider(const GLvertex3f &position = GLvertex3f(), float value = 0);
    ~AGSlider();
    
    virtual void update(float t, float dt);
    virtual void render();

    virtual void touchDown(const AGTouchInfo &t);
    virtual void touchMove(const AGTouchInfo &t);
    virtual void touchUp(const AGTouchInfo &t);
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);
    
    virtual GLvertex2f size();
    void setSize(const GLvertex2f &size);
    
    float value() const { return m_value; }
    void setValue(float value);

    enum Scale
    {
        LINEAR,
        EXPONENTIAL
    };
    
    Scale scale() const { return m_scale; }
    void setScale(Scale scale) { m_scale = scale; }
    
    enum Type
    {
        DISCRETE,
        CONTINUOUS
    };
    
    Type type() const { return m_type; }
    void setType(Type type);
    
    enum Alignment
    {
        ALIGN_CENTER,
        ALIGN_LEFT,
        ALIGN_RIGHT,
    };
    
    Alignment alignment() const { return m_alignment; }
    void setAlignment(Alignment alignment) { m_alignment = alignment; }
    
    void onUpdate(const std::function<void (float)> &update);
    void onStartStopUpdating(const std::function<void (float start)> &start,
                             const std::function<void (float start, float stop)> &stop);
    
    /**
     Validator function takes two arguments (old and new value) and returns
     validated value. 
     */
    void setValidator(const std::function<float (float, float)> &validator);
    
    /** */
    void blink(bool enableBlink = true);
    
private:
    
    void _updateValue(float value);
    
    GLvertex2f m_size;
    GLvertex2f m_textSize;
    
    float m_startValue = 0;
    double m_value = 0;
    Scale m_scale = LINEAR;
    Type m_type = DISCRETE;
    
    Alignment m_alignment = ALIGN_CENTER;
    
    constexpr const static size_t BUF_SIZE = 32;
    char m_str[BUF_SIZE];
    
    float m_ytravel = 0;
    bool m_active = false;
    
    int m_numTouches = 0;
    AGTouchInfo m_firstFinger;
    AGTouchInfo m_lastPosition;
    
    std::function<void (float)> m_update;
    std::function<void (float)> m_start;
    std::function<void (float, float)> m_stop;
    std::function<float (float, float)> m_validator;
    
    bool m_enableBlink;
    powcurvef m_blink;
};


#endif /* AGSlider_h */
