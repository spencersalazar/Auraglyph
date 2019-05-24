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
m_lastFire(FLT_MIN), m_interval(FLT_MAX), m_action(NULL), m_repeat(true), m_done(false)
{
    [[AGAudioManager instance] addTimer:this];
}

AGTimer::AGTimer(float interval, void (^action)(AGTimer *timer), bool repeat) :
m_lastFire(FLT_MIN), m_interval(interval), m_action(action), m_repeat(repeat), m_done(false)
{
    [[AGAudioManager instance] addTimer:this];
}

AGTimer::~AGTimer()
{
    [[AGAudioManager instance] removeTimer:this];
    m_action = NULL;
}

void AGTimer::reset()
{
    m_lastFire = FLT_MIN;
    m_done = false;
}

void AGTimer::checkTimer(float t, float dt)
{
    // initial condition
    if(m_lastFire == FLT_MIN) m_lastFire = t;
    
    if(!m_done && t-m_lastFire >= m_interval)
    {
        if(m_action)
            m_action(this);
        
        if(m_repeat)
            m_lastFire = t;
        else
            m_done = true;
    }
}
