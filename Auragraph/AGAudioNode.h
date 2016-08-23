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

#import <GLKit/GLKit.h>
#import <Foundation/Foundation.h>

#import <list>
#import <vector>
#import <string>

using namespace std;


//------------------------------------------------------------------------------
// ### AGAudioNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNode

class AGAudioNode : public AGNode
{
public:
    
    static void initializeAudioNode();
    
    using AGNode::AGNode;
    virtual void init() override;
    virtual void init(const AGDocument::Node &docNode) override;
    virtual ~AGAudioNode();
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    virtual AGUIObject *hitTest(const GLvertex3f &t) override;
    
    virtual GLvertex3f relativePositionForInputPort(int port) const override;
    virtual GLvertex3f relativePositionForOutputPort(int port) const override;
    
    virtual AGRate rate() override { return RATE_AUDIO; }
    inline float gain() { return m_gain; }
    
    const float *lastOutputBuffer() const { return m_outputBuffer; }
    
    static int sampleRate() { return s_sampleRate; }
    static int bufferSize() { return 1024; }
    
    virtual AGDocument::Node serialize() override;
    //    template<class NodeClass>
    //    static AGAudioNode *createFromDocNode(const AGDocument::Node &docNode);
    
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
    float * m_outputBuffer;
    float ** m_inputPortBuffer;
    
    float m_gain;
    
    void allocatePortBuffers();
    void pullInputPorts(sampletime t, int nFrames);
    void renderLast(float *output, int nFrames);
};


//------------------------------------------------------------------------------
// ### AGAudioOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioOutputNode

class AGAudioOutputNode : public AGAudioNode
{
public:
    
    class Manifest : public AGStandardNodeManifest<AGAudioOutputNode>
    {
    public:
        string _type() const override { return "Output"; };
        string _name() const override { return "Output"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, false }
            };
        }
        
        vector<AGPortInfo> _editPortInfo() const override { return { }; }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.005*AGStyle::oldGlobalScale;
            
            // speaker icon
            vector<GLvertex3f> iconGeo = {
                { -radius*0.5f*0.16f, radius*0.5f, 0 },
                { -radius*0.5f, radius*0.5f, 0 },
                { -radius*0.5f, -radius*0.5f, 0 },
                { -radius*0.5f*0.16f, -radius*0.5f, 0 },
                { radius*0.5f, -radius, 0 },
                { radius*0.5f, radius, 0 },
                { -radius*0.5f*0.16f, radius*0.5f, 0 },
                { -radius*0.5f*0.16f, -radius*0.5f, 0 },
            };
            
            return iconGeo;
        }
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; }
    };
    
    using AGAudioNode::AGAudioNode;
    
    void init() override;
    void init(const AGDocument::Node &docNode) override;
    ~AGAudioOutputNode();
    
    virtual int numOutputPorts() const override { return 0; }
    virtual int numInputPorts() const override { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;    
};


#endif /* defined(__Auragraph__AGAudioNode__) */
