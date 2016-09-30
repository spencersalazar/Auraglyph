//
//  AGWaveformAudioNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 9/28/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGWaveformAudioNode.h"
#include "AGUINodeEditor.h"
#include "AGGenericShader.h"
#include "GeoGenerator.h"
#include "spdsp.h"

class AGWaveformEditor : public AGUINodeEditor
{
private:
    AGAudioWaveformNode * const m_node;
    float m_width, m_height;
    
    AGSqueezeAnimation m_squeeze;
    bool m_doneEditing;
    
public:
    AGWaveformEditor(AGAudioWaveformNode *node) :
    m_node(node), m_doneEditing(false)
    {
        m_squeeze.open();
        m_width = 400;
        m_height = m_width*0.5f;
    }
    
    virtual void update(float t, float dt) override
    {
        AGInteractiveObject::update(t, dt);
        
        m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview,
                                                      position().x, position().y, 0);
        
        m_squeeze.update(t, dt);
        m_renderState.modelview = m_squeeze.apply(m_renderState.modelview);
    }
    
    virtual void render() override
    {
        GLvertex3f box[4];
        GeoGen::makeRect(box, m_width, m_height);
        
        // fill
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::black);
        drawTriangleFan(box, 4);
        
        // stroke
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineLoop(box, 4);
        
        // draw y-axis
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineStrip((GLvertex2f[]) {
            { -m_width*0.5f*0.9f,  m_height*0.5f*0.9f },
            { -m_width*0.5f*0.9f, -m_height*0.5f*0.9f },
        }, 2);
        
        // draw x-axis
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineStrip((GLvertex2f[]) {
            { -m_width*0.5f*0.9f, 0 },
            {  m_width*0.5f*0.9f, 0 },
        }, 2);
    }
    
    virtual void touchDown(const AGTouchInfo &t) override
    {
        
    }
    
    virtual void touchMove(const AGTouchInfo &t) override
    {
        
    }
    
    virtual void touchUp(const AGTouchInfo &t) override
    {
        
    }
    
    void renderOut() override
    {
        m_squeeze.close();
        
        AGInteractiveObject::renderOut();
    }
    
    bool finishedRenderingOut() override
    {
        return m_squeeze.finishedClosing();
    }
    
    virtual bool doneEditing() override { return m_doneEditing; }
    
    virtual GLvertex3f position() override { return m_node->position(); }
    virtual GLvertex2f size() override { return GLvertex2f(m_width, m_height); }
    
    void drawTriangleFan(GLvertex3f geo[], int size)
    {
        AGGenericShader &shader = AGGenericShader::instance();
        
        shader.useProgram();
        
        shader.setModelViewMatrix(m_renderState.modelview);
        shader.setProjectionMatrix(m_renderState.projection);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glDrawArrays(GL_TRIANGLE_FAN, 0, size);
    }
    
    void drawLineLoop(GLvertex3f geo[], int size)
    {
        AGGenericShader &shader = AGGenericShader::instance();
        
        shader.useProgram();
        
        shader.setModelViewMatrix(m_renderState.modelview);
        shader.setProjectionMatrix(m_renderState.projection);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glDrawArrays(GL_LINE_LOOP, 0, size);
    }
    
    void drawLineStrip(GLvertex2f geo[], int size)
    {
        AGGenericShader &shader = AGGenericShader::instance();
        
        shader.useProgram();
        
        shader.setModelViewMatrix(m_renderState.modelview);
        shader.setProjectionMatrix(m_renderState.projection);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glDrawArrays(GL_LINE_STRIP, 0, size);
    }
    
    void drawLineStrip(GLvertex3f geo[], int size)
    {
        AGGenericShader &shader = AGGenericShader::instance();
        
        shader.useProgram();
        
        shader.setModelViewMatrix(m_renderState.modelview);
        shader.setProjectionMatrix(m_renderState.projection);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glDrawArrays(GL_LINE_STRIP, 0, size);
    }
    
    void drawWaveform(float waveform[], int size, GLvertex2f from, GLvertex2f to)
    {
        
    }
};


void AGAudioWaveformNode::initFinal()
{
    m_waveform.resize(1024, 0);
    for(int i = 0; i < m_waveform.size(); i++)
        m_waveform[i] = sinf(2*M_PI*((float)i)/m_waveform.size());
    m_phase = 0;
}

float AGAudioWaveformNode::get(float phase)
{
    double pos = ((double)phase)*m_waveform.size();
    int whole = (int)floor(pos);
    double fract = fmod(pos, 1.0f);
    
    // linear interpolation
    return m_waveform[whole]*(1-fract) + m_waveform[(whole+1)%m_waveform.size()]*(fract);
}

void AGAudioWaveformNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
//    float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
//    float *freqv = inputPortVector(PARAM_FREQ);
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = get(m_phase) * param(AUDIO_PARAM_GAIN);
        output[i] += m_outputBuffer[i];
        
        m_phase = clipunit(m_phase + param(PARAM_FREQ)/sampleRate());
    }
    
    m_lastTime = t;
}

AGUINodeEditor *AGAudioWaveformNode::createCustomEditor()
{
    AGUINodeEditor *editor = new AGWaveformEditor(this);
    editor->init();
    return editor;
}
