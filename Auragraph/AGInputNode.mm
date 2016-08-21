//
//  AGInputNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 4/13/15.
//  Copyright (c) 2015 Spencer Salazar. All rights reserved.
//

#include "AGInputNode.h"
#include "spstl.h"
#include "AGStyle.h"

//------------------------------------------------------------------------------
// ### AGSliderNode ###
//------------------------------------------------------------------------------
class AGSliderNode : public AGInputNode
{
public:
    AGSliderNode(const GLvertex3f &pos) : AGInputNode(pos, s_nodeInfo) { }
    AGSliderNode(const AGDocument::Node &docNode) : AGInputNode(docNode, s_nodeInfo) { }
    
    static void initialize();
    static AGNodeInfo *nodeInfo() { return s_nodeInfo; }
    
private:
    static AGNodeInfo *s_nodeInfo;

};


AGNodeInfo *AGSliderNode::s_nodeInfo;


void AGSliderNode::initialize()
{
    if(s_nodeInfo == NULL)
    {
        s_nodeInfo = new AGNodeInfo;
        

        
        s_nodeInfo->type = "Slider";
        
        //    float radius = 0.005;
        float radius = 0.002*AGStyle::oldGlobalScale;
        float height = 0.003*AGStyle::oldGlobalScale;
        int circleSize = 48;
        s_nodeInfo->iconGeoSize = circleSize;
        s_nodeInfo->iconGeoType = GL_LINE_LOOP;
        s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
        
        for(int i = 0; i < circleSize; i++)
        {
            float y_offset = height;
            if(i >= circleSize/2)
                y_offset = -height;
            float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
            s_nodeInfo->iconGeo[i] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0)+y_offset, 0);
        }
    }
}


//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark AGNodeManager -

const AGNodeManager &AGNodeManager::inputNodeManager()
{
    if(s_inputNodeManager == NULL)
    {
        s_inputNodeManager = new AGNodeManager();
        
        s_inputNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGSliderNode>("Slider"));
//        s_inputNodeManager->m_audioNodeTypes.push_back(new NodeInfo("Knob", NULL, NULL, NULL, NULL));
//        s_inputNodeManager->m_audioNodeTypes.push_back(new NodeInfo("Button", NULL, NULL, NULL, NULL));
        
        itmap(s_inputNodeManager->m_nodeTypes, ^bool (NodeInfo *const &type){
            type->initialize();
            return true;
        });
    }
    
    return *s_inputNodeManager;
}
