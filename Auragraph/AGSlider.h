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

private:
    
    void _updateValue(float value);
    
    GLvertex3f m_position;
    GLvertex2f m_size;
    float m_value = 0;
    float m_startValue = 0;
    
    std::stringstream m_valueStream;
    
    int m_numTouches = 0;
    AGTouchInfo m_firstFinger;
    AGTouchInfo m_lastPosition;
};


#endif /* AGSlider_h */
