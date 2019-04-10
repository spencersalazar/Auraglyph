//
//  AGTutorialEntities.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

/** Specific actions + conditions for constructing tutorials.
 - AGTextTutorialAction - display text at specified location
 - AGHideUITutorialAction - hide/show UI
 - AGDrawNodeTutorialAction - display a graphic to suggest drawing a node
 
 - AGDrawNodeTutorialCondition - triggered by drawing a node figure
 - AGCreateNodeTutorialCondition - triggered by creating a node, i.e.
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
        DRAW_NODE,
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
    };
    
    /** Helper function to create tutorial conditions.
     */
    static AGTutorialCondition *make(Condition type, const map<std::string, Variant> &parameters = { });
};



