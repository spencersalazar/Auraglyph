//
//  AGAudioRecorder.h
//  Auragraph
//
//  Created by Spencer Salazar on 6/21/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma mark once

#include <string>
#include <CoreAudio/CoreAudioTypes.h>
#include "SampleCircularBuffer.h"

#ifdef __OBJC__
@class EZRecorder;
#else
typedef void EZRecorder;
#endif

class Thread;
class Signal;

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
    EZRecorder *m_recorder = NULL;
    SampleCircularBuffer *m_buffer = NULL;
    
    float *m_recorderBuffer = NULL;
    
    Thread *m_thread = NULL;
    bool m_go = false;
    Signal *m_signal = NULL;
};
