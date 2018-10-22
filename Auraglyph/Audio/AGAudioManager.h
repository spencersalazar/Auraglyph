//
//  AGAudioManager.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/13/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif // __OBJC__
#include "AGAudioCapturer.h"
#include "AGAudioOutputDestination.h"

class AGAudioOutputNode;
class AGAudioNode;
class AGTimer;

// audio-rate processor that does not actually generate audio
class AGAudioRateProcessor
{
public:
    virtual ~AGAudioRateProcessor() { }
    virtual void process(sampletime t) = 0;
};

#ifdef __OBJC__

#import "AGInterAppAudioHelper.h"

@interface AGAudioManager : NSObject<AGInterAppAudioHelperDelegate>

@property (nonatomic) AGAudioOutputDestination *masterOut;

+ (instancetype)instance;

- (void)addRenderer:(AGAudioRenderer *)renderer;
- (void)removeRenderer:(AGAudioRenderer *)renderer;
- (void)addCapturer:(AGAudioCapturer *)capturer;
- (void)removeCapturer:(AGAudioCapturer *)capturer;
- (void)addTimer:(AGTimer *)timer;
- (void)removeTimer:(AGTimer *)timer;
- (void)addAudioRateProcessor:(AGAudioRateProcessor *)processor;
- (void)removeAudioRateProcessor:(AGAudioRateProcessor *)processor;

- (void)startSessionRecording;
- (void)stopSessionRecording;

@end

#else // not __OBJC__

typedef void AGAudioManager;

#endif // __OBJC__

/** Proxy class for C++-only code */
class AGAudioManager_
{
public:
    static AGAudioManager_ &instance();
    
    AGAudioManager_(AGAudioManager *);
    
    void startSessionRecording();
    void stopSessionRecording();
    
    void addAudioRateProcessor(AGAudioRateProcessor *processor);
    void removeAudioRateProcessor(AGAudioRateProcessor *processor);
    
    void addCapturer(AGAudioCapturer *capturer);
    void removeCapturer(AGAudioCapturer *capturer);
    
    AGAudioOutputDestination *masterOut();
    
private:
    AGAudioManager *m_audioManager = nullptr;
};

