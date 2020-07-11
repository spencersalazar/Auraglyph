//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "ADSR.h"

//------------------------------------------------------------------------------
// ### AGAudioADSRNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioADSRNode

class AGAudioADSRNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_TRIGGER,
        PARAM_ATTACK,
        PARAM_DECAY,
        PARAM_SUSTAIN,
        PARAM_RELEASE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioADSRNode>
    {
    public:
        string _type() const override { return "ADSR"; };
        string _name() const override { return "ADSR"; };
        string _description() const override { return "Attack-decay-sustain-release (ADSR) envelope. "; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input to apply envelope. " },
                { AUDIO_PARAM_GAIN, "gain", .doc = "Output gain." },
                { PARAM_TRIGGER, "trigger", .doc = "Envelope trigger (triggered for any value above 0)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_ATTACK, "attack", 0.01, .doc = "Attack duration (seconds)." },
                { PARAM_DECAY, "decay", 0.01, .doc = "Decay duration (seconds)." },
                { PARAM_SUSTAIN, "sustain", 0.5, .doc = "Sustain level (linear amplitude)." },
                { PARAM_RELEASE, "release", 0.1, .doc = "Release duration (seconds)." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // ADSR shape
            vector<GLvertex3f> iconGeo = {
                { -radius_x, -radius_y, 0 },
                { -radius_x*0.75f, radius_y, 0 },
                { -radius_x*0.25f, 0, 0 },
                { radius_x*0.66f, 0, 0 },
                { radius_x, -radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_prevTrigger = FLT_MAX;
        m_adsr.setAllTimes(param(PARAM_ATTACK), param(PARAM_DECAY),
                           param(PARAM_SUSTAIN), param(PARAM_RELEASE));
    }
    
    void editPortValueChanged(int paramId) override
    {
        switch(paramId)
        {
            case PARAM_ATTACK:
            case PARAM_DECAY:
            case PARAM_SUSTAIN:
            case PARAM_RELEASE:
                m_adsr.setAllTimes(param(PARAM_ATTACK), param(PARAM_DECAY),
                                   param(PARAM_SUSTAIN), param(PARAM_RELEASE));
                break;
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *triggerv = inputPortVector(PARAM_TRIGGER);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        // use constant (1.0) virtual input if no actual inputs are present
        float virtual_input = numInputsForPort(PARAM_INPUT, AGRate::RATE_AUDIO) == 0 ? 1.0f : 0.0f;
        float *inputv = inputPortVector(PARAM_INPUT);
        
        for(int i = 0; i < nFrames; i++) {
            if(triggerv[i] != m_prevTrigger) {
                if(triggerv[i] > 0) {
                    m_adsr.keyOn();
                } else {
                    m_adsr.keyOff();
                }
            }
            m_prevTrigger = triggerv[i];
            
            m_outputBuffer[chanNum][i] = m_adsr.tick() * (inputv[i] + virtual_input) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        switch(port) {
            case 2: {
                int fire = 0;
                control.mapTo(fire);
                if(fire) {
                    m_adsr.keyOn();
                } else {
                    m_adsr.keyOff();
                }
            }
        }
    }
    
private:
    float m_prevTrigger;
    stk::ADSR m_adsr;
};


