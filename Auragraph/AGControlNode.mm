//
//  AGControlNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGControlNode.h"
#include "AGArrayNode.h"
#include "AGTimer.h"
#include "spstl.h"

//------------------------------------------------------------------------------
// ### AGControlTimerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlTimerNode

AGNodeInfo *AGControlTimerNode::s_nodeInfo = NULL;

void AGControlTimerNode::initialize()
{
    s_nodeInfo = new AGNodeInfo;
    
    float radius = 0.005;
    int circleSize = 48;
    s_nodeInfo->iconGeoSize = circleSize*2 + 4;
    s_nodeInfo->iconGeoType = GL_LINES;
    s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
    
    // TODO: multiple geoTypes (GL_LINE_LOOP + GL_LINE_STRIP) instead of wasteful GL_LINES
    
    for(int i = 0; i < circleSize; i++)
    {
        float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
        float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
        s_nodeInfo->iconGeo[i*2+0] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0), 0);
        s_nodeInfo->iconGeo[i*2+1] = GLvertex3f(radius*cosf(theta1), radius*sinf(theta1), 0);
    }
    
    float minute = 47;
    float minuteAngle = M_PI/2.0 + (minute/60.0)*(-2.0*M_PI);
    float hour = 1;
    float hourAngle = M_PI/2.0 + (hour/12.0 + minute/60.0/12.0)*(-2.0*M_PI);
    
    s_nodeInfo->iconGeo[circleSize*2+0] = GLvertex3f(0, 0, 0);
    s_nodeInfo->iconGeo[circleSize*2+1] = GLvertex3f(radius/G_RATIO*cosf(hourAngle), radius/G_RATIO*sinf(hourAngle), 0);
    s_nodeInfo->iconGeo[circleSize*2+2] = GLvertex3f(0, 0, 0);
    s_nodeInfo->iconGeo[circleSize*2+3] = GLvertex3f(radius*0.925*cosf(minuteAngle), radius*0.925*sinf(minuteAngle), 0);
    
    s_nodeInfo->editPortInfo.push_back({ "interval", true, true });
    s_nodeInfo->inputPortInfo.push_back({ "interval", true, true });
}

AGControlTimerNode::AGControlTimerNode(const GLvertex3f &pos) :
AGControlNode(pos, s_nodeInfo)
{
    m_interval = 0.5;
    m_lastFire = 0;
    m_lastTime = 0;
    m_control.v = 0;
    
    m_timer = new AGTimer(m_interval, ^(AGTimer *) {
        // flip
        m_control.v = !m_control.v;
        pushControl(0, &m_control);
    });
}

AGControlTimerNode::~AGControlTimerNode()
{
    delete m_timer;
    m_timer = NULL;
}

void AGControlTimerNode::update(float t, float dt)
{
    AGControlNode::update(t, dt);
    
//    if(t - m_lastFire >= m_interval)
//        m_lastFire = t;
//    m_lastTime = t;
}

void AGControlTimerNode::render()
{
    AGControlNode::render();
    
//    int circleSize = 48;
//    int circleFill = (int) floorf((1.0f - (m_lastTime - m_lastFire)/m_interval) * circleSize);
//    
//    glBindVertexArrayOES(0);
//    
//    GLKMatrix4 mvp = GLKMatrix4Scale(m_modelViewProjectionMatrix, 1.1, 1.1, 1.1);
//
//    AGGenericShader &shader = AGGenericShader::instance();
//    shader.useProgram();
//    shader.setMVPMatrix(mvp);
//    shader.setNormalMatrix(m_normalMatrix);
//    
//    glBindVertexArrayOES(0);
//    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_nodeInfo->iconGeo);
//    
//    GLcolor4f color = GLcolor4f::white;
//    color.a = m_fadeOut;
//    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
//    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
//    
//    glLineWidth(2.0f);
//    glDrawArrays(m_nodeInfo->iconGeoType, 0, circleFill*2);
}

void AGControlTimerNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_interval = value; m_timer->setInterval(m_interval); break;
    }
}

void AGControlTimerNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_interval; break;
    }
}

void AGControlTimerNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_nodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_nodeInfo->iconGeoType, 0, s_nodeInfo->iconGeoSize);
}

AGControlNode *AGControlTimerNode::create(const GLvertex3f &pos)
{
    return new AGControlTimerNode(pos);
}


//------------------------------------------------------------------------------
// ### AGControlNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGControlNodeManager

AGControlNodeManager *AGControlNodeManager::s_instance = NULL;

const AGControlNodeManager &AGControlNodeManager::instance()
{
    if(s_instance == NULL)
    {
        s_instance = new AGControlNodeManager();
    }
    
    return *s_instance;
}

AGControlNodeManager::AGControlNodeManager()
{
    m_controlNodeTypes.push_back(new ControlNodeType("Timer", AGControlTimerNode::initialize, AGControlTimerNode::renderIcon, AGControlTimerNode::create));
    m_controlNodeTypes.push_back(new ControlNodeType("Array", AGControlArrayNode::initialize, AGControlArrayNode::renderIcon, AGControlArrayNode::create));
}

const std::vector<AGControlNodeManager::ControlNodeType *> &AGControlNodeManager::nodeTypes() const
{
    return m_controlNodeTypes;
}

void AGControlNodeManager::renderNodeTypeIcon(ControlNodeType *type) const
{
    type->renderIcon();
}

AGControlNode * AGControlNodeManager::createNodeType(AGControlNodeManager::ControlNodeType *type, const GLvertex3f &pos) const
{
    AGControlNode *node = type->createNode(pos);
    node->setTitle(type->name);
    return node;
}

AGControlNode * AGControlNodeManager::createNodeType(const AGDocument::Node &docNode) const
{
    __block AGControlNode *node = NULL;
    
    itmap(m_controlNodeTypes, ^bool (ControlNodeType *const &type){
        if(type->name == docNode.type)
        {
            node = type->createWithDocNode(docNode);
            node->setTitle(type->name);
            return false;
        }
        
        return true;
    });
    
    return node;
}



