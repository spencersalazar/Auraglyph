//
//  AGAudioSoundFileNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGAudioNode.h"
#include "FileWvIn.h"

//------------------------------------------------------------------------------
// ### AGAudioSoundFileNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSoundFileNode

class AGAudioSoundFileNode : public AGAudioNode
{
public:
    
    enum Param
    {
        PARAM_FILE = AUDIO_PARAM_LAST+1,
        PARAM_TRIGGER,
        PARAM_RATE,
        PARAM_OUTPUT,
    };
    
    class Manifest : public AGStandardNodeManifest<AGAudioSoundFileNode>
    {
    public:
        string _type() const override;
        string _name() const override;
        string _description() const override;
        
        vector<AGPortInfo> _inputPortInfo() const override;
        vector<AGPortInfo> _editPortInfo() const override;
        vector<AGPortInfo> _outputPortInfo() const override;
        
        vector<GLvertex3f> _iconGeo() const override;
        GLuint _iconGeoType() const override;
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override;
    int numOutputPorts() const override;
    void editPortValueChanged(int paramId) override;
    void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override;
    
private:
    int m_fileNum = -1;
    float m_lastTrigger = 0;
    float m_rate = 1;
    stk::FileWvIn m_file;
};

