//
//  AGNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGNode.h"


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


bool AGAudioNode::s_init = false;
GLuint AGAudioNode::s_vertexArray = 0;
GLuint AGAudioNode::s_vertexBuffer = 0;
GLvncprimf *AGAudioNode::s_geo = NULL;
GLuint AGAudioNode::s_geoSize = 0;
int AGAudioNode::s_sampleRate = 44100;


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
        
        s_program = [ShaderHelper createProgramForVertexShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]
                                                fragmentShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];
        s_uniformMVPMatrix = glGetUniformLocation(s_program, "modelViewProjectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
        s_uniformColor2 = glGetUniformLocation(s_program, "color2");
    }
}

AGConnection::AGConnection(AGNode * src, AGNode * dst) :
m_src(src),
m_dst(dst),
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
    m_geo[0].normal = m_geo[1].normal = GLvertex3f(0, 0, 1);
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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());
    
    glLineWidth(2.0f);
    glDrawArrays(GL_LINE_STRIP, 0, m_geoSize);
}


//------------------------------------------------------------------------------
// ### AGAudioNode ###
//------------------------------------------------------------------------------

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
AGNode(pos)
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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    if(numOutputPorts())
    {
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
    }
    
    if(numInputPorts())
    {
        // draw input port
        GLKMatrix4 mvpInputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, -m_radius, 0, 0);
        mvpInputPort = GLKMatrix4Scale(mvpInputPort, 0.2, 0.2, 1);
        
        glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, mvpInputPort.m);
        if(m_inputActivation > 0)      color2 = GLcolor4f(0, 1, 0, 1);
        else if(m_inputActivation < 0) color2 = GLcolor4f(1, 0, 0, 1);
        else                           color2 = GLcolor4f(1, 1, 1, 1);
        glUniform4fv(s_uniformColor2, 1, (float*)&color2);
    }
    
    glLineWidth(2.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
}


AGNode::HitTestResult AGAudioNode::hit(const GLvertex2f &hit)
{
    float x, y;
    
    if(numInputPorts())
    {
        // check input port
        x = hit.x - (m_pos.x - m_radius);
        y = hit.y - m_pos.y;
        if(x*x + y*y <= m_portRadius*m_portRadius)
        {
            return HIT_INPUT_NODE;
        }
    }
    
    if(numOutputPorts())
    {
        // check output port
        x = hit.x - (m_pos.x + m_radius);
        y = hit.y - m_pos.y;
        if(x*x + y*y <= m_portRadius*m_portRadius)
        {
            return HIT_OUTPUT_NODE;
        }
    }
    
    // check whole node
    x = hit.x - m_pos.x;
    y = hit.y - m_pos.y;
    if(x*x + y*y <= m_radius*m_radius)
    {
        return HIT_MAIN_NODE;
    }
    
    return HIT_NONE;
}

void AGAudioNode::unhit()
{
    //m_hitInput = m_hitOutput = false;
}

GLvertex3f AGAudioNode::positionForInboundConnection(AGConnection * connection) const
{
    return GLvertex3f(m_pos.x - m_radius, m_pos.y, m_pos.z);
}

GLvertex3f AGAudioNode::positionForOutboundConnection(AGConnection * connection) const
{
    return GLvertex3f(m_pos.x + m_radius, m_pos.y, m_pos.z);
}


//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------

void AGAudioOutputNode::renderAudio(float *input, float *output, int nFrames)
{
    for(std::list<AGConnection *>::iterator i = m_inbound.begin(); i != m_inbound.end(); i++)
    {
        ((AGAudioNode *)(*i)->src())->renderAudio(input, output, nFrames);
    }
}


//------------------------------------------------------------------------------
// ### AGAudioSineWaveNode ###
//------------------------------------------------------------------------------

void AGAudioSineWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += sinf(m_phase*2.0*M_PI);
        m_phase += m_freq/sampleRate();
        if(m_phase > 1.0) m_phase -= 1.0;
    }
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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());

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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());

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
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());

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


