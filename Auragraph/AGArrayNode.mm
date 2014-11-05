//
//  AGArrayNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGArrayNode.h"

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

AGUINodeEditor *AGControlArrayNode::createCustomEditor() const
{
    return NULL;
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

