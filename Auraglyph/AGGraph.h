//
//  AGGraph.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 3/28/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include <list>
#include <map>
#include <string>

class AGNode;
class AGConnection;
class AGFreeDraw;
class AGInteractiveObject;

class AGGraph
{
public:
    
    const std::list<AGNode *> &nodes() const;

    bool hasNode(AGNode *node) const;
    AGNode *nodeWithUUID(const std::string &uuid) const;
    AGConnection *connectionWithUUID(const std::string &uuid) const;
    
    void addNode(AGNode *node);
    void removeNode(AGNode *node);
    void addConnection(AGConnection *connection);
    void removeConnection(AGConnection *connection);

private:
    std::list<AGNode *> _nodes;
    std::map<std::string, AGNode *> _uuid2Node;
    
    std::map<std::string, AGConnection *> _connections;
    
    std::map<AGNode *, std::string> _nodeUUID;
    std::map<AGConnection *, std::string> _conectionUUID;
};
