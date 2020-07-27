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

class AGNode;
class AGConnection;
class AGFreedraw;
class AGModel;

/** Interface class for model listener.
 */
class AGModelListener
{
public:
    virtual ~AGModelListener() { }
    
    virtual void nodeAddedToModel(AGModel* model, AGNode* node) { }
    virtual void nodeRemovedFromModel(AGModel* model, AGNode* node) { }
    virtual void connectionAddedToModel(AGModel* model, AGConnection* node) { }
    virtual void connectionRemovedFromModel(AGModel* model, AGConnection* node) { }
    virtual void freedrawAddedToModel(AGModel* model, AGFreeDraw* node) { }
    virtual void freedrawRemovedFromModel(AGModel* model, AGFreeDraw* node) { }
};


#include <list>

/** Template base class for something that has listeners and can broadcast to them.
 */
template<typename Listener>
class Listenable
{
public:
    virtual ~Listenable() { }
    
    void addListener(Listener* listener) { m_listeners.push_back(listener); }
    void removeListener(Listener* listener) { m_listeners.remove(listener); }

protected:
    
    void _broadcastToListeners(std::function<void (Listener*)> f)
    {
        for (auto listener : m_listeners) {
            f(listener);
        }
    }
    
    std::list<Listener*> m_listeners;
};

/** Basic model for Auraglyph sketch- nodes + freehand drawings
 */
class AGModel : public Listenable<AGModelListener>
{
public:
    
    const AGGraph& graph() const { return m_graph; }
    
    const std::list<AGFreeDraw *>& freedraws() const { return m_freedraws; }
    
    void addNode(AGNode *node);
    void removeNode(AGNode *node);
    void addConnection(AGConnection *connection);
    void removeConnection(AGConnection *connection);
    void addFreedraw(AGFreeDraw *freedraw);
    void removeFreedraw(AGFreeDraw *freedraw);
    
    void hide(bool hide_);
    
private:
    AGGraph m_graph;
    std::list<AGFreeDraw *> m_freedraws;
};


