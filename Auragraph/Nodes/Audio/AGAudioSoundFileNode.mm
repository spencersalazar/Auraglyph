//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGAudioSoundFileNode.h"


//------------------------------------------------------------------------------
// ### AGAudioSoundFileNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioSoundFileNode

string AGAudioSoundFileNode::Manifest::_type() const { return "File"; };
string AGAudioSoundFileNode::Manifest::_name() const { return "File"; };
string AGAudioSoundFileNode::Manifest::_description() const { return "Sound file player."; };

vector<AGPortInfo> AGAudioSoundFileNode::Manifest::_inputPortInfo() const
{
    return {
        { PARAM_TRIGGER, "trigger", ._default = 0 },
        { PARAM_RATE, "rate", ._default = 1 },
        { AUDIO_PARAM_GAIN, "gain", ._default = 1 },
    };
}

vector<AGPortInfo> AGAudioSoundFileNode::Manifest::_editPortInfo() const
{
    return {
        { PARAM_FILE, "file", ._default = AGControl(""),
            .type = AGControl::TYPE_STRING,
            .editorMode = AGPortInfo::EDITOR_AUDIOFILES },
        { PARAM_RATE, "rate", ._default = 1 },
        { AUDIO_PARAM_GAIN, "gain", ._default = 1 }
    };
};

vector<AGPortInfo> AGAudioSoundFileNode::Manifest::_outputPortInfo() const
{
    return {
        { PARAM_OUTPUT, "output", .doc = "Output." }
    };
}

vector<GLvertex3f> AGAudioSoundFileNode::Manifest::_iconGeo() const
{
    float r_y = 25;
    float r_x = r_y*(8.5/11.0); // US letter aspect ratio
    
    // classic folded document shape
    vector<GLvertex3f> iconGeo = {
        { r_x*(2-G_RATIO), r_y, 0 },
        { -r_x, r_y, 0 },
        { -r_x, -r_y, 0 },
        { r_x, -r_y, 0 },
        { r_x, r_y-r_x*(G_RATIO-1), 0 },
        { r_x*(2-G_RATIO), r_y-r_x*(G_RATIO-1), 0 },
        { r_x*(2-G_RATIO), r_y, 0 },
        { r_x, r_y-r_x*(G_RATIO-1), 0 },
    };
    
    return iconGeo;
}

GLuint AGAudioSoundFileNode::Manifest::_iconGeoType() const { return GL_LINE_STRIP; };


void AGAudioSoundFileNode::initFinal()
{
    stk::Stk::setSampleRate(sampleRate());
}

int AGAudioSoundFileNode::numOutputPorts() const { return 1; }
    
void AGAudioSoundFileNode::editPortValueChanged(int paramId)
{
    if(paramId == PARAM_FILE)
    {
        // todo: abstract filesystem API
        NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *subpath = [NSString stringWithUTF8String:param(PARAM_FILE).getString().c_str()];
        NSString *fullPath = [documentPath stringByAppendingPathComponent:subpath];
        m_file.openFile([fullPath UTF8String]);
        m_file.setRate(m_rate);
        // set to end of file
        m_file.addTime(m_file.getSize());
    }
}

void AGAudioSoundFileNode::renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans)
{
    if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
    m_lastTime = t;
    pullInputPorts(t, nFrames);
    
    float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
    float *triggerv = inputPortVector(PARAM_TRIGGER);
    float *ratev = inputPortVector(PARAM_RATE);
    
    for(int i = 0; i < nFrames; i++)
    {
        // Soundfile is edge-triggered
        if(m_lastTrigger <= 0 && triggerv[i] > 0)
            m_file.reset();
        
        m_lastTrigger = triggerv[i];
        
        if(ratev[i] != m_rate)
        {
            m_rate = ratev[i];
            m_file.setRate(m_rate);
        }
        
        m_outputBuffer[0][i] = m_file.tick() * gainv[i];
        output[i] += m_outputBuffer[chanNum][i];
    }
}


