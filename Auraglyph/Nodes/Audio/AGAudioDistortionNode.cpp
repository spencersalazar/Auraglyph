//
//  AGDistortionAudioNode.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/2/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGAudioNode.h"


// todo: cubic, atan, etc.
static float distortion_hard(float x)
{
    if(x < -1) return -1;
    if(x > 1) return 1;
    return x;
}

static float distortion_soft(float x)
{
    return x / (1+fabsf(x));
}

static float distortion_tanh(float x)
{
    return tanhf(x);
}

static float distortion_cubic(float x)
{
    if(x < -1) return -1;
    if(x > 1) return 1;
    return (3.0f/2.0f)*(x-(1.0f/3.0f)*(x*x*x));
}


//------------------------------------------------------------------------------
// ### AGAudioDistortionNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioDistortionNode

class AGAudioDistortionNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_DRIVE,
        PARAM_CLIP,
    };
    
    enum Clip
    {
        CLIP_SOFT = 0,
        CLIP_HARD,
        CLIP_TANH,
        CLIP_CUBIC,
        CLIP_MAX,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioDistortionNode>
    {
    public:
        string _type() const override { return "Overdrive"; };
        string _name() const override { return "Overdrive"; };
        string _description() const override { return "Overdrive distortion effect. "; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input. " },
                { AUDIO_PARAM_GAIN, "gain", .doc = "Output gain." },
                { PARAM_DRIVE, "drive", 1, .doc = "Input drive." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", 1, .doc = "Output gain." },
                { PARAM_DRIVE, "drive", 1, .doc = "Input drive." },
                { PARAM_CLIP, "clip", 0, 0, CLIP_MAX, AGPortInfo::LIN, .type = AGControl::TYPE_INT,
                    .editorMode = AGPortInfo::EDITOR_ENUM,
                    .enumInfo = {
                        { CLIP_SOFT, "soft" },
                        { CLIP_HARD, "hard" },
                        { CLIP_TANH, "tanh" },
                        { CLIP_CUBIC, "cubic" },
                    },
                    .doc = "Clipping mode."
                },
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
                float y0 = distortion_soft(x0*inputGain);
                float x1 = (((float)(i+1))-((float)(NUM_VERTEX/2)))/((float)(NUM_VERTEX/2));
                float y1 = distortion_soft(x1*inputGain);
                iconGeo.push_back((GLvertex2f) { x0*radius_x, y0*radius_x });
                iconGeo.push_back((GLvertex2f) { x1*radius_x, y1*radius_x });
            }
            
            // horizontal line
            // iconGeo.push_back((GLvertex2f) { -radius_x, 0 });
            // iconGeo.push_back((GLvertex2f) {  radius_x, 0 });
            // vertical line
            // iconGeo.push_back((GLvertex2f) { 0, -radius_x });
            // iconGeo.push_back((GLvertex2f) { 0,  radius_x });
            // diagonal line
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
        float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
        float *drivev = inputPortVector(PARAM_DRIVE);
        Clip clip = (Clip) param(PARAM_CLIP).getInt();
        
        for(int i = 0; i < nFrames; i++)
        {
            float input = inputv[i]*drivev[i];
            float clipped = 0;
            switch(clip)
            {
                case CLIP_SOFT: clipped = distortion_soft(input); break;
                case CLIP_HARD: clipped = distortion_hard(input); break;
                case CLIP_TANH: clipped = distortion_tanh(input); break;
                case CLIP_CUBIC: clipped = distortion_cubic(input); break;
                case CLIP_MAX: clipped = input; break;
            }
            
            m_outputBuffer[chanNum][i] = clipped * gainv[i];
            output[i] += m_outputBuffer[chanNum][i];
        }
    }
};



