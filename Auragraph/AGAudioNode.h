//
//  AGAudioNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGAudioNode__
#define __Auragraph__AGAudioNode__

#include "AGNode.h"

#include "Geometry.h"
#include "ShaderHelper.h"
#include "AGStyle.h"
#include "AGAudioRenderer.h"
#include "Buffers.h"

#include "gfx.h"
//#import <Foundation/Foundation.h>

#include <list>
#include <vector>
#include <string>

using namespace std;


//------------------------------------------------------------------------------
// ### AGAudioNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNode

class AGAudioNode : public AGNode, public AGAudioRenderer
{
public:
    
    enum AudioNodeParam
    {
        AUDIO_PARAM_GAIN,
        AUDIO_PARAM_LAST = AUDIO_PARAM_GAIN
    };
    
    static void initializeAudioNode();
    
    using AGNode::AGNode;
    virtual void init() override;
    virtual void init(const AGDocument::Node &docNode) override;
    virtual ~AGAudioNode();
    
    AGDocument::Node::Class nodeClass() const override { return AGDocument::Node::AUDIO; }
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    // audio
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override { assert(0); }
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t) override;
    
    virtual GLvertex3f relativePositionForInputPort(int port) const override;
    virtual GLvertex3f relativePositionForOutputPort(int port) const override;
    
    void pullPortInput(int portId, int num, sampletime t, float *output, int nFrames);
//    virtual void finalPortValue(float &value, int portId, int sample = -1) const override;
    
    virtual AGRate rate() override { return RATE_AUDIO; }
    inline float gain() const { return param(AUDIO_PARAM_GAIN); }
    
    const float *lastOutputBuffer(int portNum) const { return m_outputBuffer[portNum]; }
    
    static int sampleRate() { return s_sampleRate; }
    static int bufferSize()
    {
#ifdef TARGET_IPHONE_SIMULATOR
        return 512;
#else
        return 256;
#endif
    }
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static GLuint s_geoSize;
    
    static int s_sampleRate;
    
    float m_radius;
    float m_portRadius;
    
protected:
    
    sampletime m_lastTime;
    
    vector<Buffer<float>> m_outputBuffer;

    float ** m_inputPortBuffer; // XXX TODO: stretch goal; should we refactor this as a vector of Buffers? if our newfangled
                                // output vector scheme works, then go for it!
    
    void allocatePortBuffers();
    void pullInputPorts(sampletime t, int nFrames);
    void renderLast(float *output, int nFrames, int chanNum);
    float *inputPortVector(int paramId);
};


//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioOutputNode

class AGAudioOutputDestination;

class AGAudioOutputNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_LEFT = AUDIO_PARAM_LAST+1,
        PARAM_RIGHT
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioOutputNode>
    {
    public:
        string _type() const override { return "Output"; };
        string _name() const override { return "Output"; };
        string _description() const override { return "Routes audio to final destination device, such as a speaker or headphones."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_LEFT, "left", true, false, .doc = "Left output channel" },
                { PARAM_RIGHT, "right", true, false, .doc = "Right output channel" }
            };
        }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", false, true, 1, 0, AGFloat_Max, AGPortInfo::LOG, .doc = "Output gain." }
            };
        }

        vector<AGPortInfo> _outputPortInfo() const override { return { }; }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.0066*AGStyle::oldGlobalScale;
            
            // arrow/chevron
            vector<GLvertex3f> iconGeo = {
                {  radius*0.3f,  radius, 0 },
                { -radius*0.5f,       0, 0 },
                {  radius*0.3f, -radius, 0 },
                { -radius*0.1f,       0, 0 },
            };
            
            return iconGeo;
        }
        
        GLuint _iconGeoType() const override { return GL_LINE_LOOP; }
    };
    
    using AGAudioNode::AGAudioNode;
    ~AGAudioOutputNode();
    
    void initFinal() override;
    
    void setOutputDestination(AGAudioOutputDestination *destination);
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override;
    
private:
    AGAudioOutputDestination *m_destination = NULL;
    Buffer<float> m_inputBuffer[2];
};


#endif /* defined(__Auragraph__AGAudioNode__) */
