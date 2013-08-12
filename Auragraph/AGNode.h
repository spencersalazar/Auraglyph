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
        }
    }
    
    virtual void update(float t, float dt) = 0;
    virtual void render() = 0;
    
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
};


class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode()
    {
        initalizeNode();
        
        if(!s_init)
        {
            s_init = true;
            
            // generate circle
            s_geoSize = 64;
            s_geo = new GLvncprimf[s_geoSize];
            float radius = 0.01;
            for(int i = 0; i < s_geoSize; i++)
            {
                float theta = 2*M_PI*((float)i)/((float)(s_geoSize));
                s_geo[i].vertex = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
                s_geo[i].normal = GLvertex3f(0, 0, 1);
                s_geo[i].color = GLcolor4f(1, 1, 1, 1);
            }
            
            glGenVertexArraysOES(1, &s_vertexArray);
            glBindVertexArrayOES(s_vertexArray);
            
            glGenBuffers(1, &s_vertexBuffer);
            glBindBuffer(GL_ARRAY_BUFFER, s_vertexBuffer);
            glBufferData(GL_ARRAY_BUFFER, s_geoSize*sizeof(GLvncprimf), s_geo, GL_STATIC_DRAW);
            
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
            glEnableVertexAttribArray(GLKVertexAttribNormal);
            glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
            glEnableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
            
            glBindVertexArrayOES(0);
        }
    }
    
    AGAudioNode(GLvertex3f pos = GLvertex3f()) :
    m_pos(pos)
    {
        initializeAudioNode();
        
        //        NSLog(@"pos: (%f, %f, %f)", pos.x, pos.y, pos.z);
    }
    
    virtual void renderAudio(float *input, float *output, int nFrames)
    {
    }
    
    virtual void update(float t, float dt)
    {
        GLKMatrix4 projection = projectionMatrix();
        GLKMatrix4 modelView = globalModelViewMatrix();
        
        modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
        
        m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
        
        m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
    }
    
    virtual void render()
    {
        glBindVertexArrayOES(s_vertexArray);
        
        glUseProgram(s_program);
        
        glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
        glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
        
        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    
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




class AGControlNode : public AGNode
{
public:
    
    static void initializeControlNode();
    
    AGControlNode(GLvertex3f pos = GLvertex3f());
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    virtual void update(float t, float dt);
    virtual void render();
    
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
