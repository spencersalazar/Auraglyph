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
        TAP_SCREEN,
        DRAW_NODE,
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



