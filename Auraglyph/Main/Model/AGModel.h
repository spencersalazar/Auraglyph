//
//  AGModel.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGGraph.h"

#include <list>

class AGFreedraw;

/** Basic model for Auraglyph sketch- nodes + freehand drawings
 */
class AGModel
{
public:
    
    AGGraph& graph() { return m_graph; }
    const AGGraph& graph() const { return m_graph; }
    
    std::list<AGFreeDraw *>& freedraws() { return m_freedraws; }
    const std::list<AGFreeDraw *>& freedraws() const { return m_freedraws; }

private:
    AGGraph m_graph;
    std::list<AGFreeDraw *> m_freedraws;
};


