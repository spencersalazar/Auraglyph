//
//  AGAudioIOManager.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/27/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "Buffers.h"

/** Interface for audio renderer.
 */
class AGAudioIORenderer
{
public:
    /** Render specified number of frames to specified audio buffer.
     */
    virtual void render(int numFrames, Buffer<float> &frames) = 0;
};


/** Forward declare Objective-C classes */
FORWARD_DECLARE_OBJC_CLASS(AEAudioController);
FORWARD_DECLARE_OBJC_CLASS(AEBlockChannel);
FORWARD_DECLARE_OBJC_CLASS(AEBlockFilter);
FORWARD_DECLARE_OBJC_CLASS(AEPlaythroughChannel);


/** Manager class for dealing with audio IO
 */
class AGAudioIOManager
{
public:
    AGAudioIOManager(int sampleRate, int bufferSize, bool inputEnabled, AGAudioIORenderer *renderer);
    
    bool startAudio();
    bool stopAudio();
    
    bool enableInput(bool enable);
    
private:
    
    void _updateAudioChannel();
    AEBlockChannel *_createOutputChannel();
    AEBlockFilter *_createInputOutputFilter();
    void _render(int numFrames, Buffer<float> &frames);
    
    AGAudioIORenderer *m_renderer = nullptr;
    int m_sampleRate = 44100;
    int m_bufferSize = 256;
    int m_numInputChannels = 2;
    int m_numOutputChannels = 2;
    bool m_inputEnabled = false;
    
    Buffer<float> m_ioBuffer;
    
    AEAudioController *m_audioController = nullptr;
    AEBlockChannel *m_outputChannel = nullptr;
    AEBlockFilter *m_inputOutputFilter = nullptr;
    AEPlaythroughChannel *m_playthroughChannel = nullptr;
};
