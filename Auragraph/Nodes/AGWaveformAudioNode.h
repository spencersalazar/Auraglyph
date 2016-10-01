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
                { PARAM_INPUT, "input", true, true }
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
            
            float radius = 0.005*AGStyle::oldGlobalScale;
            
            return {
                { -radius, -radius, 0 },
                { 0, 0, 0 },
                { radius, 0.5f*radius, 0 },
            };
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override;
    void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    AGUINodeEditor *createCustomEditor() override;

private:
    vector<float> m_waveform;
    float m_phase;
    
    float get(float phase);
};


#endif /* AGWaveformAudioNode_h */
