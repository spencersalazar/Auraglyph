//
//  AGControlMidiNoteIn.cpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGMidiInput.h"
#include "AGControlNode.h"
#include "AGTimer.h"
#include "AGStyle.h"

//------------------------------------------------------------------------------
// ### AGControlMidiNoteIn ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiNoteIn

class AGControlMidiNoteIn : public AGControlNode, public AGMidiInput
{
public:
    
    enum Param
    {
        PARAM_NOTEIN_CHANNEL,
        PARAM_NOTEIN_PITCH,
        PARAM_NOTEIN_VELOCITY,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMidiNoteIn>
    {
    public:
        string _type() const override { return "MIDI Note In"; };
        string _name() const override { return "MIDI Note In"; };
        string _description() const override { return "MIDI Note In Node."; };
        
        vector<AGPortInfo> _inputPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_NOTEIN_CHANNEL, "Channel", ._default = 0, .min = 0, .max = 16,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Channel." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_NOTEIN_PITCH, "Notein: pitch", true, false, .doc = "Pitch of a note." },
                { PARAM_NOTEIN_VELOCITY, "Notein: velocity", true, false, .doc = "Velocity of a note." },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.006*AGStyle::oldGlobalScale;
            float radius_circ = radius * 0.8;
            int circleSize = 16;
            int GEO_SIZE = circleSize*2;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            // Outer circle
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
                float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius_circ*cosf(theta0), radius_circ*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius_circ*cosf(theta1), radius_circ*sinf(theta1), 0);
            }
            
            // Circles for MIDI "pins"
            for(int i = 0; i < 5; i++)
            {
                for(int j = 0; j < GEO_SIZE; j++)
                {
                    GLvertex3f vert = iconGeo[j];
                    float radius_pins = radius_circ * 0.6; // Radius described by arc of pins
                    vert = vert * 0.1; // Size of pin circle
                    float theta = M_PI * 0.25 * i; // rotate each pin by 1/5 pi
                    vert = vert + GLvertex3f(radius_pins*cosf(theta), radius_pins*sinf(theta), 0);
                    iconGeo.push_back(vert);
                }
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };

    using AGControlNode::AGControlNode;
    
    void initFinal() override
    {
        initObjC();
    }

    virtual int numOutputPorts() const override { return 2; }
    
    void editPortValueChanged(int paramId) override
    {
        // XXX when we implement channel filtering we will need to address this
    }
    
    // MIDI message handler
    void messageReceived(double deltatime, vector<unsigned char> *message) override
    {
        // Examine our first byte to determine the type of message
        uint8_t chr = message->at(0);
        
        int nodeChan = param(PARAM_NOTEIN_CHANNEL);
        
        if(nodeChan == 0)
        {
            chr &= 0xF0; // All channels, just clear the lower nibble
        }
        else {
            int msgChan = (chr & 0x0F) + 1; // Extract channel information, nudge to 1-indexed
            
            if(msgChan != nodeChan)
            {
                return; // If channel doesn't match, return
            }
            else {
                chr &= 0xF0; // Clear lower nibble, continue parsing message below
            }
        }
        
        static bool noteStatus = false; // Kludgy flag for legato tracking
        static uint8_t curNote = 0x00; //
        
        if(chr == 0x80) // Note off
        {
            if(message->at(1) == curNote)
            {
                noteStatus = false;
                
                pushControl(0, AGControl(message->at(1))); // Note pitch; do we even need to send this?
                
                // If for some reason we want to handle nonzero velocities for note off
                //pushControl(1, AGControl(message->at(2)));
                
                pushControl(1, AGControl(0)); // Assume zero, ignoring the velocity byte
            }
        }
        else if(chr == 0x90) // Note on
        {
            noteStatus = true;
            curNote = message->at(1);
            
            pushControl(0, AGControl(message->at(1))); // Note pitch
            
            // XXX surrounding this with an if(noteStatus && !shouldPlayLegato) would
            // allow us to implement, well, legato...
            pushControl(1, AGControl(message->at(2))); // Note velocity (handles zero velocity as noteoff)
        }
        else if(chr == 0xA0) { } // Mmmm... polyphonic aftertouch
        else if(chr == 0xB0) { } // CC
    }
};
