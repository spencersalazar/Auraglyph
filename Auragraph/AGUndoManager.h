//
//  AGUndoManager.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/17/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <functional>
#include <list>
#include <string>

#include "Geometry.h"

class AGNode;
class AGConnection;
class AGFreeDraw;

//------------------------------------------------------------------------------
// ### AGUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoAction

class AGUndoAction
{
public:
    static AGUndoAction *editParamUndoAction(AGNode *node, int port, float oldValue, float newValue);
    static AGUndoAction *createNodeUndoAction(AGNode *node);
    static AGUndoAction *moveNodeUndoAction(AGNode *node, const GLvertex3f &oldPos, const GLvertex3f &newPos);
    static AGUndoAction *deleteNodeUndoAction(AGNode *node);
    static AGUndoAction *createConnectionUndoAction(AGConnection *connection);
    static AGUndoAction *deleteConnectionUndoAction(AGConnection *connection);
    
    AGUndoAction(const std::string &title) : m_title(title) { }
    virtual ~AGUndoAction() { }
    
    virtual void undo() = 0;
    virtual void redo() = 0;
    
    const std::string &title() { return m_title; }
    
    virtual std::string serialize() = 0;
    static AGUndoAction *deserialize(const std::string &serialization);
    
private:
    std::string m_title;
};


//------------------------------------------------------------------------------
// ### AGBasicUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGBasicUndoAction

class AGBasicUndoAction : public AGUndoAction
{
public:
    AGBasicUndoAction(const std::string &title,
                      std::function<void ()> _undo,
                      std::function<void ()> _redo,
                      std::function<std::string ()> _serialize);
    
    virtual void undo() override;
    virtual void redo() override;
    virtual std::string serialize() override;

private:
    std::function<void ()> m_undo;
    std::function<void ()> m_redo;
    std::function<std::string ()> m_serialize;
};


//------------------------------------------------------------------------------
// ### AGUndoManagerListener ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoManagerListener

class AGUndoManagerListener
{
public:
    virtual ~AGUndoManagerListener() { }
    
    virtual void undoStateChanged() = 0;
};


//------------------------------------------------------------------------------
// ### AGUndoManager ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoManager

class AGUndoManager
{
public:
    static AGUndoManager &instance();
    
    AGUndoManager();
    ~AGUndoManager();
    
    void pushUndoAction(AGUndoAction *action);
    void undoLast();
    void redoLast();
    
    bool hasUndo();
    bool hasRedo();
    
    std::string undoItemTitle();
    std::string redoItemTitle();
    
    void addListener(AGUndoManagerListener *);
    void removeListener(AGUndoManagerListener *);
    
private:
    std::list<AGUndoAction *> m_undo;
    std::list<AGUndoAction *> m_redo;
    std::list<AGUndoManagerListener *> m_listeners;
};
