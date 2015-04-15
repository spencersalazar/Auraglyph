//
//  AGInputNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 4/13/15.
//  Copyright (c) 2015 Spencer Salazar. All rights reserved.
//

#include "AGInputNode.h"
#include "spstl.h"

//------------------------------------------------------------------------------
// ### AGSliderNode ###
//------------------------------------------------------------------------------
class AGSliderNode : public AGInputNode
{
public:
    AGSliderNode(const GLvertex3f &pos) : AGInputNode(pos, s_nodeInfo) { }
    
    static void initialize();
    static AGNodeInfo *nodeInfo() { return s_nodeInfo; }
    
private:
    static AGNodeInfo *s_nodeInfo;

};


AGNodeInfo *AGSliderNode::s_nodeInfo;


void AGSliderNode::initialize()
{
    s_nodeInfo = new AGNodeInfo;
    
//    float radius = 0.005;
    float radius = 0.003;
    int circleSize = 48;
    s_nodeInfo->iconGeoSize = circleSize;
    s_nodeInfo->iconGeoType = GL_LINE_LOOP;
    s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
    
    for(int i = 0; i < circleSize; i++)
    {
        float y_offset = radius;
        if(i >= circleSize/2)
            y_offset = -radius;
        float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
        s_nodeInfo->iconGeo[i] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0)+y_offset, 0);
    }
}


const AGNodeManager &AGNodeManager::inputNodeManager()
{
    if(s_inputNodeManager == NULL)
    {
        s_inputNodeManager = new AGNodeManager();
        
        s_inputNodeManager->m_nodeTypes.push_back(new NodeInfo("Slider",
                                                               AGSliderNode::initialize,
                                                               renderNodeIcon<AGSliderNode>,
                                                               createNode<AGSliderNode>,
                                                               NULL));
//        s_inputNodeManager->m_audioNodeTypes.push_back(new NodeInfo("Knob", NULL, NULL, NULL, NULL));
//        s_inputNodeManager->m_audioNodeTypes.push_back(new NodeInfo("Button", NULL, NULL, NULL, NULL));
    }
    
    return *s_inputNodeManager;
}

const std::vector<AGNodeManager::NodeInfo *> &AGNodeManager::nodeInfos() const
{
    return m_nodeTypes;
}

void AGNodeManager::renderNodeTypeIcon(NodeInfo *type) const
{
    type->renderIcon();
}

AGNode *AGNodeManager::createNodeType(NodeInfo *type, const GLvertex3f &pos) const
{
    return type->createNode(pos);
}

AGNode *AGNodeManager::createNodeType(const AGDocument::Node &docNode) const
{
    __block AGNode *node = NULL;
    
    itmap(m_nodeTypes, ^bool (NodeInfo *const &type){
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

