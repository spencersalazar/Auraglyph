//
//  AGTutorialEntity.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGTutorialEntity.h"

#pragma mark AGTutorialEnvironment

AGTutorialEnvironment::AGTutorialEnvironment(AGViewController_ *viewController) : m_viewController(viewController) { }

AGViewController_ *AGTutorialEnvironment::viewController() { return m_viewController; }

void AGTutorialEnvironment::store(const std::string &name, const Variant &variable) { m_variables[name] = variable; }

const Variant &AGTutorialEnvironment::fetch(const std::string &name, const Variant &variable) { return m_variables[name]; }

#pragma mark AGTutorialEntity

AGTutorialEntity::AGTutorialEntity(const map<std::string, Variant> &parameters,
                                   std::function<void (AGTutorialEnvironment &env)> onPrepare,
                                   std::function<void (AGTutorialEnvironment &env)> onFinalize)
: m_parameters(parameters), m_onPrepare(onPrepare), m_onFinalize(onFinalize)
{ }

AGTutorialEntity::~AGTutorialEntity() { }

void AGTutorialEntity::prepare(AGTutorialEnvironment &environment)
{
    prepareInternal(environment);
    m_onPrepare(environment);
}

void AGTutorialEntity::finalize(AGTutorialEnvironment &environment)
{
    finalizeInternal(environment);
    m_onFinalize(environment);
}

Variant AGTutorialEntity::getParameter(const std::string &name, Variant defaultValue)
{
    if (m_parameters.count(name))
        return m_parameters[name];
    else
        return defaultValue;
}

void AGTutorialEntity::prepareInternal(AGTutorialEnvironment &environment) { }

void AGTutorialEntity::finalizeInternal(AGTutorialEnvironment &environment) { }


#pragma mark AGTutorialAction

AGTutorialAction::AGTutorialAction(const map<std::string, Variant> &parameters,
                                   std::function<void (AGTutorialEnvironment &env)> onPrepare,
                                   std::function<void (AGTutorialEnvironment &env)> onFinalize)
: AGTutorialEntity(parameters, onPrepare, onFinalize)
{ }


#pragma mark AGTutorialCondition

AGTutorialCondition::AGTutorialCondition(const map<std::string, Variant> &parameters,
                                         std::function<void (AGTutorialEnvironment &env)> onPrepare,
                                         std::function<void (AGTutorialEnvironment &env)> onFinalize)
: AGTutorialEntity(parameters, onPrepare, onFinalize)
{ }


#pragma mark AGTutorialStep

AGTutorialStep::AGTutorialStep(const list<AGTutorialAction*> &actions,
                               const list<AGTutorialCondition*> &conditions,
                               const map<std::string, Variant> &parameters)
: AGTutorialEntity(parameters), m_actions(actions), m_conditions(conditions)
{
    // TODO: need to init these somewhere else
    for(auto action : m_actions)
        action->init();
}

AGTutorialStep::AGTutorialStep(AGTutorialAction *action,
                               const std::map<std::string, Variant> &parameters)
: AGTutorialEntity(parameters)
{
    m_actions.push_back(action);
}

AGTutorialStep::~AGTutorialStep()
{
    for(auto action : m_actions)
        delete action;
    m_actions.clear();
    for(auto condition : m_conditions)
        delete condition;
    m_conditions.clear();
}

bool AGTutorialStep::canContinue()
{
    return m_conditionStatus == AGTutorialCondition::STATUS_CONTINUE;
}

bool AGTutorialStep::isCompleted()
{
    return m_conditionStatus == AGTutorialCondition::STATUS_CONTINUE;
}

void AGTutorialStep::update(float t, float dt) 
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

void AGTutorialStep::render()
{
    AGRenderObject::render();
    
    for(auto action : m_activeActions)
        action->render();
}

void AGTutorialStep::activityOccurred(AGActivity *activity)
{
    for(auto condition : m_conditions)
        condition->activityOccurred(activity);
        
    _checkConditions();
}

void AGTutorialStep::_checkConditions()
{
    if(m_conditions.size() == 0)
    {
        // if there are no conditions, can continue immediately
        dbgprint("tutorial condition status: continue\n");
        m_conditionStatus = AGTutorialCondition::STATUS_CONTINUE;
    }
    else
    {
        for(auto condition : m_conditions)
        {
            auto status = condition->getStatus();
            if (status == AGTutorialCondition::STATUS_CONTINUE)
            {
                dbgprint("tutorial condition status: continue\n");
                m_conditionStatus = status;
                m_completedCondition = condition;
                break;
            }
        }
    }
}

void AGTutorialStep::prepareInternal(AGTutorialEnvironment &environment)
{
    m_environment = &environment;
    
    m_currentAction = m_actions.begin();
    (*m_currentAction)->prepare(*m_environment);
    m_activeActions.push_back(*m_currentAction);
    
    // if there are no conditions, can continue immediately
    if(m_conditions.size() == 0)
    {
        dbgprint("tutorial condition status: continue\n");
        m_conditionStatus = AGTutorialCondition::STATUS_CONTINUE;
    }
}

void AGTutorialStep::finalizeInternal(AGTutorialEnvironment &environment)
{ }
