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
#include "AGStyle.h"
#include "spstl.h"

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
        color.blend(1, 1, 1, state.alpha).set();
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
        glLineWidth(lineWidth);
        color.blend(1, 1, 1, state.alpha).set();
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

AGRenderObject::AGRenderObject() : m_parent(NULL), m_alpha(powcurvef(0, 1, 1, 4))
{
    m_renderState.alpha = 1;
    m_renderState.projection = GLKMatrix4Identity;
    m_renderState.modelview = GLKMatrix4Identity;
    m_renderState.normal = GLKMatrix3Identity;
    m_renderingOut = false;
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

GLKMatrix4 AGRenderObject::localTransform()
{
    GLvertex3f pos = position();
    return GLKMatrix4MakeTranslation(pos.x, pos.y, pos.y);
}

GLKMatrix4 AGRenderObject::globalTransform()
{
    GLKMatrix4 global = localTransform();
    if(parent())
        global = GLKMatrix4Multiply(global, parent()->globalTransform());
    return global;
}

GLvertex3f AGRenderObject::globalToLocalCoordinateSpace(const GLvertex3f &position)
{
    return GLKMatrix4MultiplyVector4(GLKMatrix4Invert(globalTransform(), NULL), position.asGLKVector4());
}

GLvertex3f AGRenderObject::parentToLocalCoordinateSpace(const GLvertex3f &position)
{
    return GLKMatrix4MultiplyVector4(GLKMatrix4Invert(localTransform(), NULL), position.asGLKVector4());
}

void AGRenderObject::addChild(AGRenderObject *child)
{
    m_children.push_front(child);
    child->m_parent = this;
}

void AGRenderObject::addChildToTop(AGRenderObject *child)
{
    m_children.push_back(child);
    child->m_parent = this;
}

void AGRenderObject::removeChild(AGRenderObject *child)
{
    child->renderOut();
}

void AGRenderObject::update(float t, float dt)
{
    assert(m_debug_initCalled);
    
    m_alpha.update(dt);
    
    m_renderState.alpha = m_alpha;
    if(parent())
        m_renderState.alpha *= parent()->m_renderState.alpha;
    m_renderState.projection = projectionMatrix();
    if(renderFixed())
        m_renderState.modelview = fixedModelViewMatrix();
    else if(parent())
        m_renderState.modelview = parent()->modelview();
    else
        m_renderState.modelview = globalModelViewMatrix();
    m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
    
    updateChildren(t, dt);
}

void AGRenderObject::updateChildren(float t, float dt)
{
    itmap_safe(m_children, ^(AGRenderObject *&_child){
        AGRenderObject *child = _child;
        child->update(t, dt);
        
        if(child->finishedRenderingOut())
        {
            m_children.remove(child);
            child->m_parent = NULL;
            delete child;
        }
    });
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
    m_renderingOut = true;
    m_alpha.reset(1, 0);
    
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        (*i)->renderOut();
}

bool AGRenderObject::finishedRenderingOut() const
{
    return m_renderingOut && m_alpha < 0.01;
}

void AGRenderObject::hide(bool animate)
{
    if(animate)
        m_alpha.reset(m_alpha, 0);
    else
        m_alpha.forceTo(0);
}

void AGRenderObject::unhide(bool animate)
{
    if(animate)
        m_alpha.reset(m_alpha, 1);
    else
        m_alpha.forceTo(1);
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

