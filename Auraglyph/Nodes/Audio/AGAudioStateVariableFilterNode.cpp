//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioStateVariableFilterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioStateVariableFilterNode

class AGAudioStateVariableFilterNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_LPF_OUTPUT,
        PARAM_HPF_OUTPUT,
        PARAM_BPF_OUTPUT,
        PARAM_BRF_OUTPUT,
        PARAM_CUTOFF,
        PARAM_Q,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioStateVariableFilterNode>
    {
    public:
        string _type() const override { return "StateVariableFilter"; };
        string _name() const override { return "StateVariableFilter"; };
        string _description() const override { return "State variable filter"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { PARAM_CUTOFF, "cutoff", 220.0, 0.0001, 22000.0, .doc = "Filter cutoff." },
                { PARAM_Q, "Q", 1.0, 0.0001, 10000.0, .doc = "Filter Q." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
                
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_CUTOFF, "cutoff", 220.0, 0.0001, 22000.0, .doc = "Filter cutoff." },
                { PARAM_Q, "Q", 1.0, 0.0001, 10000.0, .doc = "Filter Q." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_LPF_OUTPUT, "lp output", .doc = "LP Output." },
                { PARAM_HPF_OUTPUT, "hp output", .doc = "HP Output." },
                { PARAM_BPF_OUTPUT, "bp output", .doc = "BP Output." },
                { PARAM_BRF_OUTPUT, "br output", .doc = "Notch Output." }
                
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.0065*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // SVF shape, including lowpass, highpass, and notch
            vector<GLvertex3f> iconGeo = {
                {        -radius_x,  radius_y * 0.5f, 0 },
                { -radius_x * 0.5f,  radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.6f, 0 },
                {                0,  radius_y * 0.5f, 0 },
                {  radius_x * 0.2f,  radius_y * 0.6f, 0 },
                {  radius_x * 0.5f,  radius_y * 0.5f, 0 },
                {         radius_x,  radius_y * 0.5f, 0 },
                {  radius_x * 0.5f,  radius_y * 0.5f, 0 },
                {  radius_x * 0.2f,  radius_y * 0.4f, 0 },
                {  radius_x * 0.1f,                0, 0 },
                {                0, -radius_y * 0.5f, 0 },
                { -radius_x * 0.1f,                0, 0 },
                { -radius_x * 0.2f,  radius_y * 0.4f, 0 },
                { -radius_x * 0.5f,  radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.6f, 0 },
                {                0,  radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.1f, 0 },
                { -radius_x * 0.5f, -radius_y * 0.5f, 0 },
                { -radius_x * 0.2f,  radius_y * 0.1f, 0 },
                {                0,  radius_y * 0.5f, 0 },
                {  radius_x * 0.2f,  radius_y * 0.1f, 0 },
                {  radius_x * 0.5f, -radius_y * 0.5f, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        d1 = d2 = 0;
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *cutoffv = inputPortVector(PARAM_CUTOFF);
        float *qv = inputPortVector(PARAM_Q);
        
        for(int i = 0; i < nFrames; i++)
        {
            
            // TODO: only recompute coeffs if params have changed
            float cutoff_coeff = 2 * sin(M_PI * cutoffv[i] / sampleRate());
            float q_coeff = 1.0 / qv[i];
            
            float lpf = d2 + cutoff_coeff * d1;
            float hpf = inputv[i] - lpf - q_coeff * d1;
            float bpf = cutoff_coeff * hpf + d1;
            float brf = hpf + lpf;
            
            if (isbad(lpf) || isbad(hpf) || isbad(bpf) || isbad(brf))
                lpf = hpf = bpf = brf = 0;
            
            d1 = bpf;
            d2 = lpf;
            
            m_outputBuffer[0][i] = lpf * gainv[i];
            m_outputBuffer[1][i] = hpf * gainv[i];
            m_outputBuffer[2][i] = bpf * gainv[i];
            m_outputBuffer[3][i] = brf * gainv[i];
            
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    float d1;
    float d2;
};

