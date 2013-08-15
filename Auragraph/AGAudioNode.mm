//
//  AGAudioNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "AGNode.h"


bool AGAudioNode::s_init = false;
GLuint AGAudioNode::s_vertexArray = 0;
GLuint AGAudioNode::s_vertexBuffer = 0;
GLvncprimf *AGAudioNode::s_geo = NULL;
GLuint AGAudioNode::s_geoSize = 0;
int AGAudioNode::s_sampleRate = 44100;

bool AGAudioOutputNode::s_initAudioOutputNode = false;
GLuint AGAudioOutputNode::s_iconVertexArray = 0;
GLuint AGAudioOutputNode::s_iconVertexBuffer = 0;
GLuint AGAudioOutputNode::s_iconGeoSize = 0;
GLvncprimf * AGAudioOutputNode::s_iconGeo = NULL;
GLuint AGAudioOutputNode::s_iconGeoType = 0; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
AGPortInfo * AGAudioOutputNode::s_portInfo = NULL;

bool AGAudioSineWaveNode::s_initAudioSineWaveNode = false;
GLuint AGAudioSineWaveNode::s_iconVertexArray = 0;
GLuint AGAudioSineWaveNode::s_iconVertexBuffer = 0;
GLuint AGAudioSineWaveNode::s_iconGeoSize = 0;
GLvncprimf * AGAudioSineWaveNode::s_iconGeo = NULL;
GLuint AGAudioSineWaveNode::s_iconGeoType = 0; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
AGPortInfo * AGAudioSineWaveNode::s_portInfo = NULL;

bool AGAudioSquareWaveNode::s_initAudioSquareWaveNode = false;
GLuint AGAudioSquareWaveNode::s_iconVertexArray = 0;
GLuint AGAudioSquareWaveNode::s_iconVertexBuffer = 0;
GLuint AGAudioSquareWaveNode::s_iconGeoSize = 0;
GLvncprimf * AGAudioSquareWaveNode::s_iconGeo = NULL;
GLuint AGAudioSquareWaveNode::s_iconGeoType = 0; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
AGPortInfo * AGAudioSquareWaveNode::s_portInfo = NULL;

bool AGAudioSawtoothWaveNode::s_initAudioSawtoothWaveNode = false;
GLuint AGAudioSawtoothWaveNode::s_iconVertexArray = 0;
GLuint AGAudioSawtoothWaveNode::s_iconVertexBuffer = 0;
GLuint AGAudioSawtoothWaveNode::s_iconGeoSize = 0;
GLvncprimf * AGAudioSawtoothWaveNode::s_iconGeo = NULL;
GLuint AGAudioSawtoothWaveNode::s_iconGeoType = 0; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
AGPortInfo * AGAudioSawtoothWaveNode::s_portInfo = NULL;

bool AGAudioTriangleWaveNode::s_initAudioTriangleWaveNode = false;
GLuint AGAudioTriangleWaveNode::s_iconVertexArray = 0;
GLuint AGAudioTriangleWaveNode::s_iconVertexBuffer = 0;
GLuint AGAudioTriangleWaveNode::s_iconGeoSize = 0;
GLvncprimf * AGAudioTriangleWaveNode::s_iconGeo = NULL;
GLuint AGAudioTriangleWaveNode::s_iconGeoType = 0; // e.g. GL_LINE_STRIP, GL_LINE_LOOP, etc.
AGPortInfo * AGAudioTriangleWaveNode::s_portInfo = NULL;


//------------------------------------------------------------------------------
// ### AGAudioNode ###
//------------------------------------------------------------------------------
#pragma mark AGAudioNode

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
        }
        
        genVertexArrayAndBuffer(s_geoSize, s_geo, s_vertexArray, s_vertexBuffer);
    }
}

AGAudioNode::AGAudioNode(GLvertex3f pos) :
AGNode(pos)
{
    initializeAudioNode();
    
    m_radius = 0.01;
    m_portRadius = 0.01 * 0.2;
    
    m_inputActivation = m_outputActivation = 0;
    
    m_iconVertexArray = 0;
    m_iconGeoSize = 0;
    m_iconGeoType = 0;
    
    m_inputPortBuffer = NULL;
}

AGAudioNode::~AGAudioNode()
{
    if(m_inputPortBuffer)
    {
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_inputPortBuffer[i])
            {
                delete[] m_inputPortBuffer[i];
                m_inputPortBuffer[i] = NULL;
            }
        }
        
        delete[] m_inputPortBuffer;
        m_inputPortBuffer = NULL;
    }
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
    
    // render icon
    if(m_iconVertexArray)
    {
        // draw base outline
        glBindVertexArrayOES(m_iconVertexArray);
        
        glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
        glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
        glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());

        glLineWidth(2.0f);
        glDrawArrays(m_iconGeoType, 0, m_iconGeoSize);
    }
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
#pragma mark AGAudioOutputNode

void AGAudioOutputNode::initializeAudioOutputNode()
{
    initializeAudioNode();
    
    if(!s_initAudioOutputNode)
    {
        s_initAudioOutputNode = true;
        
        s_iconGeoSize = 8;
        s_iconGeo = new GLvncprimf[s_iconGeoSize];
        s_iconGeoType = GL_LINE_STRIP;
        float radius = 0.005;
        
        // speaker icon
        s_iconGeo[0].vertex = GLvertex3f(-radius*0.5*0.16, radius*0.5, 0);
        s_iconGeo[1].vertex = GLvertex3f(-radius*0.5, radius*0.5, 0);
        s_iconGeo[2].vertex = GLvertex3f(-radius*0.5, -radius*0.5, 0);
        s_iconGeo[3].vertex = GLvertex3f(-radius*0.5*0.16, -radius*0.5, 0);
        s_iconGeo[4].vertex = GLvertex3f(radius*0.5, -radius, 0);
        s_iconGeo[5].vertex = GLvertex3f(radius*0.5, radius, 0);
        s_iconGeo[6].vertex = GLvertex3f(-radius*0.5*0.16, radius*0.5, 0);
        s_iconGeo[7].vertex = GLvertex3f(-radius*0.5*0.16, -radius*0.5, 0);
        
        genVertexArrayAndBuffer(s_iconGeoSize, s_iconGeo, s_iconVertexArray, s_iconVertexBuffer);
        
        s_portInfo = new AGPortInfo[1];
        s_portInfo[0] = { "input", true, false };
    }
}


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
#pragma mark AGAudioSineWaveNode

void AGAudioSineWaveNode::initializeAudioSineWaveNode()
{
    initializeAudioNode();
    
    if(!s_initAudioSineWaveNode)
    {
        s_initAudioSineWaveNode = true;
        
        // generate geometry
        s_iconGeoSize = 32;
        s_iconGeo = new GLvncprimf[s_iconGeoSize];
        s_iconGeoType = GL_LINE_STRIP;
        float radius = 0.005;
        for(int i = 0; i < s_iconGeoSize; i++)
        {
            float t = ((float)i)/((float)(s_iconGeoSize-1));
            float x = (t*2-1) * radius;
            float y = radius*0.66*sinf(t*M_PI*2);
            
            s_iconGeo[i].vertex = GLvertex3f(x, y, 0);
        }
        
        genVertexArrayAndBuffer(s_iconGeoSize, s_iconGeo, s_iconVertexArray, s_iconVertexBuffer);
        
        s_portInfo = new AGPortInfo[2];
        s_portInfo[0] = { "freq", true, true };
        s_portInfo[1] = { "gain", true, true };
    }
}

AGAudioSineWaveNode::AGAudioSineWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    initializeAudioSineWaveNode();
    
    m_inputPortInfo = s_portInfo;
    
    m_iconVertexArray = s_iconVertexArray;
    m_iconGeoSize = s_iconGeoSize;
    m_iconGeoType = s_iconGeoType;
    
    m_freq = 220;
    m_phase = 0;
    
    if(numInputPorts() > 0)
    {
        m_inputPortBuffer = new float*[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
        {
            // TODO: allocate on demand
            m_inputPortBuffer[i] = new float[bufferSize()];
            memset(m_inputPortBuffer[i], 0, sizeof(float)*bufferSize());
        }
    }
    else
    {
        m_inputPortBuffer = NULL;
    }
}

void AGAudioSineWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    for(std::list<AGConnection *>::iterator c = m_inbound.begin(); c != m_inbound.end(); c++)
    {
        AGConnection * conn = *c;
        if(conn->rate() == RATE_AUDIO)
        {
            ((AGAudioNode *) conn->src())->renderAudio(input, m_inputPortBuffer[conn->dstPort()], nFrames);
        }
        //else TODO
    }
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += sinf(m_phase*2.0*M_PI) * (1 + m_inputPortBuffer[1][i]);
        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        if(m_phase > 1.0) m_phase -= 1.0;
    }
}

void AGAudioSineWaveNode::renderIcon()
{
    initializeAudioSineWaveNode();
    
    // render icon
    glBindVertexArrayOES(s_iconVertexArray);
    
    glDrawArrays(s_iconGeoType, 0, s_iconGeoSize);
}

AGAudioNode *AGAudioSineWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioSineWaveNode(pos);
}

//------------------------------------------------------------------------------
// ### AGAudioSquareWaveNode ###
//------------------------------------------------------------------------------
#pragma mark AGAudioSquareWaveNode

void AGAudioSquareWaveNode::initializeAudioSquareWaveNode()
{
    initializeAudioNode();
    
    if(!s_initAudioSquareWaveNode)
    {
        s_initAudioSquareWaveNode = true;
        
        // generate geometry
        s_iconGeoSize = 6;
        s_iconGeo = new GLvncprimf[s_iconGeoSize];
        s_iconGeoType = GL_LINE_STRIP;
        float radius_x = 0.005;
        float radius_y = radius_x * 0.66;
        
        // square wave shape
        s_iconGeo[0].vertex = GLvertex3f(-radius_x, 0, 0);
        s_iconGeo[1].vertex = GLvertex3f(-radius_x, radius_y, 0);
        s_iconGeo[2].vertex = GLvertex3f(0, radius_y, 0);
        s_iconGeo[3].vertex = GLvertex3f(0, -radius_y, 0);
        s_iconGeo[4].vertex = GLvertex3f(radius_x, -radius_y, 0);
        s_iconGeo[5].vertex = GLvertex3f(radius_x, 0, 0);
        
        genVertexArrayAndBuffer(s_iconGeoSize, s_iconGeo, s_iconVertexArray, s_iconVertexBuffer);
        
        s_portInfo = new AGPortInfo[2];
        s_portInfo[0] = { "freq", true, true };
        s_portInfo[1] = { "gain", true, true };
    }
}

AGAudioSquareWaveNode::AGAudioSquareWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    initializeAudioSquareWaveNode();
    
    m_inputPortInfo = s_portInfo;
    
    m_iconVertexArray = s_iconVertexArray;
    m_iconGeoSize = s_iconGeoSize;
    m_iconGeoType = s_iconGeoType;
    
    m_freq = 220;
    m_phase = 0;
}


void AGAudioSquareWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += m_phase < 0.5 ? 1 : -1;
        
        m_phase += m_freq/sampleRate();
        if(m_phase >= 1.0) m_phase -= 1.0;
    }
}


void AGAudioSquareWaveNode::renderIcon()
{
    initializeAudioSquareWaveNode();
    
    // render icon
    glBindVertexArrayOES(s_iconVertexArray);
    
    glDrawArrays(s_iconGeoType, 0, s_iconGeoSize);
}

AGAudioNode *AGAudioSquareWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioSquareWaveNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioSawtoothWaveNode ###
//------------------------------------------------------------------------------
#pragma mark AGAudioSawtoothWaveNode

void AGAudioSawtoothWaveNode::initializeAudioSawtoothWaveNode()
{
    initializeAudioNode();
    
    if(!s_initAudioSawtoothWaveNode)
    {
        s_initAudioSawtoothWaveNode = true;
        
        // generate geometry
        s_iconGeoSize = 4;
        s_iconGeo = new GLvncprimf[s_iconGeoSize];
        s_iconGeoType = GL_LINE_STRIP;
        float radius_x = 0.005;
        float radius_y = radius_x * 0.66;
        
        // sawtooth wave shape
        s_iconGeo[0].vertex = GLvertex3f(-radius_x, 0, 0);
        s_iconGeo[1].vertex = GLvertex3f(-radius_x, radius_y, 0);
        s_iconGeo[2].vertex = GLvertex3f(radius_x, -radius_y, 0);
        s_iconGeo[3].vertex = GLvertex3f(radius_x, 0, 0);
        
        genVertexArrayAndBuffer(s_iconGeoSize, s_iconGeo, s_iconVertexArray, s_iconVertexBuffer);
        
        s_portInfo = new AGPortInfo[2];
        s_portInfo[0] = { "freq", true, true };
        s_portInfo[1] = { "gain", true, true };
    }
}

AGAudioSawtoothWaveNode::AGAudioSawtoothWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    initializeAudioSawtoothWaveNode();
    
    m_inputPortInfo = s_portInfo;
    
    m_iconVertexArray = s_iconVertexArray;
    m_iconGeoSize = s_iconGeoSize;
    m_iconGeoType = s_iconGeoType;
    
    m_freq = 220;
    m_phase = 0;
}


void AGAudioSawtoothWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += (1-m_phase)*2-1;
        
        m_phase += m_freq/sampleRate();
        if(m_phase >= 1.0) m_phase -= 1.0;
    }
}


void AGAudioSawtoothWaveNode::renderIcon()
{
    initializeAudioSawtoothWaveNode();
    
    // render icon
    glBindVertexArrayOES(s_iconVertexArray);
    
    glDrawArrays(s_iconGeoType, 0, s_iconGeoSize);
}

AGAudioNode *AGAudioSawtoothWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioSawtoothWaveNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioTriangleWaveNode ###
//------------------------------------------------------------------------------
#pragma mark AGAudioTriangleWaveNode

void AGAudioTriangleWaveNode::initializeAudioTriangleWaveNode()
{
    initializeAudioNode();
    
    if(!s_initAudioTriangleWaveNode)
    {
        s_initAudioTriangleWaveNode = true;
        
        // generate geometry
        s_iconGeoSize = 4;
        s_iconGeo = new GLvncprimf[s_iconGeoSize];
        s_iconGeoType = GL_LINE_STRIP;
        float radius_x = 0.005;
        float radius_y = radius_x * 0.66;
        
        // sawtooth wave shape
        s_iconGeo[0].vertex = GLvertex3f(-radius_x, 0, 0);
        s_iconGeo[1].vertex = GLvertex3f(-radius_x*0.5, radius_y, 0);
        s_iconGeo[2].vertex = GLvertex3f(radius_x*0.5, -radius_y, 0);
        s_iconGeo[3].vertex = GLvertex3f(radius_x, 0, 0);
        
        genVertexArrayAndBuffer(s_iconGeoSize, s_iconGeo, s_iconVertexArray, s_iconVertexBuffer);
        
        s_portInfo = new AGPortInfo[2];
        s_portInfo[0] = { "freq", true, true };
        s_portInfo[1] = { "gain", true, true };
    }
}

AGAudioTriangleWaveNode::AGAudioTriangleWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    initializeAudioTriangleWaveNode();
    
    m_inputPortInfo = s_portInfo;
    
    m_iconVertexArray = s_iconVertexArray;
    m_iconGeoSize = s_iconGeoSize;
    m_iconGeoType = s_iconGeoType;
    
    m_freq = 220;
    m_phase = 0;
}


void AGAudioTriangleWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++)
    {
        if(m_phase < 0.5)
            output[i] += (1-m_phase*2)*2-1;
        else
            output[i] += (m_phase-0.5)*4-1;
        
        m_phase += m_freq/sampleRate();
        if(m_phase >= 1.0) m_phase -= 1.0;
    }
}


void AGAudioTriangleWaveNode::renderIcon()
{
    initializeAudioTriangleWaveNode();
    
    // render icon
    glBindVertexArrayOES(s_iconVertexArray);
    
    glDrawArrays(s_iconGeoType, 0, s_iconGeoSize);
}


AGAudioNode *AGAudioTriangleWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioTriangleWaveNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioNodeManager ###
//------------------------------------------------------------------------------
#pragma mark AGAudioNodeManager

AGAudioNodeManager *AGAudioNodeManager::s_instance = NULL;

const AGAudioNodeManager &AGAudioNodeManager::instance()
{
    if(s_instance == NULL)
    {
        s_instance = new AGAudioNodeManager();
    }
    
    return *s_instance;
}

AGAudioNodeManager::AGAudioNodeManager()
{
    m_audioNodeTypes.push_back(new AudioNodeType("SineWave", AGAudioSineWaveNode::renderIcon, AGAudioSineWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("SquareWave", AGAudioSquareWaveNode::renderIcon, AGAudioSquareWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("SawtoothWave", AGAudioSawtoothWaveNode::renderIcon, AGAudioSawtoothWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("SquareWave", AGAudioTriangleWaveNode::renderIcon, AGAudioTriangleWaveNode::create));
}

const std::vector<AGAudioNodeManager::AudioNodeType *> &AGAudioNodeManager::audioNodeTypes() const
{
    return m_audioNodeTypes;
}

void AGAudioNodeManager::renderNodeTypeIcon(AudioNodeType *type) const
{
    type->renderIcon();
}

AGAudioNode * AGAudioNodeManager::createNodeType(AudioNodeType *type, const GLvertex3f &pos) const
{
    return type->createNode(pos);
}


