//
//  AGControlNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGControlNode__
#define __Auragraph__AGControlNode__


#include "AGNode.h"


class AGTimer;

class AGControlTimerNode : public AGControlNode
{
public:
    static void initialize();
    
    AGControlTimerNode(const GLvertex3f &pos);
    ~AGControlTimerNode();
    
    virtual int numOutputPorts() const { return 1; }
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void update(float t, float dt);
    virtual void render();
    
    static void renderIcon();
    static AGControlNode *create(const GLvertex3f &pos);

private:
    static AGNodeInfo *s_nodeInfo;
    
    AGTimer *m_timer;
    
    AGIntControl m_control;
    float m_lastTime;
    float m_lastFire;
    float m_interval;
};


class AGControlNodeManager
{
public:
    static const AGControlNodeManager &instance();
    
    struct ControlNodeType
    {
        // TODO: make class
        ControlNodeType(std::string _name, void (*_initialize)(), void (*_renderIcon)(),
                        AGControlNode *(*_createNode)(const GLvertex3f &pos)) :
        name(_name),
        initialize(_initialize),
        renderIcon(_renderIcon),
        createNode(_createNode)
        { }
        
        std::string name;
        void (*initialize)();
        void (*renderIcon)();
        AGControlNode *(*createNode)(const GLvertex3f &pos);
        AGControlNode *(*createWithDocNode)(const AGDocument::Node &docNode);
    };
    
    const std::vector<ControlNodeType *> &nodeTypes() const;
    void renderNodeTypeIcon(ControlNodeType *type) const;
    AGControlNode * createNodeType(ControlNodeType *type, const GLvertex3f &pos) const;
    AGControlNode * createNodeType(const AGDocument::Node &docNode) const;
    
private:
    static AGControlNodeManager * s_instance;
    
    std::vector<ControlNodeType *> m_controlNodeTypes;
    
    AGControlNodeManager();
};



#endif /* defined(__Auragraph__AGControlNode__) */
