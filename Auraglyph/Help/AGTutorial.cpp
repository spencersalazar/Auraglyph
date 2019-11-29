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
#include "AGViewControllerProxy.h"
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
    // GLvertex3f startPos = viewController->fixedCoordinateForScreenCoordinate(CGPointMake(bounds.origin.x+30, bounds.origin.y+30));
    Variant startPos = Variant([viewController] () {
        CGRect bounds = viewController->bounds();
        return viewController->fixedCoordinateForScreenCoordinate(CGPointMake(bounds.origin.x+100, bounds.origin.y+100));
    });
    AGTutorialEnvironment *env = new AGTutorialEnvironment(viewController);
    
    std::list<AGTutorialStep*> steps;
    Variant textStartPos = startPos;
    GLvertex3f normalLineSpace = GLvertex3f(0, -30, 0);
    GLvertex3f mediumLineSpace = GLvertex3f(0, -40, 0);
    GLvertex3f largeLineSpace = GLvertex3f(0, -70, 0);

    /* hide the UI */
    {
        steps.push_back(_makeTutorialStep(AGTutorialActions::make(AGTutorialActions::HIDE_UI, {
            { "hide", 1 }
        })));
    }
    
    /* intro / draw a circle */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();
        
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "welcome to Auraglyph." },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 1.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "an infinite" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.25 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "modular" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.25 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "music" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.25 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "sketchpad." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 2 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to start, draw a circle." },
            { "position", startPos+Variant(currentTextPos += largeLineSpace) },
            { "pause", 0.01 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::SUGGEST_DRAW_NODE, {
            { "position", GLvertex3f(0, 0, 0) },
            { "pause", 0.01 },
        }));
        
        conditions.push_back(AGTutorialConditions::make(AGTutorialConditions::DRAW_NODE, {
            { "figure", (int) AG_FIGURE_CIRCLE },
            { "position>", "node1_pos" } // store position in node1_pos
        }));
        
        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* select the sine wave */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();

        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "awesome!" },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 0.25 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "you created an audio node." },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 1.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "audio nodes can create sound" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "or process an existing sound." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 1.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "here, you can see a menu" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "of different audio nodes" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to choose from." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 1.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "start by choosing the sine wave." },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::BLINK_NODE_SELECTOR, {
            { "item", 0 },
            { "pause", 0 },
        }));
        
        conditions.push_back(AGTutorialConditions::make(AGTutorialConditions::CREATE_NODE, {
            { "node_type", "SineWave" },
            { "uuid>", "node1_uuid" } // store uuid of created node in env variable
        }));
        
        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* connect to the output */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();

        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "nice!" },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 0.25 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to hear the sine wave," },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "we have to connect it" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::CREATE_NODE, {
            { "class", AGDocument::Node::AUDIO },
            { "type", "Output" },
            { "position", Variant([env](){
                // start position is based on env variable
                GLvertex3f node1Pos = env->fetch("node1_pos");
                GLvertex3f outputNodePos = node1Pos+GLvertex3f(350, 0, 0);
                env->store("output_pos", outputNodePos);
                return outputNodePos;
            })},
            { "pause", 1.0 },
            { "uuid>", "output_uuid" },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to an output node." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.5 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "drag from the output" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "of the sine wave" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::POINT_TO, {
            { "start", Variant([env](){
                // start position is based on env variable
                GLvertex3f node1Pos = env->fetch("node1_pos");
                return node1Pos+GLvertex3f(70, 0, 0);
            })},
            { "end", Variant([env](){
                GLvertex3f outputNodePos = env->fetch("output_pos");
                return outputNodePos+GLvertex3f(-70, 0, 0);
            })},
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to the output node." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 1.0 },
        }));
        
        conditions.push_back(AGTutorialConditions::make(AGTutorialConditions::CREATE_CONNECTION, {
            { "src_uuid", Variant([env]() { return env->fetch("node1_uuid").getString(); }) },
            { "dst_uuid", Variant([env]() { return env->fetch("output_uuid").getString(); }) },
            { "uuid>", "conn1_uuid" },
        }));
        
        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* tap to open the editor */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();

        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "you can change the" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "parameters of a node" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "using the node editor." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.5 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "tap the sine wave node" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to open its editor." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.5 },
        }));
        
        conditions.push_back(AGTutorialConditions::make(AGTutorialConditions::OPEN_NODE_EDITOR, {
            { "uuid", Variant([env]() { return env->fetch("node1_uuid").getString(); })},
        }));
        
        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* try changing the frequency or gain */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();

        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "tap and drag the" },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "value of a parameter" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "to adjust it." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "try changing the" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        // point to freq
        actions.push_back(AGTutorialActions::make(AGTutorialActions::POINT_TO, {
            { "start", Variant([env](){
                // start position is based on env variable node1_pos
                GLvertex3f node1Pos = env->fetch("node1_pos");
                return node1Pos+GLvertex3f(250, 32, 0);
            })},
            { "end", Variant([env](){
                // start position is based on env variable node1_pos
                GLvertex3f node1Pos = env->fetch("node1_pos");
                return node1Pos+GLvertex3f(85, 32, 0);
            })},
            { "pause", 0 },
        }));
        // point to gain
        actions.push_back(AGTutorialActions::make(AGTutorialActions::POINT_TO, {
            { "start", Variant([env](){
                // start position is based on env variable node1_pos
                GLvertex3f node1Pos = env->fetch("node1_pos");
                return node1Pos+GLvertex3f(250, -5, 0);
            })},
            { "end", Variant([env](){
                // start position is based on env variable node1_pos
                GLvertex3f node1Pos = env->fetch("node1_pos");
                return node1Pos+GLvertex3f(85, -5, 0);
            })},
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "frequency or gain" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "of the sine wave." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.5 },
        }));
        
        conditions.push_back(AGTutorialConditions::make(AGTutorialConditions::EDIT_NODE, {
            { "uuid", Variant([env]() { return env->fetch("node1_uuid").getString(); })},
            { "hang_time", 4.0f }
        }));
        
        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* disconnect the sine wave */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();
        
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "you can disconnect" },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "the sine wave by" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "tapping the connection" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::POINT_TO, {
            { "start", Variant([env](){
                GLvertex3f node1Pos = env->fetch("node1_pos");
                GLvertex3f outputNodePos = env->fetch("output_pos");
                GLvertex3f midpoint = node1Pos+(outputNodePos-node1Pos)*0.5f;
                GLvertex2f normal = normalToLine(node1Pos.xy(), outputNodePos.xy());
                return midpoint+normal*20;
            })},
            { "end", Variant([env](){
                GLvertex3f node1Pos = env->fetch("node1_pos");
                GLvertex3f outputNodePos = env->fetch("output_pos");
                GLvertex3f midpoint = node1Pos+(outputNodePos-node1Pos)*0.5f;
                GLvertex2f normal = normalToLine(node1Pos.xy(), outputNodePos.xy());
                return midpoint+normal*95;
            })},
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "and dragging it out." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));

        conditions.push_back(AGTutorialConditions::make(AGTutorialConditions::DELETE_CONNECTION, {
            { "uuid", Variant([env]() { return env->fetch("conn1_uuid").getString(); })},
        }));
        
        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* show the UI */
    {
        steps.push_back(_makeTutorialStep(AGTutorialActions::make(AGTutorialActions::HIDE_UI, {
            { "hide", 0 }
        })));
    }
    
    /* ui buttons */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();
        
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "the file menu includes" },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "functions to save, load" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "create new patches." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.3 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "undo and redo are" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "in the tools menu." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.3 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "you can access the tutorial" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "and configure Auraglyph" },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "through the settings menu." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 3.0 },
        }));

        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 0.01 }
        }));
    }
    
    /* thats all for now folks */
    {
        std::list<AGTutorialAction*> actions;
        std::list<AGTutorialCondition*> conditions;
        GLvertex3f currentTextPos = GLvertex3f();
        
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "woohoo!" },
            { "position", startPos+Variant(currentTextPos) },
            { "pause", 0.3 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "thats all for now." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 0.3 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "but check out" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "forum.auraglyph.io" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.5 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "for more tips" },
            { "position", startPos+Variant(currentTextPos += mediumLineSpace) },
            { "pause", 0.0 },
        }));
        actions.push_back(AGTutorialActions::make(AGTutorialActions::TEXT, {
            { "text", "and tutorials." },
            { "position", startPos+Variant(currentTextPos += normalLineSpace) },
            { "pause", 3.0 },
        }));

        steps.push_back(_makeTutorialStep(actions, conditions, {
            { "pause", 3.0 }
        }));
    }
    
    for(auto step : steps)
        step->init();
    AGTutorial *tutorial = new AGTutorial(steps, viewController);
    tutorial->init();
    tutorial->m_environment.reset(env);
    
    return tutorial;
}
