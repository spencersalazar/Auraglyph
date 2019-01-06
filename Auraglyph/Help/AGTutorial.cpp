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

class AGTutorialEnvironment
{
public:
    void store(const std::string &name, const Variant &variable) { m_variables[name] = variable; }
    const Variant &fetch(const std::string &name, const Variant &variable) { return m_variables[name]; }
    
private:
    map<std::string, Variant> m_variables;
};


class AGTutorialStep : public AGRenderObject
{
public:
    AGTutorialStep(const map<std::string, Variant> &parameters,
                   std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                   std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ });
    
    void prepare(AGTutorialEnvironment &environment);
    virtual bool isComplete() = 0;
    void finalize(AGTutorialEnvironment &environment);
    
protected:
    
    virtual void prepareInternal(AGTutorialEnvironment &environment) { }
    virtual void finalizeInternal(AGTutorialEnvironment &environment) { }
    
    const Variant &getParameter(const std::string &name);
    
    map<std::string, Variant> m_parameters;
    std::function<void (AGTutorialEnvironment &env)> m_onPrepare;
    std::function<void (AGTutorialEnvironment &env)> m_onFinalize;
};



AGTutorialStep::AGTutorialStep(const map<std::string, Variant> &parameters,
                               std::function<void (AGTutorialEnvironment &env)> onPrepare,
                               std::function<void (AGTutorialEnvironment &env)> onFinalize)
: m_parameters(parameters), m_onPrepare(onPrepare), m_onFinalize(onFinalize)
{ }

const Variant &AGTutorialStep::getParameter(const std::string &name)
{
    return m_parameters[name];
}

void AGTutorialStep::prepare(AGTutorialEnvironment &environment)
{
    prepareInternal(environment);
    m_onPrepare(environment);
}

void AGTutorialStep::finalize(AGTutorialEnvironment &environment)
{
    finalizeInternal(environment);
    m_onFinalize(environment);
}

class AGTextTutorialStep : public AGTutorialStep
{
public:
    using AGTutorialStep::AGTutorialStep;
    
    void render() override
    {
        TexFont *text = AGStyle::standardFont64();
        
        // horizontal-center text
        float width = text->width(m_text);
        GLKMatrix4 mv = GLKMatrix4Translate(modelview(), m_pos.x-width/2, m_pos.y, m_pos.z);
        
        text->render(m_text, AGStyle::foregroundColor(), mv, projection());
    }
    
    bool isComplete() override { return true; }
    
protected:
    string m_text;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_text = getParameter("text").getString();
        m_pos = getParameter("position").getVertex3();
    }
};


class AGTimedTextTutorialStep : public AGTextTutorialStep
{
public:
    using AGTextTutorialStep::AGTextTutorialStep;

    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        if(m_duration > 0)
            m_duration -= dt;
        else
            m_duration = 0;
    }
    
    bool isComplete() override { return m_duration == 0; }
    
protected:
    float m_duration;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_text = getParameter("text").getString();
        m_pos = getParameter("position").getVertex3();
        m_duration = getParameter("duration").getFloat();
    }
};

class AGCreateNodeTutorialStep : public AGTextTutorialStep
{
public:
    using AGTextTutorialStep::AGTextTutorialStep;
    
    virtual bool isComplete() { return true; }
    
protected:
    
};

AGTutorial *AGTutorial::createInitialTutorial()
{
    auto steps = (std::list<AGTutorialStep*>){
        new AGTimedTextTutorialStep((std::map<std::string, Variant>) {
            { "text", std::string("Welcome to Auraglyph") },
            { "position", GLvertex3f(0, 200, 0) },
            { "duration", 5 },
        }),
        new AGTimedTextTutorialStep({
            { "text", std::string("To start, draw a circle") },
            { "position", GLvertex3f(0, 200, 0) },
            { "duration", 5 },
        }),
        new AGTimedTextTutorialStep({
            { "text", std::string("Now, choose an oscillator from the menu") },
            { "position", GLvertex3f(0, 200, 0) },
            { "duration", 5 },
        }),
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

