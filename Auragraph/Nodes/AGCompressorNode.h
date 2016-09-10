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
        if ( fabs( input ) > levelEstimate )
            levelEstimate += b0_a * ( pow(input, p) - levelEstimate );
        else
            levelEstimate += b0_r * ( pow(input, p) - levelEstimate );
        output = levelEstimate;
    }
};


//------------------------------------------------------------------------------
// ### AGAudioCompressorNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioCompressorNode


class AGAudioCompressorNode : public AGAudioNode
{
public:
    
    class Manifest : public AGStandardNodeManifest<AGAudioCompressorNode>
    {
    public:
        string _type() const override { return "Compressor"; };
        string _name() const override { return "Compressor"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "threshold", true, true },
                { "ratio", true, true },
                { "gain", true, true },
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
    
    void setDefaultPortValues() override;
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    PeakDetector m_detector;
    float m_ratio, m_dBThreshold, m_linearThreshold;
};



#endif /* AGCompressorNode_hpp */
