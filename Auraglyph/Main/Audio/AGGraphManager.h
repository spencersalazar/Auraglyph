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
class AGGraph;
class AGViewController_;

class AGGraphManager
{
public:
    static AGGraphManager &instance();
    
    AGGraphManager();
    ~AGGraphManager();
    
    void addNodeToTopLevel(AGNode *node);
    
    const AGGraph *graph();
    
    void setViewController(AGViewController_ *viewController);
    
private:
    AGViewController_ *m_viewController;
};
