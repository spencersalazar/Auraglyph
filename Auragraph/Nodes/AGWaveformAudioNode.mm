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
        
        // fill frame
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::black);
        drawTriangleFan(box, 4);
        
        // stroke frame
        glLineWidth(2.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineLoop(box, 4);
        
        // draw y-axis
        glLineWidth(1.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineStrip((GLvertex2f[]) {
            { -m_width*0.5f*0.9f,  m_height*0.5f*0.9f },
            { -m_width*0.5f*0.9f, -m_height*0.5f*0.9f },
        }, 2);
        
        // draw x-axis
        glLineWidth(1.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineStrip((GLvertex2f[]) {
            { -m_width*0.5f*0.9f, 0 },
            {  m_width*0.5f*0.9f, 0 },
        }, 2);
        
        glLineWidth(3.0f);
        // draw waveform
        drawWaveform(m_node->m_waveform.data(), m_node->m_waveform.size(),
                     GLvertex2f(-m_width*0.5f*0.9f, 0), GLvertex2f(m_width*0.5f*0.9f, 0),
                     1.0f, m_height*0.5f*0.9f);
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
    
    void drawWaveform(float waveform[], int size, GLvertex2f from, GLvertex2f to, float gain = 1.0f, float yScale = 1.0f)
    {
        GLvertex2f vec = (to - from);
        
        // scale gain logarithmically
        if(gain > 0)
            gain = 1.0f/gain * (1+log10f(gain));
        else
            gain = 1;
        
        AGWaveformShader &waveformShader = AGWaveformShader::instance();
        waveformShader.useProgram();
        
        waveformShader.setWindowAmount(0);
        
        GLKMatrix4 projection = m_renderState.projection;
        GLKMatrix4 modelView = m_renderState.modelview;
        
        // rendering the waveform in reverse seems to look better
        // probably because of aliasing between graphic fps and audio rate
        // move to destination terminal
        // modelView = GLKMatrix4Translate(modelView, m_outTerminal.x, m_outTerminal.y, m_outTerminal.z);
        modelView = GLKMatrix4Translate(modelView, from.x, from.y, 0);
        // rotate to face direction of source terminal
        modelView = GLKMatrix4Rotate(modelView, vec.angle(), 0, 0, 1);
        // scale [0,1] to length of connection
        modelView = GLKMatrix4Scale(modelView, vec.magnitude(), yScale, 1);
        
        waveformShader.setProjectionMatrix(projection);
        waveformShader.setModelViewMatrix(modelView);
        
        waveformShader.setZ(0);
        waveformShader.setGain(gain);
        glVertexAttribPointer(AGWaveformShader::s_attribPositionY, 1, GL_FLOAT, GL_FALSE, 0, waveform);
        glEnableVertexAttribArray(AGWaveformShader::s_attribPositionY);
        
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(GLKVertexAttribNormal);
        
        glDisableVertexAttribArray(GLKVertexAttribPosition);
        
        glDrawArrays(GL_LINE_STRIP, 0, size);
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
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
