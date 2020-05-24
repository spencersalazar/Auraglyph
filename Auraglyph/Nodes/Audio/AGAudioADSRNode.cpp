//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "ADSR.h"
#include "spMath.h"
#include "Animation.h"

template<typename T, typename Tmin=T, typename Tmax=T>
T constrain(T v, Tmin min, Tmax max)
{
    if (v > max) { return max; }
    if (v < min) { return min; }
    return v;
}


class ADSR
{
public:
    
    /** Params set by user */
    struct Params {
        float attackTime = 0.25;
        float decayTime = 0.25;
        float sustainLevel = 0.5;
        float releaseTime = 0.25;
        
        float attackPow = 1;
        float decayPow = 1;
        float releasePow = 1;
    };
    
    /** State managed by ADSR */
    struct State {
        enum Mode {
            OFF,
            ATTACK,
            DECAY,
            SUSTAIN,
            RELEASE,
        };
        
        Mode mode = OFF;
        float t = 0;
        float currentLevel = 0;
        float sourceLevel = 0;
    };
    
    Params params;
    State state;
    
    static float evaluate(const Params p, const State s)
    {
        switch (s.mode) {
            case State::OFF: {
                return 0;
            } break;
                
            case State::ATTACK: {
                return rescale(constrain<float>(s.t/p.attackTime, 0, 1),
                               s.sourceLevel, 1.f, p.attackPow);
            } break;
                
            case State::DECAY: {
                return rescale(constrain<float>(s.t/p.decayTime, 0, 1),
                               s.sourceLevel, p.sustainLevel, p.decayPow);
            } break;
                
            case State::SUSTAIN: {
                return p.sustainLevel;
            } break;
                
            case State::RELEASE: {
                return rescale(constrain<float>(s.t/p.releaseTime, 0, 1),
                               s.sourceLevel, 0.f, p.releasePow);
            } break;
        }
    }
    
    static void advance(const Params p, State& s, const float dt)
    {
        if (s.mode == State::SUSTAIN) {
            // no change
        } else {
            
            s.t += dt;
            
            if (s.mode == State::ATTACK && s.t >= p.attackTime) {
                s.mode = State::DECAY;
                s.t -= p.attackTime;
                s.sourceLevel = 1;
            }
            
            // fall through in case dt jumps pass decay state
            if (s.mode == State::DECAY && s.t >= p.decayTime) {
                s.mode = State::SUSTAIN;
                s.t = 0;
                s.sourceLevel = p.sustainLevel;
            }
            
            if (s.mode == State::RELEASE && s.t >= p.releaseTime) {
                s.mode = State::OFF;
                s.t = 0;
                s.sourceLevel = 0;
            }
            
            s.currentLevel = evaluate(p, s);
        }
    }
    
    static void keyOn(const Params p, State& s)
    {
        s.mode = State::ATTACK;
        s.t = 0;
        // envelope from current level rather than 0
        s.sourceLevel = s.currentLevel;
    }
    
    static void keyOff(const Params p, State& s)
    {
        s.mode = State::RELEASE;
        s.t = 0;
        // envelope from current level rather than sustainLevel
        s.sourceLevel = s.currentLevel;
    }
};

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
        PARAM_SKEW,
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
        m_adsr2.params.attackTime = param(PARAM_ATTACK);
        m_adsr2.params.decayTime = param(PARAM_ATTACK);
        m_adsr2.params.sustainLevel = param(PARAM_SUSTAIN);
        m_adsr2.params.releaseTime = param(PARAM_RELEASE);
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
                m_adsr2.params.attackTime = param(PARAM_ATTACK);
                m_adsr2.params.decayTime = param(PARAM_ATTACK);
                m_adsr2.params.sustainLevel = param(PARAM_SUSTAIN);
                m_adsr2.params.releaseTime = param(PARAM_RELEASE);
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
        float virtual_input = (numInputsForPort(PARAM_INPUT, AGRate::RATE_AUDIO) == 0
                               ? 1.0f
                               : 0.0f);
        float *inputv = inputPortVector(PARAM_INPUT);
        
        float Ts = 1.0f/float(sampleRate());
        
        for(int i = 0; i < nFrames; i++) {
            if(triggerv[i] != m_prevTrigger) {
                if(triggerv[i] > 0) {
                    m_adsr.keyOn();
                    ADSR::keyOn(m_adsr2.params, m_adsr2.state);
                } else {
                    m_adsr.keyOff();
                    ADSR::keyOff(m_adsr2.params, m_adsr2.state);
                }
            }
            m_prevTrigger = triggerv[i];
            
            // m_outputBuffer[chanNum][i] = m_adsr.tick() * (inputv[i] + virtual_input) * gainv[i];
            
            ADSR::advance(m_adsr2.params, m_adsr2.state, Ts);
            float adsrLevel = m_adsr2.state.currentLevel;
            
            m_outputBuffer[chanNum][i] = adsrLevel * (inputv[i] + virtual_input) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        switch(port)
        {
            case 2: { // TODO: << why is this hardcoded to 2
                int fire = 0;
                control.mapTo(fire);
                if(fire) {
                    m_adsr.keyOn();
                    ADSR::keyOn(m_adsr2.params, m_adsr2.state);
                } else {
                    m_adsr.keyOff();
                    ADSR::keyOff(m_adsr2.params, m_adsr2.state);
                }
            }
        }
    }
    
    void _renderIcon() override
    {
        int numPoints = 50;
        float insetScale = G_RATIO-1;
        float xInset = 50*insetScale;
        float yScale = 50*insetScale/G_RATIO;
        float scale = 50;
        
        std::vector<GLvertex2f> points(numPoints);
        
        stk::ADSR adsr;
        float attackTime = param(PARAM_ATTACK);
        float decayTime = param(PARAM_DECAY);
        float sustainLevel = param(PARAM_SUSTAIN);
        float releaseTime = param(PARAM_RELEASE);
        adsr.setAllTimes(attackTime, decayTime, sustainLevel, releaseTime);
        
        float sustainTime = 0.5;
        float length = sum(attackTime, decayTime, sustainTime, releaseTime);
        
        for (int i = 0; i < numPoints; i++) {
            float x = float(i)/float(numPoints-1)*length;
        }
        
        drawLineStrip(points.data(), numPoints);
    }

    
private:
    float m_prevTrigger;
    stk::ADSR m_adsr;
    ADSR m_adsr2;
};


