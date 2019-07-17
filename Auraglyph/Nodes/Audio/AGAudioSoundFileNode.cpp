//
//  AGAudioSineWaveNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

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
        string _type() const override { return "File"; };
        string _name() const override { return "File"; };
        string _description() const override { return "Sound file player."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_TRIGGER, "trigger", ._default = 0 },
                { PARAM_RATE, "rate", ._default = 1 },
                { AUDIO_PARAM_GAIN, "gain", ._default = 1 },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_FILE, "file", ._default = AGParamValue(""),
                    .type = AGControl::TYPE_STRING,
                    .editorMode = AGPortInfo::EDITOR_AUDIOFILES },
                { PARAM_RATE, "rate", ._default = 1 },
                { AUDIO_PARAM_GAIN, "gain", ._default = 1 }
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
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGAudioNode::AGAudioNode;
    
    void initFinal() override
    {
        stk::Stk::setSampleRate(sampleRate());
    }
    
    int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_FILE)
        {
            // todo: abstract filesystem API
            NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *subpath = [NSString stringWithUTF8String:param(PARAM_FILE).getString().c_str()];
            NSString *fullPath = [documentPath stringByAppendingPathComponent:subpath];
            try {
                m_file.openFile([fullPath UTF8String]);
            } catch (const stk::StkError& error) {
                fprintf(stderr, "AGAudioSoundFileNode: unable to open file %s\n", param(PARAM_FILE).getString().c_str());
            }
            m_file.setRate(m_rate);
            // set to end of file
            m_file.addTime(m_file.getSize());
        }
    }
    
    void renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans) override
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
    
private:
    int m_fileNum = -1;
    float m_lastTrigger = 0;
    float m_rate = 1;
    stk::FileWvIn m_file;
};


