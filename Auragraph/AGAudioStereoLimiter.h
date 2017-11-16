//
//  AGAudioLimiter.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <memory>

class PeakDetector;

class AGAudioStereoLimiter
{
public:
    AGAudioStereoLimiter(float srate);
    ~AGAudioStereoLimiter();
    
    void render(float *input, float *output, int numFrames);
    
    void setThreshold(float dBThresh);
    
private:
    float m_linThreshold;
    std::unique_ptr<PeakDetector> m_follower;
};
