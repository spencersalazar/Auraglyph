//
//  AGTutorial.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 3/22/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"
#include "AGActivityManager.h"
#include "Variant.h"

#include <list>
#include <map>
#include <memory>

class AGTutorialStep;
class AGTutorialEnvironment;
class AGViewController_;
class AGUIButton;

class AGTutorial : public AGRenderObject, public AGActivityListener
{
public:
    
    static AGTutorial *createInitialTutorial(AGViewController_ *viewController);
    
    AGTutorial(std::list<AGTutorialStep*> &steps, AGViewController_ *viewController);
    ~AGTutorial();
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    void complete();
    bool isComplete();
    
    void activityOccurred(AGActivity *activity) override;
    
    const std::list<AGTutorialStep*>& steps() { return m_steps; }
    
    std::list<AGTutorialStep*>::iterator currentStep() { return m_currentStep; }
    
    void showExitTutorialButton(bool show);
    
private:
    std::unique_ptr<AGTutorialEnvironment> m_environment;
    
    std::list<AGTutorialStep*> m_steps;
    std::list<AGTutorialStep*> m_activeSteps;
    std::list<AGTutorialStep*>::iterator m_currentStep;
    
    AGUIButton* m_exitButton = nullptr;
};
