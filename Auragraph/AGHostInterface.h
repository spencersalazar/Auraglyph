/*------------------------------------------------------------------------------
 |
 | AGHostInterface.h
 | Auraglyph
 |
 | Copyright (c) 2017 Spencer Salazar. All rights reserved.
 |
 ------------------------------------------------------------------------------*/

#pragma once

#include "AGInteractiveObject.h"
#include <functional>

//------------------------------------------------------------------------------
// ### AGHostInterface ###
// Abstract base class for interface between libag and its host.
//------------------------------------------------------------------------------
#pragma mark - AGShellInterface

class AGHostInterface
{
public:
    virtual void fadeOutAndDelete(AGInteractiveObject *) = 0;
    virtual void addTouchOutsideListener(AGInteractiveObject *) = 0;
    virtual void removeTouchOutsideListener(AGInteractiveObject *) = 0;
};

//------------------------------------------------------------------------------
// ### AGGenericHostInterface ###
// Generic host interface that uses C++ lambdas.
//------------------------------------------------------------------------------
#pragma mark - AGGenericHostInterface

class AGGenericHostInterface : public AGHostInterface
{
public:
    AGGenericHostInterface(std::function<void (AGInteractiveObject *)> fadeOutAndDelete,
                           std::function<void (AGInteractiveObject *)> addTouchListener,
                           std::function<void (AGInteractiveObject *)> removeTouchListener)
    {
        m_fadeOutAndDelete = fadeOutAndDelete;
        m_addTouchListener = addTouchListener;
        m_removeTouchListener = removeTouchListener;
    }
    
    void fadeOutAndDelete(AGInteractiveObject *object) override { m_fadeOutAndDelete(object); }
    void addTouchOutsideListener(AGInteractiveObject *object) override { m_addTouchListener(object); };
    void removeTouchOutsideListener(AGInteractiveObject *object) override { m_removeTouchListener(object); };
    
private:
    std::function<void (AGInteractiveObject *)> m_fadeOutAndDelete;
    std::function<void (AGInteractiveObject *)> m_addTouchListener;
    std::function<void (AGInteractiveObject *)> m_removeTouchListener;
};
