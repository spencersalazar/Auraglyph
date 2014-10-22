//
//  AGRenderObject.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 10/14/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGRenderObject.h"


//------------------------------------------------------------------------------
// ### AGRenderObject ###
//------------------------------------------------------------------------------
#pragma mark - AGRenderObject

GLKMatrix4 AGRenderObject::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGRenderObject::s_modelViewMatrix = GLKMatrix4Identity;

AGRenderObject::AGRenderObject()
{
    m_renderState.projection = GLKMatrix4Identity;
    m_renderState.modelview = GLKMatrix4Identity;
    m_renderState.normal = GLKMatrix3Identity;
}

AGRenderObject::~AGRenderObject() { }

void AGRenderObject::update(float t, float dt)
{
    m_renderState.projection = projectionMatrix();
    m_renderState.modelview = globalModelViewMatrix();
    m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
}

void AGRenderObject::render()
{
    renderPrimitives();
}

void AGRenderObject::renderPrimitives()
{
    for(list<AGRenderInfo *>::iterator i = m_renderList.begin(); i != m_renderList.end(); i++)
    {
        glBindVertexArrayOES(0);
        
        (*i)->shader->useProgram();
        (*i)->shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, m_renderState.modelview));
        (*i)->shader->setNormalMatrix(m_renderState.normal);
        
        (*i)->set();
        
        glDrawArrays((*i)->geoType, 0, (*i)->numVertex);
    }
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

void AGInteractiveObject::touchDown(const AGTouchInfo &t) { }
void AGInteractiveObject::touchMove(const AGTouchInfo &t) { }
void AGInteractiveObject::touchUp(const AGTouchInfo &t) { }

AGInteractiveObject *AGInteractiveObject::hitTest(const GLvertex3f &t)
{
    GLvrectf bounds = effectiveBounds();
    if(t.x >= bounds.bl.x && t.x <= bounds.ur.x &&
       t.y >= bounds.bl.y && t.y <= bounds.ur.y)
        return this;
    else
        return NULL;
}

