//
//  AGNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGNode.h"


static const float G_RATIO = 1.61803398875;


bool AGConnection::s_init = false;
GLuint AGConnection::s_program = 0;
GLint AGConnection::s_uniformMVPMatrix = 0;
GLint AGConnection::s_uniformNormalMatrix = 0;
GLint AGConnection::s_uniformColor2 = 0;


bool AGNode::s_initNode = false;
GLuint AGNode::s_program = 0;
GLint AGNode::s_uniformMVPMatrix = 0;
GLint AGNode::s_uniformNormalMatrix = 0;
GLint AGNode::s_uniformColor2 = 0;
GLKMatrix4 AGNode::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGNode::s_modelViewMatrix = GLKMatrix4Identity;
const float AGNode::s_sizeFactor = 0.01;


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


//------------------------------------------------------------------------------
// ### AGConnection ###
//------------------------------------------------------------------------------

void AGConnection::initalize()
{
    if(!s_init)
    {
        s_init = true;
        
        s_program = [ShaderHelper createProgram:@"Shader"
                                 withAttributes:SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_NORMAL | SHADERHELPER_ATTR_COLOR];
        s_uniformMVPMatrix = glGetUniformLocation(s_program, "modelViewProjectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
        s_uniformColor2 = glGetUniformLocation(s_program, "color2");
    }
}

AGConnection::AGConnection(AGNode * src, AGNode * dst, int dstPort) :
m_src(src),
m_dst(dst),
m_dstPort(dstPort),
m_rate((src->rate() == RATE_AUDIO && dst->rate() == RATE_CONTROL) ? RATE_AUDIO : RATE_CONTROL), 
m_geo(NULL),
m_geoSize(0)
{
    initalize();
    
    AGNode::connect(this);
    
    m_outTerminal = src->positionForOutboundConnection(this);
    m_inTerminal = dst->positionForOutboundConnection(this);
    
    glGenVertexArraysOES(1, &m_vertexArray);
    glBindVertexArrayOES(m_vertexArray);
    
    glGenBuffers(1, &m_vertexBuffer);
    // generate line
    updatePath();

    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
    
    glBindVertexArrayOES(0);
}

void AGConnection::updatePath()
{
    if(m_geo != NULL) delete[] m_geo;
    m_geoSize = 2;
    m_geo = new GLvncprimf[m_geoSize];
    
    m_geo[0].vertex = m_inTerminal;
    m_geo[1].vertex = m_outTerminal;
    m_geo[0].color = m_geo[1].color = GLcolor4f(0.75, 0.75, 0.75, 1);
    
    glBindBuffer(GL_ARRAY_BUFFER, m_vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, m_geoSize*sizeof(GLvncprimf), m_geo, GL_STATIC_DRAW);
}

void AGConnection::update(float t, float dt)
{
    GLvertex3f newInPos = dst()->positionForInboundConnection(this);
    GLvertex3f newOutPos = src()->positionForOutboundConnection(this);
    
    if(newInPos != m_inTerminal || newOutPos != m_outTerminal)
    {
        // recalculate path
        m_inTerminal = newInPos;
        m_outTerminal = newOutPos;
        
        updatePath();
    }
}

void AGConnection::render()
{
    GLKMatrix4 projection = AGNode::projectionMatrix();
    GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
    
    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);

    glBindVertexArrayOES(m_vertexArray);
    
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normalMatrix.m);
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white);
    
    glLineWidth(2.0f);
    glDrawArrays(GL_LINE_STRIP, 0, m_geoSize);
}


//------------------------------------------------------------------------------
// ### AGControlNode ###
//------------------------------------------------------------------------------

void AGControlNode::initializeControlNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate circle
        s_geoSize = 4;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = AGNode::s_sizeFactor/(sqrt(sqrtf(2)));
        
        s_geo[0].vertex = GLvertex3f(radius, radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, -radius, 0);
        s_geo[2].vertex = GLvertex3f(-radius, -radius, 0);
        s_geo[3].vertex = GLvertex3f(-radius, radius, 0);
        
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
AGNode(pos)
{
    initializeControlNode();
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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white);

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


//------------------------------------------------------------------------------
// ### AGInputNode ###
//------------------------------------------------------------------------------

void AGInputNode::initializeInputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = AGNode::s_sizeFactor/G_RATIO;
        
        s_geo[0].vertex = GLvertex3f(-radius, radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, radius, 0);
        s_geo[2].vertex = GLvertex3f(0, -(sqrtf(radius*radius*4 - radius*radius) - radius), 0);
        
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
AGNode(pos)
{
    initializeInputNode();
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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white);

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



//------------------------------------------------------------------------------
// ### AGOutputNode ###
//------------------------------------------------------------------------------

void AGOutputNode::initializeOutputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = AGNode::s_sizeFactor/G_RATIO;
        
        s_geo[0].vertex = GLvertex3f(-radius, -radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, -radius, 0);
        s_geo[2].vertex = GLvertex3f(0, sqrtf(radius*radius*4 - radius*radius) - radius, 0);
        
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
AGNode(pos)
{
    initializeOutputNode();
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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white);

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


