//
//  Thread.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "Thread.h"

Thread::Thread() { }

Thread::~Thread()
{
    if(m_thread)
    {
        pthread_detach(m_thread);
        m_thread = NULL;
    }
}

void Thread::start(const std::function<void ()> &go)
{
    m_go = go;
    pthread_create(&m_thread, NULL, _threadFunc, this);
}

void Thread::wait()
{
    if(m_thread)
        pthread_join(m_thread, NULL);
}

void *Thread::_threadFunc(void *_this)
{
    Thread *that = static_cast<Thread *>(_this);
    that->m_go();
    return NULL;
}
