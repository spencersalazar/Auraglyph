//
//  AGAudioManager.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/13/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGAudioCapturer.h"
#include "AGAudioOutputDestination.h"

class AGAudioOutputNode;
class AGAudioNode;
class AGTimer;


#ifdef __OBJC__

#import <Foundation/Foundation.h>

@interface AGAudioManager : NSObject

@property (nonatomic) AGAudioOutputDestination *masterOut;

+ (instancetype)instance;

- (void)addRenderer:(AGAudioRenderer *)renderer;
- (void)removeRenderer:(AGAudioRenderer *)renderer;
- (void)addCapturer:(AGAudioCapturer *)capturer;
- (void)removeCapturer:(AGAudioCapturer *)capturer;
- (void)addTimer:(AGTimer *)timer;
- (void)removeTimer:(AGTimer *)timer;

@end

#endif // __OBJC__


#ifdef __cplusplus

class _AGAudioManager
{
public:
    static _AGAudioManager &instance();
    
    void addRenderer(AGAudioRenderer *renderer);
    void removeRenderer(AGAudioRenderer *renderer);
    void addCapturer(AGAudioCapturer *capturer);
    void removeCapturer(AGAudioCapturer *capturer);
    void addTimer(AGTimer *timer);
    void removeTimer(AGTimer *timer);
};

#endif // __cplusplus
