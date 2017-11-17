//
//  AGMidiOutput.mm
//  Auragraph
//
//  Created by Andrew Piepenbrink on 8/27/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGMidiOutput.h"
#include "AGPGMidiContext.h"

#include <iostream>

#pragma mark - AGMidiOutput

// PIMPL wrapper from http://stackoverflow.com/questions/7132755/wrapping-objective-c-in-objective-c-c
struct AGMidiOutput::MidiDestination {
    PGMidiDestination *d; // Output
};

vector<string> AGMidiOutput::portList;

void AGMidiOutput::initObjC()
{
    AGPGMidiContext::setup();
    // Go for it!
    attachToAllExistingDestinations();
}

AGMidiOutput::~AGMidiOutput()
{
    detachFromAllExistingDestinations();
    destinations.clear();
}

void AGMidiOutput::attachToAllExistingDestinations()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    for (PGMidiDestination *dest in midi.destinations)
    {
        destinations.push_back(new MidiDestination);
        destinations.back()->d = dest;
    }
}

void AGMidiOutput::detachFromAllExistingDestinations()
{
    destinations.clear();
}

void AGMidiOutput::sendMessage()
{
    
    Byte packetBuffer[message.size()+100]; // XXX do we really need 100 extra bytes?
    MIDIPacketList *packetList = (MIDIPacketList*)packetBuffer;
    MIDIPacket *packet = MIDIPacketListInit(packetList);
    
    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, message.size(), &message[0]);
    
    for (auto destination : destinations)
    {
        [destination->d sendPacketList:packetList];
    }
}

void AGMidiOutput::listPorts()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    int count = [midi.destinations count];
    cout << count << " ports available";
    for(NSUInteger i = 0; i < count; ++i) {
        PGMidiDestination *destination = [midi.destinations objectAtIndex:i];
        cout << i << ": " << [destination.name UTF8String] << endl;
    }
}

vector<string>& AGMidiOutput::getPortList()
{
    PGMidi *midi = AGPGMidiContext::getMidi();
    portList.clear();
    for(PGMidiDestination *destination in midi.destinations) {
        portList.push_back([destination.name UTF8String]);
    }
    return portList;
}

int AGMidiOutput::getNumPorts()
{
    return [AGPGMidiContext::getMidi().destinations count];
}

string AGMidiOutput::getPortName(unsigned int portNumber)
{
    
    PGMidi *midi = AGPGMidiContext::getMidi();
    
    // handle OBJ-C exceptions
    @try {
        PGMidiDestination *destination = [midi.destinations objectAtIndex:portNumber];
        return [destination.name UTF8String];
    }
    @catch(NSException *ex) {
        cout << "couldn't get name for port " << portNumber
        << " " << [ex.name UTF8String] << ": " << [ex.reason UTF8String] << endl;
    }
    return "";
}

bool AGMidiOutput::openPort(unsigned int portNumber)
{
    
    PGMidi *midi = AGPGMidiContext::getMidi();
    PGMidiDestination *dest = nil;
    
    // handle OBJ-C exceptions
    @try {
        dest = [midi.destinations objectAtIndex:portNumber];
    }
    @catch(NSException *ex) {
        cout << "couldn't open port " << portNumber << " " << [ex.name UTF8String]
        << ": " << [ex.reason UTF8String] << endl;
        return false;
    }
    
    destinations.clear();
    MidiDestination *new_dest = new MidiDestination;
    new_dest->d = dest;
    destinations.push_back(new_dest);
    
    portNum = portNumber;
    portName = [dest.name UTF8String];
    bOpen = true;
    cout << "opened port " << portNum << " " << portName << endl;
    return true;
}

bool AGMidiOutput::openPort(string deviceName)
{
    
    PGMidi *midi = AGPGMidiContext::getMidi();
    
    // iterate through MIDI ports, find requested device
    int port = -2;
    for(NSUInteger i = 0; i < [midi.destinations count]; ++i) {
        PGMidiDestination *dest = [midi.destinations objectAtIndex:i];
        if([dest.name UTF8String] == deviceName) {
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

bool AGMidiOutput::openVirtualPort(string portName)
{
    cout << "couldn't open virtual port \"" << portName << endl;
    cout << "virtual ports are currently not supported on iOS" << endl;
    return false;
}

void AGMidiOutput::closePort()
{
    destinations.clear();
    
    portNum = -1;
    portName = "";
    bOpen = false;
    bVirtual = false;
}

//void AGMidiOutput::setConnectionListener(AGMidiConnectionListener * listener)
//{
//    AGPGMidiContext::setConnectionListener(listener);
//}
//
//void AGMidiOutput::clearConnectionListener()
//{
//    AGPGMidiContext::clearConnectionListener();
//}
//
//void AGMidiOutput::enableNetworking()
//{
//    AGPGMidiContext::enableNetwork();
//}

