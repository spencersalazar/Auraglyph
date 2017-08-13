//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"

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

