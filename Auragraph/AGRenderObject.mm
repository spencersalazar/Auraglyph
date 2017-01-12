//
//  AGRenderObject.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 10/14/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGRenderObject.h"
#include "AGViewController.h"
#include "AGGenericShader.h"

#define DEBUG_BOUNDS 0

#if DEBUG_BOUNDS
#include "GeoGenerator.h"
#endif // DEBUG_BOUNDS


//------------------------------------------------------------------------------
// ### AGRenderInfo ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderInfo

AGRenderInfo::AGRenderInfo() :
shader(&AGGenericShader::instance()),
numVertex(0), geoType(GL_LINES), geoOffset(0)
{ }

//------------------------------------------------------------------------------
// ### AGRenderInfoV ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderInfoV
AGRenderInfoV::AGRenderInfoV() : AGRenderInfo(), color(GLcolor4f::black), geo(NULL) { }

void AGRenderInfoV::set()
{
    if(geo && numVertex)
    {
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo);
    }
}

void AGRenderInfoV::set(const AGRenderState &state)
{
    if(geo && numVertex)
    {
        GLcolor4f c = color;
        c.a *= state.alpha;
        
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &c);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo);
    }
}


//------------------------------------------------------------------------------
// ### AGRenderInfoVL ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderInfoVL

AGRenderInfoVL::AGRenderInfoVL() : AGRenderInfo(),
lineWidth(2.0), color(GLcolor4f::black), geo(NULL)
{ }

void AGRenderInfoVL::set()
{
    if(geo && numVertex)
    {
        assert(geo != NULL);
        glLineWidth(lineWidth);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo);
    }
}

void AGRenderInfoVL::set(const AGRenderState &state)
{
    if(geo && numVertex)
    {
        GLcolor4f c = color;
        c.a *= state.alpha;
        
        glLineWidth(lineWidth);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &c);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo);
    }
}

//------------------------------------------------------------------------------
// ### AGRenderInfoVC ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderInfoVC

void AGRenderInfoVC::set(const AGRenderState &state)
{
    if(geo && numVertex)
    {
        glVertexAttribPointer(AGVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvcprimf), &geo->color);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvcprimf), &geo->vertex);
    }
}

void AGRenderInfoVC::set()
{
    if(geo && numVertex)
    {
        glVertexAttribPointer(AGVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvcprimf), &geo->color);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvcprimf), &geo->vertex);
    }
}

//------------------------------------------------------------------------------
// ### AGRenderObject ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderObject

GLKMatrix4 AGRenderObject::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGRenderObject::s_modelViewMatrix = GLKMatrix4Identity;
GLKMatrix4 AGRenderObject::s_fixedModelViewMatrix = GLKMatrix4Identity;
GLKMatrix4 AGRenderObject::s_camera = GLKMatrix4Identity;

AGRenderObject::AGRenderObject() : m_parent(NULL), m_alpha(powcurvef(0, 1, 0.5, 4))
{
    m_renderState.projection = GLKMatrix4Identity;
    m_renderState.modelview = GLKMatrix4Identity;
    m_renderState.normal = GLKMatrix3Identity;
    m_debug_initCalled = false;
}

void AGRenderObject::init()
{
    // ...
    m_debug_initCalled = true;
}

AGRenderObject::~AGRenderObject()
{
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        delete *i;
}

void AGRenderObject::addChild(AGRenderObject *child)
{
    m_children.push_front(child);
    child->m_parent = this;
}

void AGRenderObject::removeChild(AGRenderObject *child)
{
    child->m_parent = NULL;
    m_children.remove(child);
}

void AGRenderObject::update(float t, float dt)
{
    assert(m_debug_initCalled);
    
    m_alpha.update(dt);
    
    m_renderState.alpha = m_alpha;
    m_renderState.projection = projectionMatrix();
    if(renderFixed())
        m_renderState.modelview = fixedModelViewMatrix();
    else
        m_renderState.modelview = globalModelViewMatrix();
    m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
    
    
    updateChildren(t, dt);
}

void AGRenderObject::updateChildren(float t, float dt)
{
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        (*i)->update(t, dt);
}

void AGRenderObject::render()
{
    assert(m_debug_initCalled);
    
    renderPrimitives();
    renderChildren();
}

void AGRenderObject::renderPrimitive(AGRenderInfo *info)
{
    glBindVertexArrayOES(0);
    
    info->shader->useProgram();
    info->shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, m_renderState.modelview));
    info->shader->setNormalMatrix(m_renderState.normal);
    
    // TODO: need to set alpha in render info
    info->set(m_renderState);
    
    glDrawArrays(info->geoType, info->geoOffset, info->numVertex);
}

void AGRenderObject::renderPrimitives()
{
    for(list<AGRenderInfo *>::iterator i = m_renderList.begin(); i != m_renderList.end(); i++)
        renderPrimitive(*i);
}

void AGRenderObject::renderChildren()
{
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        (*i)->render();
}

void AGRenderObject::renderOut()
{
    m_alpha.reset(1, 0);
    
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        (*i)->renderOut();
}

bool AGRenderObject::finishedRenderingOut()
{
    return m_alpha < 0.01;
}

void AGRenderObject::hide()
{
    m_alpha.reset(1, 0);
}

void AGRenderObject::unhide()
{
    m_alpha.reset(0, 1);
}

void AGRenderObject::debug_renderBounds()
{
#if DEBUG_BOUNDS
    GLvrectf bounds = effectiveBounds();
    GLcolor4f color = GLcolor4f(0.0f, 1.0f, 1.0f, 0.5f);
    
    glBindVertexArrayOES(0);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(GLKMatrix4Multiply(projectionMatrix(), globalModelViewMatrix()));
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(globalModelViewMatrix()), NULL));
    
    glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), &bounds);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
#endif // DEBUG_BOUNDS
}

void AGRenderObject::drawTriangleFan(GLvertex3f geo[], int size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(m_renderState.modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, size);
}

void AGRenderObject::drawTriangleFan(GLvertex3f geo[], int size, const GLKMatrix4 &xform)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    GLKMatrix4 modelview = GLKMatrix4Multiply(m_renderState.modelview, xform);
    shader.setModelViewMatrix(modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, size);
}

void AGRenderObject::drawTriangleFan(AGGenericShader &shader, GLvertex3f geo[], int size, const GLKMatrix4 &xform)
{
//    shader.useProgram();
    
    GLKMatrix4 modelview = GLKMatrix4Multiply(m_renderState.modelview, xform);
    shader.setModelViewMatrix(modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, size);
}

void AGRenderObject::drawLineLoop(GLvertex3f geo[], int size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(m_renderState.modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_LOOP, 0, size);
}

void AGRenderObject::drawLineStrip(GLvertex2f geo[], int size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(m_renderState.modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, size);
}

void AGRenderObject::drawLineStrip(GLvertex2f geo[], int size, const GLKMatrix4 &xform)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    GLKMatrix4 modelview = GLKMatrix4Multiply(m_renderState.modelview, xform);
    shader.setModelViewMatrix(modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, size);
}

void AGRenderObject::drawLineStrip(AGGenericShader &shader, GLvertex2f geo[], int size, const GLKMatrix4 &xform)
{
//    shader.useProgram();
    
    GLKMatrix4 modelview = GLKMatrix4Multiply(m_renderState.modelview, xform);
    shader.setModelViewMatrix(modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, size);
}

void AGRenderObject::drawLineStrip(GLvertex3f geo[], int size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(m_renderState.modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, size);
}

void AGRenderObject::drawWaveform(float waveform[], int size, GLvertex2f from, GLvertex2f to, float gain, float yScale)
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
    
    // move to from location
    modelView = GLKMatrix4Translate(modelView, from.x, from.y, 0);
    // rotate to face direction of to terminal
    modelView = GLKMatrix4Rotate(modelView, vec.angle(), 0, 0, 1);
    // scale [0,1] to length of connection
    modelView = GLKMatrix4Scale(modelView, vec.magnitude(), yScale, 1);
    
    waveformShader.setProjectionMatrix(projection);
    waveformShader.setModelViewMatrix(modelView);
    
    waveformShader.setZ(0);
    waveformShader.setGain(gain);
    glVertexAttribPointer(AGWaveformShader::s_attribPositionY, 1, GL_FLOAT, GL_FALSE, 0, waveform);
    glEnableVertexAttribArray(AGWaveformShader::s_attribPositionY);
    waveformShader.setNumElements(size);

    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    
    glVertexAttrib4fv(AGVertexAttribColor, (const float *) &GLcolor4f::white);
    glDisableVertexAttribArray(AGVertexAttribColor);
    
    glDisableVertexAttribArray(AGVertexAttribPosition);
    
    glLineWidth(2.0);
    
    glDrawArrays(GL_LINE_STRIP, 0, size);
    
    glEnableVertexAttribArray(AGVertexAttribPosition);
}

