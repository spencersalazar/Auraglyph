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


class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode();
    
    AGAudioNode(GLvertex3f pos = GLvertex3f());
    virtual ~AGAudioNode();
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    virtual void update(float t, float dt);
    virtual void render();
    virtual HitTestResult hit(const GLvertex2f &hit);
    virtual void unhit();
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection) const;
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection) const;
    
    virtual void activateInputPort(int type) { m_inputActivation = type; }
    virtual void activateOutputPort(int type) { m_outputActivation = type; }
    
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
    
protected:
    GLuint m_iconVertexArray;
    GLuint m_iconGeoSize;
    GLuint m_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    float ** m_inputPortBuffer;
};


class AGAudioOutputNode : public AGAudioNode
{
public:
    
    AGAudioOutputNode(GLvertex3f pos) : AGAudioNode(pos)
    {
        initializeAudioOutputNode();
        
        m_inputPortInfo = s_portInfo;
        
        m_iconVertexArray = s_iconVertexArray;
        m_iconGeoSize = s_iconGeoSize;
        m_iconGeoType = s_iconGeoType;
    }
    
    virtual int numOutputPorts() const { return 0; }
    virtual int numInputPorts() const { return 1; }

    virtual void renderAudio(float *input, float *output, int nFrames);
    
private:
    static bool s_initAudioOutputNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    static AGPortInfo * s_portInfo;
    
    static void initializeAudioOutputNode();
};


class AGAudioSineWaveNode : public AGAudioNode
{
public:
    AGAudioSineWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 2; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioSineWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    static AGPortInfo * s_portInfo;

    static void initializeAudioSineWaveNode();
};



class AGAudioSquareWaveNode : public AGAudioNode
{
public:
    AGAudioSquareWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);

private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioSquareWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    static AGPortInfo * s_portInfo;

    static void initializeAudioSquareWaveNode();
};



class AGAudioSawtoothWaveNode : public AGAudioNode
{
public:
    AGAudioSawtoothWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioSawtoothWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    static AGPortInfo * s_portInfo;

    static void initializeAudioSawtoothWaveNode();
};



class AGAudioTriangleWaveNode : public AGAudioNode
{
public:
    AGAudioTriangleWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);

private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioTriangleWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    static AGPortInfo * s_portInfo;

    static void initializeAudioTriangleWaveNode();
};


class AGAudioNodeManager
{
public:
    static const AGAudioNodeManager &instance();
    
    struct AudioNodeType
    {
    private:
        AudioNodeType(std::string _name, void (*_renderIcon)(),
                      AGAudioNode *(*_createNode)(const GLvertex3f &pos)) :
        name(_name),
        renderIcon(_renderIcon),
        createNode(_createNode)
        { }
        
        std::string name;
        void (*renderIcon)();
        AGAudioNode *(*createNode)(const GLvertex3f &pos);
        
        friend class AGAudioNodeManager;
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
