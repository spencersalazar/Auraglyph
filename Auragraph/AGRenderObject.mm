//
//  AGRenderObject.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 10/14/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGRenderObject.h"
#include "AGViewController.h"

#define DEBUG_BOUNDS 1

#if DEBUG_BOUNDS
#include "GeoGenerator.h"
#endif // DEBUG_BOUNDS

//------------------------------------------------------------------------------
// ### AGRenderObject ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderObject

GLKMatrix4 AGRenderObject::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGRenderObject::s_modelViewMatrix = GLKMatrix4Identity;
GLKMatrix4 AGRenderObject::s_fixedModelViewMatrix = GLKMatrix4Identity;

AGRenderObject::AGRenderObject() : m_parent(NULL)
{
    m_renderState.projection = GLKMatrix4Identity;
    m_renderState.modelview = GLKMatrix4Identity;
    m_renderState.normal = GLKMatrix3Identity;
}

AGRenderObject::~AGRenderObject()
{
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        delete *i;
}

void AGRenderObject::addChild(AGRenderObject *child)
{
    m_children.push_back(child);
    child->m_parent = this;
}

void AGRenderObject::removeChild(AGRenderObject *child)
{
    child->m_parent = NULL;
    m_children.remove(child);
}

void AGRenderObject::update(float t, float dt)
{
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
    renderPrimitives();
    renderChildren();
}

void AGRenderObject::renderPrimitive(AGRenderInfo *info)
{
    glBindVertexArrayOES(0);
    
    info->shader->useProgram();
    info->shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, m_renderState.modelview));
    info->shader->setNormalMatrix(m_renderState.normal);
    
    info->set();
    
    glDrawArrays(info->geoType, 0, info->numVertex);
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
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
        (*i)->renderOut();
}

void AGRenderObject::debug_renderBounds()
{
    GLvrectf bounds = effectiveBounds();
    GLcolor4f color = GLcolor4f(0.0f, 1.0f, 1.0f, 0.5f);
    
    glBindVertexArrayOES(0);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(GLKMatrix4Multiply(projectionMatrix(), globalModelViewMatrix()));
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(globalModelViewMatrix()), NULL));
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), &bounds);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
}


//------------------------------------------------------------------------------
// ### AGInteractiveObject ###
//------------------------------------------------------------------------------
#pragma mark - AGInteractiveObject

AGInteractiveObject::AGInteractiveObject() { }

AGInteractiveObject::~AGInteractiveObject() { }

void AGInteractiveObject::touchDown(const GLvertex3f &t) { }
void AGInteractiveObject::touchMove(const GLvertex3f &t) { }
void AGInteractiveObject::touchUp(const GLvertex3f &t) { }

void AGInteractiveObject::touchDown(const AGTouchInfo &t) { touchDown(t.position); }
void AGInteractiveObject::touchMove(const AGTouchInfo &t) { touchMove(t.position); }
void AGInteractiveObject::touchUp(const AGTouchInfo &t) { touchUp(t.position); }

AGInteractiveObject *AGInteractiveObject::hitTest(const GLvertex3f &t)
{
    // first check children
    AGInteractiveObject *hit;
    for(list<AGRenderObject *>::iterator i = m_children.begin(); i != m_children.end(); i++)
    {
        AGInteractiveObject *object = dynamic_cast<AGInteractiveObject *>(*i);
        if(object)
        {
            hit = object->hitTest(t);
            if(hit != NULL)
                return hit;
        }
    }
    
    // check self
    GLvrectf bounds = effectiveBounds();
    if(t.x >= bounds.bl.x && t.x <= bounds.ur.x &&
       t.y >= bounds.bl.y && t.y <= bounds.ur.y)
        return this;
    
    return NULL;
}

void AGInteractiveObject::removeFromTopLevel()
{
    [[AGViewController instance] removeTopLevelObject:this];
}


