//
//  AGControlMidiNoteIn.cpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#include "AGStyle.h"
#include "AGControlMidiNoteIn.h"
#include "AGPGMidiSourceDelegate.h"

#include <iostream>

//------------------------------------------------------------------------------
// ### AGControlMidiNoteIn ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiNoteIn

// PIMPL wrapper from http://stackoverflow.com/questions/7132755/wrapping-objective-c-in-objective-c-c
struct AGControlMidiNoteIn::InputDelegate {
    AGPGMidiSourceDelegate *d; ///< Obj-C input delegate
};

// Definition needed here since portList is static
vector<string> AGControlMidiNoteIn::portList;

void AGControlMidiNoteIn::initFinal()
{
    // setup Obj-C interface to PGMidi
    inputDelegate = new InputDelegate;
    inputDelegate->d = [[AGPGMidiSourceDelegate alloc] init];
    [inputDelegate->d setInputPtr:(AGControlMidiInput *) this];
    
    // Go for it!
    attachToAllExistingSources();
}

AGControlMidiNoteIn::~AGControlMidiNoteIn()
{
    detachFromAllExistingSources();
    delete inputDelegate;
}

void AGControlMidiNoteIn::attachToAllExistingSources()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    for (PGMidiSource *source in midi.sources)
    {
        [source addDelegate:inputDelegate->d];
    }
}

void AGControlMidiNoteIn::detachFromAllExistingSources()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    for (PGMidiSource *source in midi.sources)
    {
        [source removeDelegate:inputDelegate->d];
    }    
}

void AGControlMidiNoteIn::editPortValueChanged(int paramId)
{
    // XXX when we implement channel filtering we will need to address this
}

void AGControlMidiNoteIn::messageReceived(double deltatime, vector<unsigned char> *message)
{
    // Examine our first byte to determine the type of message
    uint8_t chr = message->at(0);
    
    int nodeChan = param(PARAM_NOTEOUT_CHANNEL);
    
    if(nodeChan == 0)
    {
        chr &= 0xF0; // All channels, just clear the lower nibble
    }
    else {
        int msgChan = (chr & 0x0F) + 1; // Extract channel information, nudge to 1-indexed

        if(msgChan != nodeChan)
        {
            return; // If channel doesn't match, return
        }
        else {
            chr &= 0xF0; // Clear lower nibble, continue parsing message below
        }
    }
    
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
    else if(chr == 0xB0) { } // CC
}

void AGControlMidiNoteIn::listPorts()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    int count = [midi.sources count];
    cout << count << " ports available";
    for(NSUInteger i = 0; i < count; ++i) {
        PGMidiSource *source = [midi.sources objectAtIndex:i];
        cout << i << ": " << [source.name UTF8String] << endl;
    }
}

vector<string>& AGControlMidiNoteIn::getPortList()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    portList.clear();
    for(PGMidiSource *source in midi.sources) {
        portList.push_back([source.name UTF8String]);
    }
    return portList;
}

int AGControlMidiNoteIn::getNumPorts()
{
    return [AGPGMidiContext::getMidi().sources count];
}

string AGControlMidiNoteIn::getPortName(unsigned int portNumber)
{
    
    PGMidi *midi = AGPGMidiContext::getMidi();
    
    // handle OBJ-C exceptions
    @try {
        PGMidiSource *source = [midi.sources objectAtIndex:portNumber];
        return [source.name UTF8String];
    }
    @catch(NSException *ex) {
        cout << "couldn't get name for port " << portNumber
        << " " << [ex.name UTF8String] << ": " << [ex.reason UTF8String] << endl;
    }
    return "";
}

bool AGControlMidiNoteIn::openPort(unsigned int portNumber)
{
    
    PGMidi *midi = AGPGMidiContext::getMidi();
    PGMidiSource *source = nil;
    
    // handle OBJ-C exceptions
    @try {
        source = [midi.sources objectAtIndex:portNumber];
    }
    @catch(NSException *ex) {
        cout << "couldn't open port " << portNumber << " " << [ex.name UTF8String]
        << ": " << [ex.reason UTF8String] << endl;
        return false;
    }
    [source addDelegate:inputDelegate->d];
    portNum = portNumber;
    portName = [source.name UTF8String];
    bOpen = true;
    cout << "opened port " << portNum << " " << portName << endl;
    return true;
}

bool AGControlMidiNoteIn::openPort(string deviceName)
{
    
    PGMidi *midi = AGPGMidiContext::getMidi();
    
    // iterate through MIDI ports, find requested device
    int port = -2;
    for(NSUInteger i = 0; i < [midi.sources count]; ++i) {
        PGMidiSource *source = [midi.sources objectAtIndex:i];
        if([source.name UTF8String] == deviceName) {
            port = i;
            break;
        }
    }
    
    // bail if not found
    if(port == -1) {
        cout << "port \"" << deviceName << "\" is not available" << endl;
        return false;
    }
    
    return openPort(port);
}

bool AGControlMidiNoteIn::openVirtualPort(string portName)
{
    cout << "couldn't open virtual port \"" << portName << endl;
    cout << "virtual ports are currently not supported on iOS" << endl;
    return false;
}

void AGControlMidiNoteIn::closePort()
{
    
    if(bOpen) {
        cout << "closing port " << portNum << " " << portName << endl;
        
        // sometimes the source may already have been removed in PGMidi, so make
        // sure we have a valid index otherwise the app will crash
        PGMidi *midi = AGPGMidiContext::getMidi();
        if(portNum < midi.sources.count) {
            PGMidiSource *source = [midi.sources objectAtIndex:portNum];
            [source removeDelegate:inputDelegate->d];
        }
    }
    
    portNum = -1;
    portName = "";
    bOpen = false;
    bVirtual = false;
}

void AGControlMidiNoteIn::ignoreTypes(bool midiSysex, bool midiTiming, bool midiSense)
{
    inputDelegate->d.bIgnoreSysex = midiSysex;
    inputDelegate->d.bIgnoreTiming = midiTiming;
    inputDelegate->d.bIgnoreSense = midiSense;
}

void AGControlMidiNoteIn::setConnectionListener(AGMidiConnectionListener * listener)
{
    AGPGMidiContext::setConnectionListener(listener);
}

void AGControlMidiNoteIn::clearConnectionListener()
{
    AGPGMidiContext::clearConnectionListener();
}

void AGControlMidiNoteIn::enableNetworking()
{
    AGPGMidiContext::enableNetwork();
}

