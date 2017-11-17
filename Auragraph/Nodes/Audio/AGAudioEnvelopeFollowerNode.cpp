//
//  AGAudioEnvelopeFollowerNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioEnvelopeFollowerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioEnvelopeFollowerNode

class AGAudioEnvelopeFollowerNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_ATTACK,
        PARAM_RELEASE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioEnvelopeFollowerNode>
    {
    public:
        string _type() const override { return "EnvelopeFollower"; };
        string _name() const override { return "EnvelopeFollower"; };
        string _description() const override { return "Envelope follower with separate attack and release times"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_ATTACK, "attack", 0.01, 0.0001, 1.0, .doc = "Attack time." },
                { PARAM_RELEASE, "release", 0.01, 0.0001, 1.0, .doc = "Release time." },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
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
            const float ONE_OVER_RAND_MAX = 1.0/4294967295.0;
            
            int NUM_SAMPS = 200;
            float m_env = 0.0;
            float attack = 0.88;
            float release = 0.88;
            float attenuation = 0.55;
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            float nudgeUp = radius_x * 0.35;
            
            vector<float> samples;
            samples.resize(NUM_SAMPS);
            
            // Generate sine-modulated noise
            for(int i = 0; i < NUM_SAMPS; i++)
            {
                samples[i] = arc4random()*ONE_OVER_RAND_MAX*2-1;
                samples[i] *= sin(((float)i / NUM_SAMPS) * 2 * M_PI);
            }
            
            // Build vertices for our noise
            vector<GLvertex3f> iconGeo;
            for(int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                vert.x = (((float)i)/(NUM_SAMPS-1)*2-1)*radius_x;
                vert.y = samples[i]*radius_y*attenuation;
                
                iconGeo.push_back(vert);
            }
            
            // Add vertices for envelope trace
            for (int i = samples.size() - 1; i >= 0; i--)
            {
                float env_input = abs(samples[i]);
                
                if(env_input > m_env)
                {
                    m_env = attack * m_env + (1-attack) * env_input;
                }
                else
                {
                    m_env = release * m_env + (1-release) * env_input;
                }
                
                GLvertex3f vert;
                
                vert.x = (((float)i)/(NUM_SAMPS-1)*2-1)*radius_x;
                vert.y = m_env * radius_y + nudgeUp;
                
                iconGeo.push_back(vert);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        m_envelope = 0;
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float attack_coeff = exp(-1.0f/(sampleRate()*(float)param(PARAM_ATTACK)));
        float release_coeff = exp(-1.0f/(sampleRate()*(float)param(PARAM_RELEASE)));
        
        for(int i = 0; i < nFrames; i++)
        {
            
            float env_input = abs(inputv[i]);
            
            if(env_input > m_envelope)
            {
                m_envelope = attack_coeff * m_envelope + (1-attack_coeff) * env_input;
            }
            else
            {
                m_envelope = release_coeff * m_envelope + (1-release_coeff) * env_input;
            }
            
            m_outputBuffer[chanNum][i] = m_envelope * gainv[i];
            
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    float m_envelope;
};

