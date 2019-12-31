//
//  AGBaseTouchHandler.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGBaseTouchHandler.h"

#include "AGModel.h"
#include "AGRenderModel.h"
#include "AGDashboard.h"

#import "AGTouchHandler.h"
#import "AGConnectTouchHandler.h"
#import "AGMoveNodeTouchHandler.h"
#import "AGDrawNodeTouchHandler.h"
#import "AGDrawFreedrawTouchHandler.h"
#import "AGEraseFreedrawTouchHandler.h"

#include "spstl.h"


#define AG_ZOOM_DEADZONE (15)


AGBaseTouchHandler::AGBaseTouchHandler(AGViewController* viewController, AGModel& model, AGRenderModel& renderModel)
: m_viewController(viewController), m_model(model), m_renderModel(renderModel)
{ }

AGNode::HitTestResult AGBaseTouchHandler::hitTest(const GLvertex3f& pos, AGNode **hitNode, int* port)
{
    AGNode::HitTestResult hit;
    
    for(AGNode *node : m_model.graph.nodes())
    {
        hit = node->hit(pos, port);
        if(hit != AGNode::HIT_NONE)
        {
            if(node)
                *hitNode = node;
            return hit;
        }
    }
    
    if(hitNode)
        *hitNode = NULL;
    return AGNode::HIT_NONE;
}

void AGBaseTouchHandler::touchesBegan(NSSet<UITouch *> *touches, UIEvent *event)
{
    dbgprint_off("touchesBegan, count = %lu\n", (unsigned long)[touches count]);
    
    // hit test each touch
    for(UITouch *touch in touches)
    {
        CGPoint p = [touch locationInView:m_viewController.view];
        GLvertex3f pos = m_renderModel.screenToWorld(p);
        GLvertex3f fixedPos = m_renderModel.screenToFixed(p);
        AGTouchHandler *handler = nil;
        AGInteractiveObject *touchCapture = NULL;
        AGInteractiveObject *touchCaptureTopLevelObject = NULL;
        
        // check modal overlay
        touchCapture = m_renderModel.modalOverlay.hitTest(fixedPos);
        if(touchCapture)
        {
            touchCaptureTopLevelObject = &m_renderModel.modalOverlay;
        }
        
        if(touchCapture == NULL)
        {
            // search dashboard items
            // search in reverse order
            for(auto i = m_renderModel.dashboard.rbegin(); i != m_renderModel.dashboard.rend(); i++)
            {
                AGInteractiveObject *object = *i;
                
                // check regular interactive object
                if(object->renderFixed())
                    touchCapture = object->hitTest(fixedPos);
                else
                    touchCapture = object->hitTest(pos);
                
                if(touchCapture)
                {
                    touchCaptureTopLevelObject = object;
                    break;
                }
            }
        }
        
        if(touchCapture == NULL)
        {
            touchCapture = m_renderModel.uiDashboard->hitTest(fixedPos);
            if(touchCapture)
                touchCaptureTopLevelObject = m_renderModel.uiDashboard;
        }

        // search pending handlers
        if(touchCapture == NULL)
        {
            if(_touchHandlerQueue && [_touchHandlerQueue hitTest:pos])
            {
                handler = _touchHandlerQueue;
                _touchHandlerQueue = nil;
            }
        }
        
        // search the rest of the objects
        if(touchCapture == NULL && handler == nil)
        {
            // search in reverse order
            for(auto i = m_renderModel.objects.rbegin(); i != m_renderModel.objects.rend(); i++)
            {
                AGInteractiveObject *object = *i;
                
                // check if its a node
                // todo: check node ports first
                AGNode *node = dynamic_cast<AGNode *>(object);
                if(node)
                {
                    // nodes require special hit testing
                    // in addition to regular hit testing
                    int port;
                    AGNode::HitTestResult result = node->hit(pos, &port);
                    if(result != AGNode::HIT_NONE)
                    {
                        if(result == AGNode::HIT_INPUT_NODE || result == AGNode::HIT_OUTPUT_NODE)
                            handler = [[AGConnectTouchHandler alloc] initWithViewController:m_viewController];
                        else if(result == AGNode::HIT_MAIN_NODE)
                            handler = [[AGMoveNodeTouchHandler alloc] initWithViewController:m_viewController node:node];
                        
                        break;
                    }
                }
                
                // check regular interactive object
                if(object->renderFixed())
                    touchCapture = object->hitTest(fixedPos);
                else
                    touchCapture = object->hitTest(pos);
                
                if(touchCapture)
                {
                    touchCaptureTopLevelObject = object;
                    break;
                }
            }
        }
        
        // search node connections
        if(touchCapture == NULL && handler == nil)
        {
            for(AGNode *node : m_model.graph.nodes())
            {
                for(AGConnection *connection : node->outbound())
                {
                    touchCapture = connection->hitTest(pos);
                    if(touchCapture)
                        break;
                }
                
                if(touchCapture)
                    break;
            }
        }
        
        // deal with drawing
        if(touchCapture == NULL && handler == nil)
        {
            if(_freeTouches.size() == 1)
            {
                // zoom gesture
                UITouch *firstTouch = _freeTouches.begin()->first;
                UITouch *secondTouch = touch;
                
                _scrollZoomTouches[0] = firstTouch;
                _freeTouches.erase(firstTouch);
                if(_touchHandlers.count(firstTouch))
                {
                    [_touchHandlers[firstTouch] touchesCancelled:[NSSet setWithObject:secondTouch] withEvent:event];
                    _touchHandlers.erase(firstTouch);
                }
                
                _scrollZoomTouches[1] = secondTouch;
                
                CGPoint p1 = [_scrollZoomTouches[0] locationInView:m_viewController.view];
                CGPoint p2 = [_scrollZoomTouches[1] locationInView:m_viewController.view];
                _initialZoomDist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
                _passedZoomDeadzone = NO;
            }
            else
            {
                switch (m_drawMode)
                {
                    case DRAWMODE_NODE:
                        handler = [[AGDrawNodeTouchHandler alloc] initWithViewController:m_viewController];
                        break;
                    case DRAWMODE_FREEDRAW:
                        handler = [[AGDrawFreedrawTouchHandler alloc] initWithViewController:m_viewController];
                        break;
                    case DRAWMODE_FREEDRAW_ERASE:
                        handler = [[AGEraseFreedrawTouchHandler alloc] initWithViewController:m_viewController];
                        break;
                }
                
                [handler touchesBegan:touches withEvent:event];
                
                _freeTouches[touch] = touch;
            }
        }
        
        // record touch
        _touches[touch] = touch;
        
        // process handler (if any)
        if(handler)
        {
            _touchHandlers[touch] = handler;
            [handler touchesBegan:[NSSet setWithObject:touch] withEvent:event];
        }
        // process capture (if any)
        else if(touchCapture)
        {
            _touchCaptures[touch] = touchCapture;
            if(touchCapture->renderFixed())
                touchCapture->touchDown(AGTouchInfo(fixedPos, p, (TouchID) touch, touch));
            else
            {
                GLvertex3f localPos = pos;
                if(touchCapture->parent())
                    // touchDown/Move/Up events treat the position as if it were in the parent coordinate space
                    localPos = touchCapture->parent()->globalToLocalCoordinateSpace(localPos);
                touchCapture->touchDown(AGTouchInfo(localPos, p, (TouchID) touch, touch));
            }
        }
        
        // has
        // is obj or one of its N-children equal to test?
        std::function<bool (AGRenderObject *obj, AGRenderObject *test)> has = [&has] (AGRenderObject *obj, AGRenderObject *test)
        {
            if(obj == test) return true;
            for(auto child : obj->children())
                if(has(child, test))
                    return true;
            return false;
        };
        
        itmap_safe(_touchOutsideListeners, ^(AGInteractiveObject *&touchOutsideListener){
            if(!has(touchOutsideListener, touchCapture))
                touchOutsideListener->touchOutside();
        });
        
        // TODO: what does __strong here really mean
        // TODO: convert AGTouchHandler to C++ class
        itmap_safe(_touchOutsideHandlers, ^(__strong AGTouchHandler *&outsideHandler){
            if(handler != outsideHandler)
                [outsideHandler touchOutside];
        });
    }
}

void AGBaseTouchHandler::touchesMoved(NSSet<UITouch *> *touches, UIEvent *event)
{
    dbgprint_off("touchesMoved, count = %lu\n", (unsigned long)[touches count]);
    
    BOOL didScroll = NO;
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint screenPos = [touch locationInView:m_viewController.view];
                
                if(touchCapture->renderFixed())
                {
                    GLvertex3f fixedPos = m_renderModel.screenToFixed(screenPos);
                    touchCapture->touchMove(AGTouchInfo(fixedPos, screenPos, (TouchID) touch, touch));
                }
                else
                {
                    GLvertex3f localPos = m_renderModel.screenToWorld(screenPos);
                    if(touchCapture->parent())
                        // touchDown/Move/Up events treat the position as if it were in the parent coordinate space
                        localPos = touchCapture->parent()->globalToLocalCoordinateSpace(localPos);
                    touchCapture->touchMove(AGTouchInfo(localPos, screenPos, (TouchID) touch, touch));
                }
            }
        }
        else if(_touchHandlers.count(touch))
        {
            AGTouchHandler *touchHandler = _touchHandlers[touch];
            [touchHandler touchesMoved:[NSSet setWithObject:touch] withEvent:event];
        }
        else if(_scrollZoomTouches[0] == touch || _scrollZoomTouches[1] == touch)
        {
            if(!didScroll)
            {
                didScroll = YES;
                CGPoint p1 = [_scrollZoomTouches[0] locationInView:m_viewController.view];
                CGPoint p1_1 = [_scrollZoomTouches[0] previousLocationInView:m_viewController.view];
                CGPoint p2 = [_scrollZoomTouches[1] locationInView:m_viewController.view];
                CGPoint p2_1 = [_scrollZoomTouches[1] previousLocationInView:m_viewController.view];
                
                CGPoint centroid = CGPointMake((p1.x+p2.x)/2, (p1.y+p2.y)/2);
                CGPoint centroid_1 = CGPointMake((p1_1.x+p2_1.x)/2, (p1_1.y+p2_1.y)/2);
                
                GLvertex3f pos = m_renderModel.screenToWorld(centroid);
                GLvertex3f pos_1 = m_renderModel.screenToWorld(centroid_1);
                
                m_renderModel.camera = m_renderModel.camera + (pos.xy() - pos_1.xy());
                dbgprint_off("camera: %f, %f, %f\n", m_renderModel.camera.x, m_renderModel.camera.y, m_renderModel.camera.z);
                
                float dist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
                float dist_1 = GLvertex2f(p1_1).distanceTo(GLvertex2f(p2_1));
                if(!_passedZoomDeadzone &&
                   (dist_1 > _initialZoomDist+AG_ZOOM_DEADZONE ||
                    dist_1 < _initialZoomDist-AG_ZOOM_DEADZONE))
                {
                    dbgprint("passed zoom deadzone\n");
                    _passedZoomDeadzone = YES;
                }
                if(_passedZoomDeadzone)
                {
                    float zoom = (dist - dist_1);
                    m_renderModel.cameraZ += zoom;
                }
            }
        }
    }
}

void AGBaseTouchHandler::touchesEnded(NSSet<UITouch *> *touches, UIEvent *event)
{
    dbgprint_off("touchEnded, count = %lu\n", (unsigned long)[touches count]);
    
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint screenPos = [touch locationInView:m_viewController.view];

                if(touchCapture->renderFixed())
                {
                    GLvertex3f fixedPos = m_renderModel.screenToFixed(screenPos);
                    touchCapture->touchUp(AGTouchInfo(fixedPos, screenPos, (TouchID) touch, touch));
                }
                else
                {
                    GLvertex3f localPos = m_renderModel.screenToWorld(screenPos);
                    if(touchCapture->parent())
                        // touchDown/Move/Up events treat the position as if it were in the parent coordinate space
                        localPos = touchCapture->parent()->globalToLocalCoordinateSpace(localPos);
                    touchCapture->touchUp(AGTouchInfo(localPos, screenPos, (TouchID) touch, touch));
                }

                _touchCaptures.erase(touch);
            }
        }
        else if(_touchHandlers.count(touch))
        {
            AGTouchHandler *touchHandler = _touchHandlers[touch];
            [touchHandler touchesEnded:[NSSet setWithObject:touch] withEvent:event];
            AGTouchHandler *nextHandler = [touchHandler nextHandler];
            if(nextHandler)
            {
                dbgprint("queuing touchHandler: %s 0x%08lx\n", [NSStringFromClass([nextHandler class]) UTF8String], (unsigned long) nextHandler);
                _touchHandlerQueue = nextHandler;
            }
            _touchHandlers.erase(touch);
        }
        else if(touch == _scrollZoomTouches[0] || touch == _scrollZoomTouches[1])
        {
            // return remaining touch to freetouches
            if(touch == _scrollZoomTouches[0])
                _freeTouches[_scrollZoomTouches[1]] = _scrollZoomTouches[1];
            else
                _freeTouches[_scrollZoomTouches[0]] = _scrollZoomTouches[0];
            _scrollZoomTouches[0] = _scrollZoomTouches[1] = NULL;
        }
        
        _freeTouches.erase(touch);
        _touches.erase(touch);
    }
}

void AGBaseTouchHandler::touchesCancelled(NSSet<UITouch *> *touches, UIEvent *event)
{
    touchesCancelled(touches, event);
}

void AGBaseTouchHandler::addTouchOutsideHandler(AGTouchHandler* handler)
{
    _touchOutsideHandlers.push_back(handler);
}

void AGBaseTouchHandler::removeTouchOutsideHandler(AGTouchHandler* handler)
{
    _touchOutsideHandlers.remove(handler);
}

void AGBaseTouchHandler::addTouchOutsideListener(AGInteractiveObject* object)
{
    _touchOutsideListeners.push_back(object);
}

void AGBaseTouchHandler::removeTouchOutsideListener(AGInteractiveObject* object)
{
    _touchOutsideListeners.remove(object);
}

void AGBaseTouchHandler::objectRemovedFromSketchModel(AGInteractiveObject* object)
{
    _removeFromTouchCapture(object);
}

void AGBaseTouchHandler::objectRemovedFromRenderModel(AGInteractiveObject* object)
{
    _removeFromTouchCapture(object);
}

void AGBaseTouchHandler::update(float t, float dt)
{
    for(auto kv : _touchHandlers)
        [_touchHandlers[kv.first] update:t dt:dt];
    [_touchHandlerQueue update:t dt:dt];
}

void AGBaseTouchHandler::render()
{
    for(auto kv : _touchHandlers)
        [_touchHandlers[kv.first] render];
    [_touchHandlerQueue render];
}

void AGBaseTouchHandler::_removeFromTouchCapture(AGInteractiveObject *object)
{
    // remove object and all children from touch capture
    std::function<void (AGRenderObject *obj)> removeAll = [&removeAll, object, this] (AGRenderObject *obj)
    {
        AGInteractiveObject *intObj = dynamic_cast<AGInteractiveObject *>(obj);
        if(intObj)
            removevalues(_touchCaptures, intObj);
        for(auto child : obj->children())
            removeAll(child);
    };
    
    removeAll(object);
}

void AGBaseTouchHandler::resignTouchHandler(AGTouchHandler* handler)
{
    removevalues(_touchHandlers, handler);
    _touchOutsideHandlers.remove(handler);
    if(handler == _touchHandlerQueue)
        _touchHandlerQueue = nil;
}

