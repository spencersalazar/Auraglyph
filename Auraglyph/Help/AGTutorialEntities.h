//
//  AGTutorialEntities.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

/** Specific actions + conditions for constructing tutorials.
 
 TODO: note inputs/outputs of each action/condition
 
 - AGTutorialActions::TEXT - display text at specified location
 - AGTutorialActions::POINT_TO - point from/to specific locations
 - AGTutorialActions::HIDE_UI - hide/show UI
 - AGTutorialActions::SUGGEST_DRAW_NODE - display a graphic to suggest drawing a node
 - AGTutorialActions::CREATE_NODE - create a node

 - AGTutorialConditions::DRAW_NODE - triggered by drawing a node figure
 - AGTutorialConditions::CREATE_NODE - triggered by creating a node
 - AGTutorialConditions::CREATE_CONNECTION - triggered by creating a connection
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
        TEXT,
        POINT_TO,
        HIDE_UI,
        SUGGEST_DRAW_NODE,
        CREATE_NODE,
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
        DRAW_NODE,
        CREATE_NODE,
        CREATE_CONNECTION,
    };
    
    /** Helper function to create tutorial conditions.
     */
    static AGTutorialCondition *make(Condition type, const map<std::string, Variant> &parameters = { });
};



