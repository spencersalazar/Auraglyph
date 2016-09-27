//
//  AGAudioNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGAudioNode__
#define __Auragraph__AGAudioNode__

#import "AGNode.h"

#import "Geometry.h"
#import "ShaderHelper.h"
#import "AGStyle.h"
#include "AGAudioRenderer.h"
#include "Buffers.h"

#import <GLKit/GLKit.h>
//#import <Foundation/Foundation.h>

#import <list>
#import <vector>
#import <string>

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
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override { assert(0); }
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t) override;
    
    virtual GLvertex3f relativePositionForInputPort(int port) const override;
    virtual GLvertex3f relativePositionForOutputPort(int port) const override;
    
    virtual void finalPortValue(float &value, int portId, int sample = -1) const override;
    
    virtual AGRate rate() override { return RATE_AUDIO; }
    inline float gain() const { return m_params.at(AUDIO_PARAM_GAIN); }
    
    const float *lastOutputBuffer() const { return m_outputBuffer; }
    
    static int sampleRate() { return s_sampleRate; }
    static int bufferSize() { return 1024; }
    
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
    Buffer<float> m_outputBuffer;
    float ** m_inputPortBuffer;
    
    void allocatePortBuffers();
    void pullInputPorts(sampletime t, int nFrames);
    void renderLast(float *output, int nFrames);
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
        PARAM_INPUT = AUDIO_PARAM_LAST+1,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioOutputNode>
    {
    public:
        string _type() const override { return "Output"; };
        string _name() const override { return "Output"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", true, false }
            };
        }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { AUDIO_PARAM_GAIN, "gain", false, true, 1, 0, AGFloat_Max, AGPortInfo::LOG }
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.0066*AGStyle::oldGlobalScale;
            
            // speaker icon
            //            vector<GLvertex3f> iconGeo = {
            //                { -radius*0.5f*0.16f, radius*0.5f, 0 },
            //                { -radius*0.5f, radius*0.5f, 0 },
            //                { -radius*0.5f, -radius*0.5f, 0 },
            //                { -radius*0.5f*0.16f, -radius*0.5f, 0 },
            //                { radius*0.5f, -radius, 0 },
            //                { radius*0.5f, radius, 0 },
            //                { -radius*0.5f*0.16f, radius*0.5f, 0 },
            //                { -radius*0.5f*0.16f, -radius*0.5f, 0 },
            //            };
            
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
    
    void setOutputDestination(AGAudioOutputDestination *destination);
    
    virtual int numOutputPorts() const override { return 0; }
    virtual int numInputPorts() const override { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
private:
    AGAudioOutputDestination *m_destination = NULL;
};


#endif /* defined(__Auragraph__AGAudioNode__) */
