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
#include "AGWaveformAudioNode.h"
#include "AGStyle.h"
#include "spdsp.h"


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
    
    m_renderState.modelview = modelView;
    m_renderState.projection = projection;
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
            float base = 0;
            int paramId = inputPortInfo(i).portId;
            if(m_params.count(paramId))
                base = m_params.at(paramId);
            if(m_controlPortBuffer[i])
                base = m_controlPortBuffer[i].getFloat();
            
            if(m_inputPortBuffer[i] != NULL)
            {
                // memset(m_inputPortBuffer[i], 0, nFrames*sizeof(float));
                
                for(int samp = 0; samp < nFrames; samp++)
                    m_inputPortBuffer[i][samp] = base;
            }
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

void AGAudioNode::finalPortValue(float &value, int portId, int sample) const
{
    int index = m_param2InputPort.at(portId);
    if(m_controlPortBuffer[index])
        value = m_controlPortBuffer[index].getFloat();
    if(sample >= 0)
        value += m_inputPortBuffer[index][sample];
}

void AGAudioNode::renderLast(float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++) output[i] += m_outputBuffer[i];
}

float *AGAudioNode::inputPortVector(int paramId)
{
    return m_inputPortBuffer[m_param2InputPort.at(paramId)];
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

void AGAudioOutputNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    m_outputBuffer.clear();
    
    for(std::list<AGConnection *>::iterator i = m_inbound.begin(); i != m_inbound.end(); i++)
    {
        if((*i)->rate() == RATE_AUDIO)
            ((AGAudioNode *)(*i)->src())->renderAudio(t, input, m_outputBuffer, nFrames);
    }
    
    float gain = param(AUDIO_PARAM_GAIN);
    
    for(int i = 0; i < nFrames; i++)
        output[i] = m_outputBuffer[i]*gain;
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
                { AUDIO_PARAM_GAIN, "gain", false, true, 1, 0, 0, AGPortInfo::LOG }
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
    
    void initFinal() override
    {
        [[AGAudioManager instance] addCapturer:this];
        
        m_inputSize = 0;
        m_input = NULL;
    }
    
    virtual ~AGAudioInputNode()
    {
        [[AGAudioManager instance] removeCapturer:this];
    }
    
    
    int numOutputPorts() const override { return 1; }
    int numInputPorts() const override { return 0; }
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        // pullInputPorts(t, nFrames);
        
        float gain = param(AUDIO_PARAM_GAIN);
        
        if(m_inputSize && m_input)
        {
            float *_outputBuffer = m_outputBuffer.buffer;
            float *_input = m_input;
            int mn = min(nFrames, m_inputSize);
            for(int i = 0; i < mn; i++)
            {
                *_outputBuffer = (*_input++)*gain;
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
    
    enum Param
    {
        PARAM_FREQ = AUDIO_PARAM_LAST+1,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioSineWaveNode>
    {
    public:
        string _type() const override { return "SineWave"; };
        string _name() const override { return "SineWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220, 0, 0, AGPortInfo::LOG },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1, 0, 0, AGPortInfo::LOG }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220, 0, 0, AGPortInfo::LOG },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1, 0, 0, AGPortInfo::LOG }
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
    
    void initFinal() override
    {
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[i] = sinf(m_phase*2.0*M_PI) * gainv[i];
            output[i] += m_outputBuffer[i];
            
            m_phase = clipunit(m_phase + freqv[i]/sampleRate());
        }
        
        m_lastTime = t;
    }
    
private:
    float m_phase;
};

//------------------------------------------------------------------------------
// ### AGAudioSquareWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSquareWaveNode

class AGAudioSquareWaveNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_FREQ = AUDIO_PARAM_LAST+1,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioSquareWaveNode>
    {
    public:
        string _type() const override { return "SquareWave"; };
        string _name() const override { return "SquareWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 }
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
    
    void initFinal() override
    {
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[i] = (m_phase < 0.5 ? 1 : -1) * gainv[i];
            output[i] += m_outputBuffer[i];
            
            m_phase = clipunit(m_phase + freqv[i]/sampleRate());
        }
        
        m_lastTime = t;
    }
    
private:
    float m_phase;
};


//------------------------------------------------------------------------------
// ### AGAudioSawtoothWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSawtoothWaveNode

class AGAudioSawtoothWaveNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_FREQ = AUDIO_PARAM_LAST+1,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioSawtoothWaveNode>
    {
    public:
        string _type() const override { return "SawWave"; };
        string _name() const override { return "SawWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 }
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
    
    void initFinal() override
    {
        m_phase = 0;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[i] = ((1-m_phase)*2-1)  * gainv[i];
            output[i] += m_outputBuffer[i];
            
            m_phase = clipunit(m_phase + freqv[i]/sampleRate());
        }
        
        m_lastTime = t;
    }
    
private:
    float m_phase;
};


//------------------------------------------------------------------------------
// ### AGAudioTriangleWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioTriangleWaveNode

class AGAudioTriangleWaveNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_FREQ = AUDIO_PARAM_LAST+1,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioTriangleWaveNode>
    {
    public:
        string _type() const override { return "TriWave"; };
        string _name() const override { return "TriWave"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true, 220 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 }
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
    
    void initFinal() override
    {
        m_phase = 0;
    }

    virtual int numOutputPorts() const override { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        
        for(int i = 0; i < nFrames; i++)
        {
            if(m_phase < 0.5)
                m_outputBuffer[i] = ((1-m_phase*2)*2-1) * gainv[i];
            else
                m_outputBuffer[i] = ((m_phase-0.5)*4-1) * gainv[i];
            output[i] += m_outputBuffer[i];
            
            m_phase = clipunit(m_phase + freqv[i]/sampleRate());
        }
        
        m_lastTime = t;
    }
    
private:
    float m_phase;
};


//------------------------------------------------------------------------------
// ### AGAudioADSRNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioADSRNode

class AGAudioADSRNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_TRIGGER,
        PARAM_ATTACK,
        PARAM_DECAY,
        PARAM_SUSTAIN,
        PARAM_RELEASE,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioADSRNode>
    {
    public:
        string _type() const override { return "ADSR"; };
        string _name() const override { return "ADSR"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", true, false },
                { AUDIO_PARAM_GAIN, "gain", true, true },
                { PARAM_TRIGGER, "trigger", true, false },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_ATTACK, "attack", true, true, 0.01 },
                { PARAM_DECAY, "decay", true, true, 0.01 },
                { PARAM_SUSTAIN, "sustain", true, true, 0.5 },
                { PARAM_RELEASE, "release", true, true, 0.1 },
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

    void initFinal() override
    {
        m_prevTrigger = FLT_MAX;
        m_adsr.setAllTimes(param(PARAM_ATTACK), param(PARAM_DECAY),
                           param(PARAM_SUSTAIN), param(PARAM_RELEASE));
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        switch(paramId)
        {
            case PARAM_ATTACK:
            case PARAM_DECAY:
            case PARAM_SUSTAIN:
            case PARAM_RELEASE:
                m_adsr.setAllTimes(param(PARAM_ATTACK), param(PARAM_DECAY),
                                   param(PARAM_SUSTAIN), param(PARAM_RELEASE));
                break;
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *triggerv = inputPortVector(PARAM_TRIGGER);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *inputv = inputPortVector(PARAM_INPUT);
        
        for(int i = 0; i < nFrames; i++)
        {
            if(triggerv[i] != m_prevTrigger)
            {
                if(triggerv[i] > 0)
                    m_adsr.keyOn();
                    else
                        m_adsr.keyOff();
                        }
            m_prevTrigger = triggerv[i];
            
            m_outputBuffer[i] = m_adsr.tick() * inputv[i] * gainv[i];
            output[i] += m_outputBuffer[i];
        }
        
        m_lastTime = t;
    }

    virtual void receiveControl(int port, const AGControl &control) override
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
    
private:
    float m_prevTrigger;
    stk::ADSR m_adsr;
};


//------------------------------------------------------------------------------
// ### AGAudioFilterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFilterNode

template<class Filter>
class AGAudioFilterFQNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_Q,
    };
    
    class ManifestLPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2RLPF>>
    {
    public:
        string _type() const override { return "LowPass"; };
        string _name() const override { return "LowPass"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", true, false },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_Q, "Q", true, true, 1, 0.001, 1000 },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_Q, "Q", true, true, 1, 0.001, 1000 },
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
                { PARAM_INPUT, "input", true, false },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_Q, "Q", true, true, 1, 0.001, 1000 },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_Q, "Q", true, true, 1, 0.001, 1000 },
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
                { PARAM_INPUT, "input", true, false },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_Q, "Q", true, true, 1, 0.001, 1000 },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_Q, "Q", true, true, 1, 0.001, 1000 },
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
    
    void initFinal() override
    {
        m_filter = Filter(sampleRate());
        m_filter.set(param(PARAM_FREQ), param(PARAM_Q));
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        switch(paramId)
        {
            case PARAM_FREQ:
            case PARAM_Q:
                m_filter.set(param(PARAM_FREQ), param(PARAM_Q));
                break;
        }
    }
    
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
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        float *qv = inputPortVector(PARAM_Q);
        
        for(int i = 0; i < nFrames; i++)
        {
            float gain = gainv[i];
            float freq = freqv[i];
            float Q = qv[i];
            
            if(freq != param(PARAM_FREQ) || Q != param(PARAM_Q))
            {
                if(Q < 0.001) Q = 0.001;
                if(freq < 0) freq = 0;
                if(freq > sampleRate()/2) freq = sampleRate()/2;
                
                m_filter.set(freq, Q);
            }
            
            float samp = gain * m_filter.tick(inputv[i]);
            if(samp == NAN || samp == INFINITY || samp == -INFINITY)
            {
                samp = 0;
                m_filter.clear();
            }
            
            m_outputBuffer[i] = samp;
            output[i] += m_outputBuffer[i];
        }
        
        m_lastTime = t;
    }

    
private:
    Filter m_filter;
};


//------------------------------------------------------------------------------
// ### AGAudioFeedbackNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFeedbackNode

class AGAudioFeedbackNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_DELAY,
        PARAM_FEEDBACK,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioFeedbackNode>
    {
    public:
        string _type() const override { return "Feedback"; };
        string _name() const override { return "Feedback"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", true, false },
                { PARAM_DELAY, "delay", true, true, 0.5, 0, AGFloat_Max },
                { PARAM_FEEDBACK, "feedback", true, true, 0.1, 0, 1 },
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_DELAY, "delay", true, true, 0.5, 0, AGFloat_Max },
                { PARAM_FEEDBACK, "feedback", true, true, 0.1, 0, 1 },
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
    
    void initFinal() override
    {
        stk::Stk::setSampleRate(sampleRate());
        _setDelay(param(PARAM_DELAY), true);
        m_delay.clear();
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_DELAY)
            _setDelay(param(PARAM_DELAY));
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames); return; }
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *delayLengthv = inputPortVector(PARAM_DELAY);
        float *feedbackGainv = inputPortVector(PARAM_FEEDBACK);
        
        for(int i = 0; i < nFrames; i++)
        {
            _setDelay(delayLengthv[i]);
            
            float delaySamp = m_delay.tick(inputv[i] + m_delay.lastOut()*feedbackGainv[i]);
            m_outputBuffer[i] = (inputv[i] + delaySamp)*gainv[i];
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
                m_delay.clear();
            }
            m_delay.setDelay(delaySamps);
            m_currentDelayLength = delaySecs;
        }
    }
    
    float m_currentDelayLength;
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
        nodeTypes.push_back(new AGAudioWaveformNode::Manifest);
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

