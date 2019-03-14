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

#include "AGActivityManager.h"


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

class AGUndoManager : public AGActivityListener
{
public:
    static AGUndoManager &instance();
    
    AGUndoManager();
    ~AGUndoManager();
    
    void pushUndoAction(AGActivity *action);
    void undoLast();
    void redoLast();
    
    bool hasUndo();
    bool hasRedo();
    
    std::string undoItemTitle();
    std::string redoItemTitle();
    
    void addListener(AGUndoManagerListener *);
    void removeListener(AGUndoManagerListener *);
    
    void activityOccurred(AGActivity *activity) override;
    
private:
    std::list<AGActivity *> m_undo;
    std::list<AGActivity *> m_redo;
    std::list<AGUndoManagerListener *> m_listeners;
};
