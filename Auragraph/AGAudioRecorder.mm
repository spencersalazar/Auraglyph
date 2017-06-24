//
//  AGAudioRecorder.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/21/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioRecorder.h"
#include "AGFileManager.h"

#import <EZAudioiOS/EZRecorder.h>
#import <EZAudioiOS/EZAudioUtilities.h>
#import "NSString+STLString.h"
#include <time.h>

#include "Thread.h"
#include "Signal.h"

#define RECORDER_BUFFER_SIZE (2048)

std::string AGAudioRecorder::pathForSessionRecording(const std::string &extension)
{
    time_t t = time(NULL);
    tm *tm = localtime(&t);
    char buf[256];
    strftime(buf, 255, "%Y-%m-%d %H-%M-%S", tm);
    
    return AGFileManager::instance().userDataDirectory() + "/Auraglyph Session " + buf + "." + extension;
}

AGAudioRecorder::AGAudioRecorder()
{
    [EZAudioUtilities setShouldExitOnCheckResultFail:NO];
    
    m_recorder = nil;
    m_buffer = new SampleCircularBuffer;
    m_buffer->initialize(RECORDER_BUFFER_SIZE);
    m_recorderBuffer = new float[RECORDER_BUFFER_SIZE];
    
    m_thread = new Thread;
    m_signal = new Signal;
}

AGAudioRecorder::~AGAudioRecorder()
{
    closeRecording();
}

void AGAudioRecorder::startRecording(const std::string &filename, int numChannels, int srate)
{
    mChannels = numChannels;
    
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithSTLString:filename]];
    
    AudioStreamBasicDescription description;
    description.mSampleRate = srate;
    description.mFormatID = kAudioFormatLinearPCM;
    description.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    description.mBytesPerPacket = sizeof(float)*numChannels;
    description.mFramesPerPacket = 1;
    description.mBytesPerFrame = sizeof(float)*numChannels;
    description.mChannelsPerFrame = numChannels;
    description.mBitsPerChannel = sizeof(float)*8;
    
    m_recorder = [[EZRecorder alloc] initWithURL:url
                                    clientFormat:description
                                        fileType:EZRecorderFileTypeM4A];
    
    m_go = true;
    m_thread->start([this](){
        m_signal->start();
        
        while(m_go)
        {
            m_signal->wait();
            if(!m_go)
                break;
            
            int num = m_buffer->get(m_recorderBuffer, RECORDER_BUFFER_SIZE);
            int nFrames = num/mChannels;
            
            assert(nFrames*mChannels == num); // no half-frames plz
            
            AudioBufferList bufferList;
            bufferList.mNumberBuffers = 1;
            bufferList.mBuffers[0].mData = m_recorderBuffer;
            bufferList.mBuffers[0].mDataByteSize = sizeof(float)*num;
            bufferList.mBuffers[0].mNumberChannels = mChannels;
            
            [m_recorder appendDataFromBufferList:&bufferList withBufferSize:nFrames];
        }
    });
}

void AGAudioRecorder::render(float *buffer, int nFrames)
{
    assert(nFrames*mChannels < RECORDER_BUFFER_SIZE);
    
    int numSamples = nFrames*mChannels;
    int numPut = m_buffer->put(buffer, numSamples);
    assert(numSamples == numPut); // buffer overflow
    m_signal->signal();
}

void AGAudioRecorder::closeRecording()
{
    m_go = false;
    m_signal->signal();
    m_thread->wait();
    
    SAFE_DELETE(m_signal);
    SAFE_DELETE(m_thread);
    
    [m_recorder closeAudioFile];
    m_recorder = nil;
    SAFE_DELETE_ARRAY(m_recorderBuffer);
    SAFE_DELETE(m_buffer);
}
