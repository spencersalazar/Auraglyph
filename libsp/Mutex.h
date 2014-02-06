//
//  Mutex.h
//  Auragraph
//
//  Created by Spencer Salazar on 2/5/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__Mutex__
#define __Auragraph__Mutex__

#include <pthread.h>

class Mutex
{
public:
    Mutex();
    ~Mutex();
    
    void lock();
    void unlock();
    
private:
    pthread_mutex_t m_mutex;
};

#endif /* defined(__Auragraph__Mutex__) */
