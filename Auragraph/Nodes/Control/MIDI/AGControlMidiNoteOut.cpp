//
//  AGControlMidiNoteOut.cpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 8/23/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGMidiOutput.h"
#include "AGControlNode.h"
#include "AGTimer.h"
#include "AGStyle.h"

//------------------------------------------------------------------------------
// ### AGControlMidiNoteOut ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiNoteOut

class AGControlMidiNoteOut : public AGControlNode, public AGMidiOutput
{
public:
    
    enum Param
    {
        PARAM_NOTEOUT_CHANNEL,
        PARAM_NOTEOUT_TRIGGER,
        PARAM_NOTEOUT_PITCH,
        PARAM_NOTEOUT_VELOCITY,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMidiNoteOut>
    {
    public:
        string _type() const override { return "MIDI Note Out"; };
        string _name() const override { return "MIDI Note Out"; };
        string _description() const override { return "MIDI Note Out Node."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_NOTEOUT_TRIGGER, "Noteout: trigger", true, false, .doc = "Trigger note output" },
                { PARAM_NOTEOUT_PITCH, "Noteout: pitch", true, false, .doc = "Pitch of a note." },
                { PARAM_NOTEOUT_VELOCITY, "Noteout: velocity", true, false, .doc = "Velocity of a note." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_NOTEOUT_CHANNEL, "Channel", ._default = 1, .min = 0, .max = 16,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Channel." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override { return { }; };
        
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
                    float theta = -M_PI * 0.25 * i; // rotate each pin by 1/5 pi
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
        
        m_chan = 1;
        m_vel = m_pitch = 0;
    }

    virtual int numOutputPorts() const override { return 0; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        if(port == 0)
        {
            float trig = control;
            
            message.clear();
            
            if(trig > 0.0) // Note on
            {
                uint8_t statusByte = 0x90 | (m_chan - 1);
                message.push_back(statusByte);
                message.push_back(m_pitch);
                message.push_back(m_vel);
            }
            else // Note off
            {
                uint8_t statusByte = 0x80 | (m_chan - 1);
                message.push_back(statusByte);
                message.push_back(m_pitch);
                message.push_back(m_vel);
            }
            
            sendMessage();
        }
        else if(port == 1) // New pitch value
        {
            m_pitch = control.getInt() & 0x7F;
        }
        else if(port == 2)
        {
            float rawVel = control.getFloat() * 127;
            m_vel = ((int) rawVel) & 0x7F;
        }
    }

    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_NOTEOUT_CHANNEL)
        {
            m_chan = param(PARAM_NOTEOUT_CHANNEL);
        }
    }
    
private:
    int m_chan;
    uint8_t m_pitch;
    uint8_t m_vel;
};
