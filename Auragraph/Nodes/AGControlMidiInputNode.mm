//
//  AGControlMidiInputNode.cpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGControlMidiInputNode.h"

#include "AGStyle.h"

#include "AGPGMidiSourceDelegate.h"

#include <iostream>

//#import <CoreMotion/CoreMotion.h>
//#import "PGMidi.h"

// XXX hint: we might want to #include our Context here, as in ofx

//------------------------------------------------------------------------------
// ### AGControlMidiInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiInputNode

// PIMPL wrapper from http://stackoverflow.com/questions/7132755/wrapping-objective-c-in-objective-c-c
struct AGControlMidiInputNode::InputDelegate {
    AGPGMidiSourceDelegate *d; ///< Obj-C input delegate
};

vector<GLvertex3f> AGControlMidiInputNode::Manifest::_iconGeo() const
{
    float radius = 0.005*AGStyle::oldGlobalScale;
    float squash = 1.0f/3.0f;
    
    // icon
    int ptsPerCircle = 32;
    vector<GLvertex3f> iconGeo(ptsPerCircle*3*2);
    
    // regular circle around center
    for(int i = 0; i < ptsPerCircle; i++)
    {
        float theta0 = ((float)i)/(ptsPerCircle)*2.0f*M_PI;
        float theta1 = ((float)i+1)/(ptsPerCircle)*2.0f*M_PI;
        iconGeo[i*2+0] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0), 0);
        iconGeo[i*2+1] = GLvertex3f(radius*cosf(theta1), radius*sinf(theta1), 0);
    }
    
    // circle around center squashed on x-axis
    for(int i = 0; i < ptsPerCircle; i++)
    {
        float theta0 = ((float)i)/(ptsPerCircle)*2.0f*M_PI;
        float theta1 = ((float)i+1)/(ptsPerCircle)*2.0f*M_PI;
        iconGeo[ptsPerCircle*2+i*2+0] = GLvertex3f(radius*squash*cosf(theta0), radius*sinf(theta0), 0);
        iconGeo[ptsPerCircle*2+i*2+1] = GLvertex3f(radius*squash*cosf(theta1), radius*sinf(theta1), 0);
    }
    
    // circle around center squashed on y-axis
    for(int i = 0; i < ptsPerCircle; i++)
    {
        float theta0 = ((float)i)/(ptsPerCircle)*2.0f*M_PI;
        float theta1 = ((float)i+1)/(ptsPerCircle)*2.0f*M_PI;
        iconGeo[ptsPerCircle*4+i*2+0] = GLvertex3f(radius*cosf(theta0), radius*squash*sinf(theta0), 0);
        iconGeo[ptsPerCircle*4+i*2+1] = GLvertex3f(radius*cosf(theta1), radius*squash*sinf(theta1), 0);
    }
    
    return iconGeo;
};

void AGControlMidiInputNode::initFinal()
{
//    m_manager = [[CMMotionManager alloc] init];
//    [m_manager startDeviceMotionUpdates];
//    
//    m_timer.setInterval(1.0f/param(PARAM_RATE).getFloat());
//    m_timer.setAction([this](AGTimer *timer){
//        if(inbound().size() == 0)
//            _pushData();
//    });
    
//    m_midi = [[PGMidi alloc] init];
    
    // setup global midi instance
    AGPGMidiContext::setup();
    
    // setup Obj-C interface to PGMidi
    inputDelegate = new InputDelegate;
    inputDelegate->d = [[AGPGMidiSourceDelegate alloc] init];
    [inputDelegate->d setInputPtr:(void*) this];
    
    // Go for it!
    attachToAllExistingSources();
}

AGControlMidiInputNode::~AGControlMidiInputNode()
{
//    [m_manager stopDeviceMotionUpdates];
//    m_manager = nil;
    
    // XXX we need to figure out how to handle this
    // [m_midi doSomethingToStopMidi];
    // m_midi = nil;
    
    //[inputDelegate->d release]; // XXX no need for this b/c of ARC
    delete inputDelegate;
}

void AGControlMidiInputNode::attachToAllExistingSources()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    for (PGMidiSource *source in midi.sources)
    {
        [source addDelegate:inputDelegate->d];
    }
    
}


void AGControlMidiInputNode::editPortValueChanged(int paramId)
{
//    switch(paramId)
//    {
//        case PARAM_RATE:
//            m_timer.setInterval(1.0f/param(PARAM_RATE).getFloat());
//            break;
//    }
    
    // XXX when we implement channel filtering we will need to address this
}

// XXX we shouldn't need to do any of this for MIDI input, MIDI output will be a different story
//void AGControlMidiInputNode::receiveControl(int port, const AGControl &control)
//{
//    _pushData();
//}

//void AGControlMidiInputNode::_pushData()
//{
//    AGControl roll = AGControl((float) m_manager.deviceMotion.attitude.roll);
//    AGControl pitch = AGControl((float) m_manager.deviceMotion.attitude.pitch);
//    AGControl yaw = AGControl((float) m_manager.deviceMotion.attitude.yaw);
//    
//    pushControl(0, roll);
//    pushControl(1, pitch);
//    pushControl(2, yaw);
    
    // XXX do we do something message-specific within this method, or split it into note, CC, etc.-specific methods?
//}

// XXX new MIDI stuff from ofx
/// wrapper around manageNewMessage
void AGControlMidiInputNode::messageReceived(double deltatime, vector<unsigned char> *message)
{
    // Basically this is our new 'pushControl'; I assume we should have some logic in here
    // to do a bit of final parsing (SourceDelegate is doing most of the heavy lifting) and
    // perhaps do things differently for notes vs. CC's, etc.
    
    // That's cute, but we can't attach our MIDI controller while we're able
    // to view these messages in XCode
    //std::cout << "Bang!" << std::endl;
    pushControl(0, AGControl(1));
    
}

void AGControlMidiInputNode::setConnectionListener(AGMidiConnectionListener * listener)
{
    //ofxPGMidiContext::setConnectionListener(listener);
    // XXX This is where we'll interact with our MidiContext... somehow
}

void AGControlMidiInputNode::ignoreTypes(bool midiSysex, bool midiTiming, bool midiSense) {
    
    inputDelegate->d.bIgnoreSysex = midiSysex;
    inputDelegate->d.bIgnoreTiming = midiTiming;
    inputDelegate->d.bIgnoreSense = midiSense;
    
    //ofLogVerbose("ofxMidiIn") << "ignore types on " << portName << ": sysex: " << midiSysex
    //<< " timing: " << midiTiming << " sense: " << midiSense;
}

