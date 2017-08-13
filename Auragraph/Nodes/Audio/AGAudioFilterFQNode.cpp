//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "SPFilter.h"

//------------------------------------------------------------------------------
// ### AGAudioFilterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioFilterNode

template<class Filter>
class AGAudioFilterFQNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_FREQ,
        PARAM_Q,
    };
    
    class ManifestLPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2RLPF>>
    {
    public:
        string _type() const override { return "LowPass"; };
        string _name() const override { return "LowPass"; };
        string _description() const override { return "Resonant low-pass filter (second order Butterworth)."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Filter input." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency. " },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
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
            
            // lowpass shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x,  radius_y*0.33f, 0 },
                { -radius_x*0.33f,  radius_y*0.33f, 0 },
                {               0,        radius_y, 0 },
                {  radius_x*0.33f, -radius_y*0.66f, 0 },
                {        radius_x, -radius_y*0.66f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    class ManifestHPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2RHPF>>
    {
    public:
        string _type() const override { return "HiPass"; };
        string _name() const override { return "HiPass"; };
        string _description() const override { return "Resonant high-pass filter (second-order Butterworth)."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Filter input." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
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
            
            // hipass shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x, -radius_y*0.66f, 0 },
                { -radius_x*0.33f, -radius_y*0.66f, 0 },
                {               0,        radius_y, 0 },
                {  radius_x*0.33f,  radius_y*0.33f, 0 },
                {        radius_x,  radius_y*0.33f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    class ManifestBPF : public AGStandardNodeManifest<AGAudioFilterFQNode<Butter2BPF>>
    {
    public:
        string _type() const override { return "BandPass"; };
        string _name() const override { return "BandPass"; };
        string _description() const override { return "Band pass filter (second-order Butterworth)."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Filter input." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_FREQ, "freq", 220, .doc = "Filter cutoff frequency." },
                { PARAM_Q, "Q", 1, 0.001, 1000, .doc = "Filter Q (bandwidth)." },
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
            
            // bandpass shape
            vector<GLvertex3f> iconGeo = {
                {       -radius_x, -radius_y*0.50f, 0 },
                { -radius_x*0.33f, -radius_y*0.50f, 0 },
                {               0,        radius_y, 0 },
                {  radius_x*0.33f, -radius_y*0.50f, 0 },
                {        radius_x, -radius_y*0.50f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_filter = Filter(sampleRate());
        m_filter.set(param(PARAM_FREQ), param(PARAM_Q));
    }
    
    void editPortValueChanged(int paramId) override
    {
        switch(paramId)
        {
            case PARAM_FREQ:
            case PARAM_Q:
                m_filter.set(param(PARAM_FREQ), param(PARAM_Q));
                break;
        }
    }
    
    float validateEditPortValue(int port, float value) const override
    {
        if(port == 1)
        {
            // freq
            if(value < 0)
                return 0;
            if(value > sampleRate()/2)
                return sampleRate()/2;
            return value;
        }
        
        return AGNode::validateEditPortValue(port, value);
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *freqv = inputPortVector(PARAM_FREQ);
        float *qv = inputPortVector(PARAM_Q);
        
        for(int i = 0; i < nFrames; i++)
        {
            float gain = gainv[i];
            float freq = freqv[i];
            float Q = qv[i];
            
            if(freq != param(PARAM_FREQ).getFloat() || Q != param(PARAM_Q).getFloat())
            {
                if(Q < 0.001) Q = 0.001;
                if(freq < 0) freq = 0;
                if(freq > sampleRate()/2) freq = sampleRate()/2;
                
                m_filter.set(freq, Q);
            }
            
            float samp = gain * m_filter.tick(inputv[i]);
            if(samp == NAN || samp == INFINITY || samp == -INFINITY)
            {
                samp = 0;
                m_filter.clear();
            }
            
            m_outputBuffer[chanNum][i] = samp;
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
    
private:
    Filter m_filter;
};


