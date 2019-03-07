//
//  AGTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGEditTouchHandler.h"

#import "AGViewController.h"
#import "Geometry.h"
#import "ShaderHelper.h"
#import "hsv.h"
#import "ES2Render.h"
#import "AGHandwritingRecognizer.h"
#import "AGNode.h"
#import "AGFreeDraw.h"
#import "AGCompositeNode.h"
#import "AGAudioCapturer.h"
#import "AGAudioManager.h"
#import "AGUserInterface.h"
#import "TexFont.h"
#import "AGDef.h"
#import "AGTrainerViewController.h"
#import "AGNodeSelector.h"
#import "AGUINodeEditor.h"
#import "AGGenericShader.h"
#include "AGActivityManager.h"
#include "AGActivity.h"
#import "AGAnalytics.h"

#import "GeoGenerator.h"
#import "spMath.h"

#include "AGStyle.h"

#import <set>


//------------------------------------------------------------------------------
// ### AGEditTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGEditTouchHandler

@interface AGEditTouchHandler ()
{
    AGUINodeEditor * _nodeEditor;
    AGInteractiveObject *_touchCapture;
    BOOL _done;
}
@end

@implementation AGEditTouchHandler


- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node
{
    if(self = [super initWithViewController:viewController])
    {
        _done = NO;
        _touchCapture = NULL;
        _nodeEditor = node->createCustomEditor();
        if(_nodeEditor == NULL)
        {
            _nodeEditor = new AGUIStandardNodeEditor(node);
            _nodeEditor->init();
        }
    }
    
    return self;
}

- (void)dealloc
{
    //    SAFE_DELETE(_nodeEditor);
    // _nodeEditor will be automatically deallocated after it fades out
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_done) return;
    
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _touchCapture = _nodeEditor->hitTest(pos);
    
    if(_touchCapture)
    {
        _touchCapture->touchDown(AGTouchInfo(pos, p, (TouchID) touch, touch));
    }
    else
    {
        // add object
        [_viewController addTopLevelObject:_nodeEditor];
        // immediately remove (cause to fade out/collapse and then deallocate)
        [_viewController fadeOutAndDelete:_nodeEditor];
        _nodeEditor = NULL;
        
        _done = YES;
        _nextHandler = nil;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_done) return;
    
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _touchCapture->touchMove(AGTouchInfo(pos, p, (TouchID) touch, touch));
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_done) return;
    
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _touchCapture->touchUp(AGTouchInfo(pos, p, (TouchID) touch, touch));
    
    _done = _nodeEditor->doneEditing();
    
    if(_done)
    {
        // add object
        [_viewController addTopLevelObject:_nodeEditor];
        // immediately remove (cause to fade out/collapse and then deallocate)
        [_viewController fadeOutAndDelete:_nodeEditor];
        _nodeEditor = NULL;
        
        _nextHandler = nil;
    }
    else
        _nextHandler = self;
}

- (void)update:(float)t dt:(float)dt
{
    if(_nodeEditor) _nodeEditor->update(t, dt);
}

- (void)render
{
    if(_nodeEditor) _nodeEditor->render();
}

@end

