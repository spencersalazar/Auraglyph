//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioPannerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioPannerNode

class AGAudioPannerNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT_L,
        PARAM_OUTPUT_R,
        PARAM_PAN,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioPannerNode>
    {
    public:
        string _type() const override { return "Panner"; };
        string _name() const override { return "Panner"; };
        string _description() const override { return "Constant-power 2-channel panner."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input" },
                { PARAM_PAN, "pan", 0, -1, 1, .doc = "Pan amount (-1.0 - 1.0)" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_PAN, "pan", 0, -1, 1, .doc = "Pan amount (-1.0 - 1.0)" },
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." }
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT_L, "left output", .doc = "Left output" },
                { PARAM_OUTPUT_R, "right output", .doc = "Right output" },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.006*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            float radius_circ = radius_x * 0.8;
            int circleSize = 24;
            int GEO_SIZE = circleSize*2;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            // Hemisphere
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = M_PI*((float)i)/((float)(circleSize));
                float theta1 = M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius_circ*cosf(theta0), radius_circ*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius_circ*cosf(theta1), radius_circ*sinf(theta1), 0);
            }
            
            // Axes
            iconGeo.push_back(GLvertex3f(0,  radius_y, 0));
            iconGeo.push_back(GLvertex3f(0,         0, 0));
            iconGeo.push_back(GLvertex3f( radius_x, 0, 0));
            iconGeo.push_back(GLvertex3f(-radius_x, 0, 0));
            
            // Arrow
            iconGeo.push_back(GLvertex3f(-radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.6, radius_y * 1.4, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.6, radius_y * 1.0, 0));
            iconGeo.push_back(GLvertex3f(-radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.6, radius_y * 1.4, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.8, radius_y * 1.2, 0));
            iconGeo.push_back(GLvertex3f( radius_x * 0.6, radius_y * 1.0, 0));
            
            // Nudge everything downwards a bit
            for(int i = 0; i < iconGeo.size(); i++)
            {
                iconGeo[i].y -= radius_y * 0.6;
            }
            
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
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *panv = inputPortVector(PARAM_PAN);
        
        for(int i = 0; i < nFrames; i++)
        {
            float theta = panv[i] * M_PI_4;
            float gain_l = sqrt(2)/2 * (sin(theta) + cos(theta));
            float gain_r = sqrt(2)/2 * (sin(theta) - cos(theta));
            
            m_outputBuffer[0][i] = inputv[i] * gain_l;
            m_outputBuffer[1][i] = inputv[i] * gain_r;
            
            output[i] += m_outputBuffer[chanNum][i] * gainv[i];
        }
    }
};

