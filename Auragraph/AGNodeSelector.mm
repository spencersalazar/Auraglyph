//
//  AGNodeSelector.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/4/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGNodeSelector.h"
#include "AGAudioNode.h"


static const float AGNODESELECTOR_RADIUS = 0.02;

static const float AGUIOpen_squeezeHeight = 0.00125;
static const float AGUIOpen_animTimeX = 0.4;
static const float AGUIOpen_animTimeY = 0.15;


template<class NodeType, class ManagerType, class InfoType>
class AGUINodeSelector : public AGUIMetaNodeSelector
{
public:
    AGUINodeSelector(const GLvertex3f &pos);
    virtual ~AGUINodeSelector();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGNode *createNode();
    
    virtual bool done() { return m_done; }
    
private:
    
    GLvertex3f m_geo[4];
    float m_radius;
    GLuint m_geoSize;
    
    float m_t;
    
    GLvertex3f m_pos;
    clampf m_verticalScrollPos;
    
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
    return new AGUINodeSelector<AGAudioNode, AGAudioNodeManager, AGAudioNodeManager::AudioNodeType>(pos);
}


//------------------------------------------------------------------------------
// ### AGUINodeSelector ###
//------------------------------------------------------------------------------
#pragma mark - AGUINodeSelector

template<class NodeType, class ManagerType, class InfoType>
AGUINodeSelector<NodeType, ManagerType, InfoType>::AGUINodeSelector(const GLvertex3f &pos) :
AGUIMetaNodeSelector(pos),
m_pos(pos),
m_node(new NodeType(pos)),
m_hit(-1),
m_t(0),
m_done(false)
{
    m_geoSize = 4;
    
    m_radius = AGNODESELECTOR_RADIUS;
    
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[0] = GLvertex3f(-m_radius, m_radius, 0);
    m_geo[1] = GLvertex3f(-m_radius, -m_radius, 0);
    m_geo[2] = GLvertex3f(m_radius, -m_radius, 0);
    m_geo[3] = GLvertex3f(m_radius, m_radius, 0);
    
    int nTypes = ManagerType::instance().nodeTypes().size();
    m_verticalScrollPos.clamp(0, ceilf(nTypes/2.0f-2)*m_radius);
    
    //    NSLog(@"scrollMax: %f", m_verticalScrollPos.max);
}

template<class NodeType, class ManagerType, class InfoType>
AGUINodeSelector<NodeType, ManagerType, InfoType>::~AGUINodeSelector()
{
    SAFE_DELETE(m_node);
}

template<class NodeType, class ManagerType, class InfoType>
void AGUINodeSelector<NodeType, ManagerType, InfoType>::update(float t, float dt)
{
    m_modelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    m_modelView = GLKMatrix4Translate(m_modelView, m_pos.x, m_pos.y, m_pos.z);
    
    float squeezeHeight = AGUIOpen_squeezeHeight;
    float animTimeX = AGUIOpen_animTimeX;
    float animTimeY = AGUIOpen_animTimeY;
    
    if(m_t < animTimeX)
        m_modelView = GLKMatrix4Scale(m_modelView, squeezeHeight+(m_t/animTimeX)*(1-squeezeHeight), squeezeHeight, 1);
    else if(m_t < animTimeX+animTimeY)
        m_modelView = GLKMatrix4Scale(m_modelView, 1.0, squeezeHeight+((m_t-animTimeX)/animTimeY)*(1-squeezeHeight), 1);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, m_modelView);
    
    m_node->update(t, dt);
    
    m_t += dt;
}

template<class NodeType, class ManagerType, class InfoType>
void AGUINodeSelector<NodeType, ManagerType, InfoType>::render()
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
    
    /* draw node types */
    
    //    GLvertex3f startPos(-m_radius/2, -m_radius/2, 0);
    GLvertex3f startPos(-m_radius/2, m_radius/2 + m_verticalScrollPos, 0);
    GLvertex3f xInc(m_radius, 0, 0);
    GLvertex3f yInc(0, -m_radius, 0);
    
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    const std::vector<InfoType *> nodeTypes = ManagerType::instance().nodeTypes();
    for(int i = 0; i < nodeTypes.size(); i++)
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
        ManagerType::instance().renderNodeTypeIcon(nodeTypes[i]);
    }
}

template<class NodeType, class ManagerType, class InfoType>
void AGUINodeSelector<NodeType, ManagerType, InfoType>::touchDown(const GLvertex3f &t)
{
    m_touchStart = t;
    m_hit = -1;
    
    // check if in entire bounds
    if(pointInRectangle(t.xy(), m_pos.xy()-GLvertex2f(m_radius, m_radius), m_pos.xy()+GLvertex2f(m_radius, m_radius)))
    {
        const std::vector<InfoType *> nodeTypes = ManagerType::instance().nodeTypes();
        GLvertex3f startPos = m_pos + GLvertex3f(-m_radius/2, m_radius/2 + m_verticalScrollPos, 0);
        GLvertex3f xInc(m_radius, 0, 0);
        GLvertex3f yInc(0, -m_radius, 0);
        float iconRadius = m_radius/2;
        
        for(int i = 0; i < nodeTypes.size(); i++)
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

template<class NodeType, class ManagerType, class InfoType>
void AGUINodeSelector<NodeType, ManagerType, InfoType>::touchMove(const GLvertex3f &t)
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

template<class NodeType, class ManagerType, class InfoType>
void AGUINodeSelector<NodeType, ManagerType, InfoType>::touchUp(const GLvertex3f &t)
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

template<class NodeType, class ManagerType, class InfoType>
AGNode *AGUINodeSelector<NodeType, ManagerType, InfoType>::createNode()
{
    if(m_hit >= 0)
    {
        const std::vector<InfoType *> nodeTypes = ManagerType::instance().nodeTypes();
        return ManagerType::instance().createNodeType(nodeTypes[m_hit], m_pos);
    }
    else
    {
        return NULL;
    }
}


