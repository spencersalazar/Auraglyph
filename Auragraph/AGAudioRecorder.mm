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
    
    m_recorderQueue = dispatch_queue_create("io.auraglyph.recorder", NULL);
    m_recorder = nil;
    m_buffer.initialize(RECORDER_BUFFER_SIZE);
    m_recorderBuffer = new float[RECORDER_BUFFER_SIZE];
}

AGAudioRecorder::~AGAudioRecorder()
{
    // close recording before
    closeRecording();
    m_recorderQueue = NULL;
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
}

void AGAudioRecorder::render(float *buffer, int nFrames)
{
    assert(nFrames*mChannels < RECORDER_BUFFER_SIZE);
    
    m_buffer.put(buffer, nFrames*mChannels);
    
    dispatch_async(m_recorderQueue, ^{
        int num = m_buffer.get(m_recorderBuffer, RECORDER_BUFFER_SIZE);
        int nFrames = num/mChannels;
        
        assert(nFrames*mChannels == num); // no half-frames plz
        
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mData = m_recorderBuffer;
        bufferList.mBuffers[0].mDataByteSize = sizeof(float)*num;
        bufferList.mBuffers[0].mNumberChannels = mChannels;
        
        [m_recorder appendDataFromBufferList:&bufferList withBufferSize:nFrames];
    });
}

void AGAudioRecorder::closeRecording()
{
    if(m_recorder != nil)
    {
        EZRecorder *recorder = m_recorder;
        m_recorder = nil;
        
        dispatch_async(m_recorderQueue, ^{
            [recorder closeAudioFile];
        });
    }
}
