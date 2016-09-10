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
#import "AGAudioManager.h"
#import "ADSR.h"
#import "DelayA.h"
#import "spstl.h"
#import "AGAudioCapturer.h"
#import "AGCompositeNode.h"
#include "AGCompressorNode.h"
#include "AGStyle.h"


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
        float radius = 0.01*AGStyle::oldGlobalScale;
        for(int i = 0; i < s_geoSize; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(s_geoSize));
            geo[i] = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
        }
        
        genVertexArrayAndBuffer(s_geoSize, geo, s_vertexArray, s_vertexBuffer);
        
        delete[] geo;
        geo = NULL;
    }
}

void AGAudioNode::init()
{
    m_gain = 1;
    
    AGNode::init();
    
    initializeAudioNode();
    
    m_radius = 0.01*AGStyle::oldGlobalScale;
    m_portRadius = 0.01*0.2*AGStyle::oldGlobalScale;
    
    m_lastTime = -1;
    m_outputBuffer.resize(bufferSize());
    m_outputBuffer.clear();
    m_inputPortBuffer = NULL;
    
    allocatePortBuffers();
}

void AGAudioNode::init(const AGDocument::Node &docNode)
{
    m_gain = 1;
    
    AGNode::init(docNode);
    
    initializeAudioNode();
    
    m_radius = 0.01*AGStyle::oldGlobalScale;
    m_portRadius = 0.01*0.2*AGStyle::oldGlobalScale;
    
    m_lastTime = -1;
    m_outputBuffer.resize(bufferSize());
    m_outputBuffer.clear();
    m_inputPortBuffer = NULL;
    
    allocatePortBuffers();
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

//void AGAudioNode::renderAudio(float *input, float *output, int nFrames)
//{
//}

void AGAudioNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
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
    
    color.a = m_fadeOut;
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
    
    glBindVertexArrayOES(0);
    
    AGNode::render();
}

AGInteractiveObject *AGAudioNode::hitTest(const GLvertex3f &t)
{
    if(pointInCircle(t.xy(), m_pos.xy(), m_radius))
        return this;
    
    return _hitTestConnections(t);
}

GLvertex3f AGAudioNode::relativePositionForInputPort(int port) const
{
    int numIn = numInputPorts();
    // compute placement to pack ports side by side on left side
    // thetaI - inner angle of the big circle traversed by 1/2 of the port
    float thetaI = acosf((2*m_radius*m_radius - s_portRadius*s_portRadius) / (2*m_radius*m_radius));
    // thetaStart - position of first port
    float thetaStart = (numIn-1)*thetaI;
    // theta - position of this port
    float theta = thetaStart - 2*thetaI*port;
    // flip horizontally to place on left side
    return GLvertex3f(-m_radius*cosf(theta), m_radius*sinf(theta), 0);
}

GLvertex3f AGAudioNode::relativePositionForOutputPort(int port) const
{
    return GLvertex3f(m_radius, 0, 0);
}

void AGAudioNode::allocatePortBuffers()
{
    if(numInputPorts() > 0)
    {
        m_inputPortBuffer = new float*[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_manifest->inputPortInfo()[i].canConnect)
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

void AGAudioNode::pullInputPorts(sampletime t, int nFrames)
{
    if(t <= m_lastTime) return;
    
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
        AGConnection *conn = *c;
        
        assert(m_inputPortBuffer && m_inputPortBuffer[conn->dstPort()]);
        
        if(conn->rate() == RATE_AUDIO)
        {
            AGAudioRenderer *rndrr = dynamic_cast<AGAudioRenderer *>(conn->src());
            rndrr->renderAudio(t, NULL, m_inputPortBuffer[conn->dstPort()], nFrames);
        }
    }
    
    this->unlock();
}


void AGAudioNode::renderLast(float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++) output[i] += m_outputBuffer[i];
}


//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioOutputNode

AGAudioOutputNode::~AGAudioOutputNode()
{
    if(m_destination)
        m_destination->removeOutput(this);
    m_destination = NULL;
}

void AGAudioOutputNode::setOutputDestination(AGAudioOutputDestination *destination)
{
    if(m_destination)
        m_destination->removeOutput(this);
    
    m_destination = destination;
    
    if(m_destination)
        m_destination->addOutput(this);
}

void AGAudioOutputNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_gain = value; break;
    }
}

void AGAudioOutputNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_gain; break;
    }
}

void AGAudioOutputNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    m_outputBuffer.clear();
    
    for(std::list<AGConnection *>::iterator i = m_inbound.begin(); i != m_inbound.end(); i++)
    {
        if((*i)->rate() == RATE_AUDIO)
            ((AGAudioNode *)(*i)->src())->renderAudio(t, input, m_outputBuffer, nFrames);
    }
    
    for(int i = 0; i < nFrames; i++)
        output[i] = m_outputBuffer[i]*m_gain;
}

//------------------------------------------------------------------------------
// ### AGAudioInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioInputNode

class AGAudioInputNode : public AGAudioNode, public AGAudioCapturer
{
public:
    
    class Manifest : public AGStandardNodeManifest<AGAudioInputNode>
    {
    public:
        string _type() const override { return "Input"; };
        string _name() const override { return "Input"; };
        
        vector<AGPortInfo> _inputPortInfo() const override { return { }; }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", false, true }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.0066*AGStyle::oldGlobalScale;
            
            // arrow/chevron
            vector<GLvertex3f> iconGeo = {
                { -radius*0.3f,  radius, 0 },
                {  radius*0.5f,       0, 0 },
                { -radius*0.3f, -radius, 0 },
                {  radius*0.1f,       0, 0 },
            };
            
            return iconGeo;
        }
        
        GLuint _iconGeoType() const override { return GL_LINE_LOOP; }
    };
    
    using AGAudioNode::AGAudioNode;
    
    void init() override
    {
        AGAudioNode::init();
        
        [[AGAudioManager instance] addCapturer:this];
    }
    
    void init(const AGDocument::Node &docNode) override
    {
        AGAudioNode::init();
        
        [[AGAudioManager instance] addCapturer:this];
    }
    
    virtual ~AGAudioInputNode()
    {
        [[AGAudioManager instance] removeCapturer:this];
    }
    
    void setDefaultPortValues() override
    {
        m_gain = 1;
        
        m_inputSize = 0;
        m_input = NULL;
    }
    
    void setEditPortValue(int port, float value) override
    {
        switch(port)
        {
            case 0: m_gain = value; break;
        }
    }
    
    void getEditPortValue(int port, float &value) const override
    {
        switch(port)
        {
            case 0: value = m_gain; break;
        }
    }
    
    int numOutputPorts() const override { return 1; }
    int numInputPorts() const override { return 0; }
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        // pullInputPorts(t, nFrames);

        if(m_inputSize && m_input)
        {
            float *_outputBuffer = m_outputBuffer.buffer;
            float *_input = m_input;
            int mn = min(nFrames, m_inputSize);
            for(int i = 0; i < mn; i++)
            {
                *_outputBuffer = (*_input++)*m_gain;
                *output++ += *_outputBuffer++;
            }
            
            m_lastTime = t;
        }
    }
    
    void captureAudio(float *input, int numFrames) override
    {
        // pretty hacky
        // TODO: maybe copy this
        m_input = input;
        m_inputSize = numFrames;
    }
    
private:
    int m_inputSize;
    float *m_input;
};

//------------------------------------------------------------------------------
// ### AGAudioSineWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSineWaveNode


class AGAudioSineWaveNode : public AGAudioNode
{
public:
    
    class Manifest : public AGStandardNodeManifest<AGAudioSineWaveNode>
    {
    public:
        string _type() const override { return "SineWave"; };
        string _name() const override { return "SineWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            int NUM_PTS = 32;
            vector<GLvertex3f> iconGeo(NUM_PTS);
            
            float radius = 0.005*AGStyle::oldGlobalScale;
            for(int i = 0; i < NUM_PTS; i++)
            {
                float t = ((float)i)/((float)(NUM_PTS-1));
                float x = (t*2-1) * radius;
                float y = radius*0.66*sinf(t*M_PI*2);
                
                iconGeo[i] = GLvertex3f(x, y, 0);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void setDefaultPortValues() override
    {
        m_freq = 220;
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    float m_freq;
    float m_phase;
};

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
    
    float gain = m_gain;
    float freq = m_freq;
    
    if(m_controlPortBuffer[0]) freq += m_controlPortBuffer[0].getFloat();
    if(m_controlPortBuffer[1]) gain += m_controlPortBuffer[1].getFloat();
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = sinf(m_phase*2.0*M_PI) * (gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];
        
        m_phase += (freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
}

//------------------------------------------------------------------------------
// ### AGAudioSquareWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSquareWaveNode

class AGAudioSquareWaveNode : public AGAudioNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGAudioSquareWaveNode>
    {
    public:
        string _type() const override { return "SquareWave"; };
        string _name() const override { return "SquareWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;

            // square wave shape
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 },
                { -radius_x, radius_y, 0 },
                { 0, radius_y, 0 },
                { 0, -radius_y, 0 },
                { radius_x, -radius_y, 0 },
                { radius_x, 0, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void setDefaultPortValues() override
    {
        m_freq = 220;
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    float m_freq;
    float m_phase;
};

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
    
    float gain = m_gain;
    float freq = m_freq;
    
    if(m_controlPortBuffer[0]) freq += m_controlPortBuffer[0].getFloat();
    if(m_controlPortBuffer[1]) gain += m_controlPortBuffer[1].getFloat();
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = (m_phase < 0.5 ? 1 : -1) * (gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];

        m_phase += (freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
}


//------------------------------------------------------------------------------
// ### AGAudioSawtoothWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSawtoothWaveNode

class AGAudioSawtoothWaveNode : public AGAudioNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGAudioSawtoothWaveNode>
    {
    public:
        string _type() const override { return "SawWave"; };
        string _name() const override { return "SawWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005f*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66f;
            
            // sawtooth wave shape
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 },
                { -radius_x, radius_y, 0 },
                { radius_x, -radius_y, 0 },
                { radius_x, 0, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };

    using AGAudioNode::AGAudioNode;
    
    void setDefaultPortValues() override
    {
        m_freq = 220;
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    float m_freq;
    float m_phase;
};

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
    
    float gain = m_gain;
    float freq = m_freq;
    
    if(m_controlPortBuffer[0]) freq += m_controlPortBuffer[0].getFloat();
    if(m_controlPortBuffer[1]) gain += m_controlPortBuffer[1].getFloat();
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = ((1-m_phase)*2-1)  * (gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];
        
        m_phase += (freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
}


//------------------------------------------------------------------------------
// ### AGAudioTriangleWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioTriangleWaveNode

class AGAudioTriangleWaveNode : public AGAudioNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGAudioTriangleWaveNode>
    {
    public:
        string _type() const override { return "TriWave"; };
        string _name() const override { return "TriWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "freq", true, true },
                { "gain", true, true }
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // sawtooth wave shape
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 },
                { -radius_x*0.5f, radius_y, 0 },
                { radius_x*0.5f, -radius_y, 0 },
                { radius_x, 0, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void setDefaultPortValues() override
    {
        m_freq = 220;
        m_phase = 0;
    }

    virtual int numOutputPorts() const override { return 1; }
    virtual int numInputPorts() const override { return 2; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    float m_freq;
    float m_phase;
};

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
    
    float gain = m_gain;
    float freq = m_freq;
    
    if(m_controlPortBuffer[0]) freq += m_controlPortBuffer[0].getFloat();
    if(m_controlPortBuffer[1]) gain += m_controlPortBuffer[1].getFloat();

    for(int i = 0; i < nFrames; i++)
    {
        if(m_phase < 0.5)
            m_outputBuffer[i] = ((1-m_phase*2)*2-1) * (gain + m_inputPortBuffer[1][i]);
        else
            m_outputBuffer[i] = ((m_phase-0.5)*4-1) * (gain + m_inputPortBuffer[1][i]);
        output[i] += m_outputBuffer[i];

        m_phase += (m_freq + m_inputPortBuffer[0][i])/sampleRate();
        while(m_phase >= 1.0) m_phase -= 1.0;
    }
    
    m_lastTime = t;
}


//------------------------------------------------------------------------------
// ### AGAudioADSRNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioADSRNode

class AGAudioADSRNode : public AGAudioNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGAudioADSRNode>
    {
    public:
        string _type() const override { return "ADSR"; };
        string _name() const override { return "ADSR"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, false },
                { "gain", true, true },
                { "trigger", true, false },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", true, true },
                { "attack", true, true },
                { "decay", true, true },
                { "sustain", true, true },
                { "release", true, true },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // ADSR shape
            vector<GLvertex3f> iconGeo = {
                { -radius_x, -radius_y, 0 },
                { -radius_x*0.75f, radius_y, 0 },
                { -radius_x*0.25f, 0, 0 },
                { radius_x*0.66f, 0, 0 },
                { radius_x, -radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;

    void setDefaultPortValues() override
    {
        m_prevTrigger = FLT_MAX;
        m_attack = 0.01;
        m_decay = 0.01;
        m_sustain = 0.5;
        m_release = 0.1;
        m_adsr.setAllTimes(m_attack, m_decay, m_sustain, m_release);
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    virtual void receiveControl(int port, const AGControl &control) override;
    
private:
    float m_prevTrigger;
    
    float m_attack, m_decay, m_sustain, m_release;
    stk::ADSR m_adsr;
};

void AGAudioADSRNode::setEditPortValue(int port, float value)
{
    bool set = false;
    switch(port)
    {
        case 0: m_gain = value; break;
        case 1: m_attack = value; set = true; break;
        case 2: m_decay = value; set = true; break;
        case 3: m_sustain = value; set = true; break;
        case 4: m_release = value; set = true; break;
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

void AGAudioADSRNode::receiveControl(int port, const AGControl &control)
{
    switch(port)
    {
        case 2:
        {
            int fire = 0;
            control.mapTo(fire);
            if(fire)
                m_adsr.keyOn();
            else
                m_adsr.keyOff();
        }
    }
}


//------------------------------------------------------------------------------
// ### AGAudioFilterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFilterNode

template<class Filter>
class AGAudioFilterFQNode : public AGAudioNode
{
public:
    
    class ManifestLPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2RLPF>>
    {
    public:
        string _type() const override { return "LowPass"; };
        string _name() const override { return "LowPass"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, false },
                { "gain", true, true },
                { "freq", true, true },
                { "Q", true, true },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", true, true },
                { "freq", true, true },
                { "Q", true, true },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // lowpass shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x,  radius_y*0.33f, 0 },
                { -radius_x*0.33f,  radius_y*0.33f, 0 },
                {               0,        radius_y, 0 },
                {  radius_x*0.33f, -radius_y*0.66f, 0 },
                {        radius_x, -radius_y*0.66f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    class ManifestHPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2RHPF>>
    {
    public:
        string _type() const override { return "HiPass"; };
        string _name() const override { return "HiPass"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, false },
                { "gain", true, true },
                { "freq", true, true },
                { "Q", true, true },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", true, true },
                { "freq", true, true },
                { "Q", true, true },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // hipass shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x, -radius_y*0.66f, 0 },
                { -radius_x*0.33f, -radius_y*0.66f, 0 },
                {               0,        radius_y, 0 },
                {  radius_x*0.33f,  radius_y*0.33f, 0 },
                {        radius_x,  radius_y*0.33f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    class ManifestBPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2BPF>>
    {
    public:
        string _type() const override { return "BandPass"; };
        string _name() const override { return "BandPass"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, false },
                { "gain", true, true },
                { "freq", true, true },
                { "Q", true, true },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", true, true },
                { "freq", true, true },
                { "Q", true, true, 0.001, 1000 },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // bandpass shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x, -radius_y*0.50f, 0 },
                { -radius_x*0.33f, -radius_y*0.50f, 0 },
                {               0,        radius_y, 0 },
                {  radius_x*0.33f, -radius_y*0.50f, 0 },
                {        radius_x, -radius_y*0.50f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void init() override
    {
        m_filter = new Filter(sampleRate());
        
        AGAudioNode::init();
    }
    
    void init(const AGDocument::Node &docNode) override
    {
        m_filter = new Filter(sampleRate());
        
        AGAudioNode::init(docNode);
    }
    
    void setDefaultPortValues() override
    {
        m_freq = 220;
        m_Q = 1;
        
        m_filter->set(m_freq, m_Q);
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    float validateEditPortValue(int port, float value) const override
    {
        if(port == 1)
        {
            // freq
            if(value < 0)
                return 0;
            if(value > sampleRate()/2)
                return sampleRate()/2;
            return value;
        }
        
        return AGNode::validateEditPortValue(port, value);
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    Filter *m_filter;
    float m_freq, m_Q;
};

template<class Filter>
void AGAudioFilterFQNode<Filter>::setEditPortValue(int port, float value)
{
    bool set = false;
    
    switch(port)
    {
        case 0: m_gain = value; break;
        case 1: m_freq = value; set = true; break;
        case 2: m_Q = value; set = true; break;
    }
    
    if(set)
    {
        if(m_Q < 0.001) m_Q = 0.001;
        if(m_freq < 0) m_freq = 1;
        if(m_freq > sampleRate()/2) m_freq = sampleRate()/2;
        
        m_filter->set(m_freq, m_Q);
    }
}

template<class Filter>
void AGAudioFilterFQNode<Filter>::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_gain; break;
        case 1: value = m_freq; break;
        case 2: value = m_Q; break;
    }
}

template<class Filter>
void AGAudioFilterFQNode<Filter>::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    for(int i = 0; i < nFrames; i++)
    {
        float gain = m_gain + m_inputPortBuffer[1][i];
        float freq = m_freq + m_inputPortBuffer[2][i];
        float Q = m_Q + m_inputPortBuffer[3][i];
        
        if(freq != m_freq || m_Q != Q)
        {
            if(Q < 0.001) Q = 0.001;
            if(freq < 0) freq = 0;
            if(freq > sampleRate()/2) freq = sampleRate()/2;
            
            m_filter->set(freq, Q);
        }
        
        float samp = gain * m_filter->tick(m_inputPortBuffer[0][i]);
        if(samp == NAN || samp == INFINITY || samp == -INFINITY)
        {
            samp = 0;
            m_filter->clear();
        }
        
        m_outputBuffer[i] = samp;
        output[i] += m_outputBuffer[i];
        
        m_inputPortBuffer[0][i] = 0; // input
        m_inputPortBuffer[1][i] = 0; // gain
        m_inputPortBuffer[2][i] = 0; // freq
        m_inputPortBuffer[3][i] = 0; // Q
    }
    
    m_lastTime = t;
}


//------------------------------------------------------------------------------
// ### AGAudioFeedbackNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFeedbackNode

class AGAudioFeedbackNode : public AGAudioNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGAudioFeedbackNode>
    {
    public:
        string _type() const override { return "Feedback"; };
        string _name() const override { return "Feedback"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, false },
                { "delay", true, true },
                { "feedback", true, true },
                { "gain", true, true },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", true, true },
                { "delay", true, true, 0, AGFloat_Max },
                { "feedback", true, true, 0, 1 },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // ADSR shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x,        radius_y, 0 }, {       -radius_x,        -radius_y, 0 },
                { -radius_x*0.33f,   radius_y*0.5f, 0 }, { -radius_x*0.33f,   -radius_y*0.5f, 0 },
                {  radius_x*0.33f,  radius_y*0.25f, 0 }, {  radius_x*0.33f,  -radius_y*0.25f, 0 },
                {        radius_x, radius_y*0.125f, 0 }, {        radius_x, -radius_y*0.125f, 0 },
                {       -radius_x,               0, 0 }, {        radius_x,                0, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
     using AGAudioNode::AGAudioNode;
    
    virtual void init() override
    {
        AGAudioNode::init();
        
        stk::Stk::setSampleRate(sampleRate());
    }
    
    virtual void init(const AGDocument::Node &docNode) override
    {
        AGAudioNode::init(docNode);
        
        stk::Stk::setSampleRate(sampleRate());
    }
    
    void setDefaultPortValues() override
    {
        m_delayLength = 1;
        m_feedbackGain = 0;
        _setDelay(m_delayLength, true);
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override
    {
        bool set = false;
        switch(port)
        {
            case 0: m_gain = value; break;
            case 1: m_delayLength = value; set = true; break;
            case 2: m_feedbackGain = value; break;
        }
        
        if(set) _setDelay(m_delayLength);
    }
    
    virtual void getEditPortValue(int port, float &value) const override
    {
        switch(port)
        {
            case 0: value = m_gain; break;
            case 1: value = m_delayLength; break;
            case 2: value = m_feedbackGain; break;
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float delayLength = m_delayLength;
        float feedbackGain = m_feedbackGain;
        float gain = m_gain;
        
        // extra semicolon to trick stupid xcode into formatting correctly
        if(m_controlPortBuffer[1]) delayLength += m_controlPortBuffer[1].getFloat();;
        if(m_controlPortBuffer[2]) feedbackGain += m_controlPortBuffer[2].getFloat();;
        if(m_controlPortBuffer[3]) gain += m_controlPortBuffer[3].getFloat();;
        
        for(int i = 0; i < nFrames; i++)
        {
            float input = m_inputPortBuffer[0][i];
            delayLength += m_inputPortBuffer[1][i];
            feedbackGain += m_inputPortBuffer[2][i];
            gain += m_inputPortBuffer[3][i];
            
            _setDelay(delayLength);
            
            float delaySamp = m_delay.tick(input + m_delay.lastOut()*feedbackGain);
            m_outputBuffer[i] = (input + delaySamp)*gain;
            output[i] += m_outputBuffer[i];
        }
    }
    
private:
    
    void _setDelay(float delaySecs, bool force=false)
    {
        if(force || m_currentDelayLength != delaySecs)
        {
            float delaySamps = delaySecs*sampleRate();
            if(delaySamps > m_delay.getMaximumDelay())
            {
                int _max = m_delay.getMaximumDelay();
                while(delaySamps > _max)
                    _max *= 2;
                m_delay.setMaximumDelay(_max);
            }
            m_delay.setDelay(delaySamps);
            m_currentDelayLength = delaySecs;
        }
    }
    
    float m_delayLength, m_currentDelayLength, m_feedbackGain;
    stk::DelayA m_delay;
};


//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGNodeManager

const AGNodeManager &AGNodeManager::audioNodeManager()
{
    if(s_audioNodeManager == NULL)
    {
        s_audioNodeManager = new AGNodeManager();
        
        vector<const AGNodeManifest *> &nodeTypes = s_audioNodeManager->m_nodeTypes;
        
        nodeTypes.push_back(new AGAudioSineWaveNode::Manifest);
        nodeTypes.push_back(new AGAudioSquareWaveNode::Manifest);
        nodeTypes.push_back(new AGAudioSawtoothWaveNode::Manifest);
        nodeTypes.push_back(new AGAudioTriangleWaveNode::Manifest);
        nodeTypes.push_back(new AGAudioADSRNode::Manifest);
        nodeTypes.push_back(new AGAudioFilterFQNode<Butter2RLPF>::ManifestLPF);
        nodeTypes.push_back(new AGAudioFilterFQNode<Butter2RHPF>::ManifestHPF);
        nodeTypes.push_back(new AGAudioFilterFQNode<Butter2BPF>::ManifestBPF);
        nodeTypes.push_back(new AGAudioFeedbackNode::Manifest);
        nodeTypes.push_back(new AGAudioCompressorNode::Manifest);
        nodeTypes.push_back(new AGAudioInputNode::Manifest);
        nodeTypes.push_back(new AGAudioOutputNode::Manifest);
        nodeTypes.push_back(new AGAudioCompositeNode::Manifest);
        
        for(const AGNodeManifest *const &mf : nodeTypes)
            mf->initialize();
    }
    
    return *s_audioNodeManager;
}

