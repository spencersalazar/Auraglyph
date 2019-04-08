//
//  AGTutorialEntities.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGTutorialEntities.h"

// for rendering
#include "Geometry.h"
#include "TexFont.h"
#include "Matrix.h"
#include "AGStyle.h"
#include "GeoGenerator.h"
#include "Easing/Cubic.h"

// for hide/show UI
#include "AGViewController.h"

// for conditions / activity listening
#include "AGActivity.h"

#include <vector>

/** Tutorial step that simply displays text.
 */
class AGTextTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override;
    
    void render() override;
    
    bool isCompleted() override;
    
    bool canContinue() override;
    
protected:
    string m_text;
    float m_t = 0;
    float m_pause = 0;
    float m_textExtent = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override;
};

/** AGHideUITutorialAction
 */
class AGHideUITutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    bool isCompleted() override;
    bool canContinue() override;
    
private:
    void prepareInternal(AGTutorialEnvironment &environment) override;
};

/** AGPointToTutorialAction
 */
class AGPointToTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        
    }
    
    void render() override
    {
        
    }
    
    bool canContinue() override
    {
        
    }
    
    bool isCompleted() override
    {
        
    }
    
protected:
    std::vector<GLvertex3f> m_figure;
    bool m_canContinue = false;
    GLvertex3f m_figurePos;
    float m_tFig = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        
    }
};

/** AGDrawNodeTutorialAction
 */
class AGDrawNodeTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override;
    
    void render() override;
    
    bool canContinue() override;
    
    bool isCompleted() override;
    
protected:
    std::vector<GLvertex3f> m_figure;
    bool m_canContinue = false;
    GLvertex3f m_figurePos;
    float m_tFig = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override;
};



/** AGDrawNodeTutorialCondition
 */
class AGDrawNodeTutorialCondition : public AGTutorialCondition
{
public:
    
    using AGTutorialCondition::AGTutorialCondition;
    
    Status getStatus() override;
    
    void activityOccurred(AGActivity *activity) override;
    
private:
    Status m_status = STATUS_INCOMPLETE;
};


/** AGCreateNodeTutorialCondition
 */
class AGCreateNodeTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    Status getStatus() override;
    
    void activityOccurred(AGActivity *activity) override;
    
private:
    Status m_status = STATUS_INCOMPLETE;
};


//-----------------------------------------------------------------------------
// ACTIONS
//-----------------------------------------------------------------------------

#pragma mark AGTextTutorialAction

/** AGTextTutorialAction
 */

void AGTextTutorialAction::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
    
    m_textExtent += dt*20;
    if (m_textExtent >= m_text.size())
        m_t += dt;
}

void AGTextTutorialAction::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    Matrix4 mv = Matrix4(modelview()).translate(m_pos);
    
    int i = (int) m_textExtent;
    
    if (i < m_text.size()) {
        text->render(m_text.substr(0, i), AGStyle::foregroundColor(), mv, projection());
        
        // render last letter with fade-in
        float alpha = m_textExtent-floorf(m_textExtent);
        alpha = powf(alpha, 0.33);
        float x = text->width(m_text.substr(0, i));
        text->render(m_text.substr(i, 1), AGStyle::foregroundColor().withAlpha(alpha), mv.translate(x, 0, 0), projection());
    } else {
        text->render(m_text, AGStyle::foregroundColor(), mv, projection());
    }
}

bool AGTextTutorialAction::isCompleted() { return false; }

bool AGTextTutorialAction::canContinue()
{
    return m_t >= m_pause && m_textExtent >= m_text.size();
}

void AGTextTutorialAction::prepareInternal(AGTutorialEnvironment &environment)
{
    m_text = getParameter("text", "").getString();
    m_pos = getParameter("position", GLvertex3f()).getVertex3();
    m_pause = getParameter("pause", 0).getFloat();
    
    m_t = 0;
    m_textExtent = 0;
    
    dbgprint("showing tutorial text %s\n", m_text.c_str());
}


#pragma mark AGHideUITutorialAction

/** AGHideUITutorialAction
 */

bool AGHideUITutorialAction::isCompleted() { return true; }

bool AGHideUITutorialAction::canContinue() { return true; }

void AGHideUITutorialAction::prepareInternal(AGTutorialEnvironment &environment)
{
    int hide = getParameter("hide").getInt();
    
    if (hide)
        environment.viewController()->hideDashboard();
    else
        environment.viewController()->showDashboard();
}


#pragma mark AGDrawNodeTutorialAction

/** AGDrawNodeTutorialAction
 */

constexpr static const float CYCLE_TIME = 1.5;
constexpr static const float CYCLE_PAUSE = 0.125;
constexpr static const float FADE_TIME = 0.5;
constexpr static const float FADE_PAUSE = 0.33;
constexpr static const float TOTAL_TIME = CYCLE_TIME+CYCLE_PAUSE+FADE_TIME+FADE_PAUSE;

void AGDrawNodeTutorialAction::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
    
    m_tFig += dt;
    m_tFig = fmodf(m_tFig, TOTAL_TIME);
}

void AGDrawNodeTutorialAction::render()
{
    AGRenderObject::render();
    
    float t = min(m_tFig/CYCLE_TIME, 1.0f);
    t = easing::cubic::easeInOut(t, 0, 1, 1);
    int num = t*m_figure.size();
    
    float alpha = 1;
    if (m_tFig >= CYCLE_PAUSE) {
        alpha = max(0.0f, 1-(m_tFig-CYCLE_TIME-CYCLE_PAUSE)/FADE_TIME);
    }
    
    AGStyle::foregroundColor().withAlpha(alpha).set();
    drawLineStrip(m_figure.data(), num);
}

bool AGDrawNodeTutorialAction::canContinue() { return m_canContinue; }

bool AGDrawNodeTutorialAction::isCompleted() { return m_canContinue; }

void AGDrawNodeTutorialAction::prepareInternal(AGTutorialEnvironment &environment)
{
    GeoGen::makeCircleStroke(m_figure, 64, 62.5);
    // add original point to draw as line strip
    m_figure.push_back(m_figure[0]);
    // rotate to start at +pi/2
    for(int i = 0; i < m_figure.size(); i++) {
        m_figure[i] = rotateZ(m_figure[i], M_PI_2);
    }
    
    m_figurePos = getParameter("figurePosition", GLvertex3f()).getVertex3();
}

//-----------------------------------------------------------------------------
// CONDITIONS
//-----------------------------------------------------------------------------

#pragma mark AGDrawNodeTutorialCondition

/**
 */
AGTutorialCondition::Status AGDrawNodeTutorialCondition::getStatus()
{
    return m_status;
}

void AGDrawNodeTutorialCondition::activityOccurred(AGActivity *activity)
{
    if (activity->type() == AGActivity::DrawNodeActivityType) {
        m_status = STATUS_CONTINUE;
    }
}


#pragma mark AGCreateNodeTutorialCondition

/**
 */
AGTutorialCondition::Status AGCreateNodeTutorialCondition::getStatus()
{
    return m_status;
}

void AGCreateNodeTutorialCondition::activityOccurred(AGActivity *activity)
{
    if (activity->type() == AGActivity::CreateNodeActivityType) {
        m_status = STATUS_CONTINUE;
    }
}

#pragma mark - Helpers

AGTutorialAction *AGTutorialActions::make(AGTutorialActions::Action type, const map<std::string, Variant> &parameters)
{
    AGTutorialAction *action = nullptr;
    
    switch (type) {
        case AGTutorialActions::TEXT:
            action = new AGTextTutorialAction(parameters);
            break;
            
        case AGTutorialActions::HIDE_UI:
            action = new AGHideUITutorialAction(parameters);
            break;
            
        case AGTutorialActions::DRAW_NODE:
            action = new AGDrawNodeTutorialAction(parameters);
            break;
            
        default:
            assert(0);
            break;
    }
    
    assert(action != nullptr);
    
    action->init();
    
    return action;
}

AGTutorialCondition *AGTutorialConditions::make(AGTutorialConditions::Condition type, const map<std::string, Variant> &parameters)
{
    AGTutorialCondition *condition = nullptr;
    
    switch (type) {
        case AGTutorialConditions::DRAW_NODE:
            condition = new AGDrawNodeTutorialCondition(parameters);
            break;
            
        case AGTutorialConditions::CREATE_NODE:
            condition = new AGCreateNodeTutorialCondition(parameters);
            break;
            
        default:
            assert(0);
            break;
    }
    
    assert(condition != nullptr);
    
    return condition;
}

