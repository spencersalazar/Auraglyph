//
//  AGAudioManager.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/13/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGAudioManager.h"
#import "AGNode.h"
#import "AGAudioNode.h"
#import "AGTimer.h"

#import "mo_audio.h"

#import "Mutex.h"
#import "spstl.h"



class AGAudioManagerOutputDestination : public AGAudioOutputDestination
{
public:
    
    AGAudioManagerOutputDestination(AGAudioManager *manager) :
    m_manager(manager)
    { }
    
    void addOutput(AGAudioRenderer *renderer) override
    {
        [m_manager addRenderer:renderer];
    }
    
    virtual void removeOutput(AGAudioRenderer *renderer) override
    {
        [m_manager removeRenderer:renderer];
    }
    
private:
    AGAudioManager *m_manager;
};


static float g_audio_buf[1024];

@interface AGAudioManager ()
{
    sampletime t;
    
    list<AGAudioRenderer *> _renderers;
    Mutex _renderersMutex;
    list<AGAudioCapturer *> _capturers;
    Mutex _capturersMutex;
    list<AGTimer *> _timers;
    Mutex _timersMutex;
    
    float _inputBuffer[1024];
}

- (void)renderAudio:(Float32 *)buffer numFrames:(UInt32)numFrames;

@end


void audio_cb( Float32 * buffer, UInt32 numFrames, void * userData )
{
    [(__bridge AGAudioManager *)userData renderAudio:buffer numFrames:numFrames];
}

static AGAudioManager *g_audioManager;


@implementation AGAudioManager

+ (instancetype)instance
{
    return g_audioManager;
}

- (id)init
{
    if(self = [super init])
    {
        g_audioManager = self;
        
        self.masterOut = new AGAudioManagerOutputDestination(self);
        
        t = 0;
        
        memset(g_audio_buf, 0, sizeof(float)*1024);
        memset(_inputBuffer, 0, sizeof(float)*1024);
        
        MoAudio::init(AGAudioNode::sampleRate(), AGAudioNode::bufferSize(), 2);
        MoAudio::start(audio_cb, (__bridge void *) self);
    }
    
    return self;
}

- (void)dealloc
{
    SAFE_DELETE(self.masterOut);
}

- (void)addRenderer:(AGAudioRenderer *)renderer
{
    _renderersMutex.lock();
    _renderers.push_back(renderer);
    _renderersMutex.unlock();
}

- (void)removeRenderer:(AGAudioRenderer *)renderer
{
    _renderersMutex.lock();
    _renderers.remove(renderer);
    _renderersMutex.unlock();
}

- (void)addCapturer:(AGAudioCapturer *)capturer
{
    _capturersMutex.lock();
    _capturers.push_back(capturer);
    _capturersMutex.unlock();
}

- (void)removeCapturer:(AGAudioCapturer *)capturer
{
    _capturersMutex.lock();
    _capturers.remove(capturer);
    _capturersMutex.unlock();
}

- (void)addTimer:(AGTimer *)timer
{
    _timersMutex.lock();
    _timers.push_back(timer);
    _timersMutex.unlock();
}

- (void)removeTimer:(AGTimer *)timer
{
    _timersMutex.lock();
    _timers.remove(timer);
    _timersMutex.unlock();
}


- (void)renderAudio:(Float32 *)buffer numFrames:(UInt32)numFrames
{
    memset(g_audio_buf, 0, sizeof(float)*1024);
    
    _timersMutex.lock();
    for(AGTimer *timer : _timers )
    {
        float tf = ((float)t)/((float)AGAudioNode::sampleRate());
        float dtf = ((float)numFrames)/((float)AGAudioNode::sampleRate());
        timer->checkTimer(tf, dtf);
    };
    _timersMutex.unlock();
    
    for(int i = 0; i < numFrames; i++)
    {
        _inputBuffer[i] = buffer[i*2];
    }
    
    _capturersMutex.lock();
    for(AGAudioCapturer *capturer : _capturers)
        capturer->captureAudio(_inputBuffer, numFrames);
    _capturersMutex.unlock();
    
    _renderersMutex.lock();
    for(AGAudioRenderer *renderer : _renderers)
        renderer->renderAudio(t, NULL, g_audio_buf, numFrames, 0, 1);
    _renderersMutex.unlock();
    
    for(int i = 0; i < numFrames; i++)
    {
        buffer[i*2] = g_audio_buf[i];
        buffer[i*2+1] = g_audio_buf[i];
    }
    
    t += numFrames;
}


@end
