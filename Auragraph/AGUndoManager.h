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

//------------------------------------------------------------------------------
// ### AGUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoAction

class AGUndoAction
{
public:
    virtual ~AGUndoAction() { }
    
    virtual void undo() = 0;
    virtual void redo() = 0;
};

//------------------------------------------------------------------------------
// ### AGBasicUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGBasicUndoAction

class AGBasicUndoAction : public AGUndoAction
{
public:
    AGBasicUndoAction(std::function<void ()> _undo, std::function<void ()> _redo);
    
    virtual void undo() override;
    virtual void redo() override;

private:
    std::function<void ()> m_undo;
    std::function<void ()> m_redo;
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
    
private:
    std::list<AGUndoAction *> m_undo;
    std::list<AGUndoAction *> m_redo;
};
