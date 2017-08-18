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

//------------------------------------------------------------------------------
// ### AGUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoAction

class AGUndoAction
{
public:
    AGUndoAction(const std::string &title) : m_title(title) { }
    virtual ~AGUndoAction() { }
    
    virtual void undo() = 0;
    virtual void redo() = 0;
    
    const std::string &title() { return m_title; }
    
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
                      std::function<void ()> _redo);
    
    virtual void undo() override;
    virtual void redo() override;

private:
    std::function<void ()> m_undo;
    std::function<void ()> m_redo;
};


//------------------------------------------------------------------------------
// ### AGBasicUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGBasicUndoAction

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
