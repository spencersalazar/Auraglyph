//
//  AGControlMidiInput.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 8/6/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#ifndef AGControlMidiInputNode_h
#define AGControlMidiInputNode_h

#include <vector>

// This is a stub superclass for the note and CC nodes. Kludgy AF
class AGControlMidiInput
{
public:
    // MIDI message handler
    virtual void messageReceived(double deltatime, std::vector<unsigned char> *message) = 0;
};

#endif /* AGControlMidiInputNode_h */
