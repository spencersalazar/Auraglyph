//
//  AGNodeSelector.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/4/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGNodeSelector.h"
#include "AGAudioNode.h"
#include "AGControlNode.h"
#include "AGInputNode.h"
#include "AGOutputNode.h"
#include "AGControlNode.h"
#include "AGStyle.h"
#include "AGGenericShader.h"

static const float AGNODESELECTOR_RADIUS = 0.02*AGStyle::oldGlobalScale;

std::list<AGUIMetaNodeSelector*> AGUIMetaNodeSelector::s_nodeSelectors;

template<class NodeType, class ManagerType>
class AGUINodeSelector : public AGUIMetaNodeSelector
{
public:
    AGUINodeSelector(const ManagerType &manager, const GLvertex3f &pos);
    AGUINodeSelector(const GLvertex3f &pos);
    virtual ~AGUINodeSelector();
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    virtual void touchDown(const GLvertex3f &t) override;
    virtual void touchMove(const GLvertex3f &t) override;
    virtual void touchUp(const GLvertex3f &t) override;
    
    virtual AGNode *createNode() override;
    
    virtual bool done() override { return m_done; }
    
    GLvrectf effectiveBounds() override
    {
        return GLvrectf(m_pos-GLvertex2f(m_radius, m_radius), m_pos+GLvertex2f(m_radius, m_radius));
    }
    
    virtual void blink(bool enable, int item = -1) override
    {
        if (enable) {
            m_blinkItem = item;
            m_itemBlink.reset();
        } else {
            m_blinkItem = -1;
        }
    }
    
    virtual void renderOut() override;
    virtual bool finishedRenderingOut() const override;
    
private:
    const ManagerType &m_manager;
    
    GLvertex3f m_geo[4];
    float m_radius;
    GLuint m_geoSize;
    
    momentum<float, clampf> m_verticalScrollPos;
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    NodeType *m_node;
    
    int m_hit;
    GLvertex3f m_touchStart;
    GLvertex3f m_lastTouch;
    bool m_done;
    
    powcurvef m_itemBlink;
    int m_blinkItem = -1;
};


AGUIMetaNodeSelector *AGUIMetaNodeSelector::audioNodeSelector(const GLvertex3f &pos)
{
    AGUIMetaNodeSelector *nodeSelector = new AGUINodeSelector<AGAudioNode, AGNodeManager>(AGNodeManager::audioNodeManager(), pos);
    nodeSelector->init();
    return nodeSelector;
}

AGUIMetaNodeSelector *AGUIMetaNodeSelector::controlNodeSelector(const GLvertex3f &pos)
{
    AGUIMetaNodeSelector *nodeSelector = new AGUINodeSelector<AGControlNode, AGNodeManager>(AGNodeManager::controlNodeManager(), pos);
    nodeSelector->init();
    return nodeSelector;
}

AGUIMetaNodeSelector *AGUIMetaNodeSelector::inputNodeSelector(const GLvertex3f &pos)
{
    AGUIMetaNodeSelector *nodeSelector = new AGUINodeSelector<AGInputNode, AGNodeManager>(AGNodeManager::inputNodeManager(), pos);
    nodeSelector->init();
    return nodeSelector;
}

AGUIMetaNodeSelector *AGUIMetaNodeSelector::outputNodeSelector(const GLvertex3f &pos)
{
    AGUIMetaNodeSelector *nodeSelector = new AGUINodeSelector<AGOutputNode, AGNodeManager>(AGNodeManager::outputNodeManager(), pos);
    nodeSelector->init();
    return nodeSelector;
}


//------------------------------------------------------------------------------
// ### AGUINodeSelector ###
//------------------------------------------------------------------------------
#pragma mark - AGUINodeSelector

template<class NodeType, class ManagerType>
AGUINodeSelector<NodeType, ManagerType>::AGUINodeSelector(const ManagerType &manager, const GLvertex3f &pos) :
AGUIMetaNodeSelector(pos),
m_node(new NodeType(AGNodeManifest::defaultManifest(), pos)),
m_hit(-1),
m_done(false),
m_manager(manager),
m_itemBlink(powcurvef(1, 0, 1.1, 0.75))
{
    m_node->init();
    
    setPosition(pos);
    
    m_geoSize = 4;
    
    m_radius = AGNODESELECTOR_RADIUS;
    
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[0] = GLvertex3f(-m_radius, m_radius, 0);
    m_geo[1] = GLvertex3f(-m_radius, -m_radius, 0);
    m_geo[2] = GLvertex3f(m_radius, -m_radius, 0);
    m_geo[3] = GLvertex3f(m_radius, m_radius, 0);
    
    unsigned long nTypes = m_manager.nodeTypes().size();
    m_verticalScrollPos.raw().clampTo(0, max(ceilf(nTypes/2.0f-2)*m_radius,0.0f));
    m_verticalScrollPos.setLoss(0.5);
    m_verticalScrollPos.setDrag(0.1);
    
    m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
    m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
    //    NSLog(@"scrollMax: %f", m_verticalScrollPos.max);
    
    s_nodeSelectors.push_back(this);
}

template<class NodeType, class ManagerType>
AGUINodeSelector<NodeType, ManagerType>::~AGUINodeSelector()
{
    dbgprint_off("AGUINodeSelector::~AGUINodeSelector()");
    SAFE_DELETE(m_node);
    
    s_nodeSelectors.remove(this);
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::update(float t, float dt)
{
    m_verticalScrollPos.update(t, dt);
    
    m_itemBlink.update(dt);
    if (m_itemBlink.isFinished()) {
        m_itemBlink.reset();
    }
    
    Matrix4 modelview = AGNode::globalModelViewMatrix();
    Matrix4 projection = AGNode::projectionMatrix();
    
    modelview = modelview.translate(m_pos.x, m_pos.y, m_pos.z);
    
    if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
    if(m_xScale >= 0.99f) m_yScale.update(dt);
    
    modelview = modelview.scale(m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                1);
    
    m_node->update(t, dt);
    
    // todo: fix this
    // for AGRenderObject functions
    m_renderState.modelview = modelview;
    m_renderState.projection = projection;
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::render()
{
    glDisable(GL_TEXTURE_2D);
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    /* draw blank audio node */
    m_node->render();
    
    /* draw bounding box */
    
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(m_renderState.modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glDisableVertexAttribArray(AGVertexAttribColor);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    glDisableVertexAttribArray(AGVertexAttribTexCoord0);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    
    // fill
    AGStyle::frameBackgroundColor().withAlpha(0.75).set();
    glDrawArrays(GL_TRIANGLE_FAN, 0, m_geoSize);
    
    // stroke
    AGStyle::foregroundColor().set();
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, m_geoSize);
    
    /* draw scroll bar */
    unsigned long nTypes = m_manager.nodeTypes().size();
    if(nTypes > 4)
    {
        float scroll_bar_margin = 0.95;
        // maximum distance that can be scrolled
        float scroll_max_scroll = ceilf(nTypes/2.0f-2)*m_radius;
        // height of the scroll bar tray area
        float scroll_bar_tray_height = m_radius*2*scroll_bar_margin;
        // percent of the total scroll area that is visible * tray height
        float scroll_bar_height = scroll_bar_tray_height/ceilf(nTypes/2.0f-1);
        // percent of scroll position * (tray height - bar height)
        float scroll_bar_y = m_verticalScrollPos/scroll_max_scroll*(scroll_bar_tray_height-scroll_bar_height);
        
        GLvertex3f scroll_bar_geo[2];
        scroll_bar_geo[0] = GLvertex2f(m_radius*scroll_bar_margin, m_radius*scroll_bar_margin-scroll_bar_y);
        scroll_bar_geo[1] = GLvertex2f(m_radius*scroll_bar_margin, m_radius*scroll_bar_margin-(scroll_bar_y+scroll_bar_height));
        
        // load it up and draw
        AGStyle::foregroundColor().set();
        glLineWidth(1.0);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), scroll_bar_geo);
        glDrawArrays(GL_LINES, 0, 2);
    }
    
    /* draw node types */
    
    AGClipShader &clipShader = AGClipShader::instance();
    
    clipShader.useProgram();
    
    clipShader.setModelViewMatrix(m_renderState.modelview);
    clipShader.setProjectionMatrix(m_renderState.projection);
    clipShader.setClip(GLvertex2f(-m_radius, -m_radius), GLvertex2f(m_radius*2, m_radius*2));
    clipShader.setLocalMatrix(Matrix4::identity);
    
    //    GLvertex3f startPos(-m_radius/2, -m_radius/2, 0);
    GLvertex3f startPos(-m_radius/2, m_radius/2 + m_verticalScrollPos, 0);
    GLvertex3f xInc(m_radius, 0, 0);
    GLvertex3f yInc(0, -m_radius, 0);
    
    for(int i = 0; i < m_manager.nodeTypes().size(); i++)
    {
        GLvertex3f iconPos = startPos + (xInc*(i%2)) + (yInc*(i/2));
        
        Matrix4 modelView = m_renderState.modelview;
        modelView = modelView.translate(iconPos.x, iconPos.y, iconPos.z);
        
        if(i == m_hit) {
            // draw highlight background
            Matrix4 hitMat = Matrix4::makeTranslation(iconPos.x, iconPos.y, iconPos.z).scale(0.5f);
            clipShader.setLocalMatrix(hitMat);
            AGStyle::foregroundColor().withAlpha(0.75f).set();
            
            drawTriangleFan(clipShader, m_geo, 4, hitMat);
            
            AGStyle::frameBackgroundColor().set();
        } else if(i == m_blinkItem) {
            float blink = m_itemBlink;
            
            Matrix4 blinkMat = Matrix4::makeTranslation(iconPos.x, iconPos.y, iconPos.z).scale(0.45f);
            clipShader.setLocalMatrix(blinkMat);
            
            AGStyle::foregroundColor().withAlpha(blink).set();
            
            drawTriangleFan(clipShader, m_geo, m_geoSize, blinkMat);
            
            float alpha = easeInOut(blink, 3.25f, 0.3f);
            auto fgColor = AGStyle::foregroundColor();
            auto bgColor = AGStyle::frameBackgroundColor();
            fgColor.alphaBlend(bgColor, alpha).set();
            
        } else {
            AGStyle::foregroundColor().set();
        }
        
        clipShader.setModelViewMatrix(modelView);
        clipShader.setLocalMatrix(Matrix4::makeTranslation(iconPos.x, iconPos.y, iconPos.z));
        
        glLineWidth(4.0f);
        m_manager.renderNodeTypeIcon(m_manager.nodeTypes()[i]);
    }
    
    if (m_blinkItem >= 0) {
        // check if blink item is off screen
        GLvertex3f iconPos = startPos + (xInc*(m_blinkItem%2)) + (yInc*(m_blinkItem/2));
        bool blinkTop = false, blinkBottom = false;
        if (iconPos.y-m_radius/2*0.9 > m_radius) {
            blinkTop = true;
        } else if (iconPos.y+m_radius/2*0.9 < -m_radius) {
            blinkBottom = true;
        }
        
        if (blinkTop || blinkBottom) {
            float marginY = 0.9f;
            float marginX = 0.95f;
            GLvertex2f blinkStart {
                m_blinkItem%2 == 0 ? -m_radius*marginX : m_radius*(1-marginX),
                blinkTop ? m_radius*marginY : -m_radius*marginY,
            };
            GLvertex2f blinkStop {
                m_blinkItem%2 == 0 ? -m_radius*(1-marginX) : m_radius*marginX,
                blinkTop ? m_radius : -m_radius,
            };
            
            GLvrectf blinkBox { blinkStart, blinkStop };

            AGStyle::foregroundColor().withAlpha(m_itemBlink).set();
            
            glLineWidth(4.0f);
            clipShader.setLocalMatrix(Matrix4::identity);
            drawTriangleFan(clipShader, (GLvertex3f*) &blinkBox, 4, Matrix4::identity);
        }
    }
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::touchDown(const GLvertex3f &t)
{
    m_touchStart = t;
    m_hit = -1;
    
    // check if in entire bounds
    if(pointInRectangle(t.xy(), m_pos.xy()-GLvertex2f(m_radius, m_radius), m_pos.xy()+GLvertex2f(m_radius, m_radius)))
    {
        GLvertex3f startPos = m_pos + GLvertex3f(-m_radius/2, m_radius/2 + m_verticalScrollPos, 0);
        GLvertex3f xInc(m_radius, 0, 0);
        GLvertex3f yInc(0, -m_radius, 0);
        float iconRadius = m_radius/2;
        
        for(int i = 0; i < m_manager.nodeTypes().size(); i++)
        {
            GLvertex3f iconPos = startPos + (xInc*(i%2)) + (yInc*(i/2));
            
            if(t.x > iconPos.x-iconRadius && t.x < iconPos.x+iconRadius &&
               t.y > iconPos.y-iconRadius && t.y < iconPos.y+iconRadius)
            {
                m_hit = i;
                m_done = true;
                break;
            }
        }
    }
    
    m_lastTouch = t;
    m_verticalScrollPos.on();
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::touchMove(const GLvertex3f &t)
{
    float maxTravel = m_radius*0.05;
    
    if((t - m_touchStart).magnitudeSquared() > maxTravel*maxTravel)
    {
        // start scrolling
        m_verticalScrollPos += (t.y - m_lastTouch.y);
        m_hit = -1;
        
        if (m_hit == m_blinkItem) {
            // reset blink curve
            m_itemBlink.reset();
        }
        
        m_done = false;
    }
    
    m_lastTouch = t;
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::touchUp(const GLvertex3f &t)
{
    if(pointInRectangle(t.xy(), m_pos.xy()-GLvertex2f(m_radius, m_radius), m_pos.xy()+GLvertex2f(m_radius, m_radius)))
    {
        //
    }
    else if(!pointInRectangle(m_touchStart.xy(), m_pos.xy()-GLvertex2f(m_radius, m_radius), m_pos.xy()+GLvertex2f(m_radius, m_radius)))
    {
        m_done = true;
    }
    
    m_verticalScrollPos.off();
}

template<class NodeType, class ManagerType>
AGNode *AGUINodeSelector<NodeType, ManagerType>::createNode()
{
    if(m_hit >= 0)
    {
        return m_manager.createNodeType(m_manager.nodeTypes()[m_hit], m_pos);
    }
    else
    {
        return NULL;
    }
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::renderOut()
{
    m_node->renderOut();
    m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
    m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
}

template<class NodeType, class ManagerType>
bool AGUINodeSelector<NodeType, ManagerType>::finishedRenderingOut() const
{
    return m_xScale <= AGStyle::open_squeezeHeight;
//    return true;
}


