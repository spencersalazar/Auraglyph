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

#import "Mutex.h"
#import "spstl.h"
#import "AGAudioRecorder.h"
#include "AGAudioIOManager.h"

#include <memory>



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


class AGAudioManagerRenderer : public AGAudioIORenderer
{
public:
    void render(int numFrames, Buffer<float> &frames) override;
    
    AGAudioManager *m_audioManager = nil;
};


@interface AGAudioManager ()
{
    sampletime t;
    
    list<AGAudioRenderer *> _renderers;
    Mutex _renderersMutex;
    list<AGAudioCapturer *> _capturers;
    Mutex _capturersMutex;
    list<AGTimer *> _timers;
    Mutex _timersMutex;
    list<AGAudioRateProcessor *> _processors;
    Mutex _processorsMutex;
    
    float _inputBuffer[1024];
    Buffer<float> _outputBuffer;
    
    Mutex _sessionRecorderMutex;
    AGAudioRecorder *_sessionRecorder;
    
    std::unique_ptr<AGAudioIOManager> _audioIO;
    std::unique_ptr<AGAudioManagerRenderer> _renderer;
}

- (void)renderAudio:(Float32 *)buffer numFrames:(UInt32)numFrames;

@end


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
        
        _outputBuffer.resize(1024*2);
        _outputBuffer.clear();
        
        memset(_inputBuffer, 0, sizeof(float)*1024);
        
        _renderer.reset(new AGAudioManagerRenderer);
        _renderer->m_audioManager = self;
        
        auto inputPermission = AGAudioIOManager::inputPermission();
        // enable audio input if recording permission is already granted
        bool enableInput = (inputPermission == AGAudioIOManager::INPUT_PERMISSION_ALLOWED);
        _audioIO.reset(new AGAudioIOManager(AGAudioNode::sampleRate(), AGAudioNode::bufferSize(),
                                            enableInput, _renderer.get()));
        _audioIO->startAudio();
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
    if (_capturers.size() == 0 &&
        !_audioIO->inputEnabled() &&
        _audioIO->inputPermission() != AGAudioIOManager::INPUT_PERMISSION_DENIED) {
        // enable input if not already / attempt to get record permission
        _audioIO->enableInput(true);
    }
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

- (void)addAudioRateProcessor:(AGAudioRateProcessor *)processor
{
    _processorsMutex.lock();
    _processors.push_back(processor);
    _processorsMutex.unlock();
}

- (void)removeAudioRateProcessor:(AGAudioRateProcessor *)processor
{
    _processorsMutex.lock();
    _processors.remove(processor);
    _processorsMutex.unlock();
}


- (void)renderAudio:(Float32 *)buffer numFrames:(UInt32)numFrames
{
    _outputBuffer.clear();
    
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
    
    _processorsMutex.lock();
    for(auto processor : _processors)
        processor->process(t);
    _processorsMutex.unlock();
    
    _renderersMutex.lock();
    for(AGAudioRenderer *renderer : _renderers)
        renderer->renderAudio(t, NULL, _outputBuffer, numFrames, 0, 2);
    _renderersMutex.unlock();
    
    for(int i = 0; i < numFrames; i++)
    {
        buffer[i*2] = _outputBuffer[i*2];
        buffer[i*2+1] = _outputBuffer[i*2+1];
    }
    
    t += numFrames;
    
    _sessionRecorderMutex.lock();
    
    if(_sessionRecorder)
        _sessionRecorder->render(_outputBuffer, numFrames);
    
    _sessionRecorderMutex.unlock();
}

- (void)startSessionRecording
{
    _sessionRecorderMutex.lock();
    
    if(!_sessionRecorder)
    {
        _sessionRecorder = new AGAudioRecorder;
        string file = AGAudioRecorder::pathForSessionRecording("m4a");
        NSLog(@"Starting session recording to %s", file.c_str());
        _sessionRecorder->startRecording(file, 2, AGAudioNode::sampleRate());
    }
    
    _sessionRecorderMutex.unlock();
}

- (void)stopSessionRecording
{
    _sessionRecorder->closeRecording();
    
    _sessionRecorderMutex.lock();
    
    if(_sessionRecorder)
    {
        delete _sessionRecorder;
        _sessionRecorder = NULL;
    }
    
    _sessionRecorderMutex.unlock();
}


@end


void AGAudioManagerRenderer::render(int numFrames, Buffer<float> &frames)
{
    [m_audioManager renderAudio:frames.buffer numFrames:numFrames];
}


AGAudioManager_ &AGAudioManager_::instance()
{
    static AGAudioManager_ *s_instance = nullptr;
    if(s_instance == nullptr)
    {
        s_instance = new AGAudioManager_([AGAudioManager instance]);
    }
    
    return *s_instance;
}

AGAudioManager_::AGAudioManager_(AGAudioManager *audioManager)
{
    m_audioManager = audioManager;
}

void AGAudioManager_::startSessionRecording()
{
    [m_audioManager startSessionRecording];
}

void AGAudioManager_::stopSessionRecording()
{
    [m_audioManager stopSessionRecording];
}

void AGAudioManager_::addAudioRateProcessor(AGAudioRateProcessor *processor)
{
    [m_audioManager addAudioRateProcessor:processor];
}

void AGAudioManager_::removeAudioRateProcessor(AGAudioRateProcessor *processor)
{
    [m_audioManager removeAudioRateProcessor:processor];
}

void AGAudioManager_::addCapturer(AGAudioCapturer *capturer)
{
    [m_audioManager addCapturer:capturer];
}

void AGAudioManager_::removeCapturer(AGAudioCapturer *capturer)
{
    [m_audioManager removeCapturer:capturer];
}

AGAudioOutputDestination *AGAudioManager_::masterOut()
{
    return m_audioManager.masterOut;
}
