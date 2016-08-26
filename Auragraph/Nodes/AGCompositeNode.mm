//
//  AGCompositeNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGCompositeNode.h"

void AGAudioCompositeNode::addOutputNode(AGAudioNode *outputNode)
{
    m_outputNodes.push_back(outputNode);
}

void AGAudioCompositeNode::addInputNode(AGAudioCapturer *inputNode)
{
    m_inputNodes.push_back(inputNode);
}

void AGAudioCompositeNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_gain = value; break;
    }
}

void AGAudioCompositeNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_gain; break;
    }
}

void AGAudioCompositeNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    assert(m_buffer);
    
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    // feed input audio to input port(s)
    for(AGAudioCapturer *capturer : m_inputNodes)
        capturer->captureAudio(m_inputPortBuffer[0], nFrames);
    
    // render internal audio
    for(AGAudioNode *outputNode : m_outputNodes)
        outputNode->renderAudio(t, input, m_buffer, nFrames);
    
    for(int i = 0; i < nFrames; i++)
        output[i] *= m_buffer[i]*m_gain;
    
    m_lastTime = t;
}
