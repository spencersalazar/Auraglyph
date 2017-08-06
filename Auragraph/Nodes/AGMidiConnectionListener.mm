//
//  AGMidiConnectionListener.mm
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#include "AGMidiConnectionListener.h"

#include <iostream>

void AGMidiConnectionListener::midiInputAdded(string name, bool isNetwork) {
    cout << "Added MIDI input: " << name << endl;
}

void AGMidiConnectionListener::midiInputRemoved(string name, bool isNetwork) {
    cout << "Removed MIDI input: " << name << endl;
}

void AGMidiConnectionListener::midiOutputAdded(string name, bool isNetwork) {
    cout << "Added MIDI output: " << name << endl;
}

void AGMidiConnectionListener::midiOutputRemoved(string name, bool isNetwork) {
    cout << "Removed MIDI output: " << name << endl;
}
