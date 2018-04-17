//
//  AGTutorial.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 3/22/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGTutorial.h"

#include "Geometry.h"
#include "AGStyle.h"

#include "AGGraphManager.h"

#include <string>

class AGTextTutorialStep : public AGTutorialStep
{
public:
    AGTextTutorialStep(const std::string &text, GLvertex3f pos)
    : m_text(text)
    {
        m_pos = pos;
    }
    
    virtual void render()
    {
        TexFont *text = AGStyle::standardFont64();
        
        // horizontal-center text
        float width = text->width(m_text);
        GLKMatrix4 mv = GLKMatrix4Translate(modelview(), m_pos.x-width/2, m_pos.y, m_pos.z);
        
        text->render(m_text, AGStyle::foregroundColor(), mv, projection());
    }
    
    virtual bool isComplete() { return true; }
    
private:
    string m_text;
};


class AGTimedTextTutorialStep : public AGTextTutorialStep
{
public:
    AGTimedTextTutorialStep(const std::string &text, GLvertex3f pos, float duration)
    : AGTextTutorialStep(text, pos), m_duration(duration)
    { }
    
    virtual void update(float t, float dt)
    {
        AGRenderObject::update(t, dt);
        
        if(m_duration > 0)
            m_duration -= dt;
        else
            m_duration = 0;
    }
    
    virtual bool isComplete() { return m_duration == 0; }
    
private:
    float m_duration;
};

class AGCreateNodeTutorialStep : public AGTextTutorialStep
{
public:
    AGCreateNodeTutorialStep(const std::string &text, GLvertex3f pos, AGGraphManager *graphManager, const std::string &nodeType)
    : AGTextTutorialStep(text, pos)
    { }
    
    virtual bool isComplete() { return true; }
    
private:
    
};

AGTutorial *AGTutorial::createInitialTutorial()
{
    auto steps = (std::list<AGTutorialStep*>){
        new AGTimedTextTutorialStep("Welcome to Auraglyph", GLvertex3f(0, 200, 0), 5),
        new AGTimedTextTutorialStep("To start, draw a circle", GLvertex3f(0, 200, 0), 5),
        new AGTimedTextTutorialStep("Now, choose an oscillator from the menu", GLvertex3f(0, 200, 0), 5),
    };
    for(auto step : steps)
        step->init();
    AGTutorial *tutorial = new AGTutorial(steps);
    tutorial->init();
    return tutorial;
}

AGTutorial::AGTutorial(std::list<AGTutorialStep*> &steps)
: m_steps(steps)
{
    m_currentStep = m_steps.begin();
}

AGTutorial::~AGTutorial()
{
    for(auto step : m_steps)
        delete step;    
    m_steps.clear();
}

void AGTutorial::update(float t, float dt)
{
    if(!isComplete())
    {
        (*m_currentStep)->update(t, dt);
        if((*m_currentStep)->isComplete())
        {
            m_currentStep++;
            if(m_currentStep != m_steps.end())
                (*m_currentStep)->update(t, dt);
        }
    }
}

void AGTutorial::render()
{
    if(!isComplete())
        (*m_currentStep)->render();
}

bool AGTutorial::isComplete()
{
    return m_currentStep == m_steps.end();
}

