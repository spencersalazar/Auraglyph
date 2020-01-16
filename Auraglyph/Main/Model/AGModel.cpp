//
//  AGModel.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGModel.h"
#include "AGNode.h"

void AGModel::addNode(AGNode *node)
{
    m_graph.addNode(node);
    node->setModel(this);
    _broadcastToListeners([this, node](AGModelListener* listener){
        listener->nodeAddedToModel(this, node);
    });
}

void AGModel::removeNode(AGNode *node)
{
    m_graph.removeNode(node);
    node->setModel(nullptr);
    _broadcastToListeners([this, node](AGModelListener* listener){
        listener->nodeRemovedFromModel(this, node);
    });
}

void AGModel::addConnection(AGConnection *connection)
{
    m_graph.addConnection(connection);
    _broadcastToListeners([this, connection](AGModelListener* listener){
        listener->connectionAddedToModel(this, connection);
    });
}

void AGModel::removeConnection(AGConnection *connection)
{
    m_graph.removeConnection(connection);
    _broadcastToListeners([this, connection](AGModelListener* listener){
        listener->connectionRemovedFromModel(this, connection);
    });
}

void AGModel::addFreedraw(AGFreeDraw *freedraw)
{
    m_freedraws.push_back(freedraw);
    _broadcastToListeners([this, freedraw](AGModelListener* listener){
        listener->freedrawAddedToModel(this, freedraw);
    });
}

void AGModel::removeFreedraw(AGFreeDraw *freedraw)
{
    m_freedraws.remove(freedraw);
    _broadcastToListeners([this, freedraw](AGModelListener* listener){
        listener->freedrawRemovedFromModel(this, freedraw);
    });
}
