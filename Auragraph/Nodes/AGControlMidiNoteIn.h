//
//  AGControlMidiNoteIn.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#ifndef AGControlMidiNoteIn_h
#define AGControlMidiNoteIn_h

#include "AGControlNode.h"
#include "AGTimer.h"
#include "AGStyle.h"

#include "AGControlMidiInput.h"
#include "AGMidiConnectionListener.h"
#include "AGPGMidiContext.h"

//------------------------------------------------------------------------------
// ### AGControlMidiNoteIn ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiNoteIn

class AGControlMidiNoteIn : public AGControlNode, public AGControlMidiInput
{
public:
    
    enum Param
    {
        PARAM_NOTEOUT_CHANNEL,
        PARAM_NOTEOUT_PITCH,
        PARAM_NOTEOUT_VELOCITY,
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
                { PARAM_NOTEOUT_CHANNEL, "Channel", ._default = 0, .min = 0, .max = 16,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Channel." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_NOTEOUT_PITCH, "Noteout: pitch", true, false, .doc = "Pitch of a note." },
                { PARAM_NOTEOUT_VELOCITY, "Noteout: velocity", true, false, .doc = "Velocity of a note." },
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
    
    void initFinal() override;
    
    ~AGControlMidiNoteIn();
    
    void attachToAllExistingSources();
    void detachFromAllExistingSources();
    
    void editPortValueChanged(int paramId) override;
    
    virtual int numOutputPorts() const override { return 2; }
    
    // MIDI message handler
    void messageReceived(double deltatime, vector<unsigned char> *message) override;
    
    // XXX Should the below functions/members even be public? That seemed to make sense
    // in ofx because other classes were calling these methods to hook things
    // together, but our architecture is different.
    
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
    
private:
    struct InputDelegate; // forward declaration for Obj-C wrapper
    InputDelegate *inputDelegate; ///< Obj-C midi input interface
    
    int portNum;     //< current port num, -2 if not connected, -1 if we're listening to all
    string portName; //< current port name, "" if not connected
    
    // I'm not sure if this should be static, it was in ofx... ah wait, it has to be because
    // it's getting called by a static member function. So again, I ask, do those functions
    // themselves need to be static? Leave it for now, wait until we have functional nodes
    // so we can see if port browsing causes contention among node instances. Sheesh...
    static vector<string> portList; //< list of port names
        
    bool bOpen;    //< is the port currently open?
    bool bVerbose; //< print incoming bytes?
    bool bVirtual; //< are we connected to a virtual port?
};

#endif /* AGControlMidiNoteIn_h */
