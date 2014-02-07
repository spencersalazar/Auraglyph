//
//  AGAudioNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGAudioNode__
#define __Auragraph__AGAudioNode__

#import "Geometry.h"
#import <GLKit/GLKit.h>
#import <Foundation/Foundation.h>
#import "ShaderHelper.h"
#import <list>
#import <vector>
#import <string>
#import "AGNode.h"

using namespace std;

struct AGAudioNodeInfo
{
    GLuint iconVertexArray;
    GLuint iconVertexBuffer;
    GLuint iconGeoSize;
    GLuint iconGeoType;
    
    vector<AGPortInfo> portInfo;
};


class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode();
    
    AGAudioNode(GLvertex3f pos = GLvertex3f());
    virtual ~AGAudioNode();
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    virtual void update(float t, float dt);
    virtual void render();
    virtual HitTestResult hit(const GLvertex3f &hit);
    virtual void unhit();
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection) const;
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection) const;
    
    virtual void activateInputPort(int type) { m_inputActivation = type; }
    virtual void activateOutputPort(int type) { m_outputActivation = type; }
    virtual void activate(int type) { m_activation = type; }

    virtual AGRate rate() { return RATE_AUDIO; }
    
    static int sampleRate() { return s_sampleRate; }
    static int bufferSize() { return 256; }
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static GLuint s_geoSize;
    
    static int s_sampleRate;
    
    float m_radius;
    float m_portRadius;
    
    int m_inputActivation;
    int m_outputActivation;
    int m_activation;
    
protected:
    GLuint m_iconVertexArray;
    GLuint m_iconGeoSize;
    GLuint m_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    float ** m_inputPortBuffer;
    
    float m_gain;
    
    void allocatePortBuffers();
    void pullInputPorts(int nFrames);
};


class AGAudioOutputNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioOutputNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 0; }
    virtual int numInputPorts() const { return 1; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    static AGAudioNodeInfo *s_audioNodeInfo;
};


class AGAudioNodeManager
{
public:
    static const AGAudioNodeManager &instance();
    
    struct AudioNodeType
    {
        // TODO: make class
        AudioNodeType(std::string _name, void (*_initialize)(), void (*_renderIcon)(),
                      AGAudioNode *(*_createNode)(const GLvertex3f &pos)) :
        name(_name),
        initialize(_initialize),
        renderIcon(_renderIcon),
        createNode(_createNode)
        { }
        
        std::string name;
        void (*initialize)();
        void (*renderIcon)();
        AGAudioNode *(*createNode)(const GLvertex3f &pos);
    };
    
    const std::vector<AudioNodeType *> &audioNodeTypes() const;
    void renderNodeTypeIcon(AudioNodeType *type) const;
    AGAudioNode * createNodeType(AudioNodeType *type, const GLvertex3f &pos) const;
    
private:
    static AGAudioNodeManager * s_instance;
    
    std::vector<AudioNodeType *> m_audioNodeTypes;
    
    AGAudioNodeManager();
};



#endif /* defined(__Auragraph__AGAudioNode__) */
