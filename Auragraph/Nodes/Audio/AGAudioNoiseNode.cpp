//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioNoiseNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNoiseNode

class AGAudioNoiseNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT = AUDIO_PARAM_LAST+1,
    };
    
    
    class Manifest : public AGStandardNodeManifest<AGAudioNoiseNode>
    {
    public:
        string _type() const override { return "Noise"; };
        string _name() const override { return "Noise"; };
        string _description() const override { return "White noise generator."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
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
            int NUM_SAMPS = 25;
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // x icon
            vector<GLvertex3f> iconGeo;
            iconGeo.resize(NUM_SAMPS);
            
            for(int i = 0; i < NUM_SAMPS; i++)
            {
                float randomSample = arc4random()*ONE_OVER_RAND_MAX*2-1;
                iconGeo[i].x = (((float)i)/(NUM_SAMPS-1)*2-1)*radius_x;
                iconGeo[i].y = randomSample*radius_y;
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        srandom((unsigned int) time(NULL));
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        
        for(int i = 0; i < nFrames; i++)
        {
            float randomSample = arc4random()*ONE_OVER_RAND_MAX*2-1;
            m_outputBuffer[chanNum][i] = randomSample*gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    constexpr static const float ONE_OVER_RAND_MAX = 1.0/4294967295.0;
};

