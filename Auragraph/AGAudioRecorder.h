//
//  AGAudioRecorder.h
//  Auragraph
//
//  Created by Spencer Salazar on 6/21/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma mark once

#include <string>
#include <dispatch/dispatch.h>
#include <CoreAudio/CoreAudioTypes.h>
#include "SampleCircularBuffer.h"

#ifdef __OBJC__
@class EZRecorder;
#else
typedef void EZRecorder;
#endif


class AGAudioRecorder
{
public:
    AGAudioRecorder();
    ~AGAudioRecorder();
    
    void startRecording(const std::string &filename, int numChannels, int srate);
    void render(float *buffer, int nFrames);
    void closeRecording();
    
    static std::string pathForSessionRecording(const std::string &extension);
    
private:
    int mChannels;
    EZRecorder *m_recorder;
    dispatch_queue_t m_recorderQueue;
    SampleCircularBuffer m_buffer;
    
    float *m_recorderBuffer;
};
