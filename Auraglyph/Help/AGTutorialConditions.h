//
//  AGTutorialEntities.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGTutorialEntity.h"

/** Class enum of all possible tutorial conditions
*/
class AGTutorialConditions
{
public:
    enum Condition {
        ACTIONS_COMPLETED, /* Continue when all actions have completed. */
        TAP_SCREEN, /* Continue after user taps screen */
        DRAW_NODE, /* */
        CREATE_NODE,
        CREATE_CONNECTION,
        OPEN_NODE_EDITOR,
        EDIT_NODE,
        DELETE_CONNECTION,
    };
    
    /** Helper function to create tutorial conditions.
     */
    static AGTutorialCondition *make(Condition type, const map<std::string, Variant> &parameters = { });
};


/** AGCompositeTutorialCondition
 */
class AGCompositeTutorialCondition : public AGTutorialCondition
{
public:
    
    enum Operator
    {
        OR,
        AND,
    };

    static AGCompositeTutorialCondition* makeOr(const std::list<AGTutorialCondition*>& conditions)
    {
        return new AGCompositeTutorialCondition(OR, conditions);
    }
    
    static AGCompositeTutorialCondition* makeAnd(const std::list<AGTutorialCondition*>& conditions)
    {
        return new AGCompositeTutorialCondition(AND, conditions);
    }

    AGCompositeTutorialCondition(Operator op, const std::list<AGTutorialCondition*>& conditions)
    : m_op(op), m_conditions(conditions)
    { }
    
    ~AGCompositeTutorialCondition()
    {
        for (auto condition : m_conditions) {
            delete condition;
        }
    }
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        for (auto condition : m_conditions) {
            condition->prepare(environment);
        }
    }

    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        for (auto condition : m_conditions) {
            condition->finalize(environment);
        }
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        for (auto condition : m_conditions) {
            condition->activityOccurred(activity);
        }
    }
    
    /** */
    Status getStatus() override
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

private:
    Operator m_op = Operator::OR;
    std::list<AGTutorialCondition*> m_conditions;
};


