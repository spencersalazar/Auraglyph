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
    
    GLKMatrix4 modelView;
    if(renderFixed())
        modelView = fixedModelViewMatrix();
    else
        modelView = globalModelViewMatrix();
    
    // convert touch to parent coordinate space
    // all child objects are oriented in terms of this coordinate space
    GLvertex3f tt = GLKMatrix4MultiplyVector4(GLKMatrix4Invert(localTransform(), NULL), t.asGLKVector4());
    
    // search in reverse order of rendering
    for(auto i = m_children.rbegin(); i != m_children.rend(); i++)
    {
        AGInteractiveObject *object = dynamic_cast<AGInteractiveObject *>(*i);
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

void AGInteractiveObject::addTouchOutsideListener(AGTouchOutsideListener *listener)
{
    AGViewController *viewController = [AGViewController instance];
    [viewController addTouchOutsideListener:listener];
}

void AGInteractiveObject::removeTouchOutsideListener(AGTouchOutsideListener *listener)
{
    [[AGViewController instance] removeTouchOutsideListener:listener];
}


