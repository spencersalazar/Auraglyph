//
//  AGControlMidiInputNode.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/20/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//
//  Parts of this code are based on ofxMidi by Dan Wilcox.
//  See https://github.com/danomatika/ofxMidi for documentation

#ifndef AGControlMidiInputNode_h
#define AGControlMidiInputNode_h

#include "AGControlNode.h"
#include "AGTimer.h"
#include "AGStyle.h"

#include "AGMidiConnectionListener.h"
#include "AGPGMidiContext.h"

//------------------------------------------------------------------------------
// ### AGControlMidiInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiInputNode

class AGControlMidiInputNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_NOTEOUT_PITCH,
        PARAM_NOTEOUT_VELOCITY,
        PARAM_CCOUT_CCNUM,
        PARAM_CCOUT_CCVAL,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMidiInputNode>
    {
    public:
        string _type() const override { return "MIDI Input"; };
        string _name() const override { return "MIDI Input"; };
        string _description() const override { return "MIDI Input Node."; };
        
        vector<AGPortInfo> _inputPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _editPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_NOTEOUT_PITCH, "Noteout: pitch", true, false, .doc = "Pitch of a note." },
                { PARAM_NOTEOUT_VELOCITY, "Noteout: velocity", true, false, .doc = "Velocity of a note." },
                { PARAM_CCOUT_CCNUM, "CC out: CC number", true, false, .doc = "CC number." },
                { PARAM_CCOUT_CCVAL, "CC out: CC value", true, false, .doc = "CC value." },
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
    
    ~AGControlMidiInputNode();
    
    // Simply attach to everything, ala-PGMidi example code. Filtering
    // and choosing devices will come later
    void attachToAllExistingSources();
    
    // XXX not needed for now (i.e. for early-stage proof-of-concept), but will be needed to implement channel filtering
    void editPortValueChanged(int paramId) override;
    
    // XXX will not be needed for this (i.e. MIDI input), but *WILL* be needed for MIDI output!
    //void receiveControl(int port, const AGControl &control) override;
    
    // XXX didn't we get rid of this in a generic fashion?! Oh... no, not at all. It's still *everywhere* in ther codebase :-/
    // Oh well, not really pertinent to the problem at hand...
    virtual int numOutputPorts() const override { return 4; }
    
    // XXX new MIDI stuff from ofx
    /// wrapper around manageNewMessage
    void messageReceived(double deltatime, vector<unsigned char> *message);

    // XXX so I don't think we'll be using this since this node *is* the
    // listener in its own right; in ofx this was part of ofxMidiIn, and the
    // *ofApp* was the class adding itself to its MidiIns as a listener. We
    // may, however, return to using this if we choose to split this functionality
    // (i.e. all the old ofxMidiIn stuff) back out of our node for some reason.
    // In that case, we *would* want our node to be able to add itself as a listener.
    static void setConnectionListener(AGMidiConnectionListener * listener);
    
    // XXX Okay, here are the rest of the public member functions from
    // ofxPGMidiIn, here are some notes on what we should do with them; do
    // keep in mind that much of this stuff is baggage that ofxPGMidiIn
    // had to inherit from ofxBaseMidiIn (i.e. including pure virtual stuff),
    // so we need not be super-concerned about including them here because
    // we're not necessarily trying for such a generic solution as in ofxMidi
    
    // XXX no need for these, although we *will* need to do constructor and
    // destructor stuff resembling ofx in initFinal() and the destructor
    //ofxPGMidiIn(const string name);
    //virtual ~ofxPGMidiIn();
    
    // XXX nah, we're not really going to need these b/c much of this implies
    // a text-listing/menu-spitting thingy, i.e. not our node's job, at least
    // not for now. For now? Just do something like 'attachToAllExistingSources'
    // from the PGMidi example code's viewController. Filtering will come later!
    // One thing *does* make me question this a bit more: these beasties are static,
    // is this going to cause us trouble down the road?
    //static void listPorts();
    //static vector<string>& getPortList();
    //static int getNumPorts();
    //static string getPortName(unsigned int portNumber);
    
    // XXX again, probably a bit heavyweight for what our node is trying to do
    //bool openPort(unsigned int portNumber);
    //bool openPort(string deviceName);
    //bool openVirtualPort(string portName); ///< currently noop on iOS
    //void closePort();
    
    // XXX well, initially I thought it might be mest to strip out a good deal
    // of the ofxMidi parsing and rewrite it from scratch, omitting these things
    // to streamline stuff. But since it now looks more likely that we'll be
    // keeping more ofx stuff anyway, why not just leverage this parsing ourselves
    // so we don't have to worry about choking on unexpected SysEx crap? Keep it!
    // Also, let's make them all default to true; this used to be handled by the
    // ofx base class
    void ignoreTypes(bool midiSysex=true, bool midiTiming=true, bool midiSense=true);
    
    // XXX already included above
    /// wrapper around manageNewMessage
    //void messageReceived(double deltatime, vector<unsigned char> *message);
    
    // iOS specific global stuff,
    // easier to route through here thanks to Obj-C/C++ mix
    // XXX already included above
    //static void setConnectionListener(ofxMidiConnectionListener * listener);
    
    // XXX let's hide 'em for now, though we will need to bring them back if
    // we take this ofxMidiIn stuff back *out* of our node
    //static void clearConnectionListener();
    //static void enableNetworking();

    
private:
    struct InputDelegate; // forward declaration for Obj-C wrapper
    InputDelegate *inputDelegate; ///< Obj-C midi input interface
};

#endif /* AGControlMidiInputNode_h */
