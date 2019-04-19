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
#include "AGTutorialEntity.h"
#include "AGTutorialEntities.h"

#include <string>


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

/** */
static AGTutorialStep *_makeTutorialStep(const std::list<AGTutorialAction*> &actions,
                                         const std::list<AGTutorialCondition*> &conditions,
                                         const std::map<std::string, Variant> &parameters = { })
{
    AGTutorialStep *step = new AGTutorialStep(actions, conditions, parameters);
    step->init();
    return step;
}

static AGTutorialStep *_makeTutorialStep(AGTutorialAction *action,
                                         const std::map<std::string, Variant> &parameters = { })
{
    AGTutorialStep *step = new AGTutorialStep(action, parameters);
    step->init();
    return step;
}


#include "AGHandwritingRecognizer.h"

AGTutorial *AGTutorial::createInitialTutorial(AGViewController_ *viewController)
{
    CGRect bounds = viewController->bounds();
    GLvertex3f startPos = viewController->fixedCoordinateForScreenCoordinate(CGPointMake(bounds.origin.x+30, bounds.origin.y+30));
    AGTutorialEnvironment *env = new AGTutorialEnvironment(viewController);
    
    auto steps = (std::list<AGTutorialStep*>){
        /* hide the UI */
        _makeTutorialStep(AGTutorialActions::make(AGTutorialActions::HIDE_UI, { { "hide", 1 } })),

        /* intro / draw a circle */
        _makeTutorialStep((std::list<AGTutorialAction*>) {
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "welcome to Auraglyph." },
                { "position", GLvertex3f(startPos.x, startPos.y, 0) },
                { "pause", 1.0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "an infinite" },
                { "position", GLvertex3f(startPos.x, startPos.y-40, 0) },
                { "pause", 0.25 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "modular" },
                { "position", GLvertex3f(startPos.x, startPos.y-70, 0) },
                { "pause", 0.25 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "music" },
                { "position", GLvertex3f(startPos.x, startPos.y-100, 0) },
                { "pause", 0.25 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "sketchpad." },
                { "position", GLvertex3f(startPos.x, startPos.y-130, 0) },
                { "pause", 2 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "to start, draw a circle." },
                { "position", GLvertex3f(startPos.x, startPos.y-200, 0) },
                { "pause", 0.01 },
            }),
            AGTutorialActions::make(AGTutorialActions::DRAW_NODE, {
                { "position", GLvertex3f(startPos.x, startPos.y-200, 0) },
                { "pause", 0.01 },
            }),
        }, (std::list<AGTutorialCondition*>) {
            AGTutorialConditions::make(AGTutorialConditions::DRAW_NODE, {
                { "figure", (int) AG_FIGURE_CIRCLE },
                { "position=", "node1_pos" } // store position in node1_pos
            }),
        }, { { "pause", 0.01 } }),
        
        /* select the sine wave */
        _makeTutorialStep((std::list<AGTutorialAction*>) {
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "awesome! " },
                { "position", GLvertex3f(startPos.x, startPos.y, 0) },
                { "pause", 0.25 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "you created an audio node." },
                { "position", GLvertex3f(startPos.x, startPos.y-40, 0) },
                { "pause", 1.0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "audio nodes can create sound" },
                { "position", GLvertex3f(startPos.x, startPos.y-80, 0) },
                { "pause", 0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "or process an existing sound." },
                { "position", GLvertex3f(startPos.x, startPos.y-110, 0) },
                { "pause", 1.0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "here, you can see a menu" },
                { "position", GLvertex3f(startPos.x, startPos.y-150, 0) },
                { "pause", 0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "of different audio nodes" },
                { "position", GLvertex3f(startPos.x, startPos.y-180, 0) },
                { "pause", 0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "to choose from." },
                { "position", GLvertex3f(startPos.x, startPos.y-210, 0) },
                { "pause", 1.0 },
            }),
            AGTutorialActions::make(AGTutorialActions::POINT_TO, {
                { "start", Variant([env](){
                    // start position is based on env variable
                    GLvertex3f node1Pos = env->fetch("node1_pos");
                    return node1Pos+GLvertex3f(-300, 50, 0);
                })},
                { "end", Variant([env]() -> GLvertex3f {
                    // start position is based on env variable
                    GLvertex3f node1Pos = env->fetch("node1_pos");
                    return node1Pos+GLvertex3f(-120, 50, 0);
                })},
                { "pause", 0 },
            }),
            AGTutorialActions::make(AGTutorialActions::TEXT, {
                { "text", "start by choosing the sine wave." },
                { "position", GLvertex3f(startPos.x, startPos.y-250, 0) },
                { "pause", 0 },
            }),
        }, (std::list<AGTutorialCondition*>) {
            AGTutorialConditions::make(AGTutorialConditions::CREATE_NODE, {
                { "node_type", "SineWave" }
            }),
        }, { { "pause", 0.01 } }),
        
        /* end / unhide the UI */
        _makeTutorialStep(AGTutorialActions::make(AGTutorialActions::HIDE_UI, { { "hide", 0 } })),
    };
    
    for(auto step : steps)
        step->init();
    AGTutorial *tutorial = new AGTutorial(steps, viewController);
    tutorial->init();
    tutorial->m_environment.reset(env);
    
    return tutorial;
}
