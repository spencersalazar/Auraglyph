//
//  AGPGMidiDelegate.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#import "PGMidi.h"

class AGMidiConnectionListener;

@interface AGPGMidiDelegate : NSObject <PGMidiDelegate>
{
    AGMidiConnectionListener *listenerPtr;
}

- (void) midi:(PGMidi*)midi sourceAdded:(PGMidiSource *)source;
- (void) midi:(PGMidi*)midi sourceRemoved:(PGMidiSource *)source;
- (void) midi:(PGMidi*)midi destinationAdded:(PGMidiDestination *)destination;
- (void) midi:(PGMidi*)midi destinationRemoved:(PGMidiDestination *)destination;

- (void) setListenerPtr:(void *)p;

@end
