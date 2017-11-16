//
//  AGAudioLimiter.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioStereoLimiter.h"
#include "AGCompressorNode.h"
#include "spdsp.h"

AGAudioStereoLimiter::AGAudioStereoLimiter(float srate)
{
    m_follower = std::unique_ptr<PeakDetector>(new PeakDetector);
    m_follower->setTauAttack(0.001, srate);
    m_follower->setTauRelease(0.050, srate);
    setThreshold(-0.5);
}

AGAudioStereoLimiter::~AGAudioStereoLimiter() { }

void AGAudioStereoLimiter::setThreshold(float dBThresh)
{
    m_linThreshold = dB2lin(dBThresh);
}

void AGAudioStereoLimiter::render(float *input, float *output, int numFrames)
{
    for(int i = 0; i < numFrames; i++)
    {
        float level = 0;
        m_follower->processStereo(input[i*2], input[i*2+1], level);
        
        float gain = 1;
        if(level > m_linThreshold)
            gain = powf(m_linThreshold/level, -1.0f);
        output[i*2] *= gain;
        output[i*2+1] *= gain;
    }
}

