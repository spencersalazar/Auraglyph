//
//  AGInterAppAudioHelper.m
//  Auraglyph
//
//  Created by Spencer Salazar on 10/20/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#import "AGInterAppAudioHelper.h"
#import "mo_audio.h"
#import <AVFoundation/AVFoundation.h>

@interface AGInterAppAudioHelper ()

- (void)_interAppAudioConnected;
- (void)_launchInterAppAudioHost;

@end

static void IsInterAppConnectedCallback(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement) {
    NSLog(@"IsInterAppConnectedCallback");
    
    AGInterAppAudioHelper *iaaHelper = (__bridge AGInterAppAudioHelper *) inRefCon;
    
    [iaaHelper _interAppAudioConnected];
}

@implementation AGInterAppAudioHelper

- (id)init
{
    if (self = [super init]) {
        self.audioUnit = MoAudio::m_au;
        self.productName = [[NSBundle mainBundle].infoDictionary valueForKey:@"CFBundleDisplayName"];
        OSType osTypeCode = 'Aura';
        self.productManufacturer = osTypeCode;
        
        return self;
    }
    
    return nil;
}

- (void)dealloc
{
    AudioUnitRemovePropertyListenerWithUserData(self.audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                                IsInterAppConnectedCallback, (__bridge void *) self);
}

- (void)setup
{
    // set up property listener
    AudioUnitAddPropertyListener(self.audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                 IsInterAppConnectedCallback, (__bridge void *) self);
    
    // publish audio units for inter-app audio
    AudioComponentDescription desc = { kAudioUnitType_RemoteInstrument, 'iasp', 0, 0, 0 };
    desc.componentManufacturer = self.productManufacturer;
    OSStatus result = AudioOutputUnitPublish(&desc, (__bridge CFStringRef) self.productName, 1, self.audioUnit);
    if (result != noErr)
        NSLog(@"AudioOutputUnitPublish instrument result: %d", (int)result);
    
    desc.componentType = kAudioUnitType_RemoteGenerator;
    result = AudioOutputUnitPublish(&desc, (__bridge CFStringRef) self.productName, 1, self.audioUnit);
    if (result != noErr)
        NSLog(@"AudioOutputUnitPublish generator result: %d", (int)result);
}

- (void)_interAppAudioConnected
{
    [self.delegate interAppAudioHelperDidConnectInterAppAudio:self];
}

- (BOOL)isInterAppAudio
{
    Boolean isInterApp = 0;
    UInt32 size = sizeof(Boolean);
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_IsInterAppConnected,
                         kAudioUnitScope_Global, 0, &isInterApp, &size);
    
    return isInterApp;
}

- (void)_launchInterAppAudioHost
{
    if([self isInterAppAudio])
    {
        CFURLRef hostURL;
        UInt32 dataSize = sizeof(CFURLRef);
        OSStatus result = AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_PeerURL,
                                               kAudioUnitScope_Global, 0, &hostURL, &dataSize);
        if (result == noErr)
            [[UIApplication sharedApplication] openURL:(__bridge_transfer NSURL *) hostURL];
        else
            // uhh
            NSLog(@"warning: unable to retrieve peer url");
    }
}


@end
