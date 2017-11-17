//
//  AGControlMidiCCIn.cpp
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
// ### AGControlMidiCCIn ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiCCIn

class AGControlMidiCCIn : public AGControlNode, public AGMidiInput
{
public:
    
    enum Param
    {
        PARAM_CCLEARN, // XXX TODO: this will eventually be a string type
        PARAM_CCNUM,
        PARAM_CHANNEL,
        PARAM_CCVAL,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMidiCCIn>
    {
    public:
        string _type() const override { return "MIDI CC In"; };
        string _name() const override { return "MIDI CC In"; };
        string _description() const override { return "MIDI CC In Node."; };
        
        vector<AGPortInfo> _inputPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_CCLEARN, "Learn", ._default = 0, .min = 0, .max = 1,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "CC learn" },
                { PARAM_CCNUM, "CC num", ._default = -1, .min = 0, .max = 127,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "CC number." },
                { PARAM_CHANNEL, "Channel", ._default = 0, .min = 0, .max = 16,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Channel." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_CCVAL, "CC out: CC value", .doc = "CC value." },
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
            
            // "CC" lettering
            for(int i = 0; i < 2; i++)
            {
                for(int j = 4; j < GEO_SIZE-4; j++)
                {
                    GLvertex3f vert = iconGeo[j];
                    //float radius_pins = radius_circ * 0.6; // Radius described by arc of pins
                    vert = vert * 0.2; // Size of letter
                    //float theta = M_PI * 0.25 * i; // rotate each pin by 1/5 pi
                    vert = vert + GLvertex3f((-0.2 + i*0.4)*radius, -0.35*radius, 0);
                    iconGeo.push_back(vert);
                }
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual void initFinal() override
    {
        initObjC();
        
        ccNum = param(PARAM_CCNUM);
        bLearn = false;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_CCLEARN)
        {
            int flag = param(PARAM_CCLEARN);
            bLearn = static_cast<bool>(flag);
        }
        else if(paramId == PARAM_CCNUM)
        {
            ccNum = param(PARAM_CCNUM);
        }
    }
    
    // MIDI message handler
    void messageReceived(double deltatime, vector<unsigned char> *message) override
    {
        // Examine our first byte to determine the type of message
        uint8_t chr = message->at(0);
        
        int nodeChan = param(PARAM_CHANNEL);
        
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
        
        if(chr == 0x80) { }// Note off
        else if(chr == 0x90) { }// Note on
        else if(chr == 0xA0) { } // Mmmm... polyphonic aftertouch
        else if(chr == 0xB0) // CC
        {
            if(bLearn)
            {
                ccNum = message->at(1);
                setEditPortValue(1, AGParamValue(ccNum));
            }
            
            if(message->at(1) == ccNum)
            {
                pushControl(0, AGControl(message->at(2)));; // CC value
            }
        }
    }
    
private:
    bool bLearn;
    int ccNum;
};
