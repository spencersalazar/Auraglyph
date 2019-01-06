//
//  AGTutorial.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 3/22/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGRenderObject.h"

#include "Variant.h"

#include <list>
#include <map>

class AGTutorialStep;

class AGTutorial : public AGRenderObject
{
public:
    
    static AGTutorial *createInitialTutorial();
    
    AGTutorial(std::list<AGTutorialStep*> &steps);
    ~AGTutorial();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    bool isComplete();
    
private:
    std::list<AGTutorialStep*> m_steps;
    std::list<AGTutorialStep*>::iterator m_currentStep;
};
