//
//  AGGraph.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 3/28/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGGraph.h"
#include "AGNode.h"

const std::list<AGNode *> &AGGraph::nodes() const
{
    return _nodes;
}

bool AGGraph::hasNode(AGNode *node) const
{
    return (std::find(_nodes.begin(), _nodes.end(), node) != _nodes.end());
}

AGNode *AGGraph::nodeWithUUID(const std::string &uuid) const
{
    if(_uuid2Node.count(uuid))
        return _uuid2Node.at(uuid);
    else
        return NULL;
}

void AGGraph::addNode(AGNode *node)
{
    _nodes.push_back(node);
    _uuid2Node[node->uuid()] = node;
}

void AGGraph::removeNode(AGNode *node)
{
    _nodes.remove(node);
    _uuid2Node.erase(node->uuid());
}
