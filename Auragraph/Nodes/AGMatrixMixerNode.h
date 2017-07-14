//
//  AGMatrixMixerNode.hpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/13/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#ifndef AGMatrixMixerNode_h
#define AGMatrixMixerNode_h

#include "AGAudioNode.h"
#include "AGSlider.h"

class AGAudioMatrixMixerNode : public AGAudioNode
{
    friend class AGMatrixMixerEditor;
    
public:
    
    enum Param
    {
        PARAM_IN_1 = AUDIO_PARAM_LAST+1,
        PARAM_IN_2,
        PARAM_IN_3,
        PARAM_IN_4,
        PARAM_OUT_1,
        PARAM_OUT_2,
        PARAM_OUT_3,
        PARAM_OUT_4,
        PARAM_GAIN_1_1,
        PARAM_GAIN_2_1,
        PARAM_GAIN_3_1,
        PARAM_GAIN_4_1,
        PARAM_GAIN_1_2,
        PARAM_GAIN_2_2,
        PARAM_GAIN_3_2,
        PARAM_GAIN_4_2,
        PARAM_GAIN_1_3,
        PARAM_GAIN_2_3,
        PARAM_GAIN_3_3,
        PARAM_GAIN_4_3,
        PARAM_GAIN_1_4,
        PARAM_GAIN_2_4,
        PARAM_GAIN_3_4,
        PARAM_GAIN_4_4,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioMatrixMixerNode>
    {
    public:
        string _type() const override { return "Matrix mixer"; };
        string _name() const override { return "Matrix mixer"; };
        string _description() const override { return "4x4 matrix mixer."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_IN_1, "in 1", true, true, .doc = "Input 1." },
                { PARAM_IN_2, "in 2", true, true, .doc = "Input 2." },
                { PARAM_IN_3, "in 3", true, true, .doc = "Input 3." },
                { PARAM_IN_4, "in 4", true, true, .doc = "Input 4." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_GAIN_1_1, "gain 1_1", true, true, 0, .doc = "In 1 - Out 1 Gain." },
                { PARAM_GAIN_2_1, "gain 2_1", true, true, 0, .doc = "In 2 - Out 1 Gain." },
                { PARAM_GAIN_3_1, "gain 3_1", true, true, 0, .doc = "In 3 - Out 1 Gain." },
                { PARAM_GAIN_4_1, "gain 4_1", true, true, 0, .doc = "In 4 - Out 1 Gain." },
                { PARAM_GAIN_1_2, "gain 1_2", true, true, 0, .doc = "In 1 - Out 2 Gain." },
                { PARAM_GAIN_2_2, "gain 2_2", true, true, 0, .doc = "In 2 - Out 2 Gain." },
                { PARAM_GAIN_3_2, "gain 3_2", true, true, 0, .doc = "In 3 - Out 2 Gain." },
                { PARAM_GAIN_4_2, "gain 4_2", true, true, 0, .doc = "In 4 - Out 2 Gain." },
                { PARAM_GAIN_1_3, "gain 1_3", true, true, 0, .doc = "In 1 - Out 3 Gain." },
                { PARAM_GAIN_2_3, "gain 2_3", true, true, 0, .doc = "In 2 - Out 3 Gain." },
                { PARAM_GAIN_3_3, "gain 3_3", true, true, 0, .doc = "In 3 - Out 3 Gain." },
                { PARAM_GAIN_4_3, "gain 4_3", true, true, 0, .doc = "In 4 - Out 3 Gain." },
                { PARAM_GAIN_1_4, "gain 1_4", true, true, 0, .doc = "In 1 - Out 4 Gain." },
                { PARAM_GAIN_2_4, "gain 2_4", true, true, 0, .doc = "In 2 - Out 4 Gain." },
                { PARAM_GAIN_3_4, "gain 3_4", true, true, 0, .doc = "In 3 - Out 4 Gain." },
                { PARAM_GAIN_4_4, "gain 4_4", true, true, 0, .doc = "In 4 - Out 4 Gain." },

                // XXX Dummy, we should not need this but we can't get rid of it
                { AUDIO_PARAM_GAIN, "gain", true, false, 1, .doc = "Output gain." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUT_1, "out 1", true, false, .doc = "Output 1." },
                { PARAM_OUT_2, "out 2", true, false, .doc = "Output 2." },
                { PARAM_OUT_3, "out 3", true, false, .doc = "Output 3." },
                { PARAM_OUT_4, "out 4", true, false, .doc = "Output 4." },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 30;
            float diameter = radius*2;
            
            GLvertex3f masterOffset(-radius, -radius, 0);
            
            vector<GLvertex3f> horizontalArrow = {
                {               0,                0, 0 },
                {        diameter,                0, 0 },
                {        diameter,                0, 0 },
                { diameter*0.925f,  diameter*0.075f, 0 },
                {        diameter,                0, 0 },
                { diameter*0.925f, -diameter*0.075f, 0 },
            };
            
            vector<GLvertex3f> verticalArrow = {
                {                0,                0, 0 },
                {                0,         diameter, 0 },
                {                0,   diameter*0.85f, 0 },
                { -diameter*0.075f,  diameter*0.925f, 0 },
                {                0,   diameter*0.85f, 0 },
                {  diameter*0.075f,  diameter*0.925f, 0 },
            };
            
            vector<GLvertex3f> iconGeo;
            
            for(int i = 1; i < 5; i++) // Populate our iconGeo with arrows
            {
                for(auto vertex : horizontalArrow)
                {
                    GLvertex3f thisOffset = GLvertex3f(0, i*0.2*diameter, 0) + masterOffset;
                    iconGeo.push_back(vertex + thisOffset);
                }

                for(auto vertex : verticalArrow)
                {
                    GLvertex3f thisOffset = GLvertex3f(i*0.2*diameter, 0, 0) + masterOffset;
                    iconGeo.push_back(vertex + thisOffset);
                }
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override;
    
    AGUINodeEditor *createCustomEditor() override;
    
private:

};

#endif /* AGMatrixMixerNode_h */
