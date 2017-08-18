//
//  AGGraphManager.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/17/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGGraphManager.h"
#include "AGNode.h"
#include "AGViewController.h"

AGGraphManager &AGGraphManager::instance()
{
    static AGGraphManager s_instance;
    return s_instance;
}

AGGraphManager::AGGraphManager()
: m_viewController(nullptr)
{ }

AGGraphManager::~AGGraphManager()
{ }

AGNode *AGGraphManager::nodeWithUUID(const std::string &uuid)
{
    assert(m_viewController != nullptr);
    return m_viewController->nodeWithUUID(uuid);
}

void AGGraphManager::setViewController(AGViewController_ *viewController)
{
    m_viewController = viewController;
}

