//
//  AGInteractiveObject.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 9/16/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGInteractiveObject.h"
#include "AGViewController.h"

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
    GLvertex3f tt = GLKMatrix4MultiplyVector4(globalModelViewMatrix(), GLKMatrix4MultiplyVector4(GLKMatrix4Invert(modelview(), NULL), t.asGLKVector4()));
    for(AGRenderObject *renderObject : m_children)
    {
        AGInteractiveObject *object = dynamic_cast<AGInteractiveObject *>(renderObject);
        if(object)
        {
            hit = object->hitTest(tt);
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
    [[AGViewController instance] fadeOutAndDelete:this];
}


