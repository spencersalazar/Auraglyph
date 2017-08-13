//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioAddNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioAddNode

class AGAudioAddNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_ADD,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioAddNode>
    {
    public:
        string _type() const override { return "Add"; };
        string _name() const override { return "Add"; };
        string _description() const override { return "Simply adds singular value, or if multiple inputs, sums all inputs. "; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "add", .doc = "Quantity to add, if only one input." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_ADD, "add", 0, .doc = "Input(s) to add." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
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
            
            // add icon
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 }, { radius_x, 0, 0 },
                { 0, radius_y, 0 }, { 0, -radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_inputBuffer.resize(bufferSize());
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        
        float gain = param(AUDIO_PARAM_GAIN);
        
        this->lock();
        
        int numInputs = numInputsForPort(PARAM_INPUT);
        // if only one input, process with edit port value
        float base = 0;
        if(numInputs == 1)
        {
            if(m_params.count(PARAM_ADD))
                base = m_params.at(PARAM_ADD);
                }
        
        // set to base value
        for(int i = 0; i < nFrames; i++)
            m_outputBuffer[chanNum][i] = base;
        
        for(int j = 0; j < numInputs; j++)
        {
            m_inputBuffer.clear();
            pullPortInput(PARAM_INPUT, j, t, m_inputBuffer, nFrames);
            
            for(int i = 0; i < nFrames; i++)
                m_outputBuffer[chanNum][i] += m_inputBuffer[i];
        }
        
        this->unlock();
        
        for(int i = 0; i < nFrames; i++)
        {
            m_outputBuffer[chanNum][i] *= gain;
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    Buffer<float> m_inputBuffer;
};


