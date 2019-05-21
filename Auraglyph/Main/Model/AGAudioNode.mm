//
//  AGAudioNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "AGNode.h"
#include "AGDef.h"
#include "AGGenericShader.h"
#include "AGAudioManager.h"
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
    
    color.a = m_fadeOut*m_renderState.alpha;
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

#include "AGCompositeNode.h"
#include "AGCompressorNode.h"
#include "AGWaveformAudioNode.h"
#include "AGMatrixMixerNode.h"
#include "Nodes/Audio/AGAudioAddNode.cpp"
#include "Nodes/Audio/AGAudioADSRNode.cpp"
#include "Nodes/Audio/AGAudioAllpassNode.cpp"
#include "Nodes/Audio/AGAudioBiquadNode.cpp"
#include "Nodes/Audio/AGAudioCompressorNode.cpp"
#include "Nodes/Audio/AGAudioEnvelopeFollowerNode.cpp"
#include "Nodes/Audio/AGAudioFeedbackNode.cpp"
#include "Nodes/Audio/AGAudioFilterFQNode.cpp"
#include "Nodes/Audio/AGAudioInputNode.cpp"
#include "Nodes/Audio/AGAudioMatrixMixerNode.cpp"
#include "Nodes/Audio/AGAudioMultiplyNode.cpp"
#include "Nodes/Audio/AGAudioNoiseNode.cpp"
#include "Nodes/Audio/AGAudioOutputNode.cpp"
#include "Nodes/Audio/AGAudioPannerNode.cpp"
#include "Nodes/Audio/AGAudioSawtoothWaveNode.cpp"
#include "Nodes/Audio/AGAudioSineWaveNode.cpp"
#include "Nodes/Audio/AGAudioSoundFileNode.cpp"
#include "Nodes/Audio/AGAudioSquareWaveNode.cpp"
#include "Nodes/Audio/AGAudioStateVariableFilterNode.cpp"
#include "Nodes/Audio/AGAudioTriangleWaveNode.cpp"
#include "Nodes/Audio/AGAudioWaveformNode.cpp"
#include "Nodes/Audio/AGAudioDistortionNode.cpp"

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
        nodeTypes.push_back(new AGAudioDistortionNode::Manifest);
        
        nodeTypes.push_back(new AGAudioAddNode::Manifest);
        nodeTypes.push_back(new AGAudioMultiplyNode::Manifest);
        
        nodeTypes.push_back(new AGAudioInputNode::Manifest);
        nodeTypes.push_back(new AGAudioOutputNode::Manifest);
        
        nodeTypes.push_back(new AGAudioEnvelopeFollowerNode::Manifest);
        nodeTypes.push_back(new AGAudioStateVariableFilterNode::Manifest);

        // nodeTypes.push_back(new AGAudioCompositeNode::Manifest);
        
        nodeTypes.push_back(new AGAudioAllpassNode::Manifest);
        nodeTypes.push_back(new AGAudioBiquadNode::Manifest);
        
        nodeTypes.push_back(new AGAudioPannerNode::Manifest);
        nodeTypes.push_back(new AGAudioMatrixMixerNode::Manifest);
        
        for(const AGNodeManifest *const &mf : nodeTypes)
            mf->initialize();
    }
    
    return *s_audioNodeManager;
}

