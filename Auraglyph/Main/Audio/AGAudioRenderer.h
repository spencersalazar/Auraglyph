//
//  AGAudioRenderer.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/25/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGAudioRenderer_h
#define AGAudioRenderer_h

class AGAudioRenderer
{
public:
    virtual ~AGAudioRenderer() { }

    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) = 0;
};


#endif /* AGAudioRenderer_h */
