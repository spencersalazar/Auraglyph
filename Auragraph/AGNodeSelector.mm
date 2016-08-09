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
#include "AGStyle.h"
#include "AGGenericShader.h"

static const float AGNODESELECTOR_RADIUS = 0.02*AGStyle::globalScale;


template<class NodeType, class ManagerType>
class AGUINodeSelector : public AGUIMetaNodeSelector
{
public:
    AGUINodeSelector(const ManagerType &manager, const GLvertex3f &pos);
    AGUINodeSelector(const GLvertex3f &pos);
    virtual ~AGUINodeSelector();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGNode *createNode();
    
    virtual bool done() { return m_done; }
    
    virtual void renderOut();
    virtual bool finishedRenderingOut();
    
private:
    const ManagerType &m_manager;
    
    GLvertex3f m_geo[4];
    float m_radius;
    GLuint m_geoSize;
    
    GLvertex3f m_pos;
    clampf m_verticalScrollPos;
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix4 m_modelView;
    GLKMatrix3 m_normalMatrix;
    
    NodeType *m_node;
    
    int m_hit;
    GLvertex3f m_touchStart;
    GLvertex3f m_lastTouch;
    bool m_done;
};


AGUIMetaNodeSelector *AGUIMetaNodeSelector::audioNodeSelector(const GLvertex3f &pos)
{
    return new AGUINodeSelector<AGAudioNode, AGAudioNodeManager>(AGAudioNodeManager::instance(), pos);
}

AGUIMetaNodeSelector *AGUIMetaNodeSelector::controlNodeSelector(const GLvertex3f &pos)
{
    return new AGUINodeSelector<AGControlNode, AGControlNodeManager>(AGControlNodeManager::instance(), pos);
}

AGUIMetaNodeSelector *AGUIMetaNodeSelector::inputNodeSelector(const GLvertex3f &pos)
{
    return new AGUINodeSelector<AGInputNode, AGNodeManager>(AGNodeManager::inputNodeManager(), pos);
}

AGUIMetaNodeSelector *AGUIMetaNodeSelector::outputNodeSelector(const GLvertex3f &pos)
{
    return new AGUINodeSelector<AGOutputNode, AGNodeManager>(AGNodeManager::outputNodeManager(), pos);
}


//------------------------------------------------------------------------------
// ### AGUINodeSelector ###
//------------------------------------------------------------------------------
#pragma mark - AGUINodeSelector

template<class NodeType, class ManagerType>
AGUINodeSelector<NodeType, ManagerType>::AGUINodeSelector(const ManagerType &manager, const GLvertex3f &pos) :
AGUIMetaNodeSelector(pos),
m_pos(pos),
m_node(new NodeType(pos)),
m_hit(-1),
m_done(false),
m_manager(manager)
{
    m_geoSize = 4;
    
    m_radius = AGNODESELECTOR_RADIUS;
    
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[0] = GLvertex3f(-m_radius, m_radius, 0);
    m_geo[1] = GLvertex3f(-m_radius, -m_radius, 0);
    m_geo[2] = GLvertex3f(m_radius, -m_radius, 0);
    m_geo[3] = GLvertex3f(m_radius, m_radius, 0);
    
    int nTypes = m_manager.nodeTypes().size();
//    m_verticalScrollPos.clamp(0, ceilf(nTypes/2.0f-2)*m_radius);
//    int nTypes = ManagerType::instance().nodeTypes().size();
    m_verticalScrollPos.clampTo(0, ceilf(nTypes/2.0f-2)*m_radius);
    
    m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
    m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
    //    NSLog(@"scrollMax: %f", m_verticalScrollPos.max);
}

template<class NodeType, class ManagerType>
AGUINodeSelector<NodeType, ManagerType>::~AGUINodeSelector()
{
    SAFE_DELETE(m_node);
}

template<class NodeType, class ManagerType>
void AGUINodeSelector<NodeType, ManagerType>::update(float t, float dt)
{
    m_modelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    m_modelView = GLKMatrix4Translate(m_modelView, m_pos.x, m_pos.y, m_pos.z);
    
    if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
    if(m_xScale >= 0.99f) m_yScale.update(dt);
    
    m_modelView = GLKMatrix4Scale(m_modelView,
                                  m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                  m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                  1);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, m_modelView);
    
    m_node->update(t, dt);
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
    
    AGClipShader &shader = AGClipShader::instance();
    
    shader.useProgram();
    
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    shader.setClip(GLvertex2f(-m_radius, -m_radius), GLvertex2f(m_radius*2, m_radius*2));
    shader.setLocalMatrix(GLKMatrix4Identity);
    
    glDisableVertexAttribArray(GLKVertexAttribColor);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    
    // stroke
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, m_geoSize);
    
    // fill
    GLcolor4f blackA = GLcolor4f(0, 0, 0, 0.75);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &blackA);
    glDrawArrays(GL_TRIANGLE_FAN, 0, m_geoSize);
    
    /* draw scroll bar */
    int nTypes = m_manager.nodeTypes().size();
    float scroll_bar_margin = 0.95;
    float scroll_max = ceilf(nTypes/2.0f-2)*m_radius;
    float scroll_bar_tray_height = m_radius*2*scroll_bar_margin;
    // percent of the total scroll area that is visible * tray height
    float scroll_bar_height = m_radius*2/scroll_max * scroll_bar_tray_height;
    // percent of scroll position * (tray height - bar height)
    float scroll_bar_y = m_verticalScrollPos/scroll_max*(scroll_bar_tray_height-scroll_bar_height);
    GLvertex3f scroll_bar_geo[2];
    scroll_bar_geo[0] = GLvertex2f(m_radius*scroll_bar_margin, m_radius*scroll_bar_margin-scroll_bar_y);
    scroll_bar_geo[1] = GLvertex2f(m_radius*scroll_bar_margin, m_radius*scroll_bar_margin-(scroll_bar_y+scroll_bar_height));
    
    // load it up and draw
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
    glLineWidth(1.0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), scroll_bar_geo);
    glDrawArrays(GL_LINES, 0, 2);
    
    /* draw node types */
    
    //    GLvertex3f startPos(-m_radius/2, -m_radius/2, 0);
    GLvertex3f startPos(-m_radius/2, m_radius/2 + m_verticalScrollPos, 0);
    GLvertex3f xInc(m_radius, 0, 0);
    GLvertex3f yInc(0, -m_radius, 0);
    
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    for(int i = 0; i < m_manager.nodeTypes().size(); i++)
    {
        GLvertex3f iconPos = startPos + (xInc*(i%2)) + (yInc*(i/2));
        
        GLKMatrix4 modelView = GLKMatrix4Translate(m_modelView, iconPos.x, iconPos.y, iconPos.z);
        GLKMatrix3 normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
        GLKMatrix4 mvp = GLKMatrix4Multiply(projection, modelView);
        
        if(i == m_hit)
        {
            // draw highlight background
            GLKMatrix4 hitModelView = GLKMatrix4Scale(modelView, 0.5, 0.5, 0.5);
            shader.setLocalMatrix(GLKMatrix4Scale(GLKMatrix4MakeTranslation(iconPos.x, iconPos.y, iconPos.z), 0.5, 0.5, 0.5));
            GLKMatrix3 hitNormal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
            GLKMatrix4 hitMvp = GLKMatrix4Multiply(projection, hitModelView);
            
            GLcolor4f whiteA = GLcolor4f::white;
            whiteA.a = 0.75;
            
            shader.setMVPMatrix(hitMvp);
            shader.setNormalMatrix(hitNormal);
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &whiteA);
            
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, m_geo);
            
            glDrawArrays(GL_TRIANGLE_FAN, 0, m_geoSize);
            
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::black);
        }
        else
        {
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::white);
        }
        
        shader.setMVPMatrix(mvp);
        shader.setNormalMatrix(normal);
        shader.setLocalMatrix(GLKMatrix4MakeTranslation(iconPos.x, iconPos.y, iconPos.z));
        
        glLineWidth(4.0f);
        m_manager.renderNodeTypeIcon(m_manager.nodeTypes()[i]);
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
bool AGUINodeSelector<NodeType, ManagerType>::finishedRenderingOut()
{
    return m_xScale <= AGStyle::open_squeezeHeight;
//    return true;
}


