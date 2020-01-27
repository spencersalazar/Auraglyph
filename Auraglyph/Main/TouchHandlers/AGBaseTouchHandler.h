//
//  AGBaseTouchHandler.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGViewController.h"

class AGModel;
class AGRenderModel;
FORWARD_DECLARE_OBJC_CLASS(UIEvent);
FORWARD_DECLARE_OBJC_CLASS(UITouch);
FORWARD_DECLARE_OBJC_CLASS(AGTouchHandler);

#ifdef __OBJC__
#import <Foundation/Foundation.h>
typedef NSSet<UITouch *> *AGTouchSet;
#else
typedef void* AGTouchSet;
#endif // __OBJC__


/** AGTouchOutsideListener
 */
class AGTouchOutsideListener
{
public:
    /** Called when a touch occurs outside the object returned by outsideObject().
     */
    virtual void touchedOutside() = 0;
    
    /** Object that is to be touched outside. Return nullptr to simply be
     notified of any touch.
     */
    virtual AGInteractiveObject* outsideObject() = 0;
};

/** Top level touch handler - process touch input
 */
class AGBaseTouchHandler
{
public:
    AGBaseTouchHandler(AGViewController* viewController, AGModel& model, AGRenderModel& renderModel);
    
    void touchesBegan(AGTouchSet touches, UIEvent *event);
    void touchesMoved(AGTouchSet touches, UIEvent *event);
    void touchesEnded(AGTouchSet touches, UIEvent *event);
    void touchesCancelled(AGTouchSet touches, UIEvent *event);
    
    void addTouchOutsideHandler(AGTouchHandler* handler);
    void removeTouchOutsideHandler(AGTouchHandler* handler);
    void addTouchOutsideListener(AGTouchOutsideListener* listener);
    void removeTouchOutsideListener(AGTouchOutsideListener* listener);

    void resignTouchHandler(AGTouchHandler* handler);
    void objectRemovedFromSketchModel(AGInteractiveObject* object);
    void objectRemovedFromRenderModel(AGInteractiveObject* object);
    
    void setDrawMode(AGDrawMode mode) { m_drawMode = mode; }
    AGDrawMode drawMode() { return m_drawMode; }

    AGNode::HitTestResult hitTest(const GLvertex3f& pos, AGNode **hitNode, int* port);
    
    void update(float t, float dt);
    void render();
    
private:
    void _removeFromTouchCapture(AGInteractiveObject *object);
    
    AGViewController* m_viewController = nil;
    AGModel& m_model;
    AGRenderModel& m_renderModel;
    
    AGDrawMode m_drawMode = DRAWMODE_NODE;
    
    float _initialZoomDist = 0;
    bool _passedZoomDeadzone = false;
    
    map<UITouch *, UITouch *> _touches;
    map<UITouch *, UITouch *> _freeTouches;
    UITouch *_scrollZoomTouches[2];
    map<UITouch *, AGTouchHandler *> _touchHandlers;
    map<UITouch *, AGInteractiveObject *> _touchCaptures;
    AGTouchHandler *_touchHandlerQueue = nil;
            
    list<AGTouchOutsideListener*> _touchOutsideListeners;
    list<AGTouchHandler *> _touchOutsideHandlers;
};


