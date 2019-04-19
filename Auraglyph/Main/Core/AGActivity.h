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
#include <map>


//------------------------------------------------------------------------------
// ### AGActivity ###
//------------------------------------------------------------------------------
class AGActivity
{
public:
    
    typedef std::string Type;
    
    static const Type EditParamActivityType;
    static const Type DrawNodeActivityType;
    static const Type CreateNodeActivityType;
    static const Type MoveNodeActivityType;
    static const Type DeleteNodeActivityType;
    static const Type CreateConnectionActivityType;
    static const Type DeleteConnectionActivityType;
    
    static AGActivity *editParamActivity(AGNode *node, int port, float oldValue, float newValue);
    static AGActivity *drawNodeActivity(AGHandwritingRecognizerFigure figure, const GLvertex3f &position);
    static AGActivity *createNodeActivity(AGNode *node);
    static AGActivity *moveNodeActivity(AGNode *node, const GLvertex3f &oldPos, const GLvertex3f &newPos);
    static AGActivity *deleteNodeActivity(AGNode *node);
    static AGActivity *createConnectionActivity(AGConnection *connection);
    static AGActivity *deleteConnectionActivity(AGConnection *connection);
    
    AGActivity(const Type &type, const std::string &title)
    : m_type(type), m_title(title)
    { }
    
    virtual ~AGActivity() { }
    
    virtual bool canUndo() const { return false; }
    virtual void undo() { }
    virtual void redo() { }
    virtual std::string serialize() const { return "{ }"; }

    Type type() const { return m_type; }
    std::string title() const { return m_title; }
    
private:
    Type m_type;
    std::string m_title;
};


//------------------------------------------------------------------------------
// ### AGUndoableActivity ###
//------------------------------------------------------------------------------
class AGUndoableActivity : public AGActivity
{
public:
    AGUndoableActivity(const std::string &type, const std::string &title,
                       std::function<void ()> undo, std::function<void ()> redo)
    : AGActivity(type, title), m_undo(undo), m_redo(redo)
    { }
    
    bool canUndo() const override { return true; }
    
    void undo() override { m_undo(); }
    
    void redo() override { m_redo(); }
    
private:
    std::function<void ()> m_undo;
    std::function<void ()> m_redo;
    std::function<std::string ()> m_serialize;
};


