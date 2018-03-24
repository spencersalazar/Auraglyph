//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioAllpassNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioAllpassNode

#pragma mark DelayI
//------------------------------------------------------------------------------
// ### DelayI ###
// Integer delay line
//------------------------------------------------------------------------------

class DelayI
{
public:
    DelayI(float max = 44100, float delay = 22050) : m_index(0)
    {
        this->maxdelay(max);
        this->delay(delay);
        this->clear();
        m_index = 0;
        m_last = 0;
    }
    
    float tick(float xn)
    {
        m_buffer[m_index] = xn;
        
        int delay_index = m_index-m_delayint;
        if(delay_index < 0)
            delay_index += m_buffer.size;
        float samp = m_buffer[delay_index];
        
        m_index = (m_index+1)%m_buffer.size;
        
        m_last = samp;
        return samp;
    }
    
    float delay(float dsamps)
    {
        assert(dsamps >= 0);
        
        m_delayint = (int)dsamps;
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
        this->clear();
        return dsamps;
    }
    
    float last()
    {
        return m_last;
    }
    
    void clear()
    {
        m_buffer.clear();
    }
    
private:
    int m_delayint;
    
    Buffer<float> m_buffer;
    float m_last;
    int m_index;
};

#pragma mark AllPassN
//------------------------------------------------------------------------------
// ### AllPassN ###
// Nth order allpass filter
//------------------------------------------------------------------------------
class AllPassN
{
public:
    AllPassN(float g = 1)
    {
        m_delay_x.clear();
        m_delay_y.clear();
        _g = g;
    }
    
    float tick(float xn)
    {
        // process output
        float yn = xn*_g + m_delay_x.last() + m_delay_y.last()*-_g;
        
        // process delays
        m_delay_y.tick(yn);
        m_delay_x.tick(xn);
        
        return yn;
    }
    
    float g(float g)
    {
        _g = g;
        return g;
    }
    
    float delay(float d)
    {
        m_delay_x.delay(d);
        m_delay_y.delay(d);
        return d;
    }
    
    float maxdelay() {
        return m_delay_x.maxdelay();
    }
    
    float maxdelay(float dsamps) {
        assert(dsamps >= 0);
        
        m_delay_x.maxdelay(dsamps);
        m_delay_y.maxdelay(dsamps);
        return dsamps;
    }
    
    void clear()
    {
        m_delay_x.clear();
        m_delay_y.clear();
    }
    
    float last()
    {
        return m_delay_y.last();
    }
    
private:
    DelayI m_delay_x;
    DelayI m_delay_y;
    
    float _g;
};

class AGAudioAllpassNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_DELAY,
        PARAM_COEFF,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioAllpassNode>
    {
    public:
        string _type() const override { return "Allpass"; };
        string _name() const override { return "Allpass"; };
        string _description() const override { return "Nth-order allpass filter"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { PARAM_DELAY, "delay", 1, 1, AGInt_Max,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Delay length (samples)." },
                { PARAM_COEFF, "coeff", 0.1, 0, 1, .doc = "Allpass coefficient." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_DELAY, "delay", 1, 1, AGInt_Max,
                    .type = AGControl::TYPE_INT, .mode = AGPortInfo::LIN,
                    .doc = "Delay length (samples)." },
                { PARAM_COEFF, "coeff", 0.1, -AGFloat_Max, AGFloat_Max, .doc = "Allpass coefficient." },
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
            float radius_x = 0.006*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            int NUM_SAMPS = 25;
            
            vector<GLvertex3f> iconGeo;
            
            for (int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                float sample = ((float)i/NUM_SAMPS);
                sample = pow(sample, 6);
                
                vert.x = ((float)i/(NUM_SAMPS-1))*radius_x - radius_x;
                vert.y = sample * radius_y;
                
                iconGeo.push_back(vert);
            }
            
            for (int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                vert.x = ((float)i/NUM_SAMPS)*radius_x;
                vert.y = -iconGeo[NUM_SAMPS-i-1].y;
                
                iconGeo.push_back(vert);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        _setDelay(param(PARAM_DELAY), true);
        m_allpass.clear();
    }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_DELAY) {
            _setDelay(param(PARAM_DELAY));
        }
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *delayLengthv = inputPortVector(PARAM_DELAY);
        float *coeffv = inputPortVector(PARAM_COEFF);
        
        for(int i = 0; i < nFrames; i++)
        {
            _setDelay(delayLengthv[i]);
            m_allpass.g(coeffv[i]);
            
            float delaySamp = m_allpass.tick(inputv[i]);
            m_outputBuffer[chanNum][i] = delaySamp * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    
    void _setDelay(float delaySamps, bool force=false)
    {
        if(force || m_currentDelayLength != delaySamps)
        {
            if(delaySamps < 0)
                delaySamps = 0;
            if(delaySamps > m_allpass.maxdelay())
            {
                int _max = m_allpass.maxdelay();
                while(delaySamps > _max)
                    _max *= 2;
                m_allpass.maxdelay(_max);
                m_allpass.clear();
            }
            m_allpass.delay(delaySamps);
            m_currentDelayLength = delaySamps;
        }
    }
    
    float m_currentDelayLength;
    AllPassN m_allpass;
};

