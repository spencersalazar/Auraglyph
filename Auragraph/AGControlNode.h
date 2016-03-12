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
    AGControlTimerNode(const AGDocument::Node &docNode);
    ~AGControlTimerNode();
    
    virtual int numOutputPorts() const { return 1; }
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void update(float t, float dt);
    virtual void render();
    
    static void renderIcon();
    static AGNode *create(const GLvertex3f &pos);
    
private:
    static AGNodeInfo *s_nodeInfo;
    
    AGTimer *m_timer;
    
    AGIntControl m_control;
    float m_lastTime;
    float m_lastFire;
    float m_interval;
};


class AGControlSequencerNode : public AGControlNode
{
public:
    static void initialize();
    
    AGControlSequencerNode(const GLvertex3f &pos);
    AGControlSequencerNode(const AGDocument::Node &docNode);
    ~AGControlSequencerNode();
    
    virtual int numOutputPorts() const { return 1; }
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void update(float t, float dt);
    virtual void render();
    
    static void renderIcon();
    static AGNode *create(const GLvertex3f &pos);
    static AGNodeInfo *nodeInfo() { return s_nodeInfo; }

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
                        AGNode *(*_createNode)(const GLvertex3f &pos),
                        AGNode *(*_createNodeWithDocNode)(const AGDocument::Node &docNode)) :
        name(_name),
        initialize(_initialize),
        renderIcon(_renderIcon),
        createNode(_createNode),
        createWithDocNode(_createNodeWithDocNode)
        { }
        
        std::string name;
        void (*initialize)();
        void (*renderIcon)();
        AGNode *(*createNode)(const GLvertex3f &pos);
        AGNode *(*createWithDocNode)(const AGDocument::Node &docNode);
    };
    
    const std::vector<ControlNodeType *> &nodeTypes() const;
    void renderNodeTypeIcon(ControlNodeType *type) const;
    AGNode * createNodeType(ControlNodeType *type, const GLvertex3f &pos) const;
    AGNode * createNodeType(const AGDocument::Node &docNode) const;
    
private:
    static AGControlNodeManager * s_instance;
    
    std::vector<ControlNodeType *> m_controlNodeTypes;
    
    AGControlNodeManager();
};



#endif /* defined(__Auragraph__AGControlNode__) */
