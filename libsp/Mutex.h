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
#include <functional>

class Mutex
{
public:
    Mutex();
    ~Mutex();
    Mutex(const Mutex &) = delete;
    
    void lock();
    void unlock();
    
    void sync(const std::function<void ()>& f);
    
    class Scope
    {
    public:
        Scope(Mutex &m);
        ~Scope();
        Scope(const Scope &) = delete;
        Scope(const Scope &&scope);
        
    private:
        Mutex &m_mutex;
    };
    
    Scope inScope();
    
private:
    pthread_mutex_t m_mutex;
};

#endif /* defined(__Auragraph__Mutex__) */
