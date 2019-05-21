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
#include "AGActivities.h"

#include <vector>


//-----------------------------------------------------------------------------
// ACTIONS
//-----------------------------------------------------------------------------

#pragma mark AGTextTutorialAction

/** Tutorial step that simply displays text.
 */
class AGTextTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_textExtent += dt*20;
        if (m_textExtent >= m_text.size())
            m_t += dt;
    }
    
    void render() override
    {
        TexFont *text = AGStyle::standardFont64();
        
        Matrix4 mv = Matrix4(modelview()).translate(m_position);
        
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
    
    bool isCompleted() override { return false; }
    
    bool canContinue() override
    {
        return m_t >= m_pause && m_textExtent >= m_text.size();
    }

protected:
    string m_text;
    Variant m_position;
    float m_t = 0;
    float m_pause = 0;
    float m_textExtent = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_text = getParameter("text", "").getString();
        m_position = getParameter("position", Variant(GLvertex3f()));
        m_pause = getParameter("pause", 0).getFloat();
        
        m_t = 0;
        m_textExtent = 0;
        
        dbgprint("showing tutorial text %s\n", m_text.c_str());
    }
};


#pragma mark AGHideUITutorialAction

/** AGHideUITutorialAction
 */
class AGHideUITutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    bool isCompleted() override { return true; }
    
    bool canContinue() override { return true; }
    
private:
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        int hide = getParameter("hide").getInt();
        
        if (hide)
            environment.viewController()->hideDashboard();
        else
            environment.viewController()->showDashboard();
    }
};


#pragma mark AGPointToTutorialAction

/** AGPointToTutorialAction
 */
class AGPointToTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_t += dt*m_speed;
        m_t = fmodf(m_t, ANIM_TIME+FADE_TIME+PAUSE_TIME);
    }
    
    void render() override
    {
        AGRenderObject::render();
        
        float alpha = 1;
        if (m_t > ANIM_TIME)
            alpha = std::max(0.0f, 1.0f-(m_t-ANIM_TIME)/FADE_TIME);
        AGStyle::foregroundColor().withAlpha(alpha).set();
        
        float t_line = std::min(m_t/ANIM_TIME, 1.0f);
        t_line = easing::cubic::easeInOut(t_line, 0, 1, 1);
        drawLineLoop((GLvertex3f[]){
            m_start, m_start + (m_end-m_start)*t_line
        }, 2);
        
        float lineLength = (m_end-m_start).magnitude();
        float arrowProj = cosf(ARROW_ANGLE)*ARROW_LENGTH;
        float arrowFract = (lineLength-arrowProj)/lineLength;
        float t_arrow = (t_line-arrowFract)/(1-arrowFract);
        if(t_arrow > 0)
        {
            //fprintf(stderr, "%f\n", t_line);
            float lineAngle = atan2f(m_start.y-m_end.y, m_start.x-m_end.x);
            float angleL = lineAngle+ARROW_ANGLE;
            GLvertex3f posL = m_end+GLvertex3f(cosf(angleL), sinf(angleL), 0)*ARROW_LENGTH;
            float angleR = lineAngle-ARROW_ANGLE;
            GLvertex3f posR = m_end+GLvertex3f(cosf(angleR), sinf(angleR), 0)*ARROW_LENGTH;
            drawLineLoop((GLvertex3f[]){
                posL, posL+(m_end-posL)*t_arrow
            }, 2);
            drawLineLoop((GLvertex3f[]){
                posR, posR+(m_end-posR)*t_arrow
            }, 2);
        }
    }
    
    bool canContinue() override
    {
        return true;
    }
    
    bool isCompleted() override
    {
        return false;
    }
    
protected:
    constexpr static const float ANIM_TIME = 1.0f;
    constexpr static const float FADE_TIME = 0.5f;
    constexpr static const float PAUSE_TIME = 0.5;
    
    constexpr static const float ARROW_LENGTH = 25;
    constexpr static const float ARROW_ANGLE = M_PI/5;

    std::vector<GLvertex3f> m_figure;
    GLvertex3f m_start;
    GLvertex3f m_end;
    float m_t = 0;
    float m_speed = 1;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_start = getParameter("start", GLvertex3f()).getVertex3();
        m_end = getParameter("end", GLvertex3f()).getVertex3();
        m_speed = getParameter("speed", 1).getFloat();

        m_figure.push_back(m_start);
        m_figure.push_back(m_end);
    }
};


#pragma mark AGSuggestDrawNodeTutorialAction

/** AGSuggestDrawNodeTutorialAction
 */

class AGSuggestDrawNodeTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_tFig += dt;
        m_tFig = fmodf(m_tFig, TOTAL_TIME);
    }
    
    void render() override
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
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return m_canContinue; }
    
protected:
    constexpr static const float CYCLE_TIME = 1.5;
    constexpr static const float CYCLE_PAUSE = 0.125;
    constexpr static const float FADE_TIME = 0.5;
    constexpr static const float FADE_PAUSE = 0.33;
    constexpr static const float TOTAL_TIME = CYCLE_TIME+CYCLE_PAUSE+FADE_TIME+FADE_PAUSE;
    
    std::vector<GLvertex3f> m_figure;
    bool m_canContinue = false;
    GLvertex3f m_figurePos;
    float m_tFig = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
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
};


#pragma mark AGCreateNodeTutorialAction

/** AGCreateNodeTutorialAction
 */

class AGCreateNodeTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        if (m_t < m_pause)
            m_canContinue = true;
        else
            m_t += dt;
    }
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return m_canContinue; }
    
protected:
    
    bool m_canContinue = false;
    GLvertex3f m_figurePos;
    float m_t = 0;
    float m_pause = 0;

    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_pause = getParameter("pause", 0);
        
        // create the node
        AGDocument::Node::Class nodeClass = (AGDocument::Node::Class) getParameter("class", AGDocument::Node::AUDIO).getInt();
        std::string type = getParameter("type", "").getString();
        GLvertex3f position = getParameter("position", GLvertex3f()).getVertex3();

        if(type.length()) {
            AGNode *node = AGNodeManager::nodeManagerForClass(nodeClass).createNodeOfType(type, position);
            // animate in
            node->unhide();
            AGGraphManager::instance().addNodeToTopLevel(node);
            if(type == "Output") {
                AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
                outputNode->setOutputDestination(AGAudioManager_::instance().masterOut());
            }
            
            // store the uuid if desired
            std::string saveUUID = getParameter("uuid>");
            if(saveUUID.length())
                environment.store(saveUUID, node->uuid());
        }
    }
};



//-----------------------------------------------------------------------------
// CONDITIONS
//-----------------------------------------------------------------------------

#pragma mark AGDrawNodeTutorialCondition

/** AGDrawNodeTutorialCondition
 */
class AGDrawNodeTutorialCondition : public AGTutorialCondition
{
public:
    
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::DrawNodeActivityType) {
            auto drawNodeActivity = dynamic_cast<AG::Activities::DrawNode *>(activity);
            
            if(drawNodeActivity != nullptr) {
                m_nodePosition = drawNodeActivity->position;
                
                if(m_matchAnyFigure || drawNodeActivity->figure == m_figure) {
                    m_status = STATUS_CONTINUE;
                }
            }
        }
    }

private:
    Status m_status = STATUS_INCOMPLETE;
    GLvertex3f m_nodePosition = GLvertex3f();
    
    bool m_matchAnyFigure = false;
    AGHandwritingRecognizerFigure m_figure = AG_FIGURE_NONE;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        if(hasParameter("figure")) {
            m_figure = (AGHandwritingRecognizerFigure) getParameter("figure", (int) AG_FIGURE_NONE).getInt();
            m_matchAnyFigure = false;
        } else {
            m_matchAnyFigure = true;
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        std::string savePosition = getParameter("position>");
        if(savePosition.length())
            environment.store(savePosition, m_nodePosition);
    }
};


#pragma mark AGCreateNodeTutorialCondition

/** AGCreateNodeTutorialCondition
 */
class AGCreateNodeTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::CreateNodeActivityType) {
            auto createNodeActivity = dynamic_cast<AG::Activities::CreateNode *>(activity);
            
            if(m_matchAnyType || createNodeActivity->serializedNode.type == m_type) {
                m_status = STATUS_CONTINUE;
                m_nodeUUID = createNodeActivity->serializedNode.uuid;
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAnyType = false;
    std::string m_type = "";
    std::string m_nodeUUID = "";
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        if(hasParameter("node_type")) {
            m_type = getParameter("node_type").getString();
            m_matchAnyType = false;
        } else {
            m_matchAnyType = true;
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        if(m_status == STATUS_CONTINUE) {
            std::string saveUUID = getParameter("uuid>");
            if(saveUUID.length())
                environment.store(saveUUID, m_nodeUUID);
        }
    }
};


#pragma mark AGCreateConnectionTutorialCondition

/** AGCreateConnectionTutorialCondition
 */
class AGCreateConnectionTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::CreateConnectionActivityType) {
            auto createConnectionActivity = dynamic_cast<AG::Activities::CreateConnection *>(activity);
            
            if(m_matchAnyType ||
               (createConnectionActivity->serializedConnection.srcUuid == getParameter("src_uuid") &&
                createConnectionActivity->serializedConnection.dstUuid == getParameter("dst_uuid"))) {
                   m_status = STATUS_CONTINUE;
               }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAnyType = false;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        if(hasParameter("src_uuid") && hasParameter("dst_uuid")) {
            m_matchAnyType = false;
        } else {
            m_matchAnyType = true;
        }
    }
};


#pragma mark AGOpenNodeEditorTutorialCondition

/** AGOpenNodeEditorTutorialCondition
 */
class AGOpenNodeEditorTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::OpenNodeEditorActivityType) {
            auto openNodeEditorActivity = dynamic_cast<AG::Activities::OpenNodeEditor *>(activity);
            
            if(m_matchAny || openNodeEditorActivity->nodeUUID == getParameter("uuid")) {
                m_status = STATUS_CONTINUE;
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAny = false;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_matchAny = !hasParameter("uuid");
    }
};

#pragma mark AGEditNodeTutorialCondition

/** AGEditNodeTutorialCondition
 */
class AGEditNodeTutorialCondition : public AGTutorialCondition
{
public:
    using AGTutorialCondition::AGTutorialCondition;
    
    AGTutorialCondition::Status getStatus() override
    {
        return m_status;
    }
    
    void activityOccurred(AGActivity *activity) override
    {
        if (activity->type() == AGActivity::EditParamActivityType) {
            auto openNodeEditorActivity = dynamic_cast<AG::Activities::EditParam *>(activity);
            
            if(m_matchAny || openNodeEditorActivity->nodeUUID == getParameter("uuid")) {
                m_status = STATUS_CONTINUE;
            }
        }
    }
    
private:
    Status m_status = STATUS_INCOMPLETE;
    
    bool m_matchAny = false;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_matchAny = !hasParameter("uuid");
    }
};


#pragma mark - Helpers

AGTutorialAction *AGTutorialActions::make(AGTutorialActions::Action type, const map<std::string, Variant> &parameters)
{
    AGTutorialAction *action = nullptr;
    
    switch (type) {
        case AGTutorialActions::TEXT: action = new AGTextTutorialAction(parameters);
            break;
        case AGTutorialActions::POINT_TO: action = new AGPointToTutorialAction(parameters);
            break;
        case AGTutorialActions::HIDE_UI: action = new AGHideUITutorialAction(parameters);
            break;
        case AGTutorialActions::SUGGEST_DRAW_NODE: action = new AGSuggestDrawNodeTutorialAction(parameters);
            break;
        case AGTutorialActions::CREATE_NODE: action = new AGCreateNodeTutorialAction(parameters);
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
        case AGTutorialConditions::CREATE_CONNECTION:
            condition = new AGCreateConnectionTutorialCondition(parameters);
            break;
        case AGTutorialConditions::OPEN_NODE_EDITOR:
            condition = new AGOpenNodeEditorTutorialCondition(parameters);
            break;
        case AGTutorialConditions::EDIT_NODE:
            condition = new AGEditNodeTutorialCondition(parameters);
            break;
        default:
            assert(0);
            break;
    }
    
    assert(condition != nullptr);
    
    return condition;
}

