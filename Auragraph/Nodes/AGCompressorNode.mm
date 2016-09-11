//
//  AGCompressorNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 9/9/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGCompressorNode.h"
#include "spdsp.h"

void AGAudioCompressorNode::setDefaultPortValues()
{
    m_gain = 1;
    m_dBThreshold = -20;
    m_linearThreshold = dB2lin(m_dBThreshold);
    m_ratio = 2;
    m_detector.setTauAttack(0.010, sampleRate());
    m_detector.setTauRelease(0.100, sampleRate());
}

void AGAudioCompressorNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0:
            m_dBThreshold = value;
            m_linearThreshold = dB2lin(m_dBThreshold);
            break;
        case 1:
            m_ratio = value;
            break;
        case 2:
            m_gain = value;
            break;
    }
}

void AGAudioCompressorNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0:
            value = m_dBThreshold;
            break;
        case 1:
            value = m_ratio;
            break;
        case 2:
            value = m_gain;
            break;
    }
}

void AGAudioCompressorNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    float gain = m_gain;
    
    // if(m_controlPortBuffer[1]) gain += m_controlPortBuffer[1].getFloat();

    for(int i = 0; i < nFrames; i++)
    {
        ///////////  PEAK DETECTOR  //////////////////////////
        float level_estimate;
        m_detector.process(m_inputPortBuffer[0][i], level_estimate);
        
        float log_level = lin2dB(level_estimate);
        
        // limiter setup
        float dbgainval = std::min(0.0, lin2dB(m_linearThreshold/level_estimate));
        
        if(log_level > m_dBThreshold)
            dbgainval = (log_level-m_dBThreshold)*(1.0f/m_ratio-1.0f);
        else
            dbgainval = 0;
        
        // Compute linear gain for compressor
        float gainval = dB2lin(dbgainval);
        m_outputBuffer[i] = m_inputPortBuffer[0][i]*gainval*gain;
        output[i] += m_outputBuffer[i];
    }
}

