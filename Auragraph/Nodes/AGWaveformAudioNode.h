//
//  AGWaveformAudioNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 9/28/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGWaveformAudioNode_h
#define AGWaveformAudioNode_h

#include "AGAudioNode.h"

class AGWaveformEditor;

class AGAudioWaveformNode : public AGAudioNode
{
    friend AGWaveformEditor;
    
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_FREQ,
        PARAM_DURATION
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioWaveformNode>
    {
    public:
        string _type() const override { return "Waveform"; };
        string _name() const override { return "Waveform"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_FREQ, "freq", true, true },
                { AUDIO_PARAM_GAIN, "gain", true, true },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", true, true, 1 },
                { PARAM_FREQ, "freq", true, true, 220 },
                { PARAM_DURATION, "dur", true, true, 1.0f/220.0f },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            int NUM_PTS = 32;
            vector<GLvertex3f> iconGeo(NUM_PTS);
            
            float radius = 25;
            float w = radius*1.3, h = w*0.3, t = h*0.75, rot = -M_PI*0.8f;
            GLvertex2f offset(-w/2,0);
            
            return {
                // waveform
                { -radius, 0, 0 },
                { -radius*0.75f, radius, 0 },
                { -radius*0.5f, 0, 0 },
                { -radius*0.25f, -radius, 0 },
                { 0, 0, 0 },
                // pen
                rotateZ(offset+GLvertex2f( w/2,      0), rot),
                rotateZ(offset+GLvertex2f( w/2-t,  h/2), rot),
                rotateZ(offset+GLvertex2f(-w/2,    h/2), rot),
                rotateZ(offset+GLvertex2f(-w/2,   -h/2), rot),
                rotateZ(offset+GLvertex2f( w/2-t, -h/2), rot),
                rotateZ(offset+GLvertex2f( w/2,      0), rot),
            };
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override;
    void deserializeFinal(const AGDocument::Node &docNode) override;
    void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
    void _renderIcon() override;
    
    AGUINodeEditor *createCustomEditor() override;
    AGDocument::Node serialize() override;
    
private:
    vector<float> m_waveform;
    float m_phase;
    
    float get(float phase);
};


#endif /* AGWaveformAudioNode_h */
