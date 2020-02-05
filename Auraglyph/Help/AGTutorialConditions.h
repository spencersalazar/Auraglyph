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
    
    /** */
    enum Operator
    {
        OR,
        AND,
    };

    /** */
    static AGCompositeTutorialCondition* makeOr(const std::list<AGTutorialCondition*>& conditions);
    
    /** */
    static AGCompositeTutorialCondition* makeAnd(const std::list<AGTutorialCondition*>& conditions);

    /** */
    AGCompositeTutorialCondition(Operator op, const std::list<AGTutorialCondition*>& conditions);
    
    /** */
    ~AGCompositeTutorialCondition();
    
    /** */
    void prepareInternal(AGTutorialEnvironment &environment) override;

    /** */
    void finalizeInternal(AGTutorialEnvironment &environment) override;
    
    /** */
    void activityOccurred(AGActivity *activity) override;
    
    /** */
    Status getStatus() override;

private:
    Operator m_op = Operator::OR;
    std::list<AGTutorialCondition*> m_conditions;
};


