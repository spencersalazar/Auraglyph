//
//  AGDocNodeList.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"
#include "AGStyle.h"


class AGScroller
{
public:
    AGScroller()
    {}
    
    void setScrollRange(float min, float max)
    {
        m_scrollPos.raw().clampTo(min, max);
    }
    
    bool isScrolling()
    {
        return m_isScrolling;
    }
    
    GLKMatrix4 apply(const GLKMatrix4 &matrix)
    {
        return GLKMatrix4Translate(matrix, 0, m_scrollPos.value(), 0);
    }
    
    virtual void update(float t, float dt)
    {
        m_scrollPos.update(t, dt);
    }
    
    virtual void touchDown(const AGTouchInfo &t)
    {
        m_isScrolling = false;
        m_touchStart = t.position;
        m_lastTouch = t.position;
        m_scrollPos.on();
    }
    
    void touchMove(const AGTouchInfo &t)
    {
        // TODO: handle x+y scrolling
        if((m_touchStart-t.position).magnitudeSquared() > AGStyle::maxTravel*AGStyle::maxTravel)
        {
            // start scrolling
            m_isScrolling = true;
            m_scrollPos += (t.position - m_lastTouch).y;
        }
        
        m_lastTouch = t.position;
    }
    
    void touchUp(const AGTouchInfo &t)
    {
        if((m_touchStart-t.position).magnitudeSquared() > AGStyle::maxTravel*AGStyle::maxTravel)
        {
            m_isScrolling = true;
        }
        
        m_scrollPos.off();
    }
    
private:
    bool m_isScrolling = false;
    momentum<float, clamp<float>> m_scrollPos;
    GLvertex3f m_touchStart;
    GLvertex3f m_lastTouch;
};


class AGDocNodeList : public AGInteractiveObject
{
public:
    AGDocNodeList();
    ~AGDocNodeList();
    
    GLKMatrix4 localTransform() override;
    void update(float t, float dt) override;
    void render() override;
    
    GLvrectf effectiveBounds() override;    
    bool renderFixed() override { return true; }
    virtual void renderOut() override;
    virtual bool finishedRenderingOut() override;
    
    virtual void touchDown(const AGTouchInfo &t) override;
    virtual void touchMove(const AGTouchInfo &t) override;
    virtual void touchUp(const AGTouchInfo &t) override;
    virtual void touchOutside() override;
    
private:
    GLvertex2f m_size;
    AGSqueezeAnimation m_squeeze;
    AGScroller m_scroller;
};

