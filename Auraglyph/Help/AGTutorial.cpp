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

/** Base class for tutorial-based entities. Captures parameters and a
 tutorial environment, is "prepared" right before it is engaged, and is
 "finalized" right after it is engaged.
 
 "Finalize" events are used to store information about the entity for future
 use by other entities, e.g. the position of a user action.
 
 "Prepare" events are used to set up the tutorial step based on parameters or
 variables from the environment, e.g. to position a graphical element based on
 previous user activity.
 
 Base classes include
 - AGTutorialAction, a small atomic action such as displaying text or graphics
 - AGTutorialCondition, which awaits a certain condition to advance to another
 tutorial step
 - AGTutorialStep, a discrete tutorial "step" comprising one or more actions
 and one more conditions for moving to successive tutorial steps
 */
class AGTutorialEntity
{
public:
    /** Constructor */
    AGTutorialEntity(const map<std::string, Variant> &parameters,
                     std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                     std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ })
    : m_parameters(parameters), m_onPrepare(onPrepare), m_onFinalize(onFinalize)
    { }
    /** Virtual destructor */
    virtual ~AGTutorialEntity() { }
    
    /** Prepare the internal state of tutorial step, reading any variables
     necessary from the specified environment.
     */
    void prepare(AGTutorialEnvironment &environment)
    {
        prepareInternal(environment);
        m_onPrepare(environment);
    }

    /** Finalize the tutorial step, storing any variables in the environment
     that may be accessed later.
     */
    void finalize(AGTutorialEnvironment &environment)
    {
        finalizeInternal(environment);
        m_onFinalize(environment);
    }
    
protected:
    /** Get parameter for this entity with specified name. */
    Variant getParameter(const std::string &name, Variant defaultValue = Variant())
    {
        if (m_parameters.count(name))
            return m_parameters[name];
        else
            return defaultValue;
    }
    
    /** Override to make subclass-specific set up when preparing this entity
     */
    virtual void prepareInternal(AGTutorialEnvironment &environment) { }
    /** Override to make subclass-specific set up when finalizing this entity
     */
    virtual void finalizeInternal(AGTutorialEnvironment &environment) { }
    
private:
    
    map<std::string, Variant> m_parameters;
    std::function<void (AGTutorialEnvironment &env)> m_onPrepare;
    std::function<void (AGTutorialEnvironment &env)> m_onFinalize;
};

/** Tutorial action, e.g. displaying graphics or text, creating a node, etc.
 */
class AGTutorialAction : public AGTutorialEntity, public AGRenderObject
{
public:
    /** Constructor */
    AGTutorialAction(const map<std::string, Variant> &parameters,
                     std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                     std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ })
    : AGTutorialEntity(parameters, onPrepare, onFinalize)
    { }
    
    /** Whether or not the action can be continued from, i.e. execute the next
     action.
     */
    virtual bool canContinue() = 0;
    
    /** Whether or not the action is complete, i.e. can be removed from the
     graphics pipeline.
     */
    virtual bool isCompleted() = 0;

    /** Render fixed */
    bool renderFixed() override { return true; }
};

/** Tutorial condition. A tutorial condition associated with a tutorial step
 is checked periodically to see if the step is complete.
 
 E.g. if a certain time has elapsed, continue anyways, or wait for a particular
 user activity.
 */
class AGTutorialCondition : public AGTutorialEntity, public AGActivityListener
{
public:
    /** Constructor */
    AGTutorialCondition(const map<std::string, Variant> &parameters,
                        std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                        std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ })
    : AGTutorialEntity(parameters, onPrepare, onFinalize)
    { }
    
    // enum of possible condition status
    enum Status
    {
        STATUS_INCOMPLETE = 0, // the condition is not yet complete and no action should be taken
        STATUS_CONTINUE, // the condition is complete, continue to the next tutorial step
        STATUS_RESTART, // the condition is incomplete and the tutorial step should be restarted
    };
    
    /** */
    virtual Status getStatus() = 0;
    /** */
    void activityOccurred(AGActivity *activity) override { }
};

/** Base class for a single "step" in a tutorial.
 Combines zero or more "actions" (e.g., display of text/graphics) with zero or
 more conditions for proceeding to the next action.
 
 By default, if no condition is provided, the step will continue when all of the
 actions have finished.
 */
class AGTutorialStep : public AGTutorialEntity, public AGRenderObject, public AGActivityListener
{
public:
    AGTutorialStep(const list<AGTutorialAction*> &actions,
                   const list<AGTutorialCondition*> &conditions,
                   const map<std::string, Variant> &parameters)
    : AGTutorialEntity(parameters), m_actions(actions), m_conditions(conditions)
    {
        for(auto action : m_actions)
            action->init();
    }
    
    ~AGTutorialStep()
    {
        for(auto action : m_actions)
            delete action;
        m_actions.clear();
        for(auto condition : m_conditions)
            delete condition;
        m_conditions.clear();
    }
    
    bool canContinue()
    {
        return m_conditionStatus == AGTutorialCondition::STATUS_CONTINUE;
    }
    
    bool isCompleted()
    {
        return m_conditionStatus == AGTutorialCondition::STATUS_CONTINUE;
    }
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        _checkConditions();
        
        if(!isCompleted())
        {
            for(auto action : m_activeActions)
                action->update(t, dt);
            
            if(m_currentAction != m_actions.end() && (*m_currentAction)->canContinue())
            {
                (*m_currentAction)->finalize(*m_environment);
                
                m_currentAction++;
                
                if(m_currentAction != m_actions.end())
                {
                    (*m_currentAction)->prepare(*m_environment);
                    (*m_currentAction)->update(t, dt);
                    m_activeActions.push_back(*m_currentAction);
                }
            }
            
            m_activeActions.remove_if([](AGTutorialAction *action){ return action->isCompleted(); });
        }
    }
    
    void render() override
    {
        AGRenderObject::render();
        
        for(auto action : m_activeActions)
            action->render();
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        for(auto condition : m_conditions)
            condition->activityOccurred(activity);
        
        _checkConditions();
    }
    
private:
    
    void _checkConditions()
    {
        if(m_conditions.size() == 0)
        {
            dbgprint("condition status: continue\n");
            m_conditionStatus = AGTutorialCondition::STATUS_CONTINUE;
        }
        else
        {
            for(auto condition : m_conditions)
            {
                auto status = condition->getStatus();
                if (status == AGTutorialCondition::STATUS_CONTINUE)
                {
                    dbgprint("condition status: continue\n");
                    m_conditionStatus = status;
                    m_completedCondition = condition;
                    break;
                }
            }
        }
    }
    
    /** Override to make subclass-specific set up when preparing this entity
     */
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_environment = &environment;
        
        m_currentAction = m_actions.begin();
        (*m_currentAction)->prepare(*m_environment);
        m_activeActions.push_back(*m_currentAction);
        
        // if there are no conditions, can continue immediately
        if(m_conditions.size() == 0)
            m_conditionStatus = AGTutorialCondition::STATUS_CONTINUE;
    }
    
    /** Override to make subclass-specific set up when finalizing this entity
     */
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        
    }
    
    AGTutorialEnvironment *m_environment = nullptr;
    
    list<AGTutorialAction*> m_actions;
    list<AGTutorialAction*>::iterator m_currentAction;
    list<AGTutorialAction*> m_activeActions;

    list<AGTutorialCondition*> m_conditions;
    AGTutorialCondition *m_completedCondition = nullptr;
    AGTutorialCondition::Status m_conditionStatus = AGTutorialCondition::STATUS_INCOMPLETE;
};


/** Tutorial step that simply displays text.
 */
class AGTextTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
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
            alpha = powf(alpha, 0.33);
            float x = text->width(m_text.substr(0, i));
            text->render(m_text.substr(i, 1), AGStyle::foregroundColor().withAlpha(alpha), mv.translate(x, 0, 0), projection());
        } else {
            text->render(m_text, AGStyle::foregroundColor(), mv, projection());
        }
    }
    
    bool isCompleted() override { return false; }
    
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
class AGHideUITutorialStep : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    bool isCompleted() override { return true; }
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


#include "GeoGenerator.h"
#include "Easing/Cubic.h"

/**
 */
class AGDrawNodeTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_tFig += dt;
        while (m_tFig > TOTAL_TIME)
            m_tFig -= TOTAL_TIME;
    }
    
    void render() override
    {
        AGRenderObject::render();
        
        float t = min(m_tFig/CYCLE_TIME, 1.0f);
        t = easing::cubic::easeInOut(t, 0, 1, 1);
        int num = t*m_figure.size();
        
        float alpha = 1;
        if (m_tFig >= CYCLE_PAUSE) {
            alpha = max(0.0f, 1-(m_tFig-CYCLE_TIME-CYCLE_PAUSE)/FADE_TIME);
        }
        
        AGStyle::foregroundColor().withAlpha(alpha).set();
        drawLineStrip(m_figure.data(), num);
    }
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return m_canContinue; }
    
protected:
    
    constexpr static const float CYCLE_TIME = 1.5;
    constexpr static const float CYCLE_PAUSE = 0.125;
    constexpr static const float FADE_TIME = 0.5;
    constexpr static const float FADE_PAUSE = 0.33;
    constexpr static const float TOTAL_TIME = CYCLE_TIME+CYCLE_PAUSE+FADE_TIME+FADE_PAUSE;

    std::vector<GLvertex3f> m_figure;
    bool m_canContinue = false;
    GLvertex3f m_figurePos;
    float m_tFig = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        GeoGen::makeCircleStroke(m_figure, 64, 62.5);
        // add original point to draw as line strip
        m_figure.push_back(m_figure[0]);
        // rotate to start at +pi/2
        for(int i = 0; i < m_figure.size(); i++) {
            m_figure[i] = rotateZ(m_figure[i], M_PI_2);
        }
        
        m_figurePos = getParameter("figurePosition", GLvertex3f()).getVertex3();
    }
};

#include "AGActivity.h"

/**
 */
class AGDrawNodeTutorialCondition : public AGTutorialCondition
{
public:
    
    using AGTutorialCondition::AGTutorialCondition;
    
    Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::DrawNodeActivityType) {
            m_status = STATUS_CONTINUE;
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
};


/**
 */
class AGCreateNodeTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::CreateNodeActivityType) {
            m_status = STATUS_CONTINUE;
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
};

AGTutorial *AGTutorial::createInitialTutorial(AGViewController_ *viewController)
{
    CGRect bounds = viewController->bounds();
    GLvertex3f startPos = viewController->fixedCoordinateForScreenCoordinate(CGPointMake(bounds.origin.x+30, bounds.origin.y+30));

    auto steps = (std::list<AGTutorialStep*>){
        /* hide the UI */
        new AGTutorialStep((std::list<AGTutorialAction*>) {
            new AGHideUITutorialStep({ { "hide", 1 } }),
        }, (std::list<AGTutorialCondition*>) { }, { { "pause", 0.01 } }),
        
        /* intro / draw a circle */
        new AGTutorialStep((std::list<AGTutorialAction*>) {
            new AGTextTutorialAction({
                { "text", "welcome to Auraglyph." },
                { "position", GLvertex3f(startPos.x, startPos.y, 0) },
                { "pause", 1.0 },
            }),
            new AGTextTutorialAction({
                { "text", "an infinite" },
                { "position", GLvertex3f(startPos.x, startPos.y-40, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialAction({
                { "text", "modular" },
                { "position", GLvertex3f(startPos.x, startPos.y-70, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialAction({
                { "text", "music" },
                { "position", GLvertex3f(startPos.x, startPos.y-100, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialAction({
                { "text", "sketchpad." },
                { "position", GLvertex3f(startPos.x, startPos.y-130, 0) },
                { "pause", 2 },
            }),
            new AGTextTutorialAction({
                { "text", "to start, draw a circle." },
                { "position", GLvertex3f(startPos.x, startPos.y-200, 0) },
                { "pause", 0.01 },
            }),
            new AGDrawNodeTutorialAction({
                { "position", GLvertex3f(startPos.x, startPos.y-200, 0) },
                { "pause", 0.01 },
            }),
        }, (std::list<AGTutorialCondition*>) {
            new AGDrawNodeTutorialCondition((map<std::string, Variant>) { }),
        }, { { "pause", 0.01 } }),
        
        /* select the sine wave */
        new AGTutorialStep((std::list<AGTutorialAction*>) {
            new AGTextTutorialAction({
                { "text", "awesome! " },
                { "position", GLvertex3f(startPos.x, startPos.y, 0) },
                { "pause", 0.25 },
            }),
            new AGTextTutorialAction({
                { "text", "you created an audio node." },
                { "position", GLvertex3f(startPos.x, startPos.y-40, 0) },
                { "pause", 1.0 },
            }),
            new AGTextTutorialAction({
                { "text", "audio nodes can create sound" },
                { "position", GLvertex3f(startPos.x, startPos.y-80, 0) },
                { "pause", 0 },
            }),
            new AGTextTutorialAction({
                { "text", "or process an existing sound." },
                { "position", GLvertex3f(startPos.x, startPos.y-110, 0) },
                { "pause", 1.0 },
            }),
            new AGTextTutorialAction({
                { "text", "here, you can see a menu" },
                { "position", GLvertex3f(startPos.x, startPos.y-150, 0) },
                { "pause", 0 },
            }),
            new AGTextTutorialAction({
                { "text", "of different audio nodes" },
                { "position", GLvertex3f(startPos.x, startPos.y-180, 0) },
                { "pause", 0 },
            }),
            new AGTextTutorialAction({
                { "text", "to choose from." },
                { "position", GLvertex3f(startPos.x, startPos.y-210, 0) },
                { "pause", 1.0 },
            }),
            new AGTextTutorialAction({
                { "text", "start by choosing the sine wave." },
                { "position", GLvertex3f(startPos.x, startPos.y-250, 0) },
                { "pause", 0 },
            }),
        }, (std::list<AGTutorialCondition*>) {
            new AGCreateNodeTutorialCondition((map<std::string, Variant>) { }),
        }, { { "pause", 0.01 } }),
        
        /* end / unhide the UI */
        new AGTutorialStep((std::list<AGTutorialAction*>) {
            new AGHideUITutorialStep({ { "hide", 0 } }),
        }, (std::list<AGTutorialCondition*>) { }, { { "pause", 0.01 } }),
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
    
    AGActivityManager::instance().addActivityListener(this);
}

AGTutorial::~AGTutorial()
{
    for(auto step : m_steps)
        delete step;    
    m_steps.clear();
    
    AGActivityManager::instance().removeActivityListener(this);
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
        
        m_activeSteps.remove_if([](AGTutorialStep *step) { return step->isCompleted(); });
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

void AGTutorial::activityOccurred(AGActivity *activity)
{
    if(m_currentStep != m_steps.end()) {
        (*m_currentStep)->activityOccurred(activity);
    }
}

