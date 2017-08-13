//
//  AGPGMidiContext.mm
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#include "AGPGMidiContext.h"

#import "iOSVersionDetection.h" // From PGMidi

PGMidi *AGPGMidiContext::midi = nil;
AGPGMidiDelegate *AGPGMidiContext::delegate = nil;

// -----------------------------------------------------------------------------
void AGPGMidiContext::setup() {
    if(midi != nil)
        return;
    IF_IOS_HAS_COREMIDI (
                         //pool = [[NSAutoreleasePool alloc] init];
                         midi = [[PGMidi alloc] init];
                         delegate = [[AGPGMidiDelegate alloc] init];
                         midi.delegate = delegate;
                         )
}

// -----------------------------------------------------------------------------
PGMidi* AGPGMidiContext::getMidi() {
    setup();
    return midi;
}

// -----------------------------------------------------------------------------
void AGPGMidiContext::setConnectionListener(AGMidiConnectionListener *listener) {
    [delegate setListenerPtr:(void*) listener];
}

// -----------------------------------------------------------------------------
void AGPGMidiContext::clearConnectionListener() {
    [delegate setListenerPtr:NULL];
}

// -----------------------------------------------------------------------------
void AGPGMidiContext::enableNetwork(bool enable) {
    if(enable) {
        midi.networkEnabled = YES;
    }
    else {
        midi.networkEnabled = NO;
    }
}
