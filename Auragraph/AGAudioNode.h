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


#endif /* defined(__Auragraph__AGAudioNode__) */
