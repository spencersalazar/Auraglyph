//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioFeedbackNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFeedbackNode


#pragma mark AllPass1
//------------------------------------------------------------------------------
// ### AllPass1 ###
// 1st order allpass filter for delay interpolation
//------------------------------------------------------------------------------
class AllPass1
{
public:
    AllPass1(float g = 1)
    {
        _g = g;
        _yn_1 = 0;
        _xn_1 = 0;
    }
    
    float tick(float xn)
    {
        // process output
        float yn = xn*_g + _xn_1 + _yn_1*-_g;
        
        // process delays
        _yn_1 = yn;
        _xn_1 = xn;
        
        return yn;
    }
    
    float g(float g)
    {
        _g = g;
        return g;
    }
    
    float delay(float d)
    {
        _g = (1-d)/(1+d);
        return d;
    }
    
    void clear()
    {
        _yn_1 = _xn_1 = 0;
    }
    
    float last()
    {
        return _yn_1;
    }
    
private:
    float _yn_1, _xn_1;
    float _g;
};

class DelayA
{
public:
    DelayA(float max = 44100, float delay = 22050) : m_index(0)
    {
        this->maxdelay(max);
        this->delay(delay);
    }
    
    float tick(float xn)
    {
        m_buffer[m_index] = xn;
        
        int delay_index = m_index-m_delayint;
        if(delay_index < 0)
            delay_index += m_buffer.size;
        float samp = m_ap.tick(m_buffer[delay_index]);
        
        m_index = (m_index+1)%m_buffer.size;
        
        return samp;
    }
    
    float delay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_delayint = (int)floorf(dsamps);
        m_delayfract = dsamps-m_delayint;
        m_ap.delay(m_delayfract);
        return dsamps;
    }
    
    float maxdelay()
    {
        return m_buffer.size-1;
    }
    
    float maxdelay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_buffer.resize((int)floorf(dsamps)+1);
        return dsamps;
    }
    
    void clear()
    {
        m_buffer.clear();
        m_ap.clear();
    }
    
    float last()
    {
        return m_ap.last();
    }
    
private:
    int m_delayint;
    float m_delayfract;
    
    Buffer<float> m_buffer;
    int m_index;
    
    AllPass1 m_ap;
};

class AGAudioFeedbackNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_DELAY,
        PARAM_FEEDBACK,
        PARAM_MIX,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioFeedbackNode>
    {
    public:
        string _type() const override { return "Feedback"; };
        string _name() const override { return "Feedback"; };
        string _description() const override { return "Delay processor with built-in feedback."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { PARAM_DELAY, "delay", 0.5, 0, AGFloat_Max, .doc = "Delay length (seconds)." },
                { PARAM_FEEDBACK, "feedback", 0.1, 0, 1, .doc = "Feedback gain." },
                { PARAM_MIX, "mix", ._default = 0.5, .min = 0.0, .max = 1.0, .doc = "Wet/dry mix."},
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_DELAY, "delay", 0.5, 0, AGFloat_Max, .doc = "Delay length (seconds)." },
                { PARAM_FEEDBACK, "feedback", 0.1, 0, 1, .doc = "Feedback gain." },
                { PARAM_MIX, "mix", ._default = 0.5, .min = 0.0, .max = 1.0, .doc = "Wet/dry mix."},
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
            float radius_y = radius_x;
            
            // ADSR shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x,        radius_y, 0 }, {       -radius_x,        -radius_y, 0 },
                { -radius_x*0.33f,   radius_y*0.5f, 0 }, { -radius_x*0.33f,   -radius_y*0.5f, 0 },
                {  radius_x*0.33f,  radius_y*0.25f, 0 }, {  radius_x*0.33f,  -radius_y*0.25f, 0 },
                {        radius_x, radius_y*0.125f, 0 }, {        radius_x, -radius_y*0.125f, 0 },
                {       -radius_x,               0, 0 }, {        radius_x,                0, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        stk::Stk::setSampleRate(sampleRate());
        _setDelay(param(PARAM_DELAY), true);
        m_delay.clear();
    }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_DELAY)
            _setDelay(param(PARAM_DELAY));
            }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *delayLengthv = inputPortVector(PARAM_DELAY);
        float *feedbackGainv = inputPortVector(PARAM_FEEDBACK);
        float *mixv = inputPortVector(PARAM_MIX);
        
        for(int i = 0; i < nFrames; i++)
        {
            _setDelay(delayLengthv[i]);
            
            float delaySamp = m_delay.tick(inputv[i] + m_delay.last()*feedbackGainv[i]);
            float outSamp = delaySamp*mixv[i] + inputv[i]*(1-mixv[i]);
            m_outputBuffer[chanNum][i] = outSamp * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    
    void _setDelay(float delaySecs, bool force=false)
    {
        if(force || m_currentDelayLength != delaySecs)
        {
            float delaySamps = delaySecs*sampleRate();
            if(delaySamps < 0)
                delaySamps = 0;
            if(delaySamps > m_delay.maxdelay())
            {
                int _max = m_delay.maxdelay();
                while(delaySamps > _max)
                    _max *= 2;
                m_delay.maxdelay(_max);
                m_delay.clear();
            }
            m_delay.delay(delaySamps);
            m_currentDelayLength = delaySecs;
        }
    }
    
    float m_currentDelayLength;
    DelayA m_delay;
};


