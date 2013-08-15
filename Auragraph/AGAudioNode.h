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
#import "AGNode.h"


class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode();
    
    AGAudioNode(GLvertex3f pos = GLvertex3f());
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    virtual void update(float t, float dt);
    virtual void render();
    virtual HitTestResult hit(const GLvertex2f &hit);
    virtual void unhit();
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection) const;
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection) const;
    
    virtual void activateInputPort(int type) { m_inputActivation = type; }
    virtual void activateOutputPort(int type) { m_outputActivation = type; }
    
    static int sampleRate() { return s_sampleRate; }
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static int s_sampleRate;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
    float m_radius;
    float m_portRadius;
    
    int m_inputActivation;
    int m_outputActivation;
    
protected:
    GLuint m_iconVertexArray;
    GLuint m_iconGeoSize;
    GLuint m_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
};


class AGAudioOutputNode : public AGAudioNode
{
public:
    
    AGAudioOutputNode(GLvertex3f pos) : AGAudioNode(pos)
    {
        initializeAudioOutputNode();
        
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
    static GLvncprimf * s_iconGeo;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    static void initializeAudioOutputNode();
};


class AGAudioSineWaveNode : public AGAudioNode
{
public:
    AGAudioSineWaveNode(GLvertex3f pos) : AGAudioNode(pos)
    {
        initializeAudioSineWaveNode();
        
        m_iconVertexArray = s_iconVertexArray;
        m_iconGeoSize = s_iconGeoSize;
        m_iconGeoType = s_iconGeoType;
        
        m_freq = 220;
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioSineWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLvncprimf * s_iconGeo;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    static void initializeAudioSineWaveNode();
};



class AGAudioSquareWaveNode : public AGAudioNode
{
public:
    AGAudioSquareWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioSquareWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLvncprimf * s_iconGeo;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    static void initializeAudioSquareWaveNode();
};



class AGAudioSawtoothWaveNode : public AGAudioNode
{
public:
    AGAudioSawtoothWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioSawtoothWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLvncprimf * s_iconGeo;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    static void initializeAudioSawtoothWaveNode();
};



class AGAudioTriangleWaveNode : public AGAudioNode
{
public:
    AGAudioTriangleWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static bool s_initAudioTriangleWaveNode;
    static GLuint s_iconVertexArray;
    static GLuint s_iconVertexBuffer;
    static GLuint s_iconGeoSize;
    static GLvncprimf * s_iconGeo;
    static GLuint s_iconGeoType; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
    
    static void initializeAudioTriangleWaveNode();
};



#endif /* defined(__Auragraph__AGAudioNode__) */
