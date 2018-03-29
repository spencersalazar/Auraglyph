//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


//------------------------------------------------------------------------------
// ### AGAudioBiquadNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioBiquadNode

class AGAudioBiquadNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_A1,
        PARAM_A2,
        PARAM_B0,
        PARAM_B1,
        PARAM_B2,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioBiquadNode>
    {
    public:
        string _type() const override { return "Biquad"; };
        string _name() const override { return "Biquad"; };
        string _description() const override { return "Biquad filter."; };
        
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
                { PARAM_A1, "a1", 0.00, -2.0, 2.0, .doc = "A1 coefficient." },
                { PARAM_A2, "a2", 0.00, -2.0, 2.0, .doc = "A2 coefficient." },
                { PARAM_B0, "b0", 0.00, -2.0, 2.0, .doc = "B0 coefficient." },
                { PARAM_B1, "b1", 0.00, -2.0, 2.0, .doc = "B1 coefficient." },
                { PARAM_B2, "b2", 0.00, -2.0, 2.0, .doc = "B2 coefficient." },
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
            float radius_x = 0.006*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            float radius_circ = radius_x * 0.8;
            int circleSize = 48;
            int GEO_SIZE = circleSize*2;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            // Unit circle
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
                float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius_circ*cosf(theta0), radius_circ*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius_circ*cosf(theta1), radius_circ*sinf(theta1), 0);
            }
            
            // 1st-quadrant zero
            for(int i = 0; i < GEO_SIZE; i++)
            {
                GLvertex3f vert = iconGeo[i];
                vert = vert * 0.15;
                float theta = M_PI / 4;
                vert = vert + GLvertex3f(radius_circ*cosf(theta), radius_circ*sinf(theta), 0);
                iconGeo.push_back(vert);
            }
            
            // 4th-quadrant zero
            for(int i = 0; i < GEO_SIZE; i++)
            {
                GLvertex3f vert = iconGeo[i+GEO_SIZE];
                vert.y = -vert.y;
                iconGeo.push_back(vert);
            }
            
            // Poles
            vector<GLvertex3f> poles = {
                { 0.5, 0.5, 0 }, { 0.3, 0.3, 0 }, { 0.3, 0.5, 0 }, { 0.5, 0.3, 0 },
                { 0.5, -0.5, 0 }, { 0.3, -0.3, 0 }, { 0.3, -0.5, 0 }, { 0.5, -0.3, 0 },
            };
            
            for(int i = 0; i < poles.size(); i++)
            {
                GLvertex3f vert = poles[i];
                vert = vert * radius_circ;
                iconGeo.push_back(vert);
            }
            
            // Axes
            iconGeo.push_back(GLvertex3f(0,  radius_y, 0));
            iconGeo.push_back(GLvertex3f(0, -radius_y, 0));
            iconGeo.push_back(GLvertex3f( radius_x, 0, 0));
            iconGeo.push_back(GLvertex3f(-radius_x, 0, 0));
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        sn_1 = sn_2 = 0;
    }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
    {
        if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
        m_lastTime = t;
        pullInputPorts(t, nFrames);
        
        float *inputv = inputPortVector(PARAM_INPUT);
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float a1 = param(PARAM_A1);
        float a2 = param(PARAM_A2);
        float b0 = param(PARAM_B0);
        float b1 = param(PARAM_B1);
        float b2 = param(PARAM_B2);
        
        for(int i = 0; i < nFrames; i++)
        {
            // Transposed Direct-Form II
            float xn = inputv[i];
            float yn = b0 * xn + sn_1;
            sn_1 = -a1 * yn + b1 * xn + sn_2;
            sn_2 = -a2 * yn + b2 * xn;
            
            if (isbad(yn) || isbad(sn_1) || isbad(sn_2))
                yn = sn_1 = sn_2 = 0;
            
            m_outputBuffer[chanNum][i] = yn * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
    
private:
    float sn_1, sn_2;
};



