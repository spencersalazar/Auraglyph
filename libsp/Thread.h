//
//  Thread.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <functional>
#include <pthread.h>

class Thread
{
public:
    Thread();
    ~Thread();
    
    void start(const std::function<void ()> &go);
    void wait();
    
private:
    static void *_threadFunc(void *_this);
    
    pthread_t m_thread = NULL;
    std::function<void ()> m_go = [](){};
};

