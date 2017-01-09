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
#include "AGInteractiveObject.h"

#include "Geometry.h"
#include "Animation.h"
#include "ES2Render.h"
#include "ShaderHelper.h"
#include "Mutex.h"

#include "gfx.h"
//#import <Foundation/Foundation.h>

#include <list>
#include <string>
#include <vector>
#include <set>


using namespace std;


class AGNode;
class AGUINodeEditor;


struct AGPortInfo
{
    int portId;
    
    string name;
    bool canConnect; // can create connection btw this port and another port
    bool canEdit; // should this port appear in the node's editor window
    
    float _default;
    float min;
    float max;
    
    enum Mode
    {
        LIN,
        LOG,
    };
    
    Mode mode;
    
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


class AGNodeManifest
{
public:
    virtual const string &type() const = 0;
    virtual const string &name() const = 0;
    virtual void initialize() const = 0;
    virtual void renderIcon() const = 0;
    virtual AGNode *createNode(const GLvertex3f &pos) const = 0;
    virtual AGNode *createNode(const AGDocument::Node &docNode) const = 0;
    
    virtual const vector<AGPortInfo> &inputPortInfo() const = 0;
    virtual const vector<AGPortInfo> &editPortInfo() const = 0;
    
    static const AGNodeManifest *defaultManifest() { return NULL; }
};


class AGNode : public AGUIObject
{
public:
    
    static void initalizeNode();
        
    static void connect(AGConnection * connection);
    static void disconnect(AGConnection * connection);
    
    AGNode(const AGNodeManifest *mf, const GLvertex3f &pos = GLvertex3f());
    AGNode(const AGNodeManifest *mf, const AGDocument::Node &docNode);
    virtual void init();
    virtual void init(const AGDocument::Node &docNode);
    
    // initialize final subclass
    virtual void initFinal() { }
    // finish deserializing final subclass
    virtual void deserializeFinal(const AGDocument::Node &docNode) { }
    
    virtual ~AGNode();
    
    virtual const string &type() { return m_manifest->type(); }
    const string &uuid() { return m_uuid; }
    void setTitle(const string &title) { m_title = title; }
    const string &title() const { return m_title; }
    
    // TODO: render/push functions protected?
    // graphics
    virtual void update(float t, float dt);
    virtual void render();
    // control
    void pushControl(int port, const AGControl &control);
    virtual void receiveControl(int port, const AGControl &control) { }
    AGControl lastControlOutput(int port);

    enum HitTestResult
    {
        HIT_NONE = 0,
        HIT_INPUT_NODE,
        HIT_OUTPUT_NODE,
        HIT_MAIN_NODE,
    };
    
    HitTestResult hit(const GLvertex3f &hit, int *port);
    void unhit();
    AGInteractiveObject *hitTest(const GLvertex3f &t);
    
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
    virtual int numInputPorts() const { if(m_manifest) return m_manifest->inputPortInfo().size(); else return 0; }
    virtual int numEditPorts() const { if(m_manifest) return m_manifest->editPortInfo().size(); else return 0; }
    virtual const AGPortInfo &inputPortInfo(int port) const { return m_manifest->inputPortInfo()[port]; }
    virtual const AGPortInfo &editPortInfo(int port) const { return m_manifest->editPortInfo()[port]; }
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection) const { return m_pos + relativePositionForInboundConnection(connection); }
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection) const { return m_pos + relativePositionForOutboundConnection(connection); }
    virtual GLvertex3f relativePositionForInboundConnection(AGConnection * connection) const { return relativePositionForInputPort(connection->dstPort()); }
    virtual GLvertex3f relativePositionForOutboundConnection(AGConnection * connection) const { return relativePositionForOutputPort(connection->srcPort()); }
    
    void trimConnectionsToNodes(const set<AGNode *> &nodes);
    const std::list<AGConnection *> outbound() const;
    const std::list<AGConnection *> inbound() const;
    
    void setEditPortValue(int port, float value) { m_params[editPortInfo(port).portId] = value; editPortValueChanged(editPortInfo(port).portId); }
    void getEditPortValue(int port, float &value) const { value = m_params.at(editPortInfo(port).portId); }
    virtual float getDefaultParamValue(int paramId) const { return editPortInfo(m_param2EditPort.at(paramId))._default; }
    float param(int paramId) const { return m_params.at(paramId); }
    void setParam(int paramId, float value) { m_params[paramId] = value; editPortValueChanged(paramId); }
    float validateParam(int paramId, float value) const { return validateEditPortValue(m_param2EditPort.at(paramId), value); }
    int numInputsForPort(int portId);

    /*** Subclassing note: override information as described ***/
    
    /* can be overridden by final subclass */
    virtual float validateEditPortValue(int port, float _new) const;
    /* can be overridden by direct subclass */
    virtual void finalPortValue(float &value, int portId, int sample = -1) const;
    /* can be overridden by final subclass */
    virtual void editPortValueChanged(int paramId) { }

    void loadEditPortValues(const AGDocument::Node &docNode);
    
    /* overridden by final subclass (if needed) */
    virtual AGUINodeEditor *createCustomEditor() { return NULL; }

    /* overridden by direct subclass */
    virtual GLvertex3f relativePositionForInputPort(int port) const { return GLvertex3f(); }
    virtual GLvertex3f relativePositionForOutputPort(int port) const { return GLvertex3f(); }
    
    /* overridden by direct subclass */
    virtual AGRate rate() { return RATE_CONTROL; }
    
    /* overridden by final or direct subclass */
    virtual void fadeOutAndRemove();
    virtual void renderOut();
    bool finishedRenderingOut();

    virtual AGDocument::Node serialize();
    
    /* overridden by direct subclass */
    virtual AGDocument::Node::Class nodeClass() const = 0;

private:
    static bool s_initNode;
    
    Mutex m_mutex;
    
    void _initBase();
    virtual void receiveControl_internal(int port, const AGControl &control);
    
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
    
    AGInteractiveObject *_hitTestConnections(const GLvertex3f &t);
    void _updateConnections(float t, float dt);
    void _renderConnections();
    
    virtual void _renderIcon();
    
    const AGNodeManifest *m_manifest;
    string m_title;
    string m_uuid; // TODO: const
    
    std::list<AGConnection *> m_inbound;
    std::list<AGConnection *> m_outbound;
    
    vector<AGControl> m_controlPortBuffer;
    vector<AGControl> m_lastControlOutput;
    
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
    
    map<int, int> m_param2InputPort;
    map<int, int> m_param2EditPort;
    map<int, float> m_params;
};


//------------------------------------------------------------------------------
// ### AGFreeDraw ###
//------------------------------------------------------------------------------
#pragma mark - AGFreeDraw

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
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGNodeManager

class AGNodeManager
{
public:
    static const AGNodeManager &audioNodeManager();
    static const AGNodeManager &controlNodeManager();
    static const AGNodeManager &inputNodeManager();
    static const AGNodeManager &outputNodeManager();
    
    const std::vector<const AGNodeManifest *> &nodeTypes() const;
    void renderNodeTypeIcon(const AGNodeManifest *mf) const;
    AGNode *createNodeType(const AGNodeManifest *mf, const GLvertex3f &pos) const;
    AGNode *createNodeType(const AGDocument::Node &docNode) const;
    AGNode *createNodeOfType(const string &type, const GLvertex3f &pos) const;
    
private:
    static AGNodeManager *s_audioNodeManager;
    static AGNodeManager *s_controlNodeManager;
    static AGNodeManager *s_inputNodeManager;
    static AGNodeManager *s_outputNodeManager;
    
    std::vector<const AGNodeManifest *> m_nodeTypes;
    
    AGNodeManager();
};

//------------------------------------------------------------------------------
// ### AGStandardNodeManifest ###
//------------------------------------------------------------------------------
#pragma mark - AGStandardNodeManifest

template<class NodeClass>
class AGStandardNodeManifest : public AGNodeManifest
{
public:
    AGStandardNodeManifest() : m_needsLoad(true) { }
    
    virtual void initialize() const override
    {
        load();
    }
    
    virtual const string &type() const override
    {
        load();
        return m_type;
    }
    
    virtual const string &name() const override
    {
        load();
        return m_type;
    }
    
    virtual const vector<AGPortInfo> &inputPortInfo() const override
    {
        load();
        return m_inputPortInfo;
    }
    
    virtual const vector<AGPortInfo> &editPortInfo() const override
    {
        load();
        return m_editPortInfo;
    }
    
    virtual void renderIcon() const override
    {
        load();
        
        glBindVertexArrayOES(0);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_iconGeo.data());
        
        glLineWidth(2.0);
        glDrawArrays(m_iconGeoType, 0, m_iconGeo.size());
    }
    
    virtual AGNode *createNode(const GLvertex3f &pos) const override
    {
        NodeClass *node = new NodeClass(this, pos);
        node->init();
        return node;
    }
    
    virtual AGNode *createNode(const AGDocument::Node &docNode) const override
    {
        NodeClass *node = new NodeClass(this, docNode);
        node->init(docNode);
        return node;
    }
    
    
protected:
    virtual string _type() const = 0;
    virtual string _name() const = 0;
    virtual vector<AGPortInfo> _inputPortInfo() const = 0;
    virtual vector<AGPortInfo> _editPortInfo() const = 0;
    virtual vector<GLvertex3f> _iconGeo() const = 0;
    virtual GLuint _iconGeoType() const = 0;
    
private:
    void load() const
    {
        if(m_needsLoad)
        {
            m_needsLoad = false;
            m_type = _type();
            m_name = _name();
            m_iconGeo = _iconGeo();
            m_iconGeoType = _iconGeoType();
            m_inputPortInfo = _inputPortInfo();
            m_editPortInfo = _editPortInfo();
        }
    }
    
    mutable bool m_needsLoad;
    mutable string m_type;
    mutable string m_name;
    mutable vector<GLvertex3f> m_iconGeo;
    mutable vector<AGPortInfo> m_inputPortInfo;
    mutable vector<AGPortInfo> m_editPortInfo;
    mutable GLuint m_iconGeoType;
};


#endif /* defined(__Auragraph__AGNode__) */


