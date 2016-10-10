//
//  AGCompositeNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGCompositeNode.h"

void AGAudioCompositeNode::addOutput(AGAudioRenderer *output)
{
    auto scope = m_outputsMutex.inScope();
    m_outputs.push_back(output);
}

void AGAudioCompositeNode::removeOutput(AGAudioRenderer *output)
{
    auto scope = m_outputsMutex.inScope();
    m_outputs.push_back(output);
}

void AGAudioCompositeNode::addSubnode(AGNode *subnode)
{
    m_subnodes.push_back(subnode);
}

void AGAudioCompositeNode::removeSubnode(AGNode *subnode)
{
    m_subnodes.remove(subnode);
}

int AGAudioCompositeNode::numOutputPorts() const
{
    return m_outputs.size();
}

void AGAudioCompositeNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    m_outputBuffer.clear();
    
    // feed input audio to input port(s)
    for(AGAudioCapturer *capturer : m_inputNodes)
        capturer->captureAudio(m_inputPortBuffer[0], nFrames);
    
    // render internal audio
    {
        Mutex::Scope scope = m_outputsMutex.inScope();
        for(AGAudioRenderer *outputNode : m_outputs)
            outputNode->renderAudio(t, input, m_outputBuffer, nFrames);
    }
    
    float gain = param(AUDIO_PARAM_GAIN);
    
    for(int i = 0; i < nFrames; i++)
        output[i] += m_outputBuffer[i]*gain;
    
    m_lastTime = t;
}
