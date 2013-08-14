//
//  AGNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGNode__
#define __Auragraph__AGNode__


#include "Geometry.h"
#import "UIKitGL.h"
#import <GLKit/GLKit.h>
#import <Foundation/Foundation.h>
#import "ShaderHelper.h"
#import <list>


class AGNode;


class AGConnection
{
public:
    
    AGConnection(AGNode * src, AGNode * dst);
    
    virtual void update(float t, float dt);
    virtual void render();
    
    AGNode * src() const { return m_src; }
    AGNode * dst() const { return m_dst; }
    
private:
    
    static bool s_init;
    static GLuint s_program;
    static GLint s_uniformMVPMatrix;
    static GLint s_uniformNormalMatrix;
    static GLint s_uniformColor2;
    
    GLuint m_vertexArray;
    GLuint m_vertexBuffer;
    
    GLvncprimf *m_geo;
    GLuint m_geoSize;
    
    AGNode * const m_src;
    AGNode * const m_dst;
    
    GLvertex3f m_outTerminal;
    GLvertex3f m_inTerminal;
    
    static void initalize();
    
    void updatePath();
};


class AGNode
{
public:
    
    static void initalizeNode()
    {
        if(!s_initNode)
        {
            s_initNode = true;
            
            s_program = [ShaderHelper createProgramForVertexShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]
                                                    fragmentShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];
            s_uniformMVPMatrix = glGetUniformLocation(s_program, "modelViewProjectionMatrix");
            s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
            s_uniformColor2 = glGetUniformLocation(s_program, "color2");
        }
    }
    
    static void setProjectionMatrix(const GLKMatrix4 &proj)
    {
        s_projectionMatrix = proj;
    }
    
    static GLKMatrix4 projectionMatrix() { return s_projectionMatrix; }
    
    static void setGlobalModelViewMatrix(const GLKMatrix4 &modelview)
    {
        s_modelViewMatrix = modelview;
    }
    
    static GLKMatrix4 globalModelViewMatrix() { return s_modelViewMatrix; }
    
    static void connect(AGConnection * connection)
    {
        connection->src()->m_outbound.push_back(connection);
        connection->dst()->m_inbound.push_back(connection);
    }
    
    
    
    virtual void update(float t, float dt) = 0;
    virtual void render() = 0;
    
    enum HitTestResult
    {
        HIT_NONE = 0,
        HIT_INPUT_NODE,
        HIT_OUTPUT_NODE,
    };
    
    virtual HitTestResult hit(const GLvertex2f &hit) = 0;
    virtual void unhit() = 0;
    
    virtual int numOutputPorts() { return 0; }
    virtual int numInputPorts() { return 0; }
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection) { return GLvertex3f(); }
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection) { return GLvertex3f(); }
    
    // 1: positive activation; 0: deactivation; -1: negative activation
    virtual void activateInputPort(int type) { }
    virtual void activateOutputPort(int type) { }
    
private:
    
    static bool s_initNode;
    
    static GLKMatrix4 s_projectionMatrix;
    static GLKMatrix4 s_modelViewMatrix;
    
protected:
    static GLuint s_program;
    static GLint s_uniformMVPMatrix;
    static GLint s_uniformNormalMatrix;
    static GLint s_uniformColor2;
    
    std::list<AGConnection *> m_inbound;
    std::list<AGConnection *> m_outbound;
};


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
    
    virtual GLvertex3f positionForInboundConnection(AGConnection * connection);
    virtual GLvertex3f positionForOutboundConnection(AGConnection * connection);

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

    GLvertex3f m_pos;
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
    
    int m_inputActivation;
    int m_outputActivation;
};


class AGAudioOutputNode : public AGAudioNode
{
public:
    AGAudioOutputNode(GLvertex3f pos) : AGAudioNode(pos) { }
    
    virtual int numOutputPorts() { return 0; }
    virtual int numInputPorts() { return 1; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
};


class AGAudioSineWaveNode : public AGAudioNode
{
public:
    AGAudioSineWaveNode(GLvertex3f pos) : AGAudioNode(pos)
    {
        m_freq = 220;
        m_phase = 0;
    }

    virtual int numOutputPorts() { return 1; }
    virtual int numInputPorts() { return 0; }
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
private:
    float m_freq;
    float m_phase;
};




class AGControlNode : public AGNode
{
public:
    
    static void initializeControlNode();
    
    AGControlNode(GLvertex3f pos = GLvertex3f());
    
    virtual void update(float t, float dt);
    virtual void render();
    virtual HitTestResult hit(const GLvertex2f &hit);
    virtual void unhit();

private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
    GLvertex3f m_pos;
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
};



class AGInputNode : public AGNode
{
public:
    
    static void initializeInputNode();
    
    AGInputNode(struct GLvertex3f pos = GLvertex3f());
    
    virtual void update(float t, float dt);    
    virtual void render();
    virtual HitTestResult hit(const GLvertex2f &hit);
    virtual void unhit();

private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
    GLvertex3f m_pos;
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
};



class AGOutputNode : public AGNode
{
public:
    
    static void initializeOutputNode();
    
    AGOutputNode(GLvertex3f pos = GLvertex3f());
    
    virtual void update(float t, float dt);
    virtual void render();
    virtual HitTestResult hit(const GLvertex2f &hit);
    virtual void unhit();

private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
    GLvertex3f m_pos;
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
};



#endif /* defined(__Auragraph__AGNode__) */
