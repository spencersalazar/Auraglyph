//
//  AGActivityManager.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 1/4/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGActivityManager.h"

AGActivityManager &AGActivityManager::instance()
{
    static AGActivityManager s_instance;
    return s_instance;
}

void AGActivityManager::addActivity(AGActivity *activity)
{
    for(auto listener : m_listeners)
        listener->activityOccurred(activity);
}

void AGActivityManager::addActivityListener(AGActivityListener *listener)
{
    m_listeners.push_back(listener);
}

void AGActivityManager::removeActivityListener(AGActivityListener *listener)
{
    m_listeners.remove(listener);
}

