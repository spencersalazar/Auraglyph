//
//  AGCompressorNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 9/9/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGCompressorNode.h"
#include "spdsp.h"

void AGAudioCompressorNode::initFinal()
{
    m_detector.setTauAttack(0.025, sampleRate());
    m_detector.setTauRelease(0.100, sampleRate());
}

void AGAudioCompressorNode::renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    m_lastTime = t;
    pullInputPorts(t, nFrames);
    
    float gain = param(AUDIO_PARAM_GAIN);
    float dbThreshold = param(PARAM_THRESHOLD);
    float linThreshold = dB2lin(dbThreshold);
    float ratio = param(PARAM_RATIO);
    float *inputv = inputPortVector(PARAM_INPUT);
    
    // if(m_controlPortBuffer[1]) gain += m_controlPortBuffer[1].getFloat();

    for(int i = 0; i < nFrames; i++)
    {
        ///////////  PEAK DETECTOR  //////////////////////////
        float level_estimate;
        m_detector.process(m_inputPortBuffer[0][i], level_estimate);
        
        float log_level = lin2dB(level_estimate);
        
        // limiter setup
        float dbgainval = std::min(0.0, lin2dB(linThreshold/level_estimate));
        
        if(log_level > dbThreshold)
            dbgainval = (log_level-dbThreshold)*(1.0f/ratio-1.0f);
        else
            dbgainval = 0;
        
        // Compute linear gain for compressor
        float gainval = dB2lin(dbgainval);
        m_outputBuffer[chanNum][i] = inputv[i]*gainval*gain;
        output[i] += m_outputBuffer[chanNum][i];
    }
}

