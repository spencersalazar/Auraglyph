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
class AGTutorialEnvironment;
class AGViewController_;

class AGTutorial : public AGRenderObject
{
public:
    
    static AGTutorial *createInitialTutorial(AGViewController_ *viewController);
    
    AGTutorial(std::list<AGTutorialStep*> &steps, AGViewController_ *viewController);
    ~AGTutorial();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    bool isComplete();
    
private:
    std::unique_ptr<AGTutorialEnvironment> m_environment;
    
    std::list<AGTutorialStep*> m_steps;
    std::list<AGTutorialStep*> m_activeSteps;
    std::list<AGTutorialStep*>::iterator m_currentStep;
};
