//
//  AGMidiInput.mm
//  Auragraph
//
//  Created by Andrew Piepenbrink on 8/26/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGStyle.h"
#include "AGMidiInput.h"
#include "AGPGMidiSourceDelegate.h"
#include "AGPGMidiContext.h"

#include <iostream>

//------------------------------------------------------------------------------
// ### AGMidiInput ###
//------------------------------------------------------------------------------
#pragma mark - AGMidiInput

// PIMPL wrapper from http://stackoverflow.com/questions/7132755/wrapping-objective-c-in-objective-c-c
struct AGMidiInput::InputDelegate {
    AGPGMidiSourceDelegate *d; ///< Obj-C input delegate
};

// Definition needed here since portList is static
vector<string> AGMidiInput::portList;

void AGMidiInput::initObjC()
{
    // setup Obj-C interface to PGMidi
    inputDelegate = new InputDelegate;
    inputDelegate->d = [[AGPGMidiSourceDelegate alloc] init];
    [inputDelegate->d setInputPtr:(AGMidiInput *) this];
    
    // Go for it!
    attachToAllExistingSources();
}

AGMidiInput::~AGMidiInput()
{
    detachFromAllExistingSources();
    delete inputDelegate;    
}

void AGMidiInput::attachToAllExistingSources()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    for (PGMidiSource *source in midi.sources)
    {
        [source addDelegate:inputDelegate->d];
    }
}

void AGMidiInput::detachFromAllExistingSources()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    for (PGMidiSource *source in midi.sources)
    {
        [source removeDelegate:inputDelegate->d];
    }
}

void AGMidiInput::listPorts()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    int count = [midi.sources count];
    cout << count << " ports available";
    for(NSUInteger i = 0; i < count; ++i) {
        PGMidiSource *source = [midi.sources objectAtIndex:i];
        cout << i << ": " << [source.name UTF8String] << endl;
    }
}

vector<string>& AGMidiInput::getPortList()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    portList.clear();
    for(PGMidiSource *source in midi.sources) {
        portList.push_back([source.name UTF8String]);
    }
    return portList;
}

int AGMidiInput::getNumPorts()
{
    return [AGPGMidiContext::getMidi().sources count];
}

string AGMidiInput::getPortName(unsigned int portNumber)
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

bool AGMidiInput::openPort(unsigned int portNumber)
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

bool AGMidiInput::openPort(string deviceName)
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
    if(port == -2) {
        cout << "port \"" << deviceName << "\" is not available" << endl;
        return false;
    }
    
    return openPort(port);
}

bool AGMidiInput::openVirtualPort(string portName)
{
    cout << "couldn't open virtual port \"" << portName << endl;
    cout << "virtual ports are currently not supported on iOS" << endl;
    return false;
}

void AGMidiInput::closePort()
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

void AGMidiInput::ignoreTypes(bool midiSysex, bool midiTiming, bool midiSense)
{
    inputDelegate->d.bIgnoreSysex = midiSysex;
    inputDelegate->d.bIgnoreTiming = midiTiming;
    inputDelegate->d.bIgnoreSense = midiSense;
}

void AGMidiInput::setConnectionListener(AGMidiConnectionListener * listener)
{
    AGPGMidiContext::setConnectionListener(listener);
}

void AGMidiInput::clearConnectionListener()
{
    AGPGMidiContext::clearConnectionListener();
}

void AGMidiInput::enableNetworking()
{
    AGPGMidiContext::enableNetwork();
}
