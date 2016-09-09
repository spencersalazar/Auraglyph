//
//  AGTimer.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGTimer.h"
#include "AGAudioManager.h"


AGTimer::AGTimer() :
m_lastFire(FLT_MIN), m_interval(FLT_MAX), m_action(NULL)
{
    [[AGAudioManager instance] addTimer:this];
}

AGTimer::AGTimer(float interval, void (^action)(AGTimer *timer)) :
m_lastFire(FLT_MIN), m_interval(interval), m_action(action)
{
    [[AGAudioManager instance] addTimer:this];
}

AGTimer::~AGTimer()
{
    [[AGAudioManager instance] removeTimer:this];
    m_action = NULL;
}

void AGTimer::checkTimer(float t, float dt)
{
    // initial condition
    if(m_lastFire == FLT_MIN) m_lastFire = t;
    
    if(t-m_lastFire >= m_interval)
    {
        if(m_action)
            m_action(this);
        m_lastFire = t;
    }
}
