//
//  AGAudioCapturer.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGAudioCapturer_h
#define AGAudioCapturer_h

class AGAudioCapturer
{
public:
    virtual ~AGAudioCapturer() { }
    
    virtual void captureAudio(float *input, int numFrames) = 0;
};

#endif /* AGAudioCapturer_hpp */


