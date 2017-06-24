//
//  Signal.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "Signal.h"

Signal::Signal()
{
    pthread_mutex_init(&m_mutex, NULL);
    pthread_cond_init(&m_cond, NULL);
}

Signal::~Signal()
{
    pthread_cond_destroy(&m_cond);
    pthread_mutex_destroy(&m_mutex);
}

void Signal::start()
{
    pthread_mutex_lock(&m_mutex);
}

void Signal::wait()
{
    pthread_cond_wait(&m_cond, &m_mutex);
}

void Signal::signal()
{
    pthread_cond_signal(&m_cond);
}

void Signal::broadcast()
{
    pthread_cond_broadcast(&m_cond);
}
