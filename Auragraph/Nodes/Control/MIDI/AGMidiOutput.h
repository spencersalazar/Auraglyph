//
//  AGMidiOutput.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 8/27/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#ifndef AGMidiOutput_h
#define AGMidiOutput_h

#include "AGMidiConnectionListener.h"

#include <vector>

#pragma mark - AGMidiOutput

class AGMidiOutput
{
public:
    ~AGMidiOutput();
    
    void attachToAllExistingDestinations();
    void detachFromAllExistingDestinations();
    
    static void listPorts();
    static vector<string>& getPortList();
    static int getNumPorts();
    static string getPortName(unsigned int portNumber);
    
    bool openPort(unsigned int portNumber);
    bool openPort(string deviceName);
    bool openVirtualPort(string portName); ///< currently noop on iOS
    void closePort();
    
    // XXX TODO: add back connectionListener stuff
    
protected:
    void initObjC(); // Hook up pointer bridge to Objective C

    vector<unsigned char> message;
    void sendMessage();
    
private:
    struct MidiDestination; // forward declaration for Obj-C wrapper
    vector<MidiDestination *> destinations; ///< Obj-C midi output interface
    
    int portNum;     //< current port num, -2 if not connected, -1 if we're listening to all
    string portName; //< current port name, "" if not connected
    
    static vector<string> portList; //< list of port names
    
    bool bOpen;    //< is the port currently open?
    bool bVerbose; //< print incoming bytes?
    bool bVirtual; //< are we connected to a virtual port?
};

#endif /* AGMidiOutput_h */
