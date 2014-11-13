//
//  AGConnection.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGConnection.h"
#include "AGNode.h"
#include "AGViewController.h"

bool AGConnection::s_init = false;
GLuint AGConnection::s_program = 0;
GLint AGConnection::s_uniformMVPMatrix = 0;
GLint AGConnection::s_uniformNormalMatrix = 0;


//------------------------------------------------------------------------------
// ### AGConnection ###
//------------------------------------------------------------------------------
#pragma mark - AGConnection

void AGConnection::initalize()
{
    if(!s_init)
    {
        s_init = true;
        
        s_program = [ShaderHelper createProgram:@"Shader"
                                 withAttributes:SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_NORMAL | SHADERHELPER_ATTR_COLOR];
        s_uniformMVPMatrix = glGetUniformLocation(s_program, "modelViewProjectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
    }
}

AGConnection::AGConnection(AGNode * src, AGNode * dst, int dstPort) :
m_src(src), m_dst(dst), m_dstPort(dstPort),
m_rate((src->rate() == RATE_AUDIO && dst->rate() == RATE_AUDIO) ? RATE_AUDIO : RATE_CONTROL),
m_geoSize(0), m_hit(false), m_stretch(false), m_active(true), m_alpha(1, 0, 0.5, 4)
{
    initalize();
    
    AGNode::connect(this);
    
    m_inTerminal = dst->positionForOutboundConnection(this);
    m_outTerminal = src->positionForOutboundConnection(this);
    
    // generate line
    updatePath();
    
    m_color = GLcolor4f(0.75, 0.75, 0.75, 1);
    
    m_break = false;
}

AGConnection::~AGConnection()
{
    //    if(m_geo != NULL) { delete[] m_geo; m_geo = NULL; }
    //    AGNode::disconnect(this);
}

void AGConnection::fadeOutAndRemove()
{
    AGNode::disconnect(this);
    m_active = false;
    m_alpha.reset();
}

void AGConnection::updatePath()
{
    m_geoSize = 3;
    
    m_geo[0] = m_inTerminal;
    if(m_stretch)
        m_geo[1] = m_stretchPoint;
    else
        m_geo[1] = (m_inTerminal + m_outTerminal)/2;
    m_geo[2] = m_outTerminal;
}

void AGConnection::update(float t, float dt)
{
    if(m_break)
        m_color = GLcolor4f::red;
    else
        m_color = GLcolor4f::white;
    
    if(m_active)
    {
        GLvertex3f newInPos = dst()->positionForInboundConnection(this);
        GLvertex3f newOutPos = src()->positionForOutboundConnection(this);
        
        if(newInPos != m_inTerminal || newOutPos != m_outTerminal)
        {
            // recalculate path
            m_inTerminal = newInPos;
            m_outTerminal = newOutPos;
            
            updatePath();
        }
    }
    else
    {
        m_alpha.update(dt);
        m_color.a = m_alpha;
        
        if(m_alpha < 0.01)
            [[AGViewController instance] removeConnection:this];
    }
}

void AGConnection::render()
{
    GLKMatrix4 projection = AGNode::projectionMatrix();
    GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
    
    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    // render line
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &m_color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normalMatrix.m);
    
    if(m_hit)
        glLineWidth(4.0f);
    else
        glLineWidth(2.0f);
    glDrawArrays(GL_LINE_STRIP, 0, m_geoSize);
    
    // render waveform
    if(src()->rate() == RATE_AUDIO)
    {
        AGAudioNode *audioSrc = (AGAudioNode *) src();
        //        GLvertex3f vec = (m_inTerminal - m_outTerminal);
        GLvertex3f vec = (m_outTerminal - m_inTerminal);
        
        // scale gain logarithmically
        float gain = audioSrc->gain();
        gain = 1.0f/gain * (1+log10f(gain+0.1));
        
        AGWaveformShader &waveformShader = AGWaveformShader::instance();
        waveformShader.useProgram();
        
        GLKMatrix4 projection = AGNode::projectionMatrix();
        GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
        //        GLKMatrix4 modelView = GLKMatrix4Identity;
        
        // rendering the waveform in reverse seems to look better
        // probably because of aliasing between graphic fps and audio rate
        //        modelView = GLKMatrix4Translate(modelView, m_outTerminal.x, m_outTerminal.y, m_outTerminal.z);
        modelView = GLKMatrix4Translate(modelView, m_inTerminal.x, m_inTerminal.y, m_inTerminal.z);
        modelView = GLKMatrix4Rotate(modelView, vec.xy().angle(), 0, 0, 1);
        //        modelView = GLKMatrix4Translate(modelView, 0, vec.xy().magnitude()/10.0, 0);
        modelView = GLKMatrix4Translate(modelView, 0.002, 0, 0);
        modelView = GLKMatrix4Scale(modelView, (vec.xy().magnitude()-0.004), 0.001, 1);
        //        modelView = GLKMatrix4Scale(modelView, 0.1, 0.1, 1);
        
        waveformShader.setProjectionMatrix(projection);
        waveformShader.setModelViewMatrix(modelView);
        waveformShader.setNormalMatrix(normalMatrix);
        
        waveformShader.setZ(0);
        waveformShader.setGain(gain);
        glVertexAttribPointer(AGWaveformShader::s_attribPositionY, 1, GL_FLOAT, GL_FALSE, 0, audioSrc->lastOutputBuffer());
        glEnableVertexAttribArray(AGWaveformShader::s_attribPositionY);
        
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(GLKVertexAttribNormal);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &m_color);
        glDisableVertexAttribArray(GLKVertexAttribColor);
        glDisableVertexAttribArray(GLKVertexAttribPosition);
        
        glLineWidth(1.0f);
        //glPointSize(4.0f);
        
        glDrawArrays(GL_LINE_STRIP, 0, AGAudioNode::bufferSize());
        //        glDrawArrays(GL_LINE_STRIP, 0, 16);
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
    }
}

void AGConnection::touchDown(const GLvertex3f &t)
{
    m_hit = true;
}

void AGConnection::touchMove(const GLvertex3f &_t)
{
    m_stretch = true;
    m_stretchPoint = _t;
    updatePath();
    
    // maths courtesy of: http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
    GLvertex2f r = GLvertex2f(m_outTerminal.x - _t.x, m_outTerminal.y - _t.y);
    GLvertex2f normal = GLvertex2f(m_inTerminal.y - m_outTerminal.y, m_outTerminal.x - m_inTerminal.x);
    
    if(fabsf(normal.normalize().dot(r)) > 0.01)
    {
        m_break = true;
    }
    else
    {
        m_break = false;
    }
}

void AGConnection::touchUp(const GLvertex3f &t)
{
    m_stretch = false;
    m_hit = false;
    
    if(m_break)
    {
        fadeOutAndRemove();
    }
    else
    {
        updatePath();
    }
    
    m_break = false;
}

AGUIObject *AGConnection::hitTest(const GLvertex3f &_t)
{
    if(!m_active)
        return NULL;
    
    GLvertex2f p0 = GLvertex2f(m_outTerminal.x, m_outTerminal.y);
    GLvertex2f p1 = GLvertex2f(m_inTerminal.x, m_inTerminal.y);
    GLvertex2f t = GLvertex2f(_t.x, _t.y);
    
    if(pointOnLine(t, p0, p1, 0.005))
        return this;
    
    return NULL;
}


