//
//  AGPGMidiContext.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#import "PGMidi.h"
#import "AGPGMidiDelegate.h"

class AGPGMidiContext
{
public:
    
    /// creates the PGMidi instance if not already existing
    static void setup();
    
    /// get the PGMidi instance
    static PGMidi* getMidi();
    
    /// set the listener for device (dis)connection events
    static void setConnectionListener(AGMidiConnectionListener *listener);
    static void clearConnectionListener();
    
    /// enable the iOS CoreMidi network interface?
    static void enableNetwork(bool enable=true);
    
private:
    
    // XXX Yay, we don't need this, thanks ARC!
    //static NSAutoreleasePool *pool; // for happy garbage collection ...
    
    static PGMidi *midi; ///< global Obj-C PGMidi instance
    static AGPGMidiDelegate *delegate; ///< device (dis)connection interface
};
