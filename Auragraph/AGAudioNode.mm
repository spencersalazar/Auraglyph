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
#include "FileWvIn.h"
#include "AGCompressorNode.h"
#include "AGWaveformAudioNode.h"
#include "AGMatrixMixerNode.h"
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

    m_outputBuffer.clear();
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
    GLcolor4f color = AGStyle::foregroundColor();
    
    // draw base outline
    glBindVertexArrayOES(s_vertexArray);
    
    color.a = m_fadeOut;
    glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    
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
    int numOut = numOutputPorts();
    // compute placement to pack ports side by side on left side
    // thetaI - inner angle of the big circle traversed by 1/2 of the port
    float thetaI = acosf((2*m_radius*m_radius - s_portRadius*s_portRadius) / (2*m_radius*m_radius));
    // thetaStart - position of first port
    float thetaStart = (numOut-1)*thetaI;
    // theta - position of this port
    float theta = thetaStart - 2*thetaI*port;
    // flip horizontally to place on left side
    return GLvertex3f(m_radius*cosf(theta), m_radius*sinf(theta), 0);
}

void AGAudioNode::allocatePortBuffers()
{
    if(numInputPorts() > 0)
    {
        m_inputPortBuffer = new float*[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
        {
            m_inputPortBuffer[i] = new float[bufferSize()];
            memset(m_inputPortBuffer[i], 0, sizeof(float)*bufferSize());
        }
    }
    else
    {
        m_inputPortBuffer = NULL;
    }
    
    m_outputBuffer.clear();
    m_outputBuffer.resize(numOutputPorts());
    for(int i = 0; i < numOutputPorts(); i++)
    {
        m_outputBuffer[i].resize(bufferSize());
        m_outputBuffer[i].clear();
    }

}

void AGAudioNode::pullInputPorts(sampletime t, int nFrames)
{
//    if(t <= m_lastTime) return;
    
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
            AGAudioNode *node = dynamic_cast<AGAudioNode *>(rndrr);
            if(node)
                dbgprint_off("rendering '%s'\n", node->title().c_str());
            rndrr->renderAudio(t, NULL, m_inputPortBuffer[conn->dstPort()], nFrames, conn->srcPort(), conn->src()->numOutputPorts());
        }
    }
    
    this->unlock();
}

void AGAudioNode::pullPortInput(int portId, int num, sampletime t, float *output, int nFrames)
{
    if(m_param2InputPort.count(portId) == 0) return;
    
    int portNum = m_param2InputPort.at(portId);
    
    int i = 0;
    for(auto conn : m_inbound)
    {
        if(conn->dstPort() == portNum)
        {
            if(i == num)
            {
                if(conn->rate() == RATE_AUDIO)
                {
                    AGAudioRenderer *rndrr = dynamic_cast<AGAudioRenderer *>(conn->src());
                    rndrr->renderAudio(t, NULL, output, nFrames, conn->srcPort(), conn->src()->numOutputPorts());
                }
                else
                {
                    // get last port value
                    float val = conn->src()->lastControlOutput(conn->srcPort()).getFloat();
                    //dbgprint("pullPortInput-control %i:%f\n", conn->srcPort(), val);
                    //
                    for(int i = 0; i < nFrames; i++)
                        output[i] = val;
                }
                
                break;
            }
            
            i++;
        }
    }
}

//void AGAudioNode::finalPortValue(float &value, int portId, int sample) const
//{
//    int index = m_param2InputPort.at(portId);
//    if(m_controlPortBuffer[index])
//        value = m_controlPortBuffer[index].getFloat();
//    if(sample >= 0)
//        value += m_inputPortBuffer[index][sample];
//}

void AGAudioNode::renderLast(float *output, int nFrames, int chanNum)
{
    for(int i = 0; i < nFrames; i++) output[i] += m_outputBuffer[chanNum][i];
}

float *AGAudioNode::inputPortVector(int paramId)
{
    assert(m_param2InputPort.count(paramId));
    return m_inputPortBuffer[m_param2InputPort.at(paramId)];
}

//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioOutputNode

void AGAudioOutputNode::initFinal()
{
    m_inputBuffer[0].resize(bufferSize());
    m_inputBuffer[1].resize(bufferSize());
}

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

void AGAudioOutputNode::renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans)
{
    assert(nChans == 2);
    
    m_inputBuffer[0].clear();
    m_inputBuffer[1].clear();
    
    this->lock();
    
    for(auto conn : m_inbound)
    {
        if(conn->rate() == RATE_AUDIO)
        {
            assert(conn->dstPort() == 0 || conn->dstPort() == 1);
            ((AGAudioNode *)conn->src())->renderAudio(t, input, m_inputBuffer[conn->dstPort()], nFrames, conn->srcPort(), conn->src()->numOutputPorts());
        }
    }
    
    this->unlock();
    
    float gain = param(AUDIO_PARAM_GAIN);
    
    for(int i = 0; i < nFrames; i++)
    {
        output[i*2] += m_inputBuffer[0][i]*gain;
        output[i*2+1] += m_inputBuffer[1][i]*gain;
    }
}

//------------------------------------------------------------------------------
// ### AGAudioInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioInputNode

class AGAudioInputNode : public AGAudioNode, public AGAudioCapturer
{
public:
    
    enum Param
    {
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
    };

    
    class Manifest : public AGStandardNodeManifest<AGAudioInputNode>
    {
    public:
        string _type() const override { return "Input"; };
        string _name() const override { return "Input"; };
        string _description() const override { return "Routes audio from input device, such as a microphone."; };

        vector<AGPortInfo> _inputPortInfo() const override { return { }; }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, 0, 0, AGPortInfo::EXP, .doc = "Output gain." }
            };
        }
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
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
    
    int numInputPorts() const override { return 0; }
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        // pullInputPorts(t, nFrames);
        
        float gain = param(AUDIO_PARAM_GAIN);
        
        if(m_inputSize && m_input)
        {
            float *_outputBuffer = m_outputBuffer[chanNum];
            float *_input = m_input;
            int mn = min(nFrames, m_inputSize);
            for(int i = 0; i < mn; i++)
            {
                *_outputBuffer = (*_input++)*gain;
                *output++ += *_outputBuffer++;
            }
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
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_PHASE,
        PARAM_TEST, // test param for enum
    };

    class Manifest : public AGStandardNodeManifest<AGAudioSineWaveNode>
    {
    public:
        
        enum TestTypes
        {
            TEST_SINOSC,
            TEST_TRIOSC,
            TEST_SAWOSC,
            TEST_SQROSC,
        };
        
        string _type() const override { return "SineWave"; };
        string _name() const override { return "SineWave"; };
        string _description() const override { return "Standard sinusoidal oscillator."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, 0, 0, AGPortInfo::EXP, .doc = "Oscillator frequency. " },
                { AUDIO_PARAM_GAIN, "gain", 1, 0, 0, AGPortInfo::EXP, .doc = "Output gain." },
                { PARAM_PHASE, "phase", 1, 0, 0, AGPortInfo::LIN, .doc = "Oscillator phase." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            vector<AGPortInfo::EnumInfo> testEnumInfo = {
                { TEST_SINOSC, "SinOsc" },
                { TEST_TRIOSC, "TriOsc" },
                { TEST_SAWOSC, "SawOsc" },
                { TEST_SQROSC, "SqrOsc" },
            };
            
            return {
                { PARAM_FREQ, "freq", 220, 0, 0, AGPortInfo::EXP, .doc = "Oscillator frequency" },
                { AUDIO_PARAM_GAIN, "gain", 1, 0, 0, AGPortInfo::EXP, .doc = "Output gain." },
                { PARAM_TEST, "test", .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM, .enumInfo = testEnumInfo,
                    .doc = "Enum test." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

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
    
    void receiveControl(int port, const AGControl &control) override
    {
        if(port == m_param2InputPort[PARAM_PHASE])
        {
            // hard-sync phase to control input
            m_phase = control.getFloat();
            // clear control
            // prevents upsampling to renderAudio phase vector
            clearControl(PARAM_PHASE);
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        // if there are audio-rate phase inputs, then ignore m_phase value
        float phase_ctl = numInputsForPort(PARAM_PHASE, AGRate::RATE_AUDIO) > 0 ? 0.0f : 1.0f;
        float *phasev = inputPortVector(PARAM_PHASE);
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] = sinf(m_phase*2.0*M_PI) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
            
            m_phase = clipunit(m_phase*phase_ctl + freqv[i]/sampleRate() + phasev[i]);
        }
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
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_WIDTH,
        PARAM_PHASE,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioSquareWaveNode>
    {
    public:
        string _type() const override { return "SquareWave"; };
        string _name() const override { return "SquareWave"; };
        string _description() const override { return "Standard square wave oscillator."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, .doc = "Oscillator frequency." },
                { PARAM_WIDTH, "width", 0.5, 0, 1, .doc = "Pulse width of wave as fraction of full wavelength." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_PHASE, "phase", 1, 0, 0, AGPortInfo::LIN, .doc = "Oscillator phase." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, .doc = "Oscillator frequency" },
                { PARAM_WIDTH, "width", 0.5, 0, 1, .doc = "Pulse width of wave as fraction of full wavelength." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
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
    
    void receiveControl(int port, const AGControl &control) override
    {
        if(port == m_param2InputPort[PARAM_PHASE])
        {
            // hard-sync phase to control input
            m_phase = control.getFloat();
            // clear control
            // prevents upsampling to renderAudio phase vector
            clearControl(PARAM_PHASE);
        }
    }

    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        float *width = inputPortVector(PARAM_WIDTH);
        // if there are audio-rate phase inputs, then ignore m_phase value
        float phase_ctl = numInputsForPort(PARAM_PHASE, AGRate::RATE_AUDIO) > 0 ? 0.0f : 1.0f;
        float *phasev = inputPortVector(PARAM_PHASE);

        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] = (m_phase < width[i] ? 1 : -1) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
            
            m_phase = clipunit(m_phase*phase_ctl + freqv[i]/sampleRate() + phasev[i]);
        }
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
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_PHASE,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioSawtoothWaveNode>
    {
    public:
        string _type() const override { return "SawWave"; };
        string _name() const override { return "SawWave"; };
        string _description() const override { return "Standard sawtooth wave oscillator."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, .doc = "Oscillator frequency" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_PHASE, "phase", 1, 0, 0, AGPortInfo::LIN, .doc = "Oscillator phase." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, .doc = "Oscillator frequency" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
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
    
    void receiveControl(int port, const AGControl &control) override
    {
        if(port == m_param2InputPort[PARAM_PHASE])
        {
            // hard-sync phase to control input
            m_phase = control.getFloat();
            // clear control
            // prevents upsampling to renderAudio phase vector
            clearControl(PARAM_PHASE);
        }
    }

    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        // if there are audio-rate phase inputs, then ignore m_phase value
        float phase_ctl = numInputsForPort(PARAM_PHASE, AGRate::RATE_AUDIO) > 0 ? 0.0f : 1.0f;
        float *phasev = inputPortVector(PARAM_PHASE);
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] = ((1-m_phase)*2-1)  * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
            
            m_phase = clipunit(m_phase*phase_ctl + freqv[i]/sampleRate() + phasev[i]);
        }
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
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_PHASE,
    };

    class Manifest : public AGStandardNodeManifest<AGAudioTriangleWaveNode>
    {
    public:
        string _type() const override { return "TriWave"; };
        string _name() const override { return "TriWave"; };
        string _description() const override { return "Standard triangle wave oscillator."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, .doc = "Oscillator frequency" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_PHASE, "phase", 1, 0, 0, AGPortInfo::LIN, .doc = "Oscillator phase." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, .doc = "Oscillator frequency" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
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
    
    void receiveControl(int port, const AGControl &control) override
    {
        if(port == m_param2InputPort[PARAM_PHASE])
        {
            // hard-sync phase to control input
            m_phase = control.getFloat();
            // clear control
            // prevents upsampling to renderAudio phase vector
            clearControl(PARAM_PHASE);
        }
    }

    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        // if there are audio-rate phase inputs, then ignore m_phase value
        float phase_ctl = numInputsForPort(PARAM_PHASE, AGRate::RATE_AUDIO) > 0 ? 0.0f : 1.0f;
        float *phasev = inputPortVector(PARAM_PHASE);
        
        for(int i = 0; i < nFrames; i++)
        {
            if(m_phase < 0.5)
                m_outputBuffer[chanNum][i] = ((1-m_phase*2)*2-1) * gainv[i];
            else
                m_outputBuffer[chanNum][i] = ((m_phase-0.5)*4-1) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
            
            m_phase = clipunit(m_phase*phase_ctl + freqv[i]/sampleRate() + phasev[i]);
        }
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
        PARAM_OUTPUT,
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
        string _description() const override { return "Attack-decay-sustain-release (ADSR) envelope. "; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input to apply envelope. " },
                { AUDIO_PARAM_GAIN, "gain", .doc = "Output gain." },
                { PARAM_TRIGGER, "trigger", .doc = "Envelope trigger (triggered for any value above 0)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_ATTACK, "attack", 0.01, .doc = "Attack duration (seconds)." },
                { PARAM_DECAY, "decay", 0.01, .doc = "Decay duration (seconds)." },
                { PARAM_SUSTAIN, "sustain", 0.5, .doc = "Sustain level (linear amplitude)." },
                { PARAM_RELEASE, "release", 0.1, .doc = "Release duration (seconds)." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

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
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *triggerv = inputPortVector(PARAM_TRIGGER);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        // use constant (1.0) virtual input if no actual inputs are present
        float virtual_input = numInputsForPort(PARAM_INPUT, AGRate::RATE_AUDIO) == 0 ? 1.0f : 0.0f;
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
            
            m_outputBuffer[chanNum][i] = m_adsr.tick() * (inputv[i] + virtual_input) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
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
        PARAM_OUTPUT,
        PARAM_FREQ,
        PARAM_Q,
    };
    
    class ManifestLPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2RLPF>>
    {
    public:
        string _type() const override { return "LowPass"; };
        string _name() const override { return "LowPass"; };
        string _description() const override { return "Resonant low-pass filter (second order Butterworth)."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Filter input." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency. " },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

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
        string _description() const override { return "Resonant high-pass filter (second-order Butterworth)."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Filter input." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

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
        string _description() const override { return "Band pass filter (second-order Butterworth)."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Filter input." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
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
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
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
            
            if(freq != param(PARAM_FREQ).getFloat() || Q != param(PARAM_Q).getFloat())
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
            
            m_outputBuffer[chanNum][i] = samp;
            output[i] += m_outputBuffer[chanNum][i];
        }
    }

    
private:
    Filter m_filter;
};


//------------------------------------------------------------------------------
// ### AGAudioFeedbackNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFeedbackNode


#pragma mark AllPass1
//------------------------------------------------------------------------------
// ### AllPass1 ###
// 1st order allpass filter for delay interpolation
//------------------------------------------------------------------------------
class AllPass1
{
public:
    AllPass1(float g = 1)
    {
        _g = g;
        _yn_1 = 0;
        _xn_1 = 0;
    }
    
    float tick(float xn)
    {
        // process output
        float yn = xn*_g + _xn_1 + _yn_1*-_g;
        
        // process delays
        _yn_1 = yn;
        _xn_1 = xn;
        
        return yn;
    }
    
    float g(float g)
    {
        _g = g;
        return g;
    }
    
    float delay(float d)
    {
        _g = (1-d)/(1+d);
        return d;
    }
    
    void clear()
    {
        _yn_1 = _xn_1 = 0;
    }
    
    float last()
    {
        return _yn_1;
    }
    
private:
    float _yn_1, _xn_1;
    float _g;
};

class DelayA
{
public:
    DelayA(float max = 44100, float delay = 22050) : m_index(0)
    {
        this->maxdelay(max);
        this->delay(delay);
    }
    
    float tick(float xn)
    {
        m_buffer[m_index] = xn;
        
        int delay_index = m_index-m_delayint;
        if(delay_index < 0)
            delay_index += m_buffer.size;
        float samp = m_ap.tick(m_buffer[delay_index]);
        
        m_index = (m_index+1)%m_buffer.size;
        
        return samp;
    }
    
    float delay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_delayint = (int)floorf(dsamps);
        m_delayfract = dsamps-m_delayint;
        m_ap.delay(m_delayfract);
        return dsamps;
    }
    
    float maxdelay()
    {
        return m_buffer.size-1;
    }
    
    float maxdelay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_buffer.resize((int)floorf(dsamps)+1);
        return dsamps;
    }
    
    void clear()
    {
        m_buffer.clear();
        m_ap.clear();
    }
    
    float last()
    {
        return m_ap.last();
    }
    
private:
    int m_delayint;
    float m_delayfract;
    
    Buffer<float> m_buffer;
    int m_index;
    
    AllPass1 m_ap;
};

class AGAudioFeedbackNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_DELAY,
        PARAM_FEEDBACK,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioFeedbackNode>
    {
    public:
        string _type() const override { return "Feedback"; };
        string _name() const override { return "Feedback"; };
        string _description() const override { return "Delay processor with built-in feedback."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { PARAM_DELAY, "delay", 0.5, 0, AGFloat_Max, .doc = "Delay length (seconds)." },
                { PARAM_FEEDBACK, "feedback", 0.1, 0, 1, .doc = "Feedback gain." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_DELAY, "delay", 0.5, 0, AGFloat_Max, .doc = "Delay length (seconds)." },
                { PARAM_FEEDBACK, "feedback", 0.1, 0, 1, .doc = "Feedback gain." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
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
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_DELAY)
            _setDelay(param(PARAM_DELAY));
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *delayLengthv = inputPortVector(PARAM_DELAY);
        float *feedbackGainv = inputPortVector(PARAM_FEEDBACK);
        
        for(int i = 0; i < nFrames; i++)
        {
            _setDelay(delayLengthv[i]);
            
            float delaySamp = m_delay.tick(inputv[i] + m_delay.last()*feedbackGainv[i]);
            m_outputBuffer[chanNum][i] = (inputv[i] + delaySamp)*gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    
    void _setDelay(float delaySecs, bool force=false)
    {
        if(force || m_currentDelayLength != delaySecs)
        {
            float delaySamps = delaySecs*sampleRate();
            if(delaySamps < 0)
                delaySamps = 0;
            if(delaySamps > m_delay.maxdelay())
            {
                int _max = m_delay.maxdelay();
                while(delaySamps > _max)
                    _max *= 2;
                m_delay.maxdelay(_max);
                m_delay.clear();
            }
            m_delay.delay(delaySamps);
            m_currentDelayLength = delaySecs;
        }
    }
    
    float m_currentDelayLength;
    DelayA m_delay;
};


//------------------------------------------------------------------------------
// ### AGAudioAddNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioAddNode

class AGAudioAddNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_ADD,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioAddNode>
    {
    public:
        string _type() const override { return "Add"; };
        string _name() const override { return "Add"; };
        string _description() const override { return "Simply adds singular value, or if multiple inputs, sums all inputs. "; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "add", .doc = "Quantity to add, if only one input." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_ADD, "add", 0, .doc = "Input(s) to add." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // add icon
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 }, { radius_x, 0, 0 },
                { 0, radius_y, 0 }, { 0, -radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_inputBuffer.resize(bufferSize());
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        
        float gain = param(AUDIO_PARAM_GAIN);
        
        this->lock();
        
        int numInputs = numInputsForPort(PARAM_INPUT);
        // if only one input, process with edit port value
        float base = 0;
        if(numInputs == 1)
        {
            if(m_params.count(PARAM_ADD))
                base = m_params.at(PARAM_ADD);
        }
        
        // set to base value
        for(int i = 0; i < nFrames; i++)
            m_outputBuffer[chanNum][i] = base;
        
        for(int j = 0; j < numInputs; j++)
        {
            m_inputBuffer.clear();
            pullPortInput(PARAM_INPUT, j, t, m_inputBuffer, nFrames);
            
            for(int i = 0; i < nFrames; i++)
                m_outputBuffer[chanNum][i] += m_inputBuffer[i];
        }
        
        this->unlock();
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] *= gain;
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    Buffer<float> m_inputBuffer;
};




//------------------------------------------------------------------------------
// ### AGAudioMultiplyNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioMultiplyNode

class AGAudioMultiplyNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_MULTIPLY,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioMultiplyNode>
    {
    public:
        string _type() const override { return "Multiply"; };
        string _name() const override { return "Multiply"; };
        string _description() const override { return "Multiplies a single input by a constant value, or multiples inputs together if there is more than one. "; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "multiply", .doc = "Quantity to multiply by, if only one input." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_MULTIPLY, "multiply", 1, .doc = "Input(s) to multiply together." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // x icon
            vector<GLvertex3f> iconGeo = {
                { -radius_x, radius_y, 0 }, { radius_x, -radius_y, 0 },
                { -radius_x, -radius_y, 0 }, { radius_x, radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_inputBuffer.resize(bufferSize());
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        
        float gain = param(AUDIO_PARAM_GAIN);
        
        this->lock();
        
        int numInputs = numInputsForPort(PARAM_INPUT);
        // if only one input, process with edit port value
        float base = 1;
        if(numInputs == 1)
        {
            if(m_params.count(PARAM_MULTIPLY))
                base = m_params.at(PARAM_MULTIPLY);
        }
        
        // set to base value
        for(int i = 0; i < nFrames; i++)
            m_outputBuffer[chanNum][i] = base;
        
        for(int j = 0; j < numInputs; j++)
        {
            m_inputBuffer.clear();
            pullPortInput(PARAM_INPUT, j, t, m_inputBuffer, nFrames);
            
            for(int i = 0; i < nFrames; i++)
                m_outputBuffer[chanNum][i] *= m_inputBuffer[i];
        }
        
        this->unlock();
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] *= gain;
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    Buffer<float> m_inputBuffer;
};



//------------------------------------------------------------------------------
// ### AGAudioNoiseNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNoiseNode

class AGAudioNoiseNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
    };
    
    
    class Manifest : public AGStandardNodeManifest<AGAudioNoiseNode>
    {
    public:
        string _type() const override { return "Noise"; };
        string _name() const override { return "Noise"; };
        string _description() const override { return "White noise generator."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }

        vector<GLvertex3f> _iconGeo() const override
        {
            int NUM_SAMPS = 25;
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // x icon
            vector<GLvertex3f> iconGeo;
            iconGeo.resize(NUM_SAMPS);
            
            for(int i = 0; i < NUM_SAMPS; i++)
            {
                float randomSample = arc4random()*ONE_OVER_RAND_MAX*2-1;
                iconGeo[i].x = (((float)i)/(NUM_SAMPS-1)*2-1)*radius_x;
                iconGeo[i].y = randomSample*radius_y;
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        srandom(time(NULL));
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        
        for(int i = 0; i < nFrames; i++)
        {
            float randomSample = arc4random()*ONE_OVER_RAND_MAX*2-1;
            m_outputBuffer[chanNum][i] = randomSample*gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    constexpr static const float ONE_OVER_RAND_MAX = 1.0/4294967295.0;
};

//------------------------------------------------------------------------------
// ### AGAudioEnvelopeFollowerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioEnvelopeFollowerNode

class AGAudioEnvelopeFollowerNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_ATTACK,
        PARAM_RELEASE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioEnvelopeFollowerNode>
    {
    public:
        string _type() const override { return "EnvelopeFollower"; };
        string _name() const override { return "EnvelopeFollower"; };
        string _description() const override { return "Envelope follower with separate attack and release times"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_ATTACK, "attack", 0.01, 0.0001, 1.0, .doc = "Attack time." },
                { PARAM_RELEASE, "release", 0.01, 0.0001, 1.0, .doc = "Release time." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            const float ONE_OVER_RAND_MAX = 1.0/4294967295.0;
            
            int NUM_SAMPS = 200;
            float m_env = 0.0;
            float attack = 0.88;
            float release = 0.88;
            float attenuation = 0.55;
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            float nudgeUp = radius_x * 0.35;
            
            vector<float> samples;
            samples.resize(NUM_SAMPS);
            
            // Generate sine-modulated noise
            for(int i = 0; i < NUM_SAMPS; i++)
            {
                samples[i] = arc4random()*ONE_OVER_RAND_MAX*2-1;
                samples[i] *= sin(((float)i / NUM_SAMPS) * 2 * M_PI);
            }

            // Build vertices for our noise
            vector<GLvertex3f> iconGeo;
            for(int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
            
                vert.x = (((float)i)/(NUM_SAMPS-1)*2-1)*radius_x;
                vert.y = samples[i]*radius_y*attenuation;
                
                iconGeo.push_back(vert);
            }
            
            // Add vertices for envelope trace
            for (int i = samples.size() - 1; i >= 0; i--)
            {
                float env_input = abs(samples[i]);
                
                if(env_input > m_env)
                {
                    m_env = attack * m_env + (1-attack) * env_input;
                }
                else
                {
                    m_env = release * m_env + (1-release) * env_input;
                }
                
                GLvertex3f vert;
                    
                vert.x = (((float)i)/(NUM_SAMPS-1)*2-1)*radius_x;
                vert.y = m_env * radius_y + nudgeUp;
                
                iconGeo.push_back(vert);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_envelope = 0;
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float attack_coeff = exp(-1.0f/(sampleRate()*(float)param(PARAM_ATTACK)));
        float release_coeff = exp(-1.0f/(sampleRate()*(float)param(PARAM_RELEASE)));
        
        for(int i = 0; i < nFrames; i++)
        {
            
            float env_input = abs(inputv[i]);
            
            if(env_input > m_envelope)
            {
                m_envelope = attack_coeff * m_envelope + (1-attack_coeff) * env_input;
            }
            else
            {
                m_envelope = release_coeff * m_envelope + (1-release_coeff) * env_input;
            }
            
            m_outputBuffer[chanNum][i] = m_envelope * gainv[i];
            
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    float m_envelope;
};

//------------------------------------------------------------------------------
// ### AGAudioStateVariableFilterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioStateVariableFilterNode

class AGAudioStateVariableFilterNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_LPF_OUTPUT,
        PARAM_HPF_OUTPUT,
        PARAM_BPF_OUTPUT,
        PARAM_BRF_OUTPUT,
        PARAM_CUTOFF,
        PARAM_Q,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioStateVariableFilterNode>
    {
    public:
        string _type() const override { return "StateVariableFilter"; };
        string _name() const override { return "StateVariableFilter"; };
        string _description() const override { return "State variable filter"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { PARAM_CUTOFF, "cutoff", 220.0, 0.0001, 7000.0, .doc = "Filter cutoff." },
                { PARAM_Q, "Q", 1.0, 0.0001, 100.0, .doc = "Filter Q." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }

            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_CUTOFF, "cutoff", 220.0, 0.0001, 7000.0, .doc = "Filter cutoff." },
                { PARAM_Q, "Q", 1.0, 0.0001, 100.0, .doc = "Filter Q." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_LPF_OUTPUT, "lp output", .doc = "LP Output." },
                { PARAM_HPF_OUTPUT, "hp output", .doc = "HP Output." },
                { PARAM_BPF_OUTPUT, "bp output", .doc = "BP Output." },
                { PARAM_BRF_OUTPUT, "br output", .doc = "Notch Output." }

            };
        }

        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.0065*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // SVF shape, including lowpass, highpass, and notch
            vector<GLvertex3f> iconGeo = {
                {        -radius_x,  radius_y * 0.5f, 0 },
                { -radius_x * 0.5f,  radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.6f, 0 },
                {                0,  radius_y * 0.5f, 0 },
                {  radius_x * 0.2f,  radius_y * 0.6f, 0 },
                {  radius_x * 0.5f,  radius_y * 0.5f, 0 },
                {         radius_x,  radius_y * 0.5f, 0 },
                {  radius_x * 0.5f,  radius_y * 0.5f, 0 },
                {  radius_x * 0.2f,  radius_y * 0.4f, 0 },
                {  radius_x * 0.1f,                0, 0 },
                {                0, -radius_y * 0.5f, 0 },
                { -radius_x * 0.1f,                0, 0 },
                { -radius_x * 0.2f,  radius_y * 0.4f, 0 },
                { -radius_x * 0.5f,  radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.6f, 0 },
                {                0,  radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.1f, 0 },
                { -radius_x * 0.5f, -radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.1f, 0 },
                {                0,  radius_y * 0.5f, 0 },
                {  radius_x * 0.2f,  radius_y * 0.1f, 0 },
                {  radius_x * 0.5f, -radius_y * 0.5f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        d1 = d2 = 0;
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *cutoffv = inputPortVector(PARAM_CUTOFF);
        float *qv = inputPortVector(PARAM_Q);
        
        for(int i = 0; i < nFrames; i++)
        {
            
            // TODO: only recompute coeffs if params have changed
            float cutoff_coeff = 2 * sin(M_PI * cutoffv[i] / sampleRate());
            float q_coeff = 1.0 / qv[i];
            
            float lpf = d2 + cutoff_coeff * d1;
            float hpf = inputv[i] - lpf - q_coeff * d1;
            float bpf = cutoff_coeff * hpf + d1;
            float brf = hpf + lpf;
            
            if (isbad(lpf) || isbad(hpf) || isbad(bpf) || isbad(brf))
                lpf = hpf = bpf = brf = 0;
            
            d1 = bpf;
            d2 = lpf;
            
            m_outputBuffer[0][i] = lpf * gainv[i];
            m_outputBuffer[1][i] = hpf * gainv[i];
            m_outputBuffer[2][i] = bpf * gainv[i];
            m_outputBuffer[3][i] = brf * gainv[i];
            
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    float d1;
    float d2;
};

//------------------------------------------------------------------------------
// ### AGAudioAllpassNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioAllpassNode

#pragma mark DelayI
//------------------------------------------------------------------------------
// ### DelayI ###
// Integer delay line
//------------------------------------------------------------------------------

class DelayI
{
public:
    DelayI(float max = 44100, float delay = 22050) : m_index(0)
    {
        this->maxdelay(max);
        this->delay(delay);
        this->clear();
        m_index = 0;
        m_last = 0;
    }
    
    float tick(float xn)
    {
        m_buffer[m_index] = xn;
        
        int delay_index = m_index-m_delayint;
        if(delay_index < 0)
            delay_index += m_buffer.size;
        float samp = m_buffer[delay_index];
        
        m_index = (m_index+1)%m_buffer.size;
        
        m_last = samp;
        return samp;
    }
    
    float delay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_delayint = (int)dsamps;
        return dsamps;
    }
    
    float maxdelay()
    {
        return m_buffer.size-1;
    }
    
    float maxdelay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_buffer.resize((int)floorf(dsamps)+1);
        this->clear();
        return dsamps;
    }
    
    float last()
    {
        return m_last;
    }
    
    void clear()
    {
        m_buffer.clear();
    }
    
private:
    int m_delayint;
    
    Buffer<float> m_buffer;
    float m_last;
    int m_index;
};

#pragma mark AllPassN
//------------------------------------------------------------------------------
// ### AllPassN ###
// Nth order allpass filter
//------------------------------------------------------------------------------
class AllPassN
{
public:
    AllPassN(float g = 1)
    {
        m_delay_x.clear();
        m_delay_y.clear();
        _g = g;
    }
    
    float tick(float xn)
    {
        // process output
        float yn = xn*_g + m_delay_x.last() + m_delay_y.last()*-_g;
        
        // process delays
        m_delay_y.tick(yn);
        m_delay_x.tick(xn);
        
        return yn;
    }
    
    float g(float g)
    {
        _g = g;
        return g;
    }
    
    float delay(float d)
    {
        m_delay_x.delay(d);
        m_delay_y.delay(d);
        return d;
    }
    
    float maxdelay() {
        return m_delay_x.maxdelay();
    }
    
    float maxdelay(float dsamps) {
        assert(dsamps >= 0);
        
        m_delay_x.maxdelay(dsamps);
        m_delay_y.maxdelay(dsamps);
        return dsamps;
    }
    
    void clear()
    {
        m_delay_x.clear();
        m_delay_y.clear();
    }
    
    float last()
    {
        return m_delay_y.last();
    }
    
private:
    DelayI m_delay_x;
    DelayI m_delay_y;
    
    float _g;
};

class AGAudioAllpassNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_DELAY,
        PARAM_COEFF,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioAllpassNode>
    {
    public:
        string _type() const override { return "Allpass"; };
        string _name() const override { return "Allpass"; };
        string _description() const override { return "Nth-order allpass filter"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { PARAM_DELAY, "delay", 1, 1, AGInt_Max,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Delay length (samples)." },
                { PARAM_COEFF, "coeff", 0.1, 0, 1, .doc = "Allpass coefficient." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_DELAY, "delay", 1, 1, AGInt_Max,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Delay length (samples)." },
                { PARAM_COEFF, "coeff", 0.1, -AGFloat_Max, AGFloat_Max, .doc = "Allpass coefficient." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.006*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            int NUM_SAMPS = 25;
            
            vector<GLvertex3f> iconGeo;
            
            for (int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                float sample = ((float)i/NUM_SAMPS);
                sample = pow(sample, 6);
                
                vert.x = ((float)i/(NUM_SAMPS-1))*radius_x - radius_x;
                vert.y = sample * radius_y;
                
                iconGeo.push_back(vert);
            }

            for (int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                vert.x = ((float)i/NUM_SAMPS)*radius_x;
                vert.y = -iconGeo[NUM_SAMPS-i-1].y;
                
                iconGeo.push_back(vert);
            }

            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        _setDelay(param(PARAM_DELAY), true);
        m_allpass.clear();
    }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_DELAY) {
            _setDelay(param(PARAM_DELAY));
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *delayLengthv = inputPortVector(PARAM_DELAY);
        float *coeffv = inputPortVector(PARAM_COEFF);
        
        for(int i = 0; i < nFrames; i++)
        {
            _setDelay(delayLengthv[i]);
            m_allpass.g(coeffv[i]);
            
            float delaySamp = m_allpass.tick(inputv[i]);
            m_outputBuffer[chanNum][i] = delaySamp * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    
    void _setDelay(float delaySamps, bool force=false)
    {
        if(force || m_currentDelayLength != delaySamps)
        {
            if(delaySamps < 0)
                delaySamps = 0;
            if(delaySamps > m_allpass.maxdelay())
            {
                int _max = m_allpass.maxdelay();
                while(delaySamps > _max)
                    _max *= 2;
                m_allpass.maxdelay(_max);
                m_allpass.clear();
            }
            m_allpass.delay(delaySamps);
            m_currentDelayLength = delaySamps;
        }
    }
    
    float m_currentDelayLength;
    AllPassN m_allpass;
};

//------------------------------------------------------------------------------
// ### AGAudioBiquadNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioBiquadNode

class AGAudioBiquadNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_A1,
        PARAM_A2,
        PARAM_B0,
        PARAM_B1,
        PARAM_B2,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioBiquadNode>
    {
    public:
        string _type() const override { return "Biquad"; };
        string _name() const override { return "Biquad"; };
        string _description() const override { return "Biquad filter."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_A1, "a1", 0.00, -2.0, 2.0, .doc = "A1 coefficient." },
                { PARAM_A2, "a2", 0.00, -2.0, 2.0, .doc = "A2 coefficient." },
                { PARAM_B0, "b0", 0.00, -2.0, 2.0, .doc = "B0 coefficient." },
                { PARAM_B1, "b1", 0.00, -2.0, 2.0, .doc = "B1 coefficient." },
                { PARAM_B2, "b2", 0.00, -2.0, 2.0, .doc = "B2 coefficient." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.006*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            float radius_circ = radius_x * 0.8;
            int circleSize = 48;
            int GEO_SIZE = circleSize*2;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            // Unit circle
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
                float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius_circ*cosf(theta0), radius_circ*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius_circ*cosf(theta1), radius_circ*sinf(theta1), 0);
            }
            
            // 1st-quadrant zero
            for(int i = 0; i < GEO_SIZE; i++)
            {
                GLvertex3f vert = iconGeo[i];
                vert = vert * 0.15;
                float theta = M_PI / 4;
                vert = vert + GLvertex3f(radius_circ*cosf(theta), radius_circ*sinf(theta), 0);
                iconGeo.push_back(vert);
            }

            // 4th-quadrant zero
            for(int i = 0; i < GEO_SIZE; i++)
            {
                GLvertex3f vert = iconGeo[i+GEO_SIZE];
                vert.y = -vert.y;
                iconGeo.push_back(vert);
            }
            
            // Poles
            vector<GLvertex3f> poles = {
                { 0.5, 0.5, 0 }, { 0.3, 0.3, 0 }, { 0.3, 0.5, 0 }, { 0.5, 0.3, 0 },
                { 0.5, -0.5, 0 }, { 0.3, -0.3, 0 }, { 0.3, -0.5, 0 }, { 0.5, -0.3, 0 },
            };
            
            for(int i = 0; i < poles.size(); i++)
            {
                GLvertex3f vert = poles[i];
                vert = vert * radius_circ;
                iconGeo.push_back(vert);
            }
            
            // Axes
            iconGeo.push_back(GLvertex3f(0,  radius_y, 0));
            iconGeo.push_back(GLvertex3f(0, -radius_y, 0));
            iconGeo.push_back(GLvertex3f( radius_x, 0, 0));
            iconGeo.push_back(GLvertex3f(-radius_x, 0, 0));
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        sn_1 = sn_2 = 0;
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float a1 = param(PARAM_A1);
        float a2 = param(PARAM_A2);
        float b0 = param(PARAM_B0);
        float b1 = param(PARAM_B1);
        float b2 = param(PARAM_B2);
        
        for(int i = 0; i < nFrames; i++)
        {
            // Transposed Direct-Form II
            float xn = inputv[i];
            float yn = b0 * xn + sn_1;
            sn_2 = -a2 * yn + b2 * xn;
            sn_1 = -a1 * yn + b1 * xn;
            
            if (isbad(yn) || isbad(sn_1) || isbad(sn_2))
                yn = sn_1 = sn_2 = 0;
            
            m_outputBuffer[chanNum][i] = yn * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    float sn_1, sn_2;
};



//------------------------------------------------------------------------------
// ### AGAudioPannerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioPannerNode

class AGAudioPannerNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT_L,
        PARAM_OUTPUT_R,
        PARAM_PAN,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioPannerNode>
    {
    public:
        string _type() const override { return "Panner"; };
        string _name() const override { return "Panner"; };
        string _description() const override { return "Constant-power 2-channel panner."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input" },
                { PARAM_PAN, "pan", 0, -1, 1, .doc = "Pan amount (-1.0 - 1.0)" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_PAN, "pan", 0, -1, 1, .doc = "Pan amount (-1.0 - 1.0)" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT_L, "left output", .doc = "Left output" },
                { PARAM_OUTPUT_R, "right output", .doc = "Right output" },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.006*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            float radius_circ = radius_x * 0.8;
            int circleSize = 24;
            int GEO_SIZE = circleSize*2;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            // Hemisphere
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = M_PI*((float)i)/((float)(circleSize));
                float theta1 = M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius_circ*cosf(theta0), radius_circ*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius_circ*cosf(theta1), radius_circ*sinf(theta1), 0);
            }
            
            // Axes
            iconGeo.push_back(GLvertex3f(0,  radius_y, 0));
            iconGeo.push_back(GLvertex3f(0,         0, 0));
            iconGeo.push_back(GLvertex3f( radius_x, 0, 0));
            iconGeo.push_back(GLvertex3f(-radius_x, 0, 0));
            
            // Arrow
            iconGeo.push_back(GLvertex3f(-radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.6, radius_y * 1.4, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.6, radius_y * 1.0, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.6, radius_y * 1.4, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.6, radius_y * 1.0, 0));
            
            // Nudge everything downwards a bit
            for(int i = 0; i < iconGeo.size(); i++)
            {
                iconGeo[i].y -= radius_y * 0.6;
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override { }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *panv = inputPortVector(PARAM_PAN);
        
        for(int i = 0; i < nFrames; i++)
        {
            float theta = panv[i] * M_PI_4;
            float gain_l = sqrt(2)/2 * (sin(theta) + cos(theta));
            float gain_r = sqrt(2)/2 * (sin(theta) - cos(theta));

            m_outputBuffer[0][i] = inputv[i] * gain_l;
            m_outputBuffer[1][i] = inputv[i] * gain_r;
            
            output[i] += m_outputBuffer[chanNum][i] * gainv[i];
        }
    }    
};

//------------------------------------------------------------------------------
// ### AGAudioSoundFileNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSoundFileNode

class AGAudioSoundFileNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_FILE = AUDIO_PARAM_LAST+1,
        PARAM_TRIGGER,
        PARAM_RATE,
        PARAM_OUTPUT,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioSoundFileNode>
    {
    public:
        string _type() const override { return "File"; };
        string _name() const override { return "File"; };
        string _description() const override { return "Sound file player."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_TRIGGER, "trigger", ._default = 0 },
                { PARAM_RATE, "rate", ._default = 1 },
                { AUDIO_PARAM_GAIN, "gain", ._default = 1 },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FILE, "file", ._default = AGControl(""),
                    .type = AGControl::TYPE_STRING,
                    .editorMode = AGPortInfo::EDITOR_AUDIOFILES },
                { PARAM_RATE, "rate", ._default = 1 },
                { AUDIO_PARAM_GAIN, "gain", ._default = 1 }
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float r_y = 25;
            float r_x = r_y*(8.5/11.0); // US letter aspect ratio
            
            // classic folded document shape
            vector<GLvertex3f> iconGeo = {
                { r_x*(2-G_RATIO), r_y, 0 },
                { -r_x, r_y, 0 },
                { -r_x, -r_y, 0 },
                { r_x, -r_y, 0 },
                { r_x, r_y-r_x*(G_RATIO-1), 0 },
                { r_x*(2-G_RATIO), r_y-r_x*(G_RATIO-1), 0 },
                { r_x*(2-G_RATIO), r_y, 0 },
                { r_x, r_y-r_x*(G_RATIO-1), 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        stk::Stk::setSampleRate(sampleRate());
    }
    
    int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_FILE)
        {
            // todo: abstract filesystem API
            NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *subpath = [NSString stringWithUTF8String:param(PARAM_FILE).getString().c_str()];
            NSString *fullPath = [documentPath stringByAppendingPathComponent:subpath];
            m_file.openFile([fullPath UTF8String]);
            m_file.setRate(m_rate);
            // set to end of file
            m_file.addTime(m_file.getSize());
        }
    }
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *triggerv = inputPortVector(PARAM_TRIGGER);
        float *ratev = inputPortVector(PARAM_RATE);
        
        for(int i = 0; i < nFrames; i++)
        {
            // Soundfile is edge-triggered
            if(m_lastTrigger <= 0 && triggerv[i] > 0)
                m_file.reset();
                
            m_lastTrigger = triggerv[i];
            
            if(ratev[i] != m_rate)
            {
                m_rate = ratev[i];
                m_file.setRate(m_rate);
            }
            
            m_outputBuffer[0][i] = m_file.tick() * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    int m_fileNum = -1;
    float m_lastTrigger = 0;
    float m_rate = 1;
    stk::FileWvIn m_file;
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
        nodeTypes.push_back(new AGAudioSawtoothWaveNode::Manifest);
        
        nodeTypes.push_back(new AGAudioSquareWaveNode::Manifest);
        nodeTypes.push_back(new AGAudioTriangleWaveNode::Manifest);
        
        nodeTypes.push_back(new AGAudioWaveformNode::Manifest);
        nodeTypes.push_back(new AGAudioNoiseNode::Manifest);
        
        nodeTypes.push_back(new AGAudioSoundFileNode::Manifest);
        
        nodeTypes.push_back(new AGAudioADSRNode::Manifest);
        nodeTypes.push_back(new AGAudioFeedbackNode::Manifest);

        nodeTypes.push_back(new AGAudioFilterFQNode<Butter2RLPF>::ManifestLPF);
        nodeTypes.push_back(new AGAudioFilterFQNode<Butter2RHPF>::ManifestHPF);
        
        nodeTypes.push_back(new AGAudioFilterFQNode<Butter2BPF>::ManifestBPF);
        nodeTypes.push_back(new AGAudioCompressorNode::Manifest);

        nodeTypes.push_back(new AGAudioEnvelopeFollowerNode::Manifest);
        
        nodeTypes.push_back(new AGAudioAddNode::Manifest);
        nodeTypes.push_back(new AGAudioMultiplyNode::Manifest);
        
        nodeTypes.push_back(new AGAudioInputNode::Manifest);
        nodeTypes.push_back(new AGAudioOutputNode::Manifest);
        
        nodeTypes.push_back(new AGAudioCompositeNode::Manifest);
        
        nodeTypes.push_back(new AGAudioStateVariableFilterNode::Manifest);
        
        nodeTypes.push_back(new AGAudioAllpassNode::Manifest);
        
        nodeTypes.push_back(new AGAudioBiquadNode::Manifest);
        
        nodeTypes.push_back(new AGAudioPannerNode::Manifest);
        
        nodeTypes.push_back(new AGAudioMatrixMixerNode::Manifest);
        
        for(const AGNodeManifest *const &mf : nodeTypes)
            mf->initialize();
    }
    
    return *s_audioNodeManager;
}

