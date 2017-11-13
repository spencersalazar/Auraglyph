//
//  AGCompressorNode.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 9/9/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGCompressorNode_hpp
#define AGCompressorNode_hpp

#include "AGAudioNode.h"

#include "AGAudioNode.h"
#include "AGAudioCapturer.h"
#include "AGAudioOutputDestination.h"

#include <list>
#include <algorithm>

using namespace std;


class PeakDetector {
    
protected:
    float b0_r, a1_r, b0_a, a1_a, levelEstimate;
    float p, _1_p;

public:
    PeakDetector() {
        
        // default to pass-through
        this->a1_r = 0; // release coeffs
        this->b0_r = 1;
        this->a1_a = 0; // attack coeffs
        this->b0_a = 1;
        setP(2);
        reset();
    }
    
    void setTauRelease(float tauRelease, float fs) {
        a1_r = exp( -1.0 / ( tauRelease * fs ) );
        b0_r = 1 - a1_r;
    }
    
    void setTauAttack(float tauAttack, float fs) {
        a1_a = exp( -1.0 / ( tauAttack * fs ) );
        b0_a = 1 - a1_a;
    }
    
    void setP(float p)
    {
        this->p = p;
        _1_p = 1.0/p;
    }
    
    void reset() {
        // reset filter state
        levelEstimate = 0;
    }
    
    void process (float input, float& output) {
        input = pow(fabs(input), p);
        if ( input > levelEstimate )
            levelEstimate += b0_a*(input-levelEstimate );
        else
            levelEstimate += b0_r*(input-levelEstimate);
        output = pow(levelEstimate, _1_p);
    }
    
    void processStereo (float inputLeft, float inputRight, float& output) {
        inputLeft = pow(fabs(inputLeft), p);
        inputRight = pow(fabs(inputRight), p);
        float input = std::max(inputLeft, inputRight);
        if ( input > levelEstimate )
            levelEstimate += b0_a*(input-levelEstimate );
        else
            levelEstimate += b0_r*(input-levelEstimate);
        output = pow(levelEstimate, _1_p);
    }
};


//------------------------------------------------------------------------------
// ### AGAudioCompressorNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioCompressorNode


class AGAudioCompressorNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
        PARAM_OUTPUT,
        PARAM_THRESHOLD,
        PARAM_RATIO,
        PARAM_ATTACK,
        PARAM_RELEASE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioCompressorNode>
    {
    public:
        string _type() const override { return "Compressor"; };
        string _name() const override { return "Compressor"; };
        string _description() const override { return "Dynamic range compressor node."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input signal. " }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_THRESHOLD, "threshold", -20, -200, 0, .doc = "Compressor threshold (dB)." },
                { PARAM_RATIO, "ratio", 2, 1, AGFloat_Max, .doc = "Compressor ratio." },
                { PARAM_ATTACK, "attack", 0.025, 0, 1, .doc = "Compressor attack." },
                { PARAM_RELEASE, "release", 0.1, 0, 1, .doc = "Compressor release." },
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
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override;
    
private:
    PeakDetector m_detector;
};



#endif /* AGCompressorNode_hpp */
