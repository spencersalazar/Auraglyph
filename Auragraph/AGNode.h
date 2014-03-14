//
//  AGNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGNode__
#define __Auragraph__AGNode__


#import <GLKit/GLKit.h>
#import "Geometry.h"
#import "Animation.h"
#import "ES2Render.h"
#import <Foundation/Foundation.h>
#import "ShaderHelper.h"
#import "AGUserInterface.h"
#import "Mutex.h"
#import "AGControl.h"

#import <list>
#import <string>
#import <vector>


class AGNode;

enum AGRate
{
    RATE_CONTROL,
    RATE_AUDIO,
};

struct AGPortInfo
{
    std::string name;
    bool canConnect; // can create connection btw this port and another port
    bool canEdit; // should this port appear in the node's editor window
    
    // TODO: min, max, units label, etc.
};

struct AGNodeInfo
{
    AGNodeInfo() : iconGeo(NULL), iconGeoSize(0), iconGeoType(GL_LINE_STRIP) { }
    
    GLvertex3f *iconGeo;
    GLuint iconGeoSize;
    GLuint iconGeoType;
    
    vector<AGPortInfo> inputPortInfo;
    vector<AGPortInfo> editPortInfo;
};

typedef unsigned long long sampletime;


class AGConnection : public AGUIObject
{
public:
    
    AGConnection(AGNode * src, AGNode * dst, int dstPort);
    ~AGConnection();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    AGNode * src() const { return m_src; }
    AGNode * dst() const { return m_dst; }
    int dstPort() const { return m_dstPort; }
    
    AGRate rate() { return m_rate; }
    
    void fadeOutAndRemove();
    
private:
    
    static bool s_init;
    static GLuint s_program;
    static GLint s_uniformMVPMatrix;
    static GLint s_uniformNormalMatrix;
    
    GLvertex3f m_geo[3];
    GLcolor4f m_color;
    GLuint m_geoSize;
    
    AGNode * const m_src;
    AGNode * const m_dst;
    const int m_dstPort;
    
    GLvertex3f m_outTerminal;
    GLvertex3f m_inTerminal;
    
    bool m_hit;
    bool m_stretch;
    bool m_break;
    GLvertex3f m_stretchPoint;
    
    bool m_active;
    expcurvef m_alpha;
    
    const AGRate m_rate;
    
    static void initalize();
    
    void updatePath();
};


class AGNode : public AGUIObject
{
public:
    
    static void initalizeNode();
    
    static void setProjectionMatrix(const GLKMatrix4 &proj) { s_projectionMatrix = proj; }
    static GLKMatrix4 projectionMatrix() { return s_projectionMatrix; }
    static void setGlobalModelViewMatrix(const GLKMatrix4 &modelview) { s_modelViewMatrix = modelview; }
    static GLKMatrix4 globalModelViewMatrix() { return s_modelViewMatrix; }
    
    static void connect(AGConnection * connection);
    static void disconnect(AGConnection * connection);
    
    AGNode(GLvertex3f pos = GLvertex3f());
    virtual ~AGNode();
    
    virtual void update(float t, float dt);
    virtual void render();
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) { assert(0); }
    virtual AGControl *renderControl(sampletime t) { assert(0); return NULL; }

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
    // TODO: all of these should be pure virtual
    virtual void setEditPortValue(int port, float value) { }
    virtual void getEditPortValue(int port, float &value) const { }
    
    virtual GLvertex3f relativePositionForInputPort(int port) const { return GLvertex3f(); }
    virtual GLvertex3f relativePositionForOutputPort(int port) const { return GLvertex3f(); }
    
    virtual AGRate rate() { return RATE_CONTROL; }
    
    virtual void fadeOutAndRemove();
    
private:
    static bool s_initNode;
    
    static GLKMatrix4 s_projectionMatrix;
    static GLKMatrix4 s_modelViewMatrix;
    
    Mutex m_mutex;
    
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
    
    std::list<AGConnection *> m_inbound;
    std::list<AGConnection *> m_outbound;
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
    expcurvef m_fadeOut;
};


class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode();
    
    AGAudioNode(GLvertex3f pos = GLvertex3f());
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
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static GLuint s_geoSize;
    
    static int s_sampleRate;
    
    float m_radius;
    float m_portRadius;
    
protected:
    
    float * m_outputBuffer;
    float ** m_inputPortBuffer;
    
    float m_gain;
    
    void allocatePortBuffers();
    void pullInputPorts(sampletime t, int nFrames);
};


class AGControlNode : public AGNode
{
public:
    static void initializeControlNode();
    
    AGControlNode(GLvertex3f pos = GLvertex3f());
    virtual ~AGControlNode() { }
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
//    virtual HitTestResult hit(const GLvertex3f &hit);
//    virtual void unhit();
    
    virtual GLvertex3f relativePositionForInputPort(int port) const { return GLvertex3f(-s_radius, 0, 0); }
    virtual GLvertex3f relativePositionForOutputPort(int port) const { return GLvertex3f(s_radius, 0, 0); }
        
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



class AGControlTimerNode : public AGControlNode
{
public:
    static void initialize();

    AGControlTimerNode(const GLvertex3f &pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;

    virtual AGControl *renderControl(sampletime t);
    
private:
    static AGNodeInfo *s_nodeInfo;
    
    AGIntControl m_control;
    sampletime m_lastTime;
    sampletime m_lastFire;
    float m_interval;
};



class AGInputNode : public AGNode
{
public:
    
    static void initializeInputNode();
    
    AGInputNode(GLvertex3f pos = GLvertex3f());
    
    virtual void update(float t, float dt);    
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);

    virtual HitTestResult hit(const GLvertex3f &hit);
    virtual void unhit();

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
    AGFreeDraw(GLvncprimf *points, int nPoints);
    ~AGFreeDraw();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
private:
    GLvncprimf *m_points;
    int m_nPoints;
    bool m_touchDown;
    GLvertex3f m_position;
    GLvertex3f m_touchLast;
    
    bool m_active;
    expcurvef m_alpha;
    
    // debug
    int m_touchPoint0;
};




#endif /* defined(__Auragraph__AGNode__) */
