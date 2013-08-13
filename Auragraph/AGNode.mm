//
//  AGNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGNode.h"


bool AGNode::s_initNode = false;
GLuint AGNode::s_program = 0;
GLint AGNode::s_uniformMVPMatrix = 0;
GLint AGNode::s_uniformNormalMatrix = 0;
GLint AGNode::s_uniformColor2 = 0;
GLKMatrix4 AGNode::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGNode::s_modelViewMatrix = GLKMatrix4Identity;


bool AGAudioNode::s_init = false;
GLuint AGAudioNode::s_vertexArray = 0;
GLuint AGAudioNode::s_vertexBuffer = 0;
GLvncprimf *AGAudioNode::s_geo = NULL;
GLuint AGAudioNode::s_geoSize = 0;


bool AGControlNode::s_init = false;
GLuint AGControlNode::s_vertexArray = 0;
GLuint AGControlNode::s_vertexBuffer = 0;
GLvncprimf *AGControlNode::s_geo = NULL;
GLuint AGControlNode::s_geoSize = 0;


bool AGInputNode::s_init = false;
GLuint AGInputNode::s_vertexArray = 0;
GLuint AGInputNode::s_vertexBuffer = 0;
GLvncprimf *AGInputNode::s_geo = NULL;
GLuint AGInputNode::s_geoSize = 0;


bool AGOutputNode::s_init = false;
GLuint AGOutputNode::s_vertexArray = 0;
GLuint AGOutputNode::s_vertexBuffer = 0;
GLvncprimf *AGOutputNode::s_geo = NULL;
GLuint AGOutputNode::s_geoSize = 0;



void AGAudioNode::initializeAudioNode()
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

AGAudioNode::AGAudioNode(GLvertex3f pos) :
m_pos(pos)
{
    initializeAudioNode();
    
    m_radius = 0.01;
    m_portRadius = 0.01 * 0.2;
    
    m_inputActivation = m_outputActivation = 0;
    
    //        NSLog(@"pos: (%f, %f, %f)", pos.x, pos.y, pos.z);
}

void AGAudioNode::renderAudio(float *input, float *output, int nFrames)
{
}

void AGAudioNode::update(float t, float dt)
{
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGAudioNode::render()
{
    GLcolor4f color2(1, 1, 1, 1);
    
    // draw base outline
    glBindVertexArrayOES(s_vertexArray);
    
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
    glUniform4fv(s_uniformColor2, 1, (float*)&color2);
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    // draw output port
    GLKMatrix4 mvpOutputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, m_radius, 0, 0);
    mvpOutputPort = GLKMatrix4Scale(mvpOutputPort, 0.2, 0.2, 1);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, mvpOutputPort.m);
    if(m_outputActivation > 0)      color2 = GLcolor4f(0, 1, 0, 1);
    else if(m_outputActivation < 0) color2 = GLcolor4f(1, 0, 0, 1);
    else                            color2 = GLcolor4f(1, 1, 1, 1);
    glUniform4fv(s_uniformColor2, 1, (float*)&color2);
    
    glLineWidth(2.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    // draw input port
    GLKMatrix4 mvpInputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, -m_radius, 0, 0);
    mvpInputPort = GLKMatrix4Scale(mvpInputPort, 0.2, 0.2, 1);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, mvpInputPort.m);
    if(m_inputActivation > 0)      color2 = GLcolor4f(0, 1, 0, 1);
    else if(m_inputActivation < 0) color2 = GLcolor4f(1, 0, 0, 1);
    else                           color2 = GLcolor4f(1, 1, 1, 1);
    glUniform4fv(s_uniformColor2, 1, (float*)&color2);
    
    glLineWidth(2.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
}


AGNode::HitTestResult AGAudioNode::hit(const GLvertex2f &hit)
{
    float x, y;
    
    // check input port
    x = hit.x - (m_pos.x - m_radius);
    y = hit.y - m_pos.y;
    if(x*x + y*y <= m_portRadius*m_portRadius)
    {
        return HIT_INPUT_NODE;
    }
    
    // check output port
    x = hit.x - (m_pos.x + m_radius);
    y = hit.y - m_pos.y;
    if(x*x + y*y <= m_portRadius*m_portRadius)
    {
        return HIT_OUTPUT_NODE;
    }
    
    // check whole node
    x = hit.x - m_pos.x;
    y = hit.y - m_pos.y;
    if(x*x + y*y <= m_radius*m_radius)
    {
        return HIT_NONE;
    }
    
    return HIT_NONE;
}

void AGAudioNode::unhit()
{
    //m_hitInput = m_hitOutput = false;
}


void AGControlNode::initializeControlNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate circle
        s_geoSize = 4;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = 0.01/(sqrt(sqrtf(2)));
        
        s_geo[0].vertex = GLvertex3f(radius, radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, -radius, 0);
        s_geo[2].vertex = GLvertex3f(-radius, -radius, 0);
        s_geo[3].vertex = GLvertex3f(-radius, radius, 0);
        s_geo[0].normal = s_geo[1].normal = s_geo[2].normal = s_geo[3].normal = GLvertex3f(0, 0, 1);
        s_geo[0].color = s_geo[1].color = s_geo[2].color = s_geo[3].color = GLcolor4f(1, 1, 1, 1);
        
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

AGControlNode::AGControlNode(GLvertex3f pos) :
m_pos(pos)
{
    initializeControlNode();
}

void AGControlNode::renderAudio(float *input, float *output, int nFrames)
{
}

void AGControlNode::update(float t, float dt)
{
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGControlNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    // TODO
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
}

AGNode::HitTestResult AGControlNode::hit(const GLvertex2f &hit)
{
    return HIT_NONE;
}

void AGControlNode::unhit()
{
    
}


void AGInputNode::initializeInputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = 0.01;
        
        s_geo[0].vertex = GLvertex3f(-radius, radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, radius, 0);
        s_geo[2].vertex = GLvertex3f(0, -(sqrtf(radius*radius*4 - radius*radius) - radius), 0);
        s_geo[0].normal = s_geo[1].normal = s_geo[2].normal = GLvertex3f(0, 0, 1);
        s_geo[0].color = s_geo[1].color = s_geo[2].color = GLcolor4f(1, 1, 1, 1);
        
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

AGInputNode::AGInputNode(GLvertex3f pos) :
m_pos(pos)
{
    initializeInputNode();
}

void AGInputNode::renderAudio(float *input, float *output, int nFrames)
{
}

void AGInputNode::update(float t, float dt)
{
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGInputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    // TODO
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
}


AGNode::HitTestResult AGInputNode::hit(const GLvertex2f &hit)
{
    return HIT_NONE;
}

void AGInputNode::unhit()
{
    
}



void AGOutputNode::initializeOutputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = 0.01;
        
        s_geo[0].vertex = GLvertex3f(-radius, -radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, -radius, 0);
        s_geo[2].vertex = GLvertex3f(0, sqrtf(radius*radius*4 - radius*radius) - radius, 0);
        s_geo[0].normal = s_geo[1].normal = s_geo[2].normal = GLvertex3f(0, 0, 1);
        s_geo[0].color = s_geo[1].color = s_geo[2].color = GLcolor4f(1, 1, 1, 1);
        
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

AGOutputNode::AGOutputNode(GLvertex3f pos) :
m_pos(pos)
{
    initializeOutputNode();
}

void AGOutputNode::renderAudio(float *input, float *output, int nFrames)
{
}

void AGOutputNode::update(float t, float dt)
{
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGOutputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    // TODO
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
}

AGNode::HitTestResult AGOutputNode::hit(const GLvertex2f &hit)
{
    return HIT_NONE;
}

void AGOutputNode::unhit()
{
    
}


