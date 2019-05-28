//
//  AGInterAppAudioManager.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/28/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGInterAppAudioManager.h"

static void IsInterAppConnectedCallback(void *inRefCon, AudioUnit inUnit,
                                        AudioUnitPropertyID inID, AudioUnitScope inScope,
                                        AudioUnitElement inElement)
{
    AGInterAppAudioManager *iaaMgr = (AGInterAppAudioManager *) inRefCon;
    iaaMgr->onInterAppAudioEnabled();
}

AGInterAppAudioManager::AGInterAppAudioManager(AudioUnit au, std::function<void (bool enabled)> onInterAppAudioEnable)
: m_au(au), m_onInterAppAudioEnable(onInterAppAudioEnable)
{
    AudioUnitAddPropertyListener(m_au, kAudioUnitProperty_IsInterAppConnected,
                                 IsInterAppConnectedCallback, this);
}

void AGInterAppAudioManager::publishInterAppAudioUnit(OSType type, OSType manufacturer, const std::string &name)
{
    AudioComponentDescription desc = { type, 'iasp', manufacturer, 0, 0 };
    CFStringRef cfname = CFStringCreateWithBytes(NULL, (const UInt8 *) name.c_str(),
                                                 name.size(), kCFStringEncodingUTF8, false);
    OSStatus result = AudioOutputUnitPublish(&desc, cfname, 1, m_au);
    if (result != noErr)
        NSLog(@"AGInterAppAudioManager::publishInterAppAudioUnit: error: %d", (int)result);
    CFRelease(cfname);
}

bool AGInterAppAudioManager::isInterAppAudio()
{
    Boolean isInterApp = 0;
    UInt32 size = sizeof(Boolean);
    
    AudioUnitGetProperty(m_au, kAudioUnitProperty_IsInterAppConnected,
                         kAudioUnitScope_Global, 0,
                         &isInterApp, &size);
    
    return isInterApp;
}

void AGInterAppAudioManager::launchInterAppAudioHost()
{
    if(isInterAppAudio())
    {
        CFURLRef hostURL;
        UInt32 dataSize = sizeof(CFURLRef);
        OSStatus result = AudioUnitGetProperty(m_au, kAudioUnitProperty_PeerURL,
                                               kAudioUnitScope_Global, 0,
                                               &hostURL, &dataSize);
        if (result == noErr)
            [[UIApplication sharedApplication] openURL:(__bridge_transfer NSURL *) hostURL];
        else
            // uhh
            NSLog(@"warning: unable to retrieve peer url");
    }
}

void AGInterAppAudioManager::onInterAppAudioEnabled()
{
    m_onInterAppAudioEnable(isInterAppAudio());
}
