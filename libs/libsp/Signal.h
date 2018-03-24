//
//  Signal.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <pthread.h>

class Signal
{
public:
    Signal();
    ~Signal();
    
    void start();
    void wait();
    
    void signal();
    void broadcast();
    
private:
    pthread_mutex_t m_mutex;
    pthread_cond_t m_cond;
};

