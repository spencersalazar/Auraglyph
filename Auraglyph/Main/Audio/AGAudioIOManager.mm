//
//  AGAudioIOManager.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/27/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGAudioIOManager.h"

#import "TheAmazingAudioEngine/TheAmazingAudioEngine.h"
#import "Modules/AEPlaythroughChannel.h"
#import <AVFoundation/AVFoundation.h>

#include "AGInterAppAudioManager.h"

@interface AGAudioIOManagerProxy : NSObject

@property AGAudioIOManager *audioIOManager;

- (void)applicationWillResignActive:(NSNotification *)n;
- (void)applicationDidBecomeActive:(NSNotification *)n;

@end

@implementation AGAudioIOManagerProxy

- (id)initWithAudioIOManager:(AGAudioIOManager *)audioIOManager
{
    if (self = [super init]) {
        self.audioIOManager = audioIOManager;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:[UIApplication sharedApplication]];

    return self;
}

- (void)applicationWillResignActive:(NSNotification *)n
{
    self.audioIOManager->applicationWillResignActive();
}

- (void)applicationDidBecomeActive:(NSNotification *)n
{
    self.audioIOManager->applicationDidBecomeActive();
}

@end

AGAudioIOManager::AGAudioIOManager(int sampleRate, int bufferSize,
                                   bool inputEnabled, AGAudioIORenderer *renderer)
: m_sampleRate(sampleRate), m_bufferSize(bufferSize),
m_inputEnabled(inputEnabled), m_renderer(renderer)
{
    AudioStreamBasicDescription audioDescription;
    memset(&audioDescription, 0, sizeof(audioDescription));
    audioDescription.mFormatID          = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags       = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    audioDescription.mChannelsPerFrame  = m_numOutputChannels;
    audioDescription.mBytesPerPacket    = sizeof(float);
    audioDescription.mFramesPerPacket   = 1;
    audioDescription.mBytesPerFrame     = sizeof(float);
    audioDescription.mBitsPerChannel    = 8 * sizeof(float);
    audioDescription.mSampleRate        = m_sampleRate;
    
    m_audioController = [[AEAudioController alloc] initWithAudioDescription:audioDescription inputEnabled:m_inputEnabled];
    m_audioController.allowMixingWithOtherApps = YES;
    
    m_audioController.preferredBufferDuration = m_bufferSize/((float) m_sampleRate);
    
    int actualBufferSize = (int) (m_audioController.currentBufferDuration*m_sampleRate);
    m_ioBuffer.resize(actualBufferSize*m_numOutputChannels);
    
    m_outputChannel = _createOutputChannel();
    m_inputOutputFilter = _createInputOutputFilter();
    m_playthroughChannel = [AEPlaythroughChannel new];
    
    _updateAudioChannel();
    
    m_interAppAudio.reset(new AGInterAppAudioManager(m_audioController.audioUnit, [this](bool iaaEnabled) {
        enableInput(false);
        startAudio();
    }));
    m_interAppAudio->publishInterAppAudioUnit(kAudioUnitType_RemoteInstrument, 'Aura', "Auraglyph");
    m_interAppAudio->publishInterAppAudioUnit(kAudioUnitType_RemoteGenerator, 'Aura', "Auraglyph");
    
    m_proxy = [[AGAudioIOManagerProxy alloc] initWithAudioIOManager:this];
}

AGAudioIOManager::~AGAudioIOManager()
{
    m_audioController = nil;
    m_outputChannel = nil;
    m_inputOutputFilter = nil;
    m_playthroughChannel = nil;
    m_proxy = nil;
}

bool AGAudioIOManager::startAudio()
{
    NSError *error;
    [m_audioController start:&error];
    if(error != nil) {
        NSLog(@"AGAudioIOManager::startAudio: error: %@", [error description]);
        return false;
    }
    
    return true;
}

bool AGAudioIOManager::stopAudio()
{
    [m_audioController stop];
    
    return true;
}

bool AGAudioIOManager::enableInput(bool enable)
{
    if (enable != m_inputEnabled) {
        NSError *error = nil;
        [m_audioController setInputEnabled:enable error:&error];
        if (error != nil) {
            NSLog(@"AGAudioIOManager::enableInput: error: %@", [error description]);
            return false;
        }
        
        m_inputEnabled = enable;
        _updateAudioChannel();
    }
    
    return true;
}

AGAudioIOManager::InputPermission AGAudioIOManager::inputPermission()
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    auto permission = session.recordPermission;
    switch(permission) {
        case AVAudioSessionRecordPermissionUndetermined:
            return INPUT_PERMISSION_UNKNOWN;
        case AVAudioSessionRecordPermissionDenied:
            return INPUT_PERMISSION_DENIED;
        case AVAudioSessionRecordPermissionGranted:
            return INPUT_PERMISSION_ALLOWED;
    }
    // this shouldnt happen
    return INPUT_PERMISSION_UNKNOWN;
}

void AGAudioIOManager::applicationWillResignActive()
{
    if(!m_interAppAudio->isInterAppAudio()) {
        stopAudio();
    }
}

void AGAudioIOManager::applicationDidBecomeActive()
{
    startAudio();
}

void AGAudioIOManager::_render(int numFrames, Buffer<float> &frames)
{
    if(m_renderer) {
        m_renderer->render(numFrames, frames);
    }
}

void AGAudioIOManager::_updateAudioChannel()
{
    // remove all channels
    [m_audioController removeChannels:@[m_outputChannel]];
    [m_audioController removeChannels:@[m_playthroughChannel]];
    [m_audioController removeFilter:m_inputOutputFilter];
    
    // add channel according to output or input+output
    if(m_inputEnabled) {
        [m_audioController addFilter:m_inputOutputFilter];
        m_playthroughChannel.channelIsMuted = YES; // start muted to avoid feedback
        [m_audioController addInputReceiver:m_playthroughChannel];
        [m_audioController addChannels:@[m_playthroughChannel]];
    } else {
        [m_audioController addChannels:@[m_outputChannel]];
    }
}

AEBlockChannel *AGAudioIOManager::_createOutputChannel()
{
    AEBlockChannel *outputChannel = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp *time,
                                                                       UInt32 frames,
                                                                       AudioBufferList *audio) {
        if(m_ioBuffer.size < frames*m_numOutputChannels) {
            NSLog(@"warning: IO buffer resized from %li to %u in audio I/O process",
                  m_ioBuffer.size, (unsigned int) frames*m_numOutputChannels);
            m_ioBuffer.resize(frames*m_numOutputChannels);
        }
        
        m_ioBuffer.clear();
        
        _render(frames, m_ioBuffer);
        
        // deinterleave output
        for(int i = 0; i < frames; i++) {
            ((float*)(audio->mBuffers[0].mData))[i] = m_ioBuffer[i*2];
            ((float*)(audio->mBuffers[1].mData))[i] = m_ioBuffer[i*2+1];
        }
    }];
    
    return outputChannel;
}


AEBlockFilter *AGAudioIOManager::_createInputOutputFilter()
{
    AEBlockFilter *filter = [AEBlockFilter filterWithBlock:^(AEAudioFilterProducer producer,
                                                             void *producerToken,
                                                             const AudioTimeStamp *time,
                                                             UInt32 frames,
                                                             AudioBufferList *audio) {
        if(m_playthroughChannel.channelIsMuted)
            m_playthroughChannel.channelIsMuted = NO;  // unmute now that there will not be feedback
        
        if(m_ioBuffer.size < frames*m_numOutputChannels) {
            NSLog(@"warning: IO buffer resized from %li to %u in audio I/O process",
                  m_ioBuffer.size, (unsigned int) frames*m_numOutputChannels);
            m_ioBuffer.resize(frames*m_numOutputChannels);
        }
        
        OSStatus status = producer(producerToken, audio, &frames);
        if(status != noErr) {
            NSLog(@"warning: received error %i generating audio input", (int)status);
            m_ioBuffer.clear();
        } else {
            // interleave input
            for(int i = 0; i < frames; i++) {
                m_ioBuffer[i*2] = ((float*)(audio->mBuffers[0].mData))[i];
                m_ioBuffer[i*2+1] = ((float*)(audio->mBuffers[1].mData))[i];
            }
        }
        
        _render(frames, m_ioBuffer);
        
        // deinterleave output
        for(int i = 0; i < frames; i++) {
            ((float*)(audio->mBuffers[0].mData))[i] = m_ioBuffer[i*2];
            ((float*)(audio->mBuffers[1].mData))[i] = m_ioBuffer[i*2+1];
        }
    }];
    
    return filter;
}

