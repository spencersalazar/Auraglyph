//
//  AGMidiInput.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 8/6/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#ifndef AGMidiInput_h
#define AGMidiInput_h

#include "AGMidiConnectionListener.h"

#include <vector>

#pragma mark - AGMidiInput

class AGMidiInput
{
public:
    ~AGMidiInput();
    
    // MIDI message handler
    virtual void messageReceived(double deltatime, std::vector<unsigned char> *message) = 0;
    
    void attachToAllExistingSources();
    void detachFromAllExistingSources();
    
    static void listPorts();
    static vector<string>& getPortList();
    static int getNumPorts();
    static string getPortName(unsigned int portNumber);
    
    bool openPort(unsigned int portNumber);
    bool openPort(string deviceName);
    bool openVirtualPort(string portName); ///< currently noop on iOS
    void closePort();
    
    void ignoreTypes(bool midiSysex=true, bool midiTiming=true, bool midiSense=true);
    static void setConnectionListener(AGMidiConnectionListener * listener);
    static void clearConnectionListener();
    static void enableNetworking();

protected:
    void initObjC(); // Hook up pointer bridge to Objective C
    
private:
    struct InputDelegate;
    InputDelegate *inputDelegate;
    
    int portNum;     //< current port num, -2 if not connected, -1 if we're listening to all
    string portName; //< current port name, "" if not connected
    
    static vector<string> portList; //< list of port names
    
    bool bOpen;    //< is the port currently open?
    bool bVerbose; //< print incoming bytes?
    bool bVirtual; //< are we connected to a virtual port?
};

#endif /* AGMidiInput_h */
