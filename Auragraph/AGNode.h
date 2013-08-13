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
    
    // 1: positive activation; 0: deactivation; -1: negative activation
    virtual void activateInputPort(int type) { }
    virtual void activateOutputPort(int type) { }

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
    
private:
    
    static bool s_initNode;
    
    static GLKMatrix4 s_projectionMatrix;
    static GLKMatrix4 s_modelViewMatrix;
    
protected:
    static GLuint s_program;
    static GLint s_uniformMVPMatrix;
    static GLint s_uniformNormalMatrix;
    static GLint s_uniformColor2;
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
    
    virtual void activateInputPort(int type) { m_inputActivation = type; }
    virtual void activateOutputPort(int type) { m_outputActivation = type; }
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    
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




class AGControlNode : public AGNode
{
public:
    
    static void initializeControlNode();
    
    AGControlNode(GLvertex3f pos = GLvertex3f());
    
    virtual void renderAudio(float *input, float *output, int nFrames);
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
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
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
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
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
