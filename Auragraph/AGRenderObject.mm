//
//  AGRenderObject.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 10/14/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGRenderObject.h"

AGRenderObject::AGRenderObject()
{
    m_renderState.mvp = GLKMatrix4Identity;
    m_renderState.normal = GLKMatrix3Identity;
}

AGRenderObject::~AGRenderObject() { }

void AGRenderObject::update(float t, float dt) { }

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
        (*i)->shader->setMVPMatrix(m_renderState.mvp);
        (*i)->shader->setNormalMatrix(m_renderState.normal);
        
        (*i)->set();
        
        glDrawArrays((*i)->geoType, 0, (*i)->numVertex);
    }
}


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

