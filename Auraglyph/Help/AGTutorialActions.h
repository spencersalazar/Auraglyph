//
//  AGTutorialActions.h
//  Auraglyph
//
//  Created by Spencer Salazar on 2/4/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

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
        TEXT,                /* display text at specified location
                              parameters:
                              - text (string) - string to display
                              - position (vertex3) - start position of text (at baseline of left side of first character)
                              */
        POINT_TO,            /* point from/to specific locations
                              parameters:
                              - start (vertex3) - start position of arrow
                              - end (vertex3) - end position of arrow
                              */
        HIDE_UI,             /* hide/show UI
                              parameters:
                              - hide (int) - boolean to hide (1) or show (0) the UI
                              */
        HIDE_GRAPH,          /* hide/show graph (nodes + connections)
                              parameters:
                              - hide (int) - boolean to hide (1) or show (0) the graph
                              */
        SELECT_TOOL,         /* select tool
                              parameters:
                              - tool (string) - tool to select, "draw", "freedraw", or "eraser"
                              */
        CLOSE_EDITORS,       /* close node editor */
        SUGGEST_DRAW_NODE,   /* display a graphic to suggest drawing a node
                              parameters:
                              - position (vertex3) - center position of suggestion
                              */
        CREATE_NODE,         /* create a node
                              parameters:
                              - class (int) - class of node (audio or control)
                              - type (string) - type of node (e.g. SineWave, etc.)
                              - position (vertex3) - center position
                              - uuid> (string) - variable name to store uuid of created node
                              */
        BLINK_NODE_SELECTOR, /* blink node selector (first found in render model)
                              parameters:
                              - item (int) - number of item to blink
                              */
        BLINK_NODE_EDITOR,   /* blink node editor for specified node
                              parameters:
                              - uuid (string) - uuid of node whose editor to blink
                              - item (int) - row of item to blink (-1 = all items)
                              */
        BLINK_DASHBOARD,     /* blink an item on the dashboard
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

