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
#import "ADSR.h"
#import "spstl.h"
#include "AGStyle.h"


template<class NodeClass>
static AGNode *createAudioNode(const AGDocument::Node &docNode)
{
    NodeClass *node = new NodeClass(docNode);
    node->init();
    return node;
}

template<class NodeClass>
static AGNode *createAudioNode(const GLvertex3f &pos)
{
    NodeClass *node = new NodeClass(pos);
    node->init();
    return node;
}



//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioOutputNode

AGNodeInfo *AGAudioOutputNode::s_audioNodeInfo = NULL;

AGAudioOutputNode::AGAudioOutputNode(GLvertex3f pos) : AGAudioNode(pos, s_audioNodeInfo)
{
    m_nodeInfo = s_audioNodeInfo;
}

AGAudioOutputNode::AGAudioOutputNode(const AGDocument::Node &docNode) : AGAudioNode(docNode, s_audioNodeInfo)
{
    m_nodeInfo = s_audioNodeInfo;
}

void AGAudioOutputNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    // s_initAudioOutputNode = true;
    
    s_audioNodeInfo->type = "Output";
    
    s_audioNodeInfo->iconGeoSize = 8;
    GLvertex3f *iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius = 0.005*AGStyle::oldGlobalScale;
    
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
    
    s_audioNodeInfo->inputPortInfo.push_back({ "input", true, false });
}


void AGAudioOutputNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    for(std::list<AGConnection *>::iterator i = m_inbound.begin(); i != m_inbound.end(); i++)
    {
        ((AGAudioNode *)(*i)->src())->renderAudio(t, input, output, nFrames);
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
    AGAudioOutputNode *node = new AGAudioOutputNode(pos);
    node->init();
    return node;
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
    AGAudioSineWaveNode(const AGDocument::Node &docNode);
    
    virtual int numOutputPorts() const { return 1; }
    
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static AGNodeInfo *nodeInfo() { return s_audioNodeInfo; }
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
    
    s_audioNodeInfo->type = "SineWave";
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 32;
    GLvertex3f *iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius = 0.005*AGStyle::oldGlobalScale;
    for(int i = 0; i < s_audioNodeInfo->iconGeoSize; i++)
    {
        float t = ((float)i)/((float)(s_audioNodeInfo->iconGeoSize-1));
        float x = (t*2-1) * radius;
        float y = radius*0.66*sinf(t*M_PI*2);
        
        iconGeo[i] = GLvertex3f(x, y, 0);
    }
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "gain", true, true });
}

AGAudioSineWaveNode::AGAudioSineWaveNode(GLvertex3f pos) : AGAudioNode(pos, s_audioNodeInfo)
{
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}

AGAudioSineWaveNode::AGAudioSineWaveNode(const AGDocument::Node &docNode) : AGAudioNode(docNode, s_audioNodeInfo)
{
    m_freq = 220;
    m_phase = 0;
    
    loadEditPortValues(docNode);
    allocatePortBuffers();
}

void AGAudioSineWaveNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioSineWaveNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioSineWaveNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    if(m_controlPortBuffer[0] != NULL) m_controlPortBuffer[0]->mapTo(m_freq);
    if(m_controlPortBuffer[1] != NULL) m_controlPortBuffer[1]->mapTo(m_gain);
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = sinf(m_phase*2.0*M_PI) * (m_gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];
        
        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
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
    AGAudioSineWaveNode *node = new AGAudioSineWaveNode(pos);
    node->init();
    return node;
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
    AGAudioSquareWaveNode(const AGDocument::Node &docNode);

    virtual int numOutputPorts() const { return 1; }
    
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static AGNodeInfo *nodeInfo() { return s_audioNodeInfo; }
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
    
    s_audioNodeInfo->type = "SquareWave";
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 6;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005*AGStyle::oldGlobalScale;
    float radius_y = radius_x * 0.66;
    
    // square wave shape
    iconGeo[0] = GLvertex3f(-radius_x, 0, 0);
    iconGeo[1] = GLvertex3f(-radius_x, radius_y, 0);
    iconGeo[2] = GLvertex3f(0, radius_y, 0);
    iconGeo[3] = GLvertex3f(0, -radius_y, 0);
    iconGeo[4] = GLvertex3f(radius_x, -radius_y, 0);
    iconGeo[5] = GLvertex3f(radius_x, 0, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "gain", true, true });
}

AGAudioSquareWaveNode::AGAudioSquareWaveNode(GLvertex3f pos) : AGAudioNode(pos, s_audioNodeInfo)
{
//    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
//    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}

AGAudioSquareWaveNode::AGAudioSquareWaveNode(const AGDocument::Node &docNode) : AGAudioNode(docNode, s_audioNodeInfo)
{
    m_freq = 220;
    m_phase = 0;
    
    loadEditPortValues(docNode);
    allocatePortBuffers();
}


void AGAudioSquareWaveNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioSquareWaveNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioSquareWaveNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    if(m_controlPortBuffer[0] != NULL) m_controlPortBuffer[0]->mapTo(m_freq);
    if(m_controlPortBuffer[1] != NULL) m_controlPortBuffer[1]->mapTo(m_gain);
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = (m_phase < 0.5 ? 1 : -1) * (m_gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];

        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
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
    AGAudioNode *node = new AGAudioSquareWaveNode(pos);
    node->init();
    return node;
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
    AGAudioSawtoothWaveNode(const AGDocument::Node &docNode);

    virtual int numOutputPorts() const { return 1; }
    
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static AGNodeInfo *nodeInfo() { return s_audioNodeInfo; }
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
    
    s_audioNodeInfo->type = "SawWave";
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 4;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005*AGStyle::oldGlobalScale;
    float radius_y = radius_x * 0.66;
    
    // sawtooth wave shape
    iconGeo[0] = GLvertex3f(-radius_x, 0, 0);
    iconGeo[1] = GLvertex3f(-radius_x, radius_y, 0);
    iconGeo[2] = GLvertex3f(radius_x, -radius_y, 0);
    iconGeo[3] = GLvertex3f(radius_x, 0, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "gain", true, true });
}

AGAudioSawtoothWaveNode::AGAudioSawtoothWaveNode(GLvertex3f pos) : AGAudioNode(pos, s_audioNodeInfo)
{
//    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
//    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}

AGAudioSawtoothWaveNode::AGAudioSawtoothWaveNode(const AGDocument::Node &docNode) : AGAudioNode(docNode, s_audioNodeInfo)
{
    m_freq = 220;
    m_phase = 0;
    
    loadEditPortValues(docNode);
    allocatePortBuffers();
}


void AGAudioSawtoothWaveNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioSawtoothWaveNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioSawtoothWaveNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    if(m_controlPortBuffer[0] != NULL) m_controlPortBuffer[0]->mapTo(m_freq);
    if(m_controlPortBuffer[1] != NULL) m_controlPortBuffer[1]->mapTo(m_gain);
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = ((1-m_phase)*2-1)  * (m_gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];
        
        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
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
    AGAudioNode *node = new AGAudioSawtoothWaveNode(pos);
    node->init();
    return node;
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
    AGAudioTriangleWaveNode(const AGDocument::Node &docNode);

    virtual int numOutputPorts() const { return 1; }
    virtual int numInputPorts() const { return 2; }
    
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static AGNodeInfo *nodeInfo() { return s_audioNodeInfo; }
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
    
    s_audioNodeInfo->type = "TriWave";
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 4;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005*AGStyle::oldGlobalScale;
    float radius_y = radius_x * 0.66;
    
    // sawtooth wave shape
    iconGeo[0] = GLvertex3f(-radius_x, 0, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.5, radius_y, 0);
    iconGeo[2] = GLvertex3f(radius_x*0.5, -radius_y, 0);
    iconGeo[3] = GLvertex3f(radius_x, 0, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "gain", true, true });
}

AGAudioTriangleWaveNode::AGAudioTriangleWaveNode(GLvertex3f pos) : AGAudioNode(pos, s_audioNodeInfo)
{
//    m_inputPortInfo = &s_audioNodeInfo->portInfo[0];
//    m_nodeInfo = s_audioNodeInfo;
    
    m_freq = 220;
    m_phase = 0;
    
    allocatePortBuffers();
}

AGAudioTriangleWaveNode::AGAudioTriangleWaveNode(const AGDocument::Node &docNode) : AGAudioNode(docNode, s_audioNodeInfo)
{
    m_freq = 220;
    m_phase = 0;
    
    loadEditPortValues(docNode);
    allocatePortBuffers();
}


void AGAudioTriangleWaveNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_freq = value; break;
        case 1: m_gain = value; break;
    }
}

void AGAudioTriangleWaveNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_freq; break;
        case 1: value = m_gain; break;
    }
}

void AGAudioTriangleWaveNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    if(m_controlPortBuffer[0] != NULL) m_controlPortBuffer[0]->mapTo(m_freq);
    if(m_controlPortBuffer[1] != NULL) m_controlPortBuffer[1]->mapTo(m_gain);
    
    for(int i = 0; i < nFrames; i++)
    {
        if(m_phase < 0.5)
            m_outputBuffer[i] = ((1-m_phase*2)*2-1) * (m_gain + m_inputPortBuffer[1][i]);
        else
            m_outputBuffer[i] = ((m_phase-0.5)*4-1) * (m_gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];

        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
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
    AGAudioNode *node = new AGAudioTriangleWaveNode(pos);
    node->init();
    return node;
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
    AGAudioADSRNode(const AGDocument::Node &docNode);

    virtual int numOutputPorts() const { return 1; }
    
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    virtual void receiveControl(int port, AGControl *control);
    
    static AGNodeInfo *nodeInfo() { return s_audioNodeInfo; }
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    float m_prevTrigger;
    
    float m_attack, m_decay, m_sustain, m_release;
    stk::ADSR m_adsr;
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};

AGNodeInfo *AGAudioADSRNode::s_audioNodeInfo = NULL;

void AGAudioADSRNode::initialize()
{
    s_audioNodeInfo = new AGNodeInfo;
    
    s_audioNodeInfo->type = "ADSR";
    
    // generate geometry
    s_audioNodeInfo->iconGeoSize = 5;
    GLvertex3f * iconGeo = new GLvertex3f[s_audioNodeInfo->iconGeoSize];
    s_audioNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005*AGStyle::oldGlobalScale;
    float radius_y = radius_x * 0.66;
    
    // ADSR shape
    iconGeo[0] = GLvertex3f(-radius_x, -radius_y, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.75, radius_y, 0);
    iconGeo[2] = GLvertex3f(-radius_x*0.25, 0, 0);
    iconGeo[3] = GLvertex3f(radius_x*0.66, 0, 0);
    iconGeo[4] = GLvertex3f(radius_x, -radius_y, 0);
    
    s_audioNodeInfo->iconGeo = iconGeo;
    
    s_audioNodeInfo->inputPortInfo.push_back({ "input", true, false });
    s_audioNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->inputPortInfo.push_back({ "trigger", true, false });
    
    s_audioNodeInfo->editPortInfo.push_back({ "gain", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "attack", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "decay", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "sustain", true, true });
    s_audioNodeInfo->editPortInfo.push_back({ "release", true, true });
}


AGAudioADSRNode::AGAudioADSRNode(GLvertex3f pos) : AGAudioNode(pos, s_audioNodeInfo)
{
    allocatePortBuffers();
    
    m_prevTrigger = FLT_MAX;
    m_attack = 0.01;
    m_decay = 0.01;
    m_sustain = 0.5;
    m_release = 0.1;
    m_adsr.setAllTimes(m_attack, m_decay, m_sustain, m_release);
}

AGAudioADSRNode::AGAudioADSRNode(const AGDocument::Node &docNode) : AGAudioNode(docNode, s_audioNodeInfo)
{
    m_prevTrigger = FLT_MAX;
    m_attack = 0.01;
    m_decay = 0.01;
    m_sustain = 0.5;
    m_release = 0.1;
    m_adsr.setAllTimes(m_attack, m_decay, m_sustain, m_release);
    
    loadEditPortValues(docNode);
    allocatePortBuffers();
}


void AGAudioADSRNode::setEditPortValue(int port, float value)
{
    bool set = false;
    switch(port)
    {
        case 0: m_gain = value; break;
        case 1: m_attack = value/1000.0f; set = true; break;
        case 2: m_decay = value/1000.0f; set = true; break;
        case 3: m_sustain = value/1000.0f; set = true; break;
        case 4: m_release = value/1000.0f; set = true; break;
    }
    
    if(set) m_adsr.setAllTimes(m_attack, m_decay, m_sustain, m_release);
}

void AGAudioADSRNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_gain; break;
        case 1: value = m_attack; break;
        case 2: value = m_decay; break;
        case 3: value = m_sustain; break;
        case 4: value = m_release; break;
    }
}

void AGAudioADSRNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        if(m_inputPortBuffer[2][i] != m_prevTrigger)
        {
            if(m_inputPortBuffer[2][i] > 0)
                m_adsr.keyOn();
            else
                m_adsr.keyOff();
        }
        m_prevTrigger = m_inputPortBuffer[2][i];
        
        m_outputBuffer[i] = m_adsr.tick() * m_inputPortBuffer[0][i];
        output[i] += m_outputBuffer[i];

        m_inputPortBuffer[0][i] = 0;
        m_inputPortBuffer[2][i] = 0;
    }
    
    m_lastTime = t;
}

void AGAudioADSRNode::receiveControl(int port, AGControl *control)
{
    switch(port)
    {
        case 2:
        {
            int fire = 0;
            control->mapTo(fire);
            if(fire)
                m_adsr.keyOn();
            else
                m_adsr.keyOff();
        }
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
    AGAudioNode *node = new AGAudioADSRNode(pos);
    node->init();
    return node;
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
    AGAudioFilterNode(const AGDocument::Node &docNode, Butter2Filter *filter, AGNodeInfo *nodeInfo);
    ~AGAudioFilterNode();
    
    virtual int numOutputPorts() const { return 1; }
    
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static void renderLowPassIcon();
    static AGNode *createLowPass(const GLvertex3f &pos);
    
    static void renderHiPassIcon();
    static AGNode *createHiPass(const GLvertex3f &pos);
    
    static void renderBandPassIcon();
    static AGNode *createBandPass(const GLvertex3f &pos);
    
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
    s_lowPassNodeInfo->type = "LowPass";
    
    // generate geometry
    s_lowPassNodeInfo->iconGeoSize = 5;
    GLvertex3f * iconGeo = new GLvertex3f[s_lowPassNodeInfo->iconGeoSize];
    s_lowPassNodeInfo->iconGeoType = GL_LINE_STRIP;
    float radius_x = 0.005*AGStyle::oldGlobalScale;
    float radius_y = radius_x * 0.66;
    
    // lowpass shape
    iconGeo[0] = GLvertex3f(     -radius_x,  radius_y*0.33, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.33,  radius_y*0.33, 0);
    iconGeo[2] = GLvertex3f(             0,       radius_y, 0);
    iconGeo[3] = GLvertex3f( radius_x*0.33, -radius_y*0.66, 0);
    iconGeo[4] = GLvertex3f(      radius_x, -radius_y*0.66, 0);
    
    s_lowPassNodeInfo->iconGeo = iconGeo;
    
    s_lowPassNodeInfo->inputPortInfo.push_back({ "input", true, false });
    s_lowPassNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_lowPassNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_lowPassNodeInfo->inputPortInfo.push_back({ "Q", true, true });
    
    s_lowPassNodeInfo->editPortInfo.push_back({ "gain", true, true });
    s_lowPassNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_lowPassNodeInfo->editPortInfo.push_back({ "Q", true, true });
    
    /* hipass node info */
    s_hiPassNodeInfo = new AGNodeInfo;
    s_hiPassNodeInfo->type = "HiPass";
    
    // generate geometry
    s_hiPassNodeInfo->iconGeoSize = 5;
    iconGeo = new GLvertex3f[s_hiPassNodeInfo->iconGeoSize];
    s_hiPassNodeInfo->iconGeoType = GL_LINE_STRIP;
    radius_x = 0.005*AGStyle::oldGlobalScale;
    radius_y = radius_x * 0.66;
    
    // hipass shape
    iconGeo[0] = GLvertex3f(     -radius_x, -radius_y*0.66, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.33, -radius_y*0.66, 0);
    iconGeo[2] = GLvertex3f(             0,       radius_y, 0);
    iconGeo[3] = GLvertex3f( radius_x*0.33,  radius_y*0.33, 0);
    iconGeo[4] = GLvertex3f(      radius_x,  radius_y*0.33, 0);
    
    s_hiPassNodeInfo->iconGeo = iconGeo;
    
    s_hiPassNodeInfo->inputPortInfo.push_back({ "input", true, false });
    s_hiPassNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_hiPassNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_hiPassNodeInfo->inputPortInfo.push_back({ "Q", true, true });
    
    s_hiPassNodeInfo->editPortInfo.push_back({ "gain", true, true });
    s_hiPassNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_hiPassNodeInfo->editPortInfo.push_back({ "Q", true, true });
    
    /* bandpass node info */
    s_bandPassNodeInfo = new AGNodeInfo;
    s_bandPassNodeInfo->type = "BandPass";
    
    // generate geometry
    s_bandPassNodeInfo->iconGeoSize = 5;
    iconGeo = new GLvertex3f[s_bandPassNodeInfo->iconGeoSize];
    s_bandPassNodeInfo->iconGeoType = GL_LINE_STRIP;
    radius_x = 0.005*AGStyle::oldGlobalScale;
    radius_y = radius_x * 0.66;
    
    // bandpass shape
    iconGeo[0] = GLvertex3f(     -radius_x, -radius_y*0.50, 0);
    iconGeo[1] = GLvertex3f(-radius_x*0.33, -radius_y*0.50, 0);
    iconGeo[2] = GLvertex3f(             0,       radius_y, 0);
    iconGeo[3] = GLvertex3f( radius_x*0.33, -radius_y*0.50, 0);
    iconGeo[4] = GLvertex3f(      radius_x, -radius_y*0.50, 0);
    
    s_bandPassNodeInfo->iconGeo = iconGeo;
    
    s_bandPassNodeInfo->inputPortInfo.push_back({ "input", true, false });
    s_bandPassNodeInfo->inputPortInfo.push_back({ "gain", true, true });
    s_bandPassNodeInfo->inputPortInfo.push_back({ "freq", true, true });
    s_bandPassNodeInfo->inputPortInfo.push_back({ "Q", true, true });
    
    s_bandPassNodeInfo->editPortInfo.push_back({ "gain", true, true });
    s_bandPassNodeInfo->editPortInfo.push_back({ "freq", true, true });
    s_bandPassNodeInfo->editPortInfo.push_back({ "Q", true, true });
}


AGAudioFilterNode::AGAudioFilterNode(GLvertex3f pos, Butter2Filter *filter, AGNodeInfo *nodeInfo) :
AGAudioNode(pos, nodeInfo),
m_filter(filter)
{
    allocatePortBuffers();
    
    m_freq = 220;
    m_Q = 1;
    
    filter->set(m_freq, m_Q);
}

AGAudioFilterNode::AGAudioFilterNode(const AGDocument::Node &docNode, Butter2Filter *filter, AGNodeInfo *nodeInfo) :
AGAudioNode(docNode, nodeInfo),
m_filter(filter)
{
    m_freq = 220;
    m_Q = 1;
    
    filter->set(m_freq, m_Q);
    
    loadEditPortValues(docNode);
    allocatePortBuffers();
}


AGAudioFilterNode::~AGAudioFilterNode()
{
    SAFE_DELETE(m_filter);
}


void AGAudioFilterNode::setEditPortValue(int port, float value)
{
    bool set = false;
    
    switch(port)
    {
        case 0: m_gain = value; break;
        case 1: m_freq = value; set = true; break;
        case 2: m_Q = value; set = true; break;
    }
    
    if(set) m_filter->set(m_freq, m_Q);
}

void AGAudioFilterNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_gain; break;
        case 1: value = m_freq; break;
        case 2: value = m_Q; break;
    }
}

void AGAudioFilterNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        float gain = m_gain + m_inputPortBuffer[1][i];
        float freq = m_freq + m_inputPortBuffer[2][i];
        float Q = m_Q + m_inputPortBuffer[3][i];
        
        if(freq != m_freq || m_Q != Q)
            m_filter->set(freq, Q);
        
        m_outputBuffer[i] = gain * m_filter->tick(m_inputPortBuffer[0][i]);
        output[i] += m_outputBuffer[i];
        
        m_inputPortBuffer[0][i] = 0; // input
        m_inputPortBuffer[1][i] = 0; // gain
        m_inputPortBuffer[2][i] = 0; // freq
        m_inputPortBuffer[3][i] = 0; // Q
    }
    
    m_lastTime = t;
}


void AGAudioFilterNode::renderLowPassIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_lowPassNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_lowPassNodeInfo->iconGeoType, 0, s_lowPassNodeInfo->iconGeoSize);
}


AGNode *AGAudioFilterNode::createLowPass(const GLvertex3f &pos)
{
    AGAudioNode *node = new AGAudioFilterNode(pos, new Butter2RLPF(sampleRate()), s_lowPassNodeInfo);
    node->init();
    return node;
}


void AGAudioFilterNode::renderHiPassIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_hiPassNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_hiPassNodeInfo->iconGeoType, 0, s_hiPassNodeInfo->iconGeoSize);
}


AGNode *AGAudioFilterNode::createHiPass(const GLvertex3f &pos)
{
    AGAudioNode *node = new AGAudioFilterNode(pos, new Butter2RHPF(sampleRate()), s_hiPassNodeInfo);
    node->init();
    return node;
}


void AGAudioFilterNode::renderBandPassIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_bandPassNodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_bandPassNodeInfo->iconGeoType, 0, s_bandPassNodeInfo->iconGeoSize);
}


AGNode *AGAudioFilterNode::createBandPass(const GLvertex3f &pos)
{
    AGAudioNode *node = new AGAudioFilterNode(pos, new Butter2BPF(sampleRate()), s_bandPassNodeInfo);
    node->init();
    return node;
}


//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark AGNodeManager -

const AGNodeManager &AGNodeManager::audioNodeManager()
{
    if(s_audioNodeManager == NULL)
    {
        s_audioNodeManager = new AGNodeManager();
        
        // s_audioNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGSliderNode>("Slider"));
        
        s_audioNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGAudioSineWaveNode>("SineWave"));
        s_audioNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGAudioSquareWaveNode>("SquareWave"));
        s_audioNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGAudioSawtoothWaveNode>("SawtoothWave"));
        s_audioNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGAudioTriangleWaveNode>("TriangleWave"));
        s_audioNodeManager->m_nodeTypes.push_back(makeNodeInfo<AGAudioADSRNode>("ADSR"));
        s_audioNodeManager->m_nodeTypes.push_back(new NodeInfo("LowPass",
                                                               AGAudioFilterNode::initialize,
                                                               AGAudioFilterNode::renderLowPassIcon,
                                                               AGAudioFilterNode::createLowPass,
                                                               NULL));
        s_audioNodeManager->m_nodeTypes.push_back(new NodeInfo("HiPass",
                                                               NULL,
                                                               AGAudioFilterNode::renderHiPassIcon,
                                                               AGAudioFilterNode::createHiPass,
                                                               NULL));
        s_audioNodeManager->m_nodeTypes.push_back(new NodeInfo("BandPass",
                                                               NULL,
                                                               AGAudioFilterNode::renderBandPassIcon,
                                                               AGAudioFilterNode::createBandPass,
                                                               NULL));
        s_audioNodeManager->m_nodeTypes.push_back(new NodeInfo("Output",
                                                               AGAudioOutputNode::initialize,
                                                               AGAudioOutputNode::renderIcon,
                                                               createAudioNode<AGAudioOutputNode>,
                                                               createAudioNode<AGAudioOutputNode>));
        
        itmap(s_audioNodeManager->m_nodeTypes, ^bool (NodeInfo *const &type){
            if(type->initialize)
                type->initialize();
            return true;
        });
    }
    
    return *s_audioNodeManager;
}

