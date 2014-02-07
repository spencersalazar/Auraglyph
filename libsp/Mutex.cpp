//
//  Mutex.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 2/5/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "Mutex.h"

Mutex::Mutex()
{
    pthread_mutex_init(&m_mutex, NULL);
}

Mutex::~Mutex()
{
    pthread_mutex_destroy(&m_mutex);
}

void Mutex::lock()
{
    pthread_mutex_lock(&m_mutex);
}

void Mutex::unlock()
{
    pthread_mutex_unlock(&m_mutex);
}
