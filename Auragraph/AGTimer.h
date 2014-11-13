//
//  AGTimer.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGTimer__
#define __Auragraph__AGTimer__

class AGTimer
{
public:
    AGTimer(float interval, void (^action)(AGTimer *timer));
    ~AGTimer();
    
    void setInterval(float interval) { m_interval = interval; }
    
    void checkTimer(float t, float dt);
    
private:
    float m_lastFire;
    float m_interval;
    void (^m_action)(AGTimer *timer);
};


#endif /* defined(__Auragraph__AGTimer__) */
