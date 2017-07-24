//
//  AGControlMidiInputNode.cpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#include "AGStyle.h"
#include "AGControlMidiInputNode.h"
#include "AGPGMidiSourceDelegate.h"

#include <iostream>

//------------------------------------------------------------------------------
// ### AGControlMidiInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiInputNode

// PIMPL wrapper from http://stackoverflow.com/questions/7132755/wrapping-objective-c-in-objective-c-c
struct AGControlMidiInputNode::InputDelegate {
    AGPGMidiSourceDelegate *d; ///< Obj-C input delegate
};

void AGControlMidiInputNode::initFinal()
{
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
    // XXX when we implement channel filtering we will need to address this
}

void AGControlMidiInputNode::messageReceived(double deltatime, vector<unsigned char> *message)
{
    // Examine our first byte to determine the type of message
    uint8_t chr = message->at(0);
    
    // XXX should we do bounds checking? the SourceDelegate is already supposed to be
    // building packets of the correct length...
    
    chr &= 0xF0; // Ignore channel information for now by clearing the lower nibble
    
    static bool noteStatus = false; // Kludgy flag for legato tracking
    static uint8_t curNote = 0x00; //
    
    if(chr == 0x80) // Note off
    {
        if(message->at(1) == curNote)
        {
            noteStatus = false;
            
            pushControl(0, AGControl(message->at(1))); // Note pitch; do we even need to send this?
        
            // If for some reason we want to handle nonzero velocities for note off
            //pushControl(1, AGControl(message->at(2)));
        
            pushControl(1, AGControl(0)); // Assume zero, ignoring the velocity byte
        }
    }
    else if(chr == 0x90) // Note on
    {
        noteStatus = true;
        curNote = message->at(1);
        
        pushControl(0, AGControl(message->at(1))); // Note pitch
        
        // XXX surrounding this with an if(noteStatus && !shouldPlayLegato) would
        // allow us to implement, well, legato...
        pushControl(1, AGControl(message->at(2))); // Note velocity (handles zero velocity as noteoff)
    }
    else if(chr == 0xA0) { } // Mmmm... polyphonic aftertouch
    else if(chr == 0xB0) // CC
    {
        pushControl(2, AGControl(message->at(1))); // CC number
        pushControl(3, AGControl(message->at(2)));; // CC value
    }
    
    // XXX all for now, we'll worry about other message types later
}

void AGControlMidiInputNode::setConnectionListener(AGMidiConnectionListener * listener)
{
    // Nothing for now
}

void AGControlMidiInputNode::ignoreTypes(bool midiSysex, bool midiTiming, bool midiSense)
{
    inputDelegate->d.bIgnoreSysex = midiSysex;
    inputDelegate->d.bIgnoreTiming = midiTiming;
    inputDelegate->d.bIgnoreSense = midiSense;
}

