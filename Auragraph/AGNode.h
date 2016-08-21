//
//  AGNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGNode__
#define __Auragraph__AGNode__


#include "AGControl.h"
#include "AGConnection.h"
#include "AGDocument.h"
//#include "AGUserInterface.h"

#include "Geometry.h"
#include "Animation.h"
#include "ES2Render.h"
#include "ShaderHelper.h"
#include "Mutex.h"

#import <GLKit/GLKit.h>
#import <Foundation/Foundation.h>

#include <list>
#include <string>
#include <vector>


using namespace std;


class AGUINodeEditor;


struct AGPortInfo
{
    string name;
    bool canConnect; // can create connection btw this port and another port
    bool canEdit; // should this port appear in the node's editor window
    
    // TODO: min, max, units label, rate, etc.
};

struct AGNodeInfo
{
    AGNodeInfo() : iconGeo(NULL), iconGeoSize(0), iconGeoType(GL_LINE_STRIP) { }
    
    string type;
    GLvertex3f *iconGeo;
    GLuint iconGeoSize;
    GLuint iconGeoType;
    
    vector<AGPortInfo> inputPortInfo;
    vector<AGPortInfo> editPortInfo;
};


class AGNode : public AGUIObject
{
public:
    
    static void initalizeNode();
        
    static void connect(AGConnection * connection);
    static void disconnect(AGConnection * connection);
    
    AGNode(GLvertex3f pos = GLvertex3f(), AGNodeInfo *nodeInfo = NULL);
    AGNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo);
    virtual ~AGNode();
    
    const string &type() { return m_nodeInfo->type; }
    const string &uuid() { return m_uuid; }
    void setTitle(const string &title) { m_title = title; }
    const string &title() const { return m_title; }
    
    // TODO: render/push functions protected?
    // graphics
    virtual void update(float t, float dt);
    virtual void render();
    // audio
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) { assert(0); }
    // control
    void pushControl(int port, AGControl *control);
    virtual void receiveControl(int port, AGControl *control) { }

    enum HitTestResult
    {
        HIT_NONE = 0,
        HIT_INPUT_NODE,
        HIT_OUTPUT_NODE,
        HIT_MAIN_NODE,
    };
    
    HitTestResult hit(const GLvertex3f &hit, int *port);
    void unhit();
    
    void setPosition(const GLvertex3f &pos) { m_pos = pos; }
    const GLvertex3f &position() const { return m_pos; }
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    // lock when creating/destroying connections to/from this node
    void lock() { m_mutex.lock(); }
    void unlock() { m_mutex.unlock(); }
    
    // 1: positive activation; 0: deactivation; -1: negative activation
    void activateInputPort(int type) { m_inputActivation = type; }
    void activateOutputPort(int type) { m_outputActivation = type; }
    void activate(int type) { m_activation = type; }
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { if(m_nodeInfo) return m_nodeInfo->inputPortInfo.size(); else return 0; }
    virtual int numEditPorts() const { if(m_nodeInfo) return m_nodeInfo->editPortInfo.size(); else return 0; }
    const AGPortInfo &inputPortInfo(int port) { return m_nodeInfo->inputPortInfo[port]; }
    const AGPortInfo &editPortInfo(int port) { return m_nodeInfo->editPortInfo[port]; }
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection) const { return m_pos + relativePositionForInboundConnection(connection); }
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection) const { return m_pos + relativePositionForOutboundConnection(connection); }
    virtual GLvertex3f relativePositionForInboundConnection(AGConnection * connection) const { return relativePositionForInputPort(connection->dstPort()); }
    virtual GLvertex3f relativePositionForOutboundConnection(AGConnection * connection) const { return relativePositionForOutputPort(0); }
    
    /*** Subclassing note: the following public functions should be overridden ***/
    
    /* overridden by final subclass */
    // TODO: should be pure virtual
    virtual void setEditPortValue(int port, float value) { }
    /* overridden by final subclass */
    virtual void getEditPortValue(int port, float &value) const { }
    
    void loadEditPortValues(const AGDocument::Node &docNode);
    
    /* overridden by final subclass */
    virtual AGUINodeEditor *createCustomEditor() { return NULL; }

    /* overridden by direct subclass */
    virtual GLvertex3f relativePositionForInputPort(int port) const { return GLvertex3f(); }
    virtual GLvertex3f relativePositionForOutputPort(int port) const { return GLvertex3f(); }
    
    /* overridden by direct subclass */
    virtual AGRate rate() { return RATE_CONTROL; }
    
    /* overridden by final or direct subclass */
    virtual void fadeOutAndRemove();
    virtual void renderOut();
    
    /* serialization - overridden by direct subclass */
    virtual AGDocument::Node serialize() = 0;
    
private:
    static bool s_initNode;
    
    Mutex m_mutex;
    virtual void receiveControl_internal(int port, AGControl *control);
    
protected:
    static float s_portRadius;
    static GLvertex3f *s_portGeo;
    static GLuint s_portGeoSize;
    static GLint s_portGeoType;
    
    const static float s_sizeFactor;
    
    virtual void addInbound(AGConnection *connection);
    virtual void addOutbound(AGConnection *connection);
    virtual void removeInbound(AGConnection *connection);
    virtual void removeOutbound(AGConnection *connection);
    
    AGNodeInfo *m_nodeInfo;
    string m_title;
    string m_uuid; // TODO: const
    
    std::list<AGConnection *> m_inbound;
    std::list<AGConnection *> m_outbound;
    
    AGControl ** m_controlPortBuffer;
    
//    AGPortInfo * m_inputPortInfo;
    
    GLvertex3f m_pos;
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
    
    // touch handling stuff
    GLvertex3f m_lastTouch;
    
    int m_inputActivation;
    int m_outputActivation;
    int m_activation;
    
    bool m_active;
    powcurvef m_fadeOut;
};


class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode();
    
    AGAudioNode(GLvertex3f pos = GLvertex3f(), AGNodeInfo *nodeInfo = NULL);
    AGAudioNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo);
    virtual ~AGAudioNode();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    virtual GLvertex3f relativePositionForInputPort(int port) const;
    virtual GLvertex3f relativePositionForOutputPort(int port) const;
    
    virtual AGRate rate() { return RATE_AUDIO; }
    inline float gain() { return m_gain; }
    
    const float *lastOutputBuffer() const { return m_outputBuffer; }
    
    static int sampleRate() { return s_sampleRate; }
    static int bufferSize() { return 1024; }
    
    virtual AGDocument::Node serialize();
//    template<class NodeClass>
//    static AGAudioNode *createFromDocNode(const AGDocument::Node &docNode);
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static GLuint s_geoSize;
    
    static int s_sampleRate;
    
    float m_radius;
    float m_portRadius;
    
protected:
    
    sampletime m_lastTime;
    float * m_outputBuffer;
    float ** m_inputPortBuffer;
    
    float m_gain;
    
    void allocatePortBuffers();
    void pullInputPorts(sampletime t, int nFrames);
    void renderLast(float *output, int nFrames);
};


class AGControlNode : public AGNode
{
public:
    static void initializeControlNode();
    
    AGControlNode(GLvertex3f pos = GLvertex3f(), AGNodeInfo *nodeInfo = NULL);
    AGControlNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo);
    virtual ~AGControlNode() { }
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
//    virtual HitTestResult hit(const GLvertex3f &hit);
//    virtual void unhit();
    
    virtual GLvertex3f relativePositionForInputPort(int port) const { return GLvertex3f(-s_radius, 0, 0); }
    virtual GLvertex3f relativePositionForOutputPort(int port) const { return GLvertex3f(s_radius, 0, 0); }
    
    virtual AGDocument::Node serialize();
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static float s_radius;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
protected:
    GLvertex3f *m_iconGeo;
    GLuint m_geoSize;
    GLuint m_geoType;
};



class AGInputNode : public AGNode
{
public:
    
    static void initializeInputNode();
    
    AGInputNode(GLvertex3f pos = GLvertex3f(), AGNodeInfo *nodeInfo = NULL);
    AGInputNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo);

    virtual void update(float t, float dt);    
    virtual void render();
    virtual void renderUI() { }
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);

    virtual HitTestResult hit(const GLvertex3f &hit);
    virtual void unhit();

    virtual GLvertex3f relativePositionForOutputPort(int port) const;
    
    virtual AGDocument::Node serialize();
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static float s_radius;

    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
};



class AGOutputNode : public AGNode
{
public:
    
    static void initializeOutputNode();
    
    AGOutputNode(GLvertex3f pos = GLvertex3f());
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);

    virtual HitTestResult hit(const GLvertex3f &hit);
    virtual void unhit();

    virtual AGDocument::Node serialize();
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static float s_radius;

    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
};


class AGFreeDraw : public AGUIObject
{
public:
    AGFreeDraw(GLvertex3f *points, int nPoints);
    AGFreeDraw(const AGDocument::Freedraw &docFreedraw);
    ~AGFreeDraw();
    
    const string &uuid() { return m_uuid; }
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    virtual AGDocument::Freedraw serialize();
    
private:
    const string m_uuid;
    
    GLvertex3f *m_points;
    int m_nPoints;
    bool m_touchDown;
    GLvertex3f m_position;
    GLvertex3f m_touchLast;
    
    bool m_active;
//    powcurvef m_alpha;
    
    // debug
    int m_touchPoint0;
};

//------------------------------------------------------------------------------
// ### utility functions ###
//------------------------------------------------------------------------------
template<class NodeClass>
static AGNode *createNode(const AGDocument::Node &docNode)
{
    NodeClass *node = new NodeClass(docNode);
    node->init();
    return node;
}

template<class NodeClass>
static AGNode *createNode(const GLvertex3f &pos)
{
    NodeClass *node = new NodeClass(pos);
    node->init();
    return node;
}

template<class NodeClass>
static void renderNodeIcon()
{
    AGNodeInfo *nodeInfo = NodeClass::nodeInfo();
    
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), nodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(nodeInfo->iconGeoType, 0, nodeInfo->iconGeoSize);
}

//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
class AGNodeManager
{
public:
    static const AGNodeManager &audioNodeManager();
    static const AGNodeManager &controlNodeManager();
    static const AGNodeManager &inputNodeManager();
    static const AGNodeManager &outputNodeManager();
    
    struct NodeInfo
    {
        NodeInfo(std::string _name,
                 void (*_initialize)(),
                 void (*_renderIcon)(),
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
    
    const std::vector<NodeInfo *> &nodeTypes() const;
    void renderNodeTypeIcon(NodeInfo *type) const;
    AGNode *createNodeType(NodeInfo *type, const GLvertex3f &pos) const;
    AGNode *createNodeType(const AGDocument::Node &docNode) const;
    
    template<class NodeClass>
    static AGNodeManager::NodeInfo *makeNodeInfo(const std::string &name)
    {
        return new NodeInfo(name, NodeClass::initialize, renderNodeIcon<NodeClass>,
                            createNode<NodeClass>, createNode<NodeClass>);
    }
    
private:
    static AGNodeManager *s_audioNodeManager;
    static AGNodeManager *s_controlNodeManager;
    static AGNodeManager *s_inputNodeManager;
    static AGNodeManager *s_outputNodeManager;
    
    std::vector<NodeInfo *> m_nodeTypes;
    
    AGNodeManager();
};

#endif /* defined(__Auragraph__AGNode__) */


