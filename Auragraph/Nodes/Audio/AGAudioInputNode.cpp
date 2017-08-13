//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"
#include "AGAudioCapturer.h"
#include "AGAudioManager.h"

//------------------------------------------------------------------------------
// ### AGAudioInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioInputNode

class AGAudioInputNode : public AGAudioNode, public AGAudioCapturer
{
public:
    
    enum Param
    {
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
    };
    
    
    class Manifest : public AGStandardNodeManifest<AGAudioInputNode>
    {
    public:
        string _type() const override { return "Input"; };
        string _name() const override { return "Input"; };
        string _description() const override { return "Routes audio from input device, such as a microphone."; };
        
        vector<AGPortInfo> _inputPortInfo() const override { return { }; }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, 0, 0, AGPortInfo::EXP, .doc = "Output gain." }
            };
        }
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.0066*AGStyle::oldGlobalScale;
            
            // arrow/chevron
            vector<GLvertex3f> iconGeo = {
                { -radius*0.3f,  radius, 0 },
                {  radius*0.5f,       0, 0 },
                { -radius*0.3f, -radius, 0 },
                {  radius*0.1f,       0, 0 },
            };
            
            return iconGeo;
        }
        
        GLuint _iconGeoType() const override { return GL_LINE_LOOP; }
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        AGAudioManager_::instance().addCapturer(this);
        
        m_inputSize = 0;
        m_input = NULL;
    }
    
    virtual ~AGAudioInputNode()
    {
        AGAudioManager_::instance().removeCapturer(this);
    }
    
    int numInputPorts() const override { return 0; }
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        // pullInputPorts(t, nFrames);
        
        float gain = param(AUDIO_PARAM_GAIN);
        
        if(m_inputSize && m_input)
        {
            float *_outputBuffer = m_outputBuffer[chanNum];
            float *_input = m_input;
            int mn = min(nFrames, m_inputSize);
            for(int i = 0; i < mn; i++)
            {
                *_outputBuffer = (*_input++)*gain;
                *output++ += *_outputBuffer++;
            }
        }
    }
    
    void captureAudio(float *input, int numFrames) override
    {
        // pretty hacky
        // TODO: maybe copy this
        m_input = input;
        m_inputSize = numFrames;
    }
    
private:
    int m_inputSize;
    float *m_input;
};

