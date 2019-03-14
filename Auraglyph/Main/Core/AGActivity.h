//
//  AGActivity.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 1/4/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGNode.h"
#include "AGHandwritingRecognizer.h"
#include "Geometry.h"

#include <string>

extern const std::string AGActivityEditParamActivityType;
extern const std::string AGActivityDrawFigureActivityType;
extern const std::string AGActivityCreateNodeActivityType;
extern const std::string AGActivityMoveNodeActivityType;
extern const std::string AGActivityDeleteNodeActivityType;
extern const std::string AGActivityCreateConnectionActivityType;
extern const std::string AGActivityDeleteConnectionActivityType;

class AGActivity
{
public:
    
    static AGActivity *editParamActivity(AGNode *node, int port, float oldValue, float newValue);
    static AGActivity *drawFigureActivity(AGHandwritingRecognizerFigure figure);
    static AGActivity *createNodeActivity(AGNode *node);
    static AGActivity *moveNodeActivity(AGNode *node, const GLvertex3f &oldPos, const GLvertex3f &newPos);
    static AGActivity *deleteNodeActivity(AGNode *node);
    static AGActivity *createConnectionActivity(AGConnection *connection);
    static AGActivity *deleteConnectionActivity(AGConnection *connection);
    
    AGActivity(const std::string &type, const std::string &title)
    : m_type(type), m_title(title)
    { }
    
    virtual ~AGActivity() { }
    
    virtual bool canUndo() const { return false; }
    virtual void undo() { }
    virtual void redo() { }
    
    std::string type() const { return m_type; }
    std::string title() const { return m_title; }
    
private:
    std::string m_type;
    std::string m_title;
};

