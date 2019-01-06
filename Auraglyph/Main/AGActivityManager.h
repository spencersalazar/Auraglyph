//
//  AGActivityManager.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 1/4/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include <list>

class AGActivity;

class AGActivityListener
{
public:
    virtual ~AGActivityListener() { }
    
    virtual void activityOccurred(AGActivity *activity) = 0;
};

class AGActivityManager
{
public:
    static AGActivityManager &instance();
    
    void addActivity(AGActivity *activity);
    
    void addActivityListener(AGActivityListener *listener);
    void removeActivityListener(AGActivityListener *listener);
    
private:
    std::list<AGActivityListener *> m_listeners;
};
