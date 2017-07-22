//
//  AGPGMidiDelegate.mm
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGPGMidiDelegate.h"

// XXX we need this, unlike in ofxPGMidiDelegate.mm, because in ofx the 'midiInputAdded'
// etc. calls are coming from ofxMidi, not ofxPGmidi (i.e. the ../ofxMidi.h include)
#include "AGMidiConnectionListener.h"

@implementation AGPGMidiDelegate

- (id) init {
    self = [super init];
    listenerPtr = NULL;
    return self;
}

// -----------------------------------------------------------------------------
- (void) midi:(PGMidi*)midi sourceAdded:(PGMidiSource *)source {
    if(listenerPtr) {
        listenerPtr->midiInputAdded([source.name UTF8String], source.isNetworkSession);
    }
}

// -----------------------------------------------------------------------------
- (void) midi:(PGMidi*)midi sourceRemoved:(PGMidiSource *)source {
    if(listenerPtr) {
        listenerPtr->midiInputRemoved([source.name UTF8String], source.isNetworkSession);
    }
}

// -----------------------------------------------------------------------------
- (void) midi:(PGMidi*)midi destinationAdded:(PGMidiDestination *)destination {
    if(listenerPtr) {
        listenerPtr->midiOutputAdded([destination.name UTF8String], destination.isNetworkSession);
    }
}

// -----------------------------------------------------------------------------
- (void) midi:(PGMidi*)midi destinationRemoved:(PGMidiDestination *)destination {
    if(listenerPtr) {
        listenerPtr->midiOutputRemoved([destination.name UTF8String], destination.isNetworkSession);
    }
}

// -----------------------------------------------------------------------------
- (void) setListenerPtr:(void *)p {
    listenerPtr = (AGMidiConnectionListener*) p;
}

@end
