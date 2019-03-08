//
//  AGTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGSelectNodeTouchHandler.h"

#import "AGDef.h"
#import "Geometry.h"

#import "AGViewController.h"
#import "AGAudioManager.h"
#import "AGNode.h"
#import "AGNodeSelector.h"
#import "AGActivityManager.h"
#import "AGActivity.h"
#import "AGAnalytics.h"


//------------------------------------------------------------------------------
// ### AGSelectNodeTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGSelectNodeTouchHandler

@implementation AGSelectNodeTouchHandler

- (id)initWithViewController:(AGViewController *)viewController nodeSelector:(AGUIMetaNodeSelector *)selector;
{
    if(self = [super initWithViewController:viewController])
    {
        _nodeSelector = selector;
        [_viewController addTopLevelObject:_nodeSelector];
        [_viewController addTouchOutsideHandler:self];
    }
    
    return self;
}

- (void)dealloc
{
    //    SAFE_DELETE(_nodeSelector);
}

- (BOOL)hitTest:(GLvertex3f)t
{
    return _nodeSelector->hitTest(t) != NULL;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    _nextHandler = nil;
    
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeSelector->touchDown(pos);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeSelector->touchMove(pos);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeSelector->touchUp(pos);
    
    AGNode * newNode = _nodeSelector->createNode();
    if(newNode)
    {
        AGAnalytics::instance().eventCreateNode(newNode->nodeClass(), newNode->type());
        
        [_viewController addNode:newNode];
        
        if(newNode->type() == "Output")
        {
            AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(newNode);
            outputNode->setOutputDestination([AGAudioManager instance].masterOut);
        }
        
        AGActivity *action = AGActivity::createNodeActivity(newNode);
        AGActivityManager::instance().addActivity(action);
    }
    
    if(!_nodeSelector->done())
        _nextHandler = self;
    else
    {
        [_viewController removeTouchOutsideHandler:self];
        [_viewController fadeOutAndDelete:_nodeSelector];
    }
}

- (void)touchOutside
{
    _nextHandler = nil;
    [_viewController fadeOutAndDelete:_nodeSelector];
    [_viewController removeTouchOutsideHandler:self];
    [_viewController resignTouchHandler:self];
}

//- (void)update:(float)t dt:(float)dt
//{
//    _nodeSelector->update(t, dt);
//}
//
//- (void)render
//{
//    _nodeSelector->render();
//}

@end

