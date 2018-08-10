//
//  AGAudioReverbNode.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 8/4/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "NHHall/nh_hall.hpp"

//------------------------------------------------------------------------------
// ### AGAudioReverbNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioReverbNode

class AGAudioReverbNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT_L,
        PARAM_OUTPUT_R,
        PARAM_T60,
        PARAM_STEREO,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioReverbNode>
    {
    public:
        string _type() const override { return "Reverb"; };
        string _name() const override { return "Reverb"; };
        string _description() const override { return "Reverberator based on NHHall reverb."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", 0, .doc = "Input." },
                { PARAM_T60, "T60", 220, .doc = "60 dB decay time for mid frequencies." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_T60, "T60", 220, .doc = "60 dB decay time for mid frequencies." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_STEREO, "stereo", 0, 0, 1, AGPortInfo::LIN, .doc = "Stereo spread." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT_L, "left", .doc = "Left channel stereo output." },
                { PARAM_OUTPUT_R, "right", .doc = "Right channel stereo output." },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x * 0.66;
            
            // sawtooth wave shape
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 },
                { -radius_x*0.5f, radius_y, 0 },
                { radius_x*0.5f, -radius_y, 0 },
                { radius_x, 0, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_reverb.reset(new nh_ugens::NHHall<>(sampleRate()));
    }
    
    void receiveControl(int port, const AGControl &control) override
    {
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);

        for(int i = 0; i < nFrames; i++)
        {
            // duplicate mono input to stereo
            nh_ugens::Stereo reverbOut = m_reverb->process(inputv[i], inputv[i]);
            m_outputBuffer[0][i] = reverbOut[0]*gainv[i];
            m_outputBuffer[1][i] = reverbOut[1]*gainv[i];

            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    std::unique_ptr<nh_ugens::NHHall<>> m_reverb;
};



