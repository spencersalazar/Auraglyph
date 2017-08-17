//
//  AGUndoManager.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/17/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGUndoManager.h"

#define AG_MAX_UNDO 100

//------------------------------------------------------------------------------
// ### AGBasicUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGBasicUndoAction

AGBasicUndoAction::AGBasicUndoAction(std::function<void ()> _undo, std::function<void ()> _redo)
: m_undo(_undo), m_redo(_redo)
{ }

void AGBasicUndoAction::undo()
{
    m_undo();
}

void AGBasicUndoAction::redo()
{
    m_redo();
}

//------------------------------------------------------------------------------
// ### AGUndoManager ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoManager

AGUndoManager &AGUndoManager::instance()
{
    static AGUndoManager s_undoManager;
    return s_undoManager;
}
    
AGUndoManager::AGUndoManager()
{ }

AGUndoManager::~AGUndoManager()
{ }

void AGUndoManager::pushUndoAction(AGUndoAction *action)
{
    m_undo.push_back(action);
    
    while(m_undo.size() > AG_MAX_UNDO)
    {
        delete m_undo.front();
        m_undo.pop_front();
    }
    
    for(auto action : m_redo)
        delete action;
    m_redo.clear();
}

void AGUndoManager::undoLast()
{
    if(m_undo.size())
    {
        AGUndoAction *action = m_undo.back();
        m_undo.pop_back();
        action->undo();
        m_redo.push_back(action);
    }
}

void AGUndoManager::redoLast()
{
    if(m_redo.size())
    {
        AGUndoAction *action = m_redo.back();
        m_redo.pop_back();
        action->redo();
        m_undo.push_back(action);
    }
}

bool AGUndoManager::hasUndo()
{
    return m_undo.size() > 0;
}

bool AGUndoManager::hasRedo()
{
    return m_redo.size() > 0;
}

