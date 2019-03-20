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
#include "Matrix.h"
#include "AGViewController.h"

#include <string>

/** Used to store and fetch information about the environment in which a
 tutorial is run, e.g. state that may change from instance to instance. For
 example, the UUIDs of nodes can be stored and then accessed later to check the
 state of that particular node. A tutorial environment is persistent throughout
 the length of a tutorial.
 */
class AGTutorialEnvironment
{
public:
    /** */
    AGTutorialEnvironment(AGViewController_ *viewController) : m_viewController(viewController) { }
    
    /** */
    AGViewController_ *viewController() { return m_viewController; }
    
    /** Store a variable in the environment. */
    void store(const std::string &name, const Variant &variable) { m_variables[name] = variable; }
    
    /** Fetch a variable from the environment. */
    const Variant &fetch(const std::string &name, const Variant &variable) { return m_variables[name]; }
    
private:
    /** */
    AGViewController_ *m_viewController = nullptr;
    /** Map of named variables in this environment. */
    map<std::string, Variant> m_variables;
};

/** Base class for a single "step" in a tutorial. */
class AGTutorialStep : public AGRenderObject
{
public:
    /** Constructor */
    AGTutorialStep(const map<std::string, Variant> &parameters,
                   std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                   std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ });
    
    /** Prepare the internal state of tutorial step, reading any variables
     necessary from the specified environment.
     */
    void prepare(AGTutorialEnvironment &environment);
    
    /** (Overriden by subclasses) Ascertain if the tutorial step can be continued.
     */
    virtual bool canContinue() = 0;
    
    /** (Overriden by subclasses) Ascertain if the tutorial step has completed.
     */
    virtual bool isComplete() = 0;

    /** Finalize the tutorial step, storing any variables in the environment
     that may be accessed later.
     */
    void finalize(AGTutorialEnvironment &environment);
    
    bool renderFixed() override { return true; }
    
protected:
    
    virtual void prepareInternal(AGTutorialEnvironment &environment) { }
    virtual void finalizeInternal(AGTutorialEnvironment &environment) { }
    
    Variant getParameter(const std::string &name, Variant defaultValue = Variant());
    
    map<std::string, Variant> m_parameters;
    std::function<void (AGTutorialEnvironment &env)> m_onPrepare;
    std::function<void (AGTutorialEnvironment &env)> m_onFinalize;
};



AGTutorialStep::AGTutorialStep(const map<std::string, Variant> &parameters,
                               std::function<void (AGTutorialEnvironment &env)> onPrepare,
                               std::function<void (AGTutorialEnvironment &env)> onFinalize)
: m_parameters(parameters), m_onPrepare(onPrepare), m_onFinalize(onFinalize)
{ }

Variant AGTutorialStep::getParameter(const std::string &name, Variant defaultValue)
{
    if (m_parameters.count(name))
        return m_parameters[name];
    else
        return defaultValue;
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


/** Represents group of tutorial steps that appear in order and then
 simultaneously go away when the last completes (after a pause).
 */
class AGTutorialStepGroup : public AGTutorialStep
{
public:
    AGTutorialStepGroup(const std::list<AGTutorialStep *> &steps,
                        const map<std::string, Variant> &parameters,
                        std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                        std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ })
    : AGTutorialStep(parameters, onPrepare, onFinalize), m_steps(steps)
    {
        for(auto step : m_steps)
            step->init();
    }
    
    ~AGTutorialStepGroup()
    {
        for(auto step : m_steps)
            delete step;
        m_steps.clear();
    }
    
    void update(float t, float dt) override
    {
        if(!isComplete()) {
            for(auto step : m_activeSteps)
                step->update(t, dt);
            
            if(m_currentStep != m_steps.end() && (*m_currentStep)->canContinue()) {
                // finalize last step
                (*m_currentStep)->finalize(*m_environment);
                
                // advance
                m_currentStep++;
                
                if (m_currentStep != m_steps.end()) {
                    // prepare next step
                    if(m_currentStep != m_steps.end())
                    {
                        (*m_currentStep)->prepare(*m_environment);
                        (*m_currentStep)->update(t, dt);
                        m_activeSteps.push_back(*m_currentStep);
                    }
                }
            }
            
            m_activeSteps.remove_if([](AGTutorialStep *step) { return step->isComplete(); });
        }
        
        if (m_currentStep == m_steps.end())
            m_t += dt;
    }

    void render() override
    {
        if(!isComplete()) {
            for(auto step : m_activeSteps)
                step->render();
        }
    }

    bool isComplete() override { return canContinue(); }
    
    bool canContinue() override { return m_currentStep == m_steps.end() && m_t >= m_pause; }

private:
    std::list<AGTutorialStep *> m_steps;
    std::list<AGTutorialStep *> m_activeSteps;
    std::list<AGTutorialStep *>::iterator m_currentStep;
    AGTutorialEnvironment *m_environment = nullptr;
    
    float m_t = 0;
    float m_pause = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_environment = &environment;
        m_pause = getParameter("pause", 0).getFloat();
        
        m_t = 0;
        
        m_currentStep = m_steps.begin();
        (*m_currentStep)->prepare(*m_environment);
        m_activeSteps.push_back(*m_currentStep);
    }
};


/** Tutorial step that simply displays text.
 */
class AGTextTutorialStep : public AGTutorialStep
{
public:
    using AGTutorialStep::AGTutorialStep;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_textExtent += dt*20;
        if (m_textExtent >= m_text.size())
            m_t += dt;
    }
    
    void render() override
    {
        TexFont *text = AGStyle::standardFont64();
        
        Matrix4 mv = Matrix4(modelview()).translate(m_pos);
        
        int i = (int) m_textExtent;
        
        if (i < m_text.size()) {
            text->render(m_text.substr(0, i), AGStyle::foregroundColor(), mv, projection());
            
            // render last letter with fade-in
            float alpha = m_textExtent-floorf(m_textExtent);
            alpha *= alpha;
            float x = text->width(m_text.substr(0, i));
            text->render(m_text.substr(i, 1), AGStyle::foregroundColor().withAlpha(alpha), mv.translate(x, 0, 0), projection());
        } else {
            text->render(m_text, AGStyle::foregroundColor(), mv, projection());
        }
    }
    
    bool isComplete() override { return false; }
    
    bool canContinue() override { return m_t >= m_pause && m_textExtent >= m_text.size(); };

protected:
    string m_text;
    float m_t = 0;
    float m_pause = 0;
    float m_textExtent = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_text = getParameter("text", "").getString();
        m_pos = getParameter("position", GLvertex3f()).getVertex3();
        m_pause = getParameter("pause", 0).getFloat();
        
        m_t = 0;
        m_textExtent = 0;
        
        dbgprint("showing tutorial text %s\n", m_text.c_str());
    }
};

/** */
class AGHideUITutorialStep : public AGTutorialStep
{
public:
    using AGTutorialStep::AGTutorialStep;
    
    bool isComplete() override { return true; }
    bool canContinue() override { return true; }

private:
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        int hide = getParameter("hide").getInt();
        
        if (hide)
            environment.viewController()->hideDashboard();
        else
            environment.viewController()->showDashboard();
    }
};


/**
 */
class AGCreateNodeTutorialStep : public AGTextTutorialStep
{
public:
    using AGTextTutorialStep::AGTextTutorialStep;
    
    virtual bool isComplete() { return true; }
    
protected:
    
};

AGTutorial *AGTutorial::createInitialTutorial(AGViewController_ *viewController)
{
    float left = -600;
    float top = 400;
    auto steps = (std::list<AGTutorialStep*>){
        new AGHideUITutorialStep({ { "hide", 1 } }),
        new AGTutorialStepGroup((std::list<AGTutorialStep*>) {
            new AGTextTutorialStep({
                { "text", std::string("welcome to Auraglyph") },
                { "position", GLvertex3f(left, top, 0) },
                { "pause", 1.0 },
            }),
            new AGTextTutorialStep({
                { "text", std::string("an infinite") },
                { "position", GLvertex3f(left, top-40, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialStep({
                { "text", std::string("modular") },
                { "position", GLvertex3f(left, top-70, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialStep({
                { "text", std::string("music") },
                { "position", GLvertex3f(left, top-100, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialStep({
                { "text", std::string("sketchpad") },
                { "position", GLvertex3f(left, top-140, 0) },
                { "pause", 0.25 },
            }),
        }, { { "pause", 3 } }),
        new AGTextTutorialStep({
            { "text", std::string("to start, draw a circle") },
            { "position", GLvertex3f(left, top-200, 0) },
            { "pause", 0 },
        }),
        new AGHideUITutorialStep({ { "hide", 0 } }),
    };
    for(auto step : steps)
        step->init();
    AGTutorial *tutorial = new AGTutorial(steps, viewController);
    tutorial->init();
    return tutorial;
}

AGTutorial::AGTutorial(std::list<AGTutorialStep*> &steps, AGViewController_ *viewController)
: m_steps(steps)
{
    m_environment.reset(new AGTutorialEnvironment(viewController));
    m_currentStep = m_steps.begin();
    
    (*m_currentStep)->prepare(*m_environment);
    m_activeSteps.push_back(*m_currentStep);
}

AGTutorial::~AGTutorial()
{
    for(auto step : m_steps)
        delete step;    
    m_steps.clear();
}

void AGTutorial::update(float t, float dt)
{
    if(!isComplete()) {
        for(auto step : m_activeSteps)
            step->update(t, dt);
        
        if((*m_currentStep)->canContinue()) {
            // finalize last step
            (*m_currentStep)->finalize(*m_environment);
            
            // advance
            m_currentStep++;
            
            if (m_currentStep != m_steps.end()) {
                // prepare next step
                if(m_currentStep != m_steps.end())
                {
                    (*m_currentStep)->prepare(*m_environment);
                    (*m_currentStep)->update(t, dt);
                    m_activeSteps.push_back(*m_currentStep);
                }
            }
        }
        
        m_activeSteps.remove_if([](AGTutorialStep *step) { return step->isComplete(); });
    }
}

void AGTutorial::render()
{
    if(!isComplete()) {
        for(auto step : m_activeSteps)
            step->render();
    }
}

bool AGTutorial::isComplete()
{
    return m_currentStep == m_steps.end();
}

