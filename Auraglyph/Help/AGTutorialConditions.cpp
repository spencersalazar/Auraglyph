//
//  AGTutorialEntities.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGTutorialConditions.h"

#include "AGTutorial.h"

// for AGTouchOutsideListener
#include "AGBaseTouchHandler.h"

// for checking existing state
#include "AGModel.h"

// for conditions / activity listening
#include "AGActivity.h"
#include "AGActivities.h"

#include "AGTimer.h"

#include <memory>


//-----------------------------------------------------------------------------
// CONDITIONS
//-----------------------------------------------------------------------------
#pragma mark - ---CONDITIONS---

AGCompositeTutorialCondition* AGCompositeTutorialCondition::makeOr(const std::list<AGTutorialCondition*>& conditions)
{
    return new AGCompositeTutorialCondition(OR, conditions);
}

AGCompositeTutorialCondition* AGCompositeTutorialCondition::makeAnd(const std::list<AGTutorialCondition*>& conditions)
{
    return new AGCompositeTutorialCondition(AND, conditions);
}

AGCompositeTutorialCondition::AGCompositeTutorialCondition(Operator op, const std::list<AGTutorialCondition*>& conditions)
: m_op(op), m_conditions(conditions)
{ }

AGCompositeTutorialCondition::~AGCompositeTutorialCondition()
{
    for (auto condition : m_conditions) {
        delete condition;
    }
}

void AGCompositeTutorialCondition::prepareInternal(AGTutorialEnvironment &environment)
{
    for (auto condition : m_conditions) {
        condition->prepare(environment);
    }
}

void AGCompositeTutorialCondition::finalizeInternal(AGTutorialEnvironment &environment)
{
    for (auto condition : m_conditions) {
        condition->finalize(environment);
    }
}
    
void AGCompositeTutorialCondition::activityOccurred(AGActivity *activity)
{
    for (auto condition : m_conditions) {
        condition->activityOccurred(activity);
    }
}
    
AGCompositeTutorialCondition::Status AGCompositeTutorialCondition::getStatus()
{
    if (m_op == Operator::OR) {
        for (auto condition : m_conditions) {
            if (condition->getStatus() == STATUS_CONTINUE) {
                return STATUS_CONTINUE;
            }
        }
        
        return STATUS_INCOMPLETE;
        
    } else if (m_op == Operator::AND) {
        for (auto condition : m_conditions) {
            if (condition->getStatus() != STATUS_CONTINUE) {
                return STATUS_INCOMPLETE;
            }
        }
        
        return STATUS_CONTINUE;
        
    } else {
        // wat
        return STATUS_INCOMPLETE;
    }
}


/** AGTapScreenTutorialCondition
 */
class AGTapScreenTutorialCondition : public AGTutorialCondition, public AGTouchOutsideListener
{
public:
    
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void touchedOutside() override
    {
        m_status = STATUS_CONTINUE;
    }
    
    AGInteractiveObject * outsideObject() override
    {
        return nullptr;
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    GLvertex3f m_nodePosition = GLvertex3f();
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        environment.viewController()->baseTouchHandler().addTouchOutsideListener(this);
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        environment.viewController()->baseTouchHandler().removeTouchOutsideListener(this);
    }
};


/** AGDrawNodeTutorialCondition
 */
class AGDrawNodeTutorialCondition : public AGTutorialCondition
{
public:
    
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::DrawNodeActivityType) {
            auto drawNodeActivity = dynamic_cast<AG::Activities::DrawNode *>(activity);
            
            if(drawNodeActivity != nullptr) {
                m_nodePosition = drawNodeActivity->position;
                
                if(m_matchAnyFigure || drawNodeActivity->figure == m_figure) {
                    m_status = STATUS_CONTINUE;
                }
            }
        }
    }

private:
    Status m_status = STATUS_INCOMPLETE;
    GLvertex3f m_nodePosition = GLvertex3f();
    
    bool m_matchAnyFigure = false;
    AGHandwritingRecognizerFigure m_figure = AG_FIGURE_NONE;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        if(hasParameter("figure")) {
            m_figure = (AGHandwritingRecognizerFigure) getParameter("figure", (int) AG_FIGURE_NONE).getInt();
            m_matchAnyFigure = false;
        } else {
            m_matchAnyFigure = true;
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        std::string savePosition = getParameter("position>");
        if(savePosition.length())
            environment.store(savePosition, m_nodePosition);
    }
};


/** AGCreateNodeTutorialCondition
 */
class AGCreateNodeTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::CreateNodeActivityType) {
            auto createNodeActivity = dynamic_cast<AG::Activities::CreateNode *>(activity);
            
            if(m_matchAnyType || createNodeActivity->serializedNode.type == m_type) {
                m_status = STATUS_CONTINUE;
                m_nodeUUID = createNodeActivity->serializedNode.uuid;
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAnyType = false;
    std::string m_type = "";
    std::string m_nodeUUID = "";
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        if(hasParameter("node_type")) {
            m_type = getParameter("node_type").getString();
            m_matchAnyType = false;
        } else {
            m_matchAnyType = true;
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        if(m_status == STATUS_CONTINUE) {
            std::string saveUUID = getParameter("uuid>");
            if(saveUUID.length())
                environment.store(saveUUID, m_nodeUUID);
        }
    }
};


/** AGCreateConnectionTutorialCondition
 */
class AGCreateConnectionTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::CreateConnectionActivityType) {
            auto createConnectionActivity = dynamic_cast<AG::Activities::CreateConnection *>(activity);
            
            if(m_matchAnyType ||
               (createConnectionActivity->serializedConnection.srcUuid == getParameter("src_uuid") &&
                createConnectionActivity->serializedConnection.dstUuid == getParameter("dst_uuid"))) {
                   m_uuid = createConnectionActivity->uuid;
                   m_status = STATUS_CONTINUE;
               }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    std::string m_uuid = "";
    
    bool m_matchAnyType = false;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        if(hasParameter("src_uuid") && hasParameter("dst_uuid")) {
            m_matchAnyType = false;
        } else {
            m_matchAnyType = true;
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        if(m_status == STATUS_CONTINUE) {
            std::string saveUUID = getParameter("uuid>");
            if(saveUUID.length())
                environment.store(saveUUID, m_uuid);
        }
    }
};


/** AGOpenNodeEditorTutorialCondition
 */
class AGOpenNodeEditorTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::OpenNodeEditorActivityType) {
            auto openNodeEditorActivity = dynamic_cast<AG::Activities::OpenNodeEditor *>(activity);
            
            if(m_matchAny || openNodeEditorActivity->nodeUUID == getParameter("uuid")) {
                m_status = STATUS_CONTINUE;
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAny = false;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_matchAny = !hasParameter("uuid");
    }
};


/** AGEditNodeTutorialCondition
 */
class AGEditNodeTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::EditParamActivityType) {
            auto openNodeEditorActivity = dynamic_cast<AG::Activities::EditParam *>(activity);
            
            if(m_matchAny || openNodeEditorActivity->nodeUUID == getParameter("uuid")) {
                float hangTime = getParameter("hang_time", 0);
                if (hangTime > 0) {
                    // allow interaction for period of time after initial interaction
                    if (m_timer) {
                        // reset the timer if it exists
                        m_timer->reset();
                    } else {
                        // create new timer
                        m_timer.reset(new AGTimer(hangTime, ^(AGTimer *timer){
                            m_status = STATUS_CONTINUE;
                        }));
                    }
                } else {
                    // don't hang, just continue
                    m_status = STATUS_CONTINUE;
                }
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAny = false;
    std::unique_ptr<AGTimer> m_timer;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_matchAny = !hasParameter("uuid");
    }
};


/** AGDeleteConnectionTutorialCondition
 */
class AGDeleteConnectionTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::DeleteConnectionActivityType) {
            auto deleteConnEditorActivity = dynamic_cast<AG::Activities::DeleteConnection *>(activity);
            
            if(m_matchAny || deleteConnEditorActivity->uuid == getParameter("uuid")) {
                m_status = STATUS_CONTINUE;
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAny = false;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_matchAny = !hasParameter("uuid");
        
        // check if already completed
        std::string uuid = getParameter("uuid");
        if (uuid.length() && environment.model().graph().connectionWithUUID(uuid) == nullptr) {
            m_status = STATUS_CONTINUE;
        }
    }
};


/** AGActionsCompletedTutorialCondition
 */
class AGActionsCompletedTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        auto currentStep = *(environment().tutorial()->currentStep());
        if (currentStep->currentAction() == currentStep->actions().end()) {
            return STATUS_CONTINUE;
        } else {
            return STATUS_INCOMPLETE;
        }
    }
};


AGTutorialCondition *AGTutorialConditions::make(AGTutorialConditions::Condition type, const map<std::string, Variant> &parameters)
{
    AGTutorialCondition *condition = nullptr;
    
    switch (type) {
        case AGTutorialConditions::ACTIONS_COMPLETED:
            return new AGActionsCompletedTutorialCondition(parameters);
            break;
        case AGTutorialConditions::TAP_SCREEN:
            return new AGTapScreenTutorialCondition(parameters);
            break;
        case AGTutorialConditions::DRAW_NODE:
            condition = new AGDrawNodeTutorialCondition(parameters);
            break;
        case AGTutorialConditions::CREATE_NODE:
            condition = new AGCreateNodeTutorialCondition(parameters);
            break;
        case AGTutorialConditions::CREATE_CONNECTION:
            condition = new AGCreateConnectionTutorialCondition(parameters);
            break;
        case AGTutorialConditions::OPEN_NODE_EDITOR:
            condition = new AGOpenNodeEditorTutorialCondition(parameters);
            break;
        case AGTutorialConditions::EDIT_NODE:
            condition = new AGEditNodeTutorialCondition(parameters);
            break;
        case AGTutorialConditions::DELETE_CONNECTION:
            condition = new AGDeleteConnectionTutorialCondition(parameters);
            break;
        default:
            assert(0);
            break;
    }
    
    assert(condition != nullptr);
    
    return condition;
}

