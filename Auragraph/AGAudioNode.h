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
    
    AGAudioNode(GLvertex3f pos = GLvertex3f(), AGNodeInfo *nodeInfo = NULL);
    AGAudioNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo);
    virtual ~AGAudioNode();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    virtual GLvertex3f relativePositionForInputPort(int port) const;
    virtual GLvertex3f relativePositionForOutputPort(int port) const;
    
    virtual AGRate rate() { return RATE_AUDIO; }
    inline float gain() { return m_gain; }
    
    const float *lastOutputBuffer() const { return m_outputBuffer; }
    
    static int sampleRate() { return s_sampleRate; }
    static int bufferSize() { return 1024; }
    
    virtual AGDocument::Node serialize();
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
    static void initialize();
    
    AGAudioOutputNode(GLvertex3f pos);
    AGAudioOutputNode(const AGDocument::Node &docNode);
    
    virtual int numOutputPorts() const { return 0; }
    virtual int numInputPorts() const { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static AGNodeInfo *nodeInfo() { return s_audioNodeInfo; }
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};


#endif /* defined(__Auragraph__AGAudioNode__) */
