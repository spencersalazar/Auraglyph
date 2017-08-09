//
//  AGControlMidiCCIn.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#ifndef AGControlMidiCCIn_h
#define AGControlMidiCCIn_h

#include "AGControlNode.h"
#include "AGTimer.h"
#include "AGStyle.h"

#include "AGControlMidiInput.h"
#include "AGMidiConnectionListener.h"
#include "AGPGMidiContext.h"

//------------------------------------------------------------------------------
// ### AGControlMidiCCIn ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiCCIn

class AGControlMidiCCIn : public AGControlNode, public AGControlMidiInput
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
    
    void initFinal() override;
    
    ~AGControlMidiCCIn();
    
    void attachToAllExistingSources();
    void detachFromAllExistingSources();
    
    void editPortValueChanged(int paramId) override;
    
    virtual int numOutputPorts() const override { return 1; }
    
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
    
    bool bLearn;
    int ccNum;
    
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

#endif /* AGControlMidiCCIn_h */
