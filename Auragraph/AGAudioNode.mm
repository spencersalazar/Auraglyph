//
//  AGAudioNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGAudioNode.h"
#import "AGNode.h"
#import "SPFilter.h"
#import "AGDef.h"
#import "AGGenericShader.h"

//------------------------------------------------------------------------------
// ### AGAudioNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNode

bool AGAudioNode::s_init = false;
GLuint AGAudioNode::s_vertexArray = 0;
GLuint AGAudioNode::s_vertexBuffer = 0;
GLuint AGAudioNode::s_geoSize = 0;
int AGAudioNode::s_sampleRate = 44100;

void AGAudioNode::initializeAudioNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate circle
        s_geoSize = 64;
        GLvertex3f *geo = new GLvertex3f[s_geoSize];
        float radius = 0.01;
        for(int i = 0; i < s_geoSize; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(s_geoSize));
            geo[i] = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
        }
        
        genVertexArrayAndBuffer(s_geoSize, geo, s_vertexArray, s_vertexBuffer);
        
        delete[] geo;
        geo = NULL;
        
        // initialize audio nodes
        const std::vector<AGAudioNodeManager::AudioNodeType *> &audioNodeTypes = AGAudioNodeManager::instance().audioNodeTypes();
        for(std::vector<AGAudioNodeManager::AudioNodeType *>::const_iterator type = audioNodeTypes.begin(); type != audioNodeTypes.end(); type++)
        {
            if((*type)->initialize)
                (*type)->initialize();
        }
    }
}


AGAudioNode::AGAudioNode(GLvertex3f pos) :
AGNode(pos)
{
    initializeAudioNode();
    
    m_gain = 1;
    
    m_radius = 0.01;
    m_portRadius = 0.01 * 0.2;
    
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
    GLcolor4f color = GLcolor4f::white;
    
    // draw base outline
    glBindVertexArrayOES(s_vertexArray);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setNormalMatrix(m_normalMatrix);

    if(m_activation)
    {
        float scale = 0.975;
        
        GLKMatrix4 projection = projectionMatrix();
        GLKMatrix4 modelView = globalModelViewMatrix();
        
        modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
        GLKMatrix4 modelViewInner = GLKMatrix4Scale(modelView, scale, scale, scale);
        GLKMatrix4 mvp = GLKMatrix4Multiply(projection, modelViewInner);
        shader.setMVPMatrix(mvp);
        
        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
        
        GLKMatrix4 modelViewOuter = GLKMatrix4Scale(modelView, 1.0/scale, 1.0/scale, 1.0/scale);
        mvp = GLKMatrix4Multiply(projection, modelViewOuter);
        shader.setMVPMatrix(mvp);

        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    else
    {
        shader.setMVPMatrix(m_modelViewProjectionMatrix);
        shader.setNormalMatrix(m_normalMatrix);

        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    
    if(numOutputPorts())
    {
        // draw output port
        GLKMatrix4 mvpOutputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, m_radius, 0, 0);
        mvpOutputPort = GLKMatrix4Scale(mvpOutputPort, 0.2, 0.2, 1);
        shader.setMVPMatrix(mvpOutputPort);
        
        if(m_outputActivation > 0)      color = GLcolor4f(0, 1, 0, 1);
        else if(m_outputActivation < 0) color = GLcolor4f(1, 0, 0, 1);
        else                            color = GLcolor4f(1, 1, 1, 1);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
        
        glLineWidth(2.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    
    if(numInputPorts())
    {
        // draw input port
        GLKMatrix4 mvpInputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, -m_radius, 0, 0);
        mvpInputPort = GLKMatrix4Scale(mvpInputPort, 0.2, 0.2, 1);
        shader.setMVPMatrix(mvpInputPort);
        
        if(m_inputActivation > 0)      color = GLcolor4f(0, 1, 0, 1);
        else if(m_inputActivation < 0) color = GLcolor4f(1, 0, 0, 1);
        else                           color = GLcolor4f(1, 1, 1, 1);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
        
        glLineWidth(2.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    
    if(m_nodeInfo)
    {
        shader.setMVPMatrix(m_modelViewProjectionMatrix);
        shader.setNormalMatrix(m_normalMatrix);

        glBindVertexArrayOES(0);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_nodeInfo->iconGeo);
    
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        
        glLineWidth(2.0f);
        glDrawArrays(m_nodeInfo->iconGeoType, 0, m_nodeInfo->iconGeoSize);
    }
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}


AGNode::HitTestResult AGAudioNode::hit(const GLvertex3f &hit)
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

void AGAudioNode::allocatePortBuffers()
{
    if(numInputPorts() > 0)
    {
        m_inputPortBuffer = new float*[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_inputPortInfo[i].canConnect)
            {
                m_inputPortBuffer[i] = new float[bufferSize()];
                memset(m_inputPortBuffer[i], 0, sizeof(float)*bufferSize());
            }
            else
            {
                m_inputPortBuffer[i] = NULL;
            }
        }
    }
    else
    {
        m_inputPortBuffer = NULL;
    }
}

void AGAudioNode::pullInputPorts(int nFrames)
{
    this->lock();
    
    if(m_inputPortBuffer != NULL)
    {
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_inputPortBuffer[i] != NULL)
                memset(m_inputPortBuffer[i], 0, nFrames*sizeof(float));
        }
    }
    
    for(std::list<AGConnection *>::iterator c = m_inbound.begin(); c != m_inbound.end(); c++)
    {
        AGConnection * conn = *c;
        if(conn->rate() == RATE_AUDIO)
        {
            assert(m_inputPortBuffer && m_inputPortBuffer[conn->dstPort()]);
            ((AGAudioNode *) conn->src())->renderAudio(NULL, m_inputPortBuffer[conn->dstPort()], nFrames);
        }
        //else TODO
    }
    
    this->unlock();
}

//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioOutputNode

AGNodeInfo *AGAudioOutputNode::s_audioNodeInfo = NULL;

AGAudioOutputNode::AGAudioOutputNode(GLvertex3f pos) : AGAudioNode(pos)
{
    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
    m_nodeInfo = s_audioNodeInfo;
}

void AGAudioOutputNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    // s_initAudioOutputNode = true;
    
    s_audioNodeInfo->iconGeoSize = 8;
    GLvertex3f *iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius = 0.005;
    
    // speaker icon
    iconGeo[0] = GLvertex3f(-radius*0.5*0.16, radius*0.5, 0);
    iconGeo[1] = GLvertex3f(-radius*0.5, radius*0.5, 0);
    iconGeo[2] = GLvertex3f(-radius*0.5, -radius*0.5, 0);
    iconGeo[3] = GLvertex3f(-radius*0.5*0.16, -radius*0.5, 0);
    iconGeo[4] = GLvertex3f(radius*0.5, -radius, 0);
    iconGeo[5] = GLvertex3f(radius*0.5, radius, 0);
    iconGeo[6] = GLvertex3f(-radius*0.5*0.16, radius*0.5, 0);
    iconGeo[7] = GLvertex3f(-radius*0.5*0.16, -radius*0.5, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->portInfo.push_back({ "input", true, false });
}


void AGAudioOutputNode::renderAudio(float *input, float *output, int nFrames)
{
    for(std::list<AGConnection *>::iterator i = m_inbound.begin(); i != m_inbound.end(); i++)
    {
        ((AGAudioNode *)(*i)->src())->renderAudio(input, output, nFrames);
    }
}

void AGAudioOutputNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_audioNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_audioNodeInfo->iconGeoType, 0, s_audioNodeInfo->iconGeoSize);
}

AGAudioNode *AGAudioOutputNode::create(const GLvertex3f &pos)
{
    return new AGAudioOutputNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioSineWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSineWaveNode

class AGAudioSineWaveNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioSineWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 2; }
    
    virtual void setInputPortValue(int port, float value);
    virtual void getInputPortValue(int port, float &value) const;
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};

AGNodeInfo *AGAudioSineWaveNode::s_audioNodeInfo = NULL;

void AGAudioSineWaveNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 32;
    GLvertex3f *iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius = 0.005;
    for(int i = 0; i < s_audioNodeInfo->iconGeoSize; i++)
    {
        float t = ((float)i)/((float)(s_audioNodeInfo->iconGeoSize-1));
        float x = (t*2-1) * radius;
        float y = radius*0.66*sinf(t*M_PI*2);
        
        iconGeo[i] = GLvertex3f(x, y, 0);
    }
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->portInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->portInfo.push_back({ "gain", true, true });
}

AGAudioSineWaveNode::AGAudioSineWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}

void AGAudioSineWaveNode::setInputPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioSineWaveNode::getInputPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioSineWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    pullInputPorts(nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += sinf(m_phase*2.0*M_PI) * (m_gain + m_inputPortBuffer[1][i]);
        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
}

void AGAudioSineWaveNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_audioNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_audioNodeInfo->iconGeoType, 0, s_audioNodeInfo->iconGeoSize);
}

AGAudioNode *AGAudioSineWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioSineWaveNode(pos);
}

//------------------------------------------------------------------------------
// ### AGAudioSquareWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSquareWaveNode

class AGAudioSquareWaveNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioSquareWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 2; }
    
    virtual void setInputPortValue(int port, float value);
    virtual void getInputPortValue(int port, float &value) const;
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};

AGNodeInfo *AGAudioSquareWaveNode::s_audioNodeInfo = NULL;

void AGAudioSquareWaveNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 6;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005;
    float radius_y = radius_x * 0.66;
    
    // square wave shape
    iconGeo[0] = GLvertex3f(-radius_x, 0, 0);
    iconGeo[1] = GLvertex3f(-radius_x, radius_y, 0);
    iconGeo[2] = GLvertex3f(0, radius_y, 0);
    iconGeo[3] = GLvertex3f(0, -radius_y, 0);
    iconGeo[4] = GLvertex3f(radius_x, -radius_y, 0);
    iconGeo[5] = GLvertex3f(radius_x, 0, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->portInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->portInfo.push_back({ "gain", true, true });
}

AGAudioSquareWaveNode::AGAudioSquareWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}


void AGAudioSquareWaveNode::setInputPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioSquareWaveNode::getInputPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioSquareWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    pullInputPorts(nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += (m_phase < 0.5 ? 1 : -1)  * (m_gain + m_inputPortBuffer[1][i]);
        
        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
}


void AGAudioSquareWaveNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_audioNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_audioNodeInfo->iconGeoType, 0, s_audioNodeInfo->iconGeoSize);
}

AGAudioNode *AGAudioSquareWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioSquareWaveNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioSawtoothWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSawtoothWaveNode

class AGAudioSawtoothWaveNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioSawtoothWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 2; }
    
    virtual void setInputPortValue(int port, float value);
    virtual void getInputPortValue(int port, float &value) const;
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};

AGNodeInfo *AGAudioSawtoothWaveNode::s_audioNodeInfo = NULL;

void AGAudioSawtoothWaveNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 4;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005;
    float radius_y = radius_x * 0.66;
    
    // sawtooth wave shape
    iconGeo[0] = GLvertex3f(-radius_x, 0, 0);
    iconGeo[1] = GLvertex3f(-radius_x, radius_y, 0);
    iconGeo[2] = GLvertex3f(radius_x, -radius_y, 0);
    iconGeo[3] = GLvertex3f(radius_x, 0, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->portInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->portInfo.push_back({ "gain", true, true });
}

AGAudioSawtoothWaveNode::AGAudioSawtoothWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}


void AGAudioSawtoothWaveNode::setInputPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioSawtoothWaveNode::getInputPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioSawtoothWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    pullInputPorts(nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += ((1-m_phase)*2-1)  * (m_gain + m_inputPortBuffer[1][i]);
        
        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
}


void AGAudioSawtoothWaveNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_audioNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_audioNodeInfo->iconGeoType, 0, s_audioNodeInfo->iconGeoSize);
}

AGAudioNode *AGAudioSawtoothWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioSawtoothWaveNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioTriangleWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioTriangleWaveNode

class AGAudioTriangleWaveNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioTriangleWaveNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 2; }
    
    virtual void setInputPortValue(int port, float value);
    virtual void getInputPortValue(int port, float &value) const;
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_freq;
    float m_phase;
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};

AGNodeInfo *AGAudioTriangleWaveNode::s_audioNodeInfo = NULL;

void AGAudioTriangleWaveNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 4;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005;
    float radius_y = radius_x * 0.66;
    
    // sawtooth wave shape
    iconGeo[0] = GLvertex3f(-radius_x, 0, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.5, radius_y, 0);
    iconGeo[2] = GLvertex3f(radius_x*0.5, -radius_y, 0);
    iconGeo[3] = GLvertex3f(radius_x, 0, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->portInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->portInfo.push_back({ "gain", true, true });
}

AGAudioTriangleWaveNode::AGAudioTriangleWaveNode(GLvertex3f pos) : AGAudioNode(pos)
{
    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}


void AGAudioTriangleWaveNode::setInputPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioTriangleWaveNode::getInputPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioTriangleWaveNode::renderAudio(float *input, float *output, int nFrames)
{
    pullInputPorts(nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        if(m_phase < 0.5)
            output[i] += ((1-m_phase*2)*2-1) * (m_gain + m_inputPortBuffer[1][i]);
        else
            output[i] += ((m_phase-0.5)*4-1) * (m_gain + m_inputPortBuffer[1][i]);

        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
}


void AGAudioTriangleWaveNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_audioNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_audioNodeInfo->iconGeoType, 0, s_audioNodeInfo->iconGeoSize);
}


AGAudioNode *AGAudioTriangleWaveNode::create(const GLvertex3f &pos)
{
    return new AGAudioTriangleWaveNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioADSRNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioADSRNode

class AGAudioADSRNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioADSRNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return s_audioNodeInfo->portInfo.size(); }
    
    virtual void setInputPortValue(int port, float value);
    virtual void getInputPortValue(int port, float &value) const;
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    int m_state;
    float m_value;
    float m_increment;
    
    float m_attack, m_decay, m_sustain, m_release;
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};

AGNodeInfo *AGAudioADSRNode::s_audioNodeInfo = NULL;

void AGAudioADSRNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 5;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005;
    float radius_y = radius_x * 0.66;
    
    // ADSR shape
    iconGeo[0] = GLvertex3f(-radius_x, -radius_y, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.75, radius_y, 0);
    iconGeo[2] = GLvertex3f(-radius_x*0.25, 0, 0);
    iconGeo[3] = GLvertex3f(radius_x*0.66, 0, 0);
    iconGeo[4] = GLvertex3f(radius_x, -radius_y, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->portInfo.push_back({ "input", true, false });
    s_audioNodeInfo->portInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->portInfo.push_back({ "trigger", true, false });
    s_audioNodeInfo->portInfo.push_back({ "attack", true, true });
    s_audioNodeInfo->portInfo.push_back({ "decay", true, true });
    s_audioNodeInfo->portInfo.push_back({ "sustain", true, true });
    s_audioNodeInfo->portInfo.push_back({ "release", true, true });
}



AGAudioADSRNode::AGAudioADSRNode(GLvertex3f pos) : AGAudioNode(pos)
{
    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
    m_nodeInfo = s_audioNodeInfo;
    
    allocatePortBuffers();
}


void AGAudioADSRNode::setInputPortValue(int port, float value)
{
    switch(port)
    {
        case 2:
            break;
        case 3:
            m_attack = value/1000.0f;
            break;
        case 4:
            m_decay = value/1000.0f;
            break;
        case 5:
            m_sustain = value/1000.0f;
            break;
        case 6:
            m_release = value/1000.0f;
            break;
    }
}

void AGAudioADSRNode::getInputPortValue(int port, float &value) const
{
    switch(port)
    {
    }
}

void AGAudioADSRNode::renderAudio(float *input, float *output, int nFrames)
{
    pullInputPorts(nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += m_inputPortBuffer[0][i];
        
        m_inputPortBuffer[0][i] = 0;
    }
}


void AGAudioADSRNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_audioNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_audioNodeInfo->iconGeoType, 0, s_audioNodeInfo->iconGeoSize);
}


AGAudioNode *AGAudioADSRNode::create(const GLvertex3f &pos)
{
    return new AGAudioADSRNode(pos);
}


//------------------------------------------------------------------------------
// ### AGAudioFilterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFilterNode

class AGAudioFilterNode : AGAudioNode
{
public:
    static void initialize();
    
    AGAudioFilterNode(GLvertex3f pos, Butter2Filter *filter, AGNodeInfo *nodeInfo);
    ~AGAudioFilterNode();
    
    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return m_nodeInfo->portInfo.size(); }
    
    virtual void setInputPortValue(int port, float value);
    virtual void getInputPortValue(int port, float &value) const;
    
    virtual void renderAudio(float *input, float *output, int nFrames);
    
    static void renderLowPassIcon();
    static AGAudioNode *createLowPass(const GLvertex3f &pos);
    
    static void renderHiPassIcon();
    static AGAudioNode *createHiPass(const GLvertex3f &pos);
    
    static void renderBandPassIcon();
    static AGAudioNode *createBandPass(const GLvertex3f &pos);
    
private:
    Butter2Filter *m_filter;
    float m_freq, m_Q;
    
    static AGNodeInfo *s_lowPassNodeInfo;
    static AGNodeInfo *s_hiPassNodeInfo;
    static AGNodeInfo *s_bandPassNodeInfo;
};

AGNodeInfo *AGAudioFilterNode::s_lowPassNodeInfo = NULL;
AGNodeInfo *AGAudioFilterNode::s_hiPassNodeInfo = NULL;
AGNodeInfo *AGAudioFilterNode::s_bandPassNodeInfo = NULL;

void AGAudioFilterNode::initialize()
{
    /* lowpass node info */
    s_lowPassNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_lowPassNodeInfo->iconGeoSize = 5;
    GLvertex3f * iconGeo = new GLvertex3f[s_lowPassNodeInfo->iconGeoSize];
    s_lowPassNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005;
    float radius_y = radius_x * 0.66;
    
    // lowpass shape
    iconGeo[0] = GLvertex3f(     -radius_x,  radius_y*0.33, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.33,  radius_y*0.33, 0);
    iconGeo[2] = GLvertex3f(             0,       radius_y, 0);
    iconGeo[3] = GLvertex3f( radius_x*0.33, -radius_y*0.66, 0);
    iconGeo[4] = GLvertex3f(      radius_x, -radius_y*0.66, 0);
    
    s_lowPassNodeInfo->iconGeo = iconGeo;
    
    s_lowPassNodeInfo->portInfo.push_back({ "input", true, false });
    s_lowPassNodeInfo->portInfo.push_back({ "gain", true, true });
    s_lowPassNodeInfo->portInfo.push_back({ "freq", true, true });
    s_lowPassNodeInfo->portInfo.push_back({ "Q", true, true });
    
    /* hipass node info */
    s_hiPassNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_hiPassNodeInfo->iconGeoSize = 5;
    iconGeo = new GLvertex3f[s_hiPassNodeInfo->iconGeoSize];
    s_hiPassNodeInfo->iconGeoType = GL_LINE_STRIP;
    radius_x = 0.005;
    radius_y = radius_x * 0.66;
    
    // hipass shape
    iconGeo[0] = GLvertex3f(     -radius_x, -radius_y*0.66, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.33, -radius_y*0.66, 0);
    iconGeo[2] = GLvertex3f(             0,       radius_y, 0);
    iconGeo[3] = GLvertex3f( radius_x*0.33,  radius_y*0.33, 0);
    iconGeo[4] = GLvertex3f(      radius_x,  radius_y*0.33, 0);
    
    s_hiPassNodeInfo->iconGeo = iconGeo;
    
    s_hiPassNodeInfo->portInfo.push_back({ "input", true, false });
    s_hiPassNodeInfo->portInfo.push_back({ "gain", true, true });
    s_hiPassNodeInfo->portInfo.push_back({ "freq", true, true });
    s_hiPassNodeInfo->portInfo.push_back({ "Q", true, true });
    
    /* bandpass node info */
    s_bandPassNodeInfo = new AGNodeInfo;
    
    // generate geometry
    s_bandPassNodeInfo->iconGeoSize = 5;
    iconGeo = new GLvertex3f[s_bandPassNodeInfo->iconGeoSize];
    s_bandPassNodeInfo->iconGeoType = GL_LINE_STRIP;
    radius_x = 0.005;
    radius_y = radius_x * 0.66;
    
    // bandpass shape
    iconGeo[0] = GLvertex3f(     -radius_x, -radius_y*0.50, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.33, -radius_y*0.50, 0);
    iconGeo[2] = GLvertex3f(             0,       radius_y, 0);
    iconGeo[3] = GLvertex3f( radius_x*0.33, -radius_y*0.50, 0);
    iconGeo[4] = GLvertex3f(      radius_x, -radius_y*0.50, 0);
    
    s_bandPassNodeInfo->iconGeo = iconGeo;
    
    s_bandPassNodeInfo->portInfo.push_back({ "input", true, false });
    s_bandPassNodeInfo->portInfo.push_back({ "gain", true, true });
    s_bandPassNodeInfo->portInfo.push_back({ "freq", true, true });
    s_bandPassNodeInfo->portInfo.push_back({ "Q", true, true });
}


AGAudioFilterNode::AGAudioFilterNode(GLvertex3f pos, Butter2Filter *filter, AGNodeInfo *nodeInfo) :
AGAudioNode(pos),
m_filter(filter)
{
    m_inputPortInfo = &nodeInfo->portInfo[0];
    m_nodeInfo = nodeInfo;
    
    allocatePortBuffers();
    
    m_freq = 220;
    m_Q = 1;
    
    filter->set(m_freq, m_Q);
}


AGAudioFilterNode::~AGAudioFilterNode()
{
    SAFE_DELETE(m_filter);
}


void AGAudioFilterNode::setInputPortValue(int port, float value)
{
    bool set = false;
    
    switch(port)
    {
        case 1: m_gain = value; break;
        case 2: m_freq = value; set = true; break;
        case 3: m_Q = value; set = true; break;
    }
    
    if(set) m_filter->set(m_freq, m_Q);
}

void AGAudioFilterNode::getInputPortValue(int port, float &value) const
{
    switch(port)
    {
        case 1: value = m_gain; break;
        case 2: value = m_freq; break;
        case 3: value = m_Q; break;
    }
}

void AGAudioFilterNode::renderAudio(float *input, float *output, int nFrames)
{
    pullInputPorts(nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i] += m_filter->tick(m_inputPortBuffer[0][i]);
        
        m_inputPortBuffer[0][i] = 0;
    }
}


void AGAudioFilterNode::renderLowPassIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_lowPassNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_lowPassNodeInfo->iconGeoType, 0, s_lowPassNodeInfo->iconGeoSize);
}


AGAudioNode *AGAudioFilterNode::createLowPass(const GLvertex3f &pos)
{
    return new AGAudioFilterNode(pos, new Butter2RLPF(sampleRate()), s_lowPassNodeInfo);
}


void AGAudioFilterNode::renderHiPassIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_hiPassNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_hiPassNodeInfo->iconGeoType, 0, s_hiPassNodeInfo->iconGeoSize);
}


AGAudioNode *AGAudioFilterNode::createHiPass(const GLvertex3f &pos)
{
    return new AGAudioFilterNode(pos, new Butter2RHPF(sampleRate()), s_hiPassNodeInfo);
}


void AGAudioFilterNode::renderBandPassIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_bandPassNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_bandPassNodeInfo->iconGeoType, 0, s_bandPassNodeInfo->iconGeoSize);
}


AGAudioNode *AGAudioFilterNode::createBandPass(const GLvertex3f &pos)
{
    return new AGAudioFilterNode(pos, new Butter2BPF(sampleRate()), s_bandPassNodeInfo);
}


//------------------------------------------------------------------------------
// ### AGAudioNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNodeManager

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
    m_audioNodeTypes.push_back(new AudioNodeType("SineWave", AGAudioSineWaveNode::initialize, AGAudioSineWaveNode::renderIcon, AGAudioSineWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("SquareWave", AGAudioSquareWaveNode::initialize, AGAudioSquareWaveNode::renderIcon, AGAudioSquareWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("SawtoothWave", AGAudioSawtoothWaveNode::initialize, AGAudioSawtoothWaveNode::renderIcon, AGAudioSawtoothWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("TriangleWave", AGAudioTriangleWaveNode::initialize, AGAudioTriangleWaveNode::renderIcon, AGAudioTriangleWaveNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("ADSR", AGAudioADSRNode::initialize, AGAudioADSRNode::renderIcon, AGAudioADSRNode::create));
    m_audioNodeTypes.push_back(new AudioNodeType("LowPass", AGAudioFilterNode::initialize, AGAudioFilterNode::renderLowPassIcon, AGAudioFilterNode::createLowPass));
    m_audioNodeTypes.push_back(new AudioNodeType("HiPass", NULL, AGAudioFilterNode::renderHiPassIcon, AGAudioFilterNode::createHiPass));
    m_audioNodeTypes.push_back(new AudioNodeType("BandPass", NULL, AGAudioFilterNode::renderBandPassIcon, AGAudioFilterNode::createBandPass));
    m_audioNodeTypes.push_back(new AudioNodeType("Output", AGAudioOutputNode::initialize, AGAudioOutputNode::renderIcon, AGAudioOutputNode::create));
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


