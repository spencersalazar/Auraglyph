//
//  AGTutorialActions.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 2/4/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

#include "AGTutorialActions.h"

// for rendering
#include "Geometry.h"
#include "TexFont.h"
#include "Matrix.h"
#include "AGStyle.h"
#include "GeoGenerator.h"

// for hide/show graph
#include "AGNode.h"
#include "AGModel.h"
#include "AGGraph.h"

// for creating new nodes and adding to model/renderModel
#include "AGGraphManager.h"
// for connecting to audio output
#include "AGAudioManager.h"

// for searching node selectors
// for searching node editors
#include "AGRenderModel.h"

// for hide/show UI
#include "AGDashboard.h"

#include <vector>


constexpr static const float DEBUG_TEXT_SPEED_FACTOR = 1.25;


//-----------------------------------------------------------------------------
// ACTIONS
//-----------------------------------------------------------------------------
#pragma mark - ---ACTIONS---

/** Tutorial step that simply displays text.
 */
class AGTextTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        dt *= DEBUG_TEXT_SPEED_FACTOR;
        
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
            environment.renderModel().uiDashboard->hide();
        else
            environment.renderModel().uiDashboard->unhide();
    }
};

/** AGHideGraphTutorialAction
 */
class AGHideGraphTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    bool isCompleted() override { return true; }
    
    bool canContinue() override { return true; }
    
private:
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        int hide = getParameter("hide").getInt();
        environment.model().hide(hide);
    }
};


#include "AGUINodeEditor.h"

/** AGCloseEditorsTutorialAction
 */
class AGCloseEditorsTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    bool isCompleted() override { return true; }
    
    bool canContinue() override { return true; }
    
private:
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        // store editors in list and delete them after the loop
        // (deleting within the loop
        std::list<AGUINodeEditor*> editors;
        for (auto object : environment.renderModel().objects) {
            auto editor = dynamic_cast<AGUINodeEditor*>(object);
            if (editor) {
                editors.push_back(editor);
            }
        }
        
        for (auto editor : editors) {
            editor->removeFromTopLevel();
        }
    }
};


/** AGPointToTutorialAction
 */
class AGPointToTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_start = getParameter("start", GLvertex3f()).getVertex3();
        m_end = getParameter("end", GLvertex3f()).getVertex3();
        
        m_t += dt*m_speed;
        m_t = fmodf(m_t, ANIM_TIME+FADE_TIME+PAUSE_TIME);
    }
    
    void render() override
    {
        AGRenderObject::render();
        
        // determine overall alpha
        float alpha = 1;
        if (m_t > ANIM_TIME)
            // clamp
            alpha = std::max(0.0f, 1.0f-(m_t-ANIM_TIME)/FADE_TIME);
        AGStyle::foregroundColor().withAlpha(alpha).set();
        
        // draw line part
        // fraction of line that is visible
        float t_line = std::min(m_t/ANIM_TIME, 1.0f);
        // ease
        t_line = easeInOut(t_line);
        // draw
        drawLineLoop((GLvertex3f[]){
            m_start, m_start + (m_end-m_start)*t_line
        }, 2);
        
        // draw arrow part
        // overall length of line
        float lineLength = (m_end-m_start).magnitude();
        // length of projection of arrow onto line
        float arrowProj = cosf(ARROW_ANGLE)*ARROW_LENGTH;
        // fraction of line occupied by the arrow projection
        float arrowFract = (lineLength-arrowProj)/lineLength;
        // fraction [0,1] of arrow that is visible
        float t_arrow = (t_line-arrowFract)/(1-arrowFract);
        if(t_arrow > 0)
        {
            //fprintf(stderr, "%f\n", t_line);
            // angle of line at endpoint
            float lineAngle = atan2f(m_start.y-m_end.y, m_start.x-m_end.x);
            // angle of left arrow flank
            float angleL = lineAngle+ARROW_ANGLE;
            // position of left arrow end
            GLvertex3f posL = m_end+GLvertex3f(cosf(angleL), sinf(angleL), 0)*ARROW_LENGTH;
            // angle of right arrow flank
            float angleR = lineAngle-ARROW_ANGLE;
            // position of right arrow end
            GLvertex3f posR = m_end+GLvertex3f(cosf(angleR), sinf(angleR), 0)*ARROW_LENGTH;
            // draw
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

    GLvertex3f m_start;
    GLvertex3f m_end;
    float m_t = 0;
    float m_speed = 1;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_start = getParameter("start", GLvertex3f()).getVertex3();
        m_end = getParameter("end", GLvertex3f()).getVertex3();
        m_speed = getParameter("speed", 1).getFloat();
    }
};


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
        t = easeInOut(t);
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


/** AGBlinkNodeSelectorTutorialAction
 */

#include "AGNodeSelector.h"

class AGBlinkNodeSelectorTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        if (m_t > m_pause)
            m_canContinue = true;
        else
            m_t += dt;
    }
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return false; }
    
protected:
    
    bool m_canContinue = false;
    float m_t = 0;
    float m_pause = 0;
    
    AGUIMetaNodeSelector* m_nodeSelector = nullptr;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_pause = getParameter("pause", 0);
        int item = getParameter("item", 0);
        
        for (auto object : environment.renderModel().objects) {
            auto nodeSelector = dynamic_cast<AGUIMetaNodeSelector*>(object);
            if (nodeSelector) {
                m_nodeSelector = nodeSelector;
                m_nodeSelector->blink(true, item);
                break;
            }
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        int item = getParameter("item", 0);
        
        for (auto object : environment.renderModel().objects) {
            auto nodeSelector = dynamic_cast<AGUIMetaNodeSelector*>(object);
            if (nodeSelector && nodeSelector == m_nodeSelector) {
                m_nodeSelector = nodeSelector;
                m_nodeSelector->blink(true, item);
                break;
            }
        }
    }
};


/** AGBlinkNodeEditorTutorialAction
 */

#include "AGUINodeEditor.h"

class AGBlinkNodeEditorTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        if (m_t > m_pause)
            m_canContinue = true;
        else
            m_t += dt;
    }
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return false; }
    
protected:
    
    bool m_canContinue = false;
    float m_t = 0;
    float m_pause = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_pause = getParameter("pause", 0);
        std::string uuid = getParameter("uuid", 0);
        int item = getParameter("item", 0);
        
        AGRenderModel& renderModel = environment.renderModel();
        for (auto object : renderModel.objects) {
            AGUIStandardNodeEditor* editor = dynamic_cast<AGUIStandardNodeEditor*>(object);
            if (editor && editor->node()->uuid() == uuid) {
                dbgprint("blinking node editor item %s:%i\n", uuid.c_str(), item);
                editor->blink(item);
                break;
            }
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        std::string uuid = getParameter("uuid", 0);
        int item = getParameter("item", 0);
        
        AGRenderModel& renderModel = environment.renderModel();
        for (auto object : renderModel.objects) {
            AGUIStandardNodeEditor* editor = dynamic_cast<AGUIStandardNodeEditor*>(object);
            if (editor && editor->node()->uuid() == uuid) {
                editor->blink(item, false);
                break;
            }
        }
    }
};


/** AGBlinkDashboardTutorialAction
 */

#include "AGMenu.h"

class AGBlinkDashboardTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        if (m_t > m_pause)
            m_canContinue = true;
        else
            m_t += dt;
    }
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return false; }
    
protected:
    
    bool m_canContinue = false;
    float m_t = 0;
    float m_pause = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_pause = getParameter("pause", 0);
        std::string item = getParameter("item", 0);
        int enable = getParameter("enable", 1);

        AGDashboard* dashboard = environment.renderModel().uiDashboard;
        // file, edit, settings, node, freedraw, eraser, trash
        if (item == "file") {
            dashboard->fileMenu()->blink(enable);
        } else if (item == "edit") {
            dashboard->editMenu()->blink(enable);
        } else if (item == "settings") {
            dashboard->settingsMenu()->blink(enable);
        } else if (item == "node") {
            dashboard->nodeModeButton()->blink(enable);
        } else if (item == "freedraw") {
            dashboard->freedrawModeButton()->blink(enable);
        } else if (item == "eraser") {
            dashboard->eraseModeButton()->blink(enable);
        }
    }
    
    void finalizeInternal(AGTutorialEnvironment &environment) override
    {
        std::string uuid = getParameter("uuid", 0);
        std::string item = getParameter("item", 0);
        int enable = getParameter("enable", 1);
        
        // disable if this action originally enabled it
        if (enable) {
            AGDashboard* dashboard = environment.renderModel().uiDashboard;
            // file, edit, settings, node, freedraw, eraser, trash
            if (item == "file") {
                dashboard->fileMenu()->blink(false);
            } else if (item == "edit") {
                dashboard->editMenu()->blink(false);
            } else if (item == "settings") {
                dashboard->settingsMenu()->blink(false);
            } else if (item == "node") {
                dashboard->nodeModeButton()->blink(false);
            } else if (item == "freedraw") {
                dashboard->freedrawModeButton()->blink(false);
            } else if (item == "eraser") {
                dashboard->eraseModeButton()->blink(false);
            }
        }
    }
};


/** AGCreateNodeTutorialAction
 */

class AGCreateNodeTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        if (m_t > m_pause)
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
            
            environment.model().addNode(node);
            environment.renderModel().objects.push_back(node);
            
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


/** AGSelectToolTutorialAction
 */

#include "AGViewController.h" // for AGDrawMode
#include "AGBaseTouchHandler.h"

class AGSelectToolTutorialAction : public AGTutorialAction
{
public:
    using AGTutorialAction::AGTutorialAction;
    
    void update(float t, float dt) override
    {
        if (m_t > m_pause) {
            m_canContinue = true;
        } else {
            m_t += dt;
        }
    }
    
    bool canContinue() override { return m_canContinue; }
    
    bool isCompleted() override { return m_canContinue; }
    
protected:
    
    bool m_canContinue = false;
    float m_t = 0;
    float m_pause = 0;
    
    void prepareInternal(AGTutorialEnvironment &environment) override
    {
        m_pause = getParameter("pause", 0);
        
        // select the tool
        std::string tool = getParameter("tool").getString();
        
        if(tool == "node") {
            environment.interactionModel().setDrawMode(DRAWMODE_NODE);
        } else if (tool == "freedraw") {
            environment.interactionModel().setDrawMode(DRAWMODE_FREEDRAW);
        } else if (tool == "eraser") {
            environment.interactionModel().setDrawMode(DRAWMODE_FREEDRAW_ERASE);
        }
    }
};


AGTutorialAction *AGTutorialActions::make(AGTutorialActions::Action type, const map<std::string, Variant> &parameters)
{
    AGTutorialAction *action = nullptr;
    
    switch (type) {
        case AGTutorialActions::TEXT:
            action = new AGTextTutorialAction(parameters);
            break;
        case AGTutorialActions::POINT_TO:
            action = new AGPointToTutorialAction(parameters);
            break;
        case AGTutorialActions::HIDE_UI:
            action = new AGHideUITutorialAction(parameters);
            break;
        case AGTutorialActions::HIDE_GRAPH:
            action = new AGHideGraphTutorialAction(parameters);
            break;
        case AGTutorialActions::SELECT_TOOL:
            action = new AGSelectToolTutorialAction(parameters);
            break;
        case AGTutorialActions::CLOSE_EDITORS:
            action = new AGCloseEditorsTutorialAction(parameters);
            break;
        case AGTutorialActions::SUGGEST_DRAW_NODE:
            action = new AGSuggestDrawNodeTutorialAction(parameters);
            break;
        case AGTutorialActions::CREATE_NODE:
            action = new AGCreateNodeTutorialAction(parameters);
            break;
        case AGTutorialActions::BLINK_NODE_SELECTOR:
            action = new AGBlinkNodeSelectorTutorialAction(parameters);
            break;
        case AGTutorialActions::BLINK_NODE_EDITOR:
            action = new AGBlinkNodeEditorTutorialAction(parameters);
            break;
        case AGTutorialActions::BLINK_DASHBOARD:
            action = new AGBlinkDashboardTutorialAction(parameters);
            break;
        default:
            assert(0);
            break;
    }
    
    assert(action != nullptr);
    
    action->init();
    
    return action;
}

