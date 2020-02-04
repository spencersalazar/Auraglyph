//
//  AGTutorialEntities.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

/* Specific actions + conditions for constructing tutorials.
 
 TODO: note inputs/outputs of each action/condition
 
 AGTutorialConditions::DRAW_NODE - triggered by drawing a node figure
 AGTutorialConditions::CREATE_NODE - triggered by creating a node
 AGTutorialConditions::CREATE_CONNECTION - triggered by creating a connection
 selecting from the node menu
 
 */

#pragma once

#include "AGTutorialEntity.h"

/** Class enum of all possible tutorial actions
 */
class AGTutorialActions
{
public:
    enum Action {
        /* common parameters:
         - pause (float) - wait specified time before continuing to next action
         */
        TEXT,
        /* display text at specified location
         parameters:
         - text (string) - string to display
         - position (vertex3) - start position of text (at baseline of left side of first character)
         */
        POINT_TO,
        /* point from/to specific locations
         parameters:
         - start (vertex3) - start position of arrow
         - end (vertex3) - end position of arrow
         */
        HIDE_UI,
        /* hide/show UI
         parameters:
         - hide (int) - boolean to hide (1) or show (0) the UI
         */
        HIDE_GRAPH,
        /* hide/show graph (nodes + connections)
         parameters:
         - hide (int) - boolean to hide (1) or show (0) the graph
         */
        SUGGEST_DRAW_NODE,
        /* display a graphic to suggest drawing a node
         parameters:
         - position (vertex3) - center position of suggestion
         */
        CREATE_NODE,
        /* create a node
         parameters:
         - class (int) - class of node (audio or control)
         - type (string) - type of node (e.g. SineWave, etc.)
         - position (vertex3) - center position
         - uuid> (string) - variable name to store uuid of created node
         */
        BLINK_NODE_SELECTOR,
        /* blink node selector (first found in render model)
         parameters:
         - item (int) - number of item to blink
         */
        BLINK_NODE_EDITOR,
        /* blink node editor for specified node
         parameters:
         - uuid (string) - uuid of node whose editor to blink
         - item (int) - row of item to blink (-1 = all items)
         */
        BLINK_DASHBOARD,
        /* blink an item on the dashboard
         parameters:
         - item (string) - name of item to blink. possible options:
         file, edit, settings, node, freedraw, eraser, trash
         - enable (int) - whether to enable - 0: disable, 1: enable (default)
         */

    };
    
    /** Helper function to create tutorial actions.
     */
    static AGTutorialAction *make(Action type, const map<std::string, Variant> &parameters = { });
};

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


