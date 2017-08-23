//
//  AGGraphManager.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/17/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <string>
#include <map>

class AGNode;
class AGConnection;
class AGViewController_;

class AGGraphManager
{
public:
    static AGGraphManager &instance();
    
    AGGraphManager();
    ~AGGraphManager();
    
    void addNodeToTopLevel(AGNode *node);
    
    AGNode *nodeWithUUID(const std::string &uuid);
    AGConnection *connectionWithUUID(const std::string &uuid);
    
    void addConnection(AGConnection *connection);
    void removeConnection(AGConnection *connection);
    
    void setViewController(AGViewController_ *viewController);
    
private:
    AGViewController_ *m_viewController;
    
    std::map<std::string, AGConnection *> m_connections;
};
