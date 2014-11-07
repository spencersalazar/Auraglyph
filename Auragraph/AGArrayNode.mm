//
//  AGArrayNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGArrayNode.h"
#include "AGUserInterface.h"
#include "GeoGenerator.h"
#include "AGStyle.h"


//------------------------------------------------------------------------------
// ### AGUIArrayEditor ###
//------------------------------------------------------------------------------
#pragma mark - AGUIArrayEditor

static const float AGUIOpen_squeezeHeight = 0.00125;
static const float AGUIOpen_animTimeX = 0.4;
static const float AGUIOpen_animTimeY = 0.15;

class AGUIArrayEditor : public AGUINodeEditor
{
public:
    static void initializeNodeEditor();
    
    AGUIArrayEditor(AGControlArrayNode *node) :
    m_node(node),
    m_doneEditing(false)
    {
        GeoGen::makeRect(m_boxGeo, 0.08, 0.03);
        
        m_boxOuterInfo.geo = m_boxGeo;
        m_boxOuterInfo.geoType = GL_LINE_LOOP;
        m_boxOuterInfo.numVertex = 4;
        m_boxOuterInfo.color = AGStyle::lightColor();
        m_renderList.push_back(&m_boxOuterInfo);
        
        m_boxInnerInfo.geo = m_boxGeo;
        m_boxInnerInfo.geoType = GL_TRIANGLE_FAN;
        m_boxInnerInfo.numVertex = 4;
        m_boxInnerInfo.color = AGStyle::frameBackgroundColor();
        m_renderList.push_back(&m_boxInnerInfo);
        
        m_xScale = lincurvef(AGUIOpen_animTimeX, AGUIOpen_squeezeHeight, 1);
        m_yScale = lincurvef(AGUIOpen_animTimeY, AGUIOpen_squeezeHeight, 1);
    }
    
    virtual void update(float t, float dt)
    {
        AGInteractiveObject::update(t, dt);
        
        m_modelView = AGNode::globalModelViewMatrix();
        m_renderState.projection = AGNode::projectionMatrix();
        
        m_modelView = GLKMatrix4Translate(m_modelView, m_node->position().x, m_node->position().y, m_node->position().z);
        
        if(m_yScale <= AGUIOpen_squeezeHeight) m_xScale.update(dt);
        if(m_xScale >= 0.99f) m_yScale.update(dt);
        
        m_modelView = GLKMatrix4Scale(m_modelView,
                                      m_yScale <= AGUIOpen_squeezeHeight ? (float)m_xScale : 1.0f,
                                      m_xScale >= 0.99f ? (float)m_yScale : AGUIOpen_squeezeHeight,
                                      1);
        
        m_renderState.modelview = m_modelView;
        m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
    }
    
    virtual void render()
    {
        AGInteractiveObject::render();
    }
    
//    virtual AGInteractiveObject *hitTest(const GLvertex3f &t)
//    {
//        AGInteractiveObject *hit = AGInteractiveObject::hitTest(t);
//        if(hit != this)
//            ;
//        return this;
//    }
    
    virtual void touchDown(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchDown(t);
        
        if(hitTest(t.position) != this) m_doneEditing = true;
    }
    
    virtual void touchMove(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchMove(t);
    }
    
    virtual void touchUp(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchUp(t);
    }
    
    void renderOut()
    {
        m_xScale = lincurvef(AGUIOpen_animTimeX/2, 1, AGUIOpen_squeezeHeight);
        m_yScale = lincurvef(AGUIOpen_animTimeY/2, 1, AGUIOpen_squeezeHeight);
    }
    
    bool finishedRenderingOut()
    {
        return m_xScale <= AGUIOpen_squeezeHeight;
    }
    
    virtual bool doneEditing() { return m_doneEditing; }
    
private:
    
    AGControlArrayNode * const m_node;
    
    string m_title;
    
    AGRenderInfoV m_boxOuterInfo, m_boxInnerInfo;
    GLvertex3f m_boxGeo[4];
    
    GLKMatrix4 m_modelView;
    lincurvef m_xScale;
    lincurvef m_yScale;

    bool m_doneEditing;
    
    std::list< std::vector<GLvertex3f> > m_drawline;
    LTKTrace m_currentTrace;
    
    float m_currentValue;
    bool m_lastTraceWasRecognized;
    bool m_decimal;
    float m_decimalFactor;
    
//    int hitTest(const GLvertex3f &t, bool *inBbox);
};


//------------------------------------------------------------------------------
// ### AGControlArrayNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlArrayNode

AGNodeInfo *AGControlArrayNode::s_nodeInfo = NULL;

void AGControlArrayNode::initialize()
{
    s_nodeInfo = new AGNodeInfo;
    
    float radius = 0.0057;
    int numBoxes = 5;
    float boxWidth = radius*2.0f/((float)numBoxes);
    float boxHeight = radius/2.5f;
    s_nodeInfo->iconGeoSize = (numBoxes*3+1)*2;
    s_nodeInfo->iconGeoType = GL_LINES;
    s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
    
    for(int i = 0; i < numBoxes; i++)
    {
        s_nodeInfo->iconGeo[i*6+0] = GLvertex3f(-radius+i*boxWidth,  boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+1] = GLvertex3f(-radius+i*boxWidth, -boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+2] = GLvertex3f(-radius+i*boxWidth,  boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+3] = GLvertex3f(-radius+i*boxWidth+boxWidth,  boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+4] = GLvertex3f(-radius+i*boxWidth, -boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+5] = GLvertex3f(-radius+i*boxWidth+boxWidth, -boxHeight, 0);
    }
    
    s_nodeInfo->iconGeo[numBoxes*6+0] = GLvertex3f(-radius+numBoxes*boxWidth, -boxHeight, 0);
    s_nodeInfo->iconGeo[numBoxes*6+1] = GLvertex3f(-radius+numBoxes*boxWidth,  boxHeight, 0);
    
    s_nodeInfo->inputPortInfo.push_back({ "iterate", true, true });
}

AGControlArrayNode::AGControlArrayNode(const GLvertex3f &pos) :
AGControlNode(pos)
{
    m_nodeInfo = s_nodeInfo;
    m_lastTime = 0;
}

void AGControlArrayNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
    }
}

void AGControlArrayNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
    }
}

AGUINodeEditor *AGControlArrayNode::createCustomEditor()
{
    return new AGUIArrayEditor(this);
}

AGControl *AGControlArrayNode::renderControl(sampletime t)
{
    if(t > m_lastTime)
    {
        m_control = 0;
    }
    
    return &m_control;
}

void AGControlArrayNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_nodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_nodeInfo->iconGeoType, 0, s_nodeInfo->iconGeoSize);
}

AGControlNode *AGControlArrayNode::create(const GLvertex3f &pos)
{
    return new AGControlArrayNode(pos);
}

