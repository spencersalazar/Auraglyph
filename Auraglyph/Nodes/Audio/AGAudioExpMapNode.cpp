//
//  AGAudioExpMapNode.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/10/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"

//------------------------------------------------------------------------------
// ### AGAudioDistortionNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioDistortionNode

class AGAudioExpMapNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_BASE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioExpMapNode>
    {
    public:
        string _type() const override { return "ExpMap"; };
        string _name() const override { return "ExpMap"; };
        string _description() const override { return "Exponential mapper. "; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input. " },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_BASE, "base", 10, .doc = "Exponent base." },
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
            
            // non-linearity shape
            vector<GLvertex3f> iconGeo;
            int NUM_VERTEX = 32;
            float inputGain = 9;
            for(int i = 0; i < NUM_VERTEX-1; i++)
            {
                float x0 = (((float)i)-((float)(NUM_VERTEX/2)))/((float)(NUM_VERTEX/2));
                float y0 = (x0*inputGain);
                float x1 = (((float)(i+1))-((float)(NUM_VERTEX/2)))/((float)(NUM_VERTEX/2));
                float y1 = (x1*inputGain);
                iconGeo.push_back((GLvertex2f) { x0*radius_x, y0*radius_x });
                iconGeo.push_back((GLvertex2f) { x1*radius_x, y1*radius_x });
            }
            
            iconGeo.push_back((GLvertex2f) { -radius_x, -radius_x });
            iconGeo.push_back((GLvertex2f) {  radius_x,  radius_x });

            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override { }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float gain = param(AUDIO_PARAM_GAIN).getFloat();
        float base = param(PARAM_BASE).getFloat();

        for(int i = 0; i < nFrames; i++)
        {
            float input = inputv[i];
            
            float scaled = powf(base, input);
            
            m_outputBuffer[chanNum][i] = scaled*gain;
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
};

