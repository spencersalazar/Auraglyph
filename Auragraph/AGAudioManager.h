//
//  AGAudioManager.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/13/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AGAudioCapturer.h"

class AGAudioOutputNode;
class AGAudioNode;
class AGTimer;


@interface AGAudioManager : NSObject

@property (nonatomic) AGAudioOutputNode * outputNode;

+ (id)instance;

- (void)addRenderer:(AGAudioNode *)renderer;
- (void)removeRenderer:(AGAudioNode *)renderer;
- (void)addCapturer:(AGAudioCapturer *)capturer;
- (void)removeCapturer:(AGAudioCapturer *)capturer;
- (void)addTimer:(AGTimer *)timer;
- (void)removeTimer:(AGTimer *)timer;

@end
