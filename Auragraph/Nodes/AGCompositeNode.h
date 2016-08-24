//
//  AGCompositeNode.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGCompositeNode_h
#define AGCompositeNode_h


#include "AGAudioNode.h"
#include "AGAudioCapturer.h"
#include <list>

using namespace std;


//------------------------------------------------------------------------------
// ### AGAudioCompositeNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioCompositeNode


class AGAudioCompositeNode : public AGAudioNode
{
public:
    
    class Manifest : public AGStandardNodeManifest<AGAudioCompositeNode>
    {
    public:
        string _type() const override { return "Composite"; };
        string _name() const override { return "Composite"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "input", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "gain", true, true }
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            int NUM_PTS = 32;
            vector<GLvertex3f> iconGeo(NUM_PTS);
            
            float radius = 0.005*AGStyle::oldGlobalScale;
            for(int i = 0; i < NUM_PTS; i++)
            {
                float t = ((float)i)/((float)(NUM_PTS-1));
                float x = radius*cos(2*M_PI*t);
                float y = radius*sin(2*M_PI*t);
                iconGeo[i] = GLvertex3f(x, y, 0);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void setDefaultPortValues() override
    {
        m_gain = 1;
        SAFE_DELETE(m_buffer);
        m_buffer = new float[1024];
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames) override;
    
    void addOutputNode(AGAudioNode *outputNode);
    void addInputNode(AGAudioCapturer *inputNode);
    
private:
    
    float *m_buffer = NULL;
    list<AGAudioNode *> m_outputNodes;
    list<AGAudioCapturer *> m_inputNodes;
};

void AGAudioCompositeNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_gain = value; break;
    }
}

void AGAudioCompositeNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_gain; break;
    }
}

void AGAudioCompositeNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    // feed input audio to input port(s)
    for(AGAudioCapturer *capturer : m_inputNodes)
        capturer->captureAudio(m_inputPortBuffer[0], nFrames);
    
    // render internal audio
    for(AGAudioNode *outputNode : m_outputNodes)
        outputNode->renderAudio(t, input, m_buffer, nFrames);
    
    for(int i = 0; i < nFrames; i++)
        output[i] *= m_buffer[i]*m_gain;
    
    m_lastTime = t;
}


#endif /* AGCompositeNode_h */
