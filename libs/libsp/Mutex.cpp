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

void Mutex::sync(const std::function<void()> &f)
{
    Scope scope = inScope();
    f();
}

Mutex::Scope Mutex::inScope()
{
    return std::move(Scope(*this));
}


Mutex::Scope::Scope(Mutex &m) : m_mutex(m)
{
    m_mutex.lock();
}

Mutex::Scope::~Scope()
{
    m_mutex.unlock();
}

Mutex::Scope::Scope(const Scope &&scope) : m_mutex(scope.m_mutex)
{ dbgprint_off("Scope move\n"); }

