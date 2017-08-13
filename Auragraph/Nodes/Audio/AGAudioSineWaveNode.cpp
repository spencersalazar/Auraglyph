//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"

//#define AGDEBUG_SINE_MUTE_BUTTON

//------------------------------------------------------------------------------
// ### AGAudioSineWaveNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSineWaveNode


class AGAudioSineWaveNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_PHASE,
#ifdef AGDEBUG_SINE_MUTE_BUTTON
        PARAM_MUTE,
#endif // AGDEBUG_SINE_MUTE_BUTTON
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioSineWaveNode>
    {
    public:
        string _type() const override { return "SineWave"; };
        string _name() const override { return "SineWave"; };
        string _description() const override { return "Standard sinusoidal oscillator."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, 0, 0, AGPortInfo::EXP, .doc = "Oscillator frequency. " },
                { AUDIO_PARAM_GAIN, "gain", 1, 0, 0, AGPortInfo::EXP, .doc = "Output gain." },
                { PARAM_PHASE, "phase", 1, 0, 0, AGPortInfo::LIN, .doc = "Oscillator phase." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", 220, 0, 0, AGPortInfo::EXP, .doc = "Oscillator frequency" },
#ifdef AGDEBUG_SINE_MUTE_BUTTON
                { PARAM_MUTE, "mute", 0, 0, 1, .type = AGControl::TYPE_BIT, .editorMode = AGPortInfo::EDITOR_ACTION, .doc = "Mute." },
#endif // AGDEBUG_SINE_MUTE_BUTTON
                { AUDIO_PARAM_GAIN, "gain", 1, 0, 0, AGPortInfo::EXP, .doc = "Output gain." }
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
            int NUM_PTS = 32;
            vector<GLvertex3f> iconGeo(NUM_PTS);
            
            float radius = 0.005*AGStyle::oldGlobalScale;
            for(int i = 0; i < NUM_PTS; i++)
            {
                float t = ((float)i)/((float)(NUM_PTS-1));
                float x = (t*2-1) * radius;
                float y = radius*0.66*sinf(t*M_PI*2);
                
                iconGeo[i] = GLvertex3f(x, y, 0);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_phase = 0;
    }
    
    void receiveControl(int port, const AGControl &control) override
    {
        if(port == m_param2InputPort[PARAM_PHASE])
        {
            // hard-sync phase to control input
            m_phase = control.getFloat();
            // clear control
            // prevents upsampling to renderAudio phase vector
            clearControl(PARAM_PHASE);
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        // if there are audio-rate phase inputs, then ignore m_phase value
        float phase_ctl = numInputsForPort(PARAM_PHASE, AGRate::RATE_AUDIO) > 0 ? 0.0f : 1.0f;
        float *phasev = inputPortVector(PARAM_PHASE);
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] = sinf(m_phase*2.0*M_PI) * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
            
            m_phase = clipunit(m_phase*phase_ctl + freqv[i]/sampleRate() + phasev[i]);
        }
    }
    
private:
    float m_phase;
};

