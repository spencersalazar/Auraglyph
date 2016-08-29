//
//  AGTouchHandler.h
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Geometry.h"
#import "AGHandwritingRecognizer.h"
#import "AGNode.h"
#import "AGUserInterface.h"
#import "AGNodeSelector.h"


@class AGViewController;

@interface AGTouchHandler : UIResponder
{
    AGViewController *_viewController;
    AGTouchHandler * _nextHandler;
}

- (id)initWithViewController:(AGViewController *)viewController;
- (AGTouchHandler *)nextHandler;

- (void)update:(float)t dt:(float)dt;
- (void)render;

@end

@interface AGDrawNodeTouchHandler : AGTouchHandler

@end

@interface AGDrawFreedrawTouchHandler : AGTouchHandler
{
    vector<GLvertex3f> _linePoints;
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
}

@end

@interface AGMoveNodeTouchHandler : AGTouchHandler
{
    GLvertex3f _anchorOffset;
    AGNode * _moveNode;
    
    GLvertex2f _firstPoint;
    float _maxTouchTravel;
}

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node;

@end

@interface AGConnectTouchHandler : AGTouchHandler

@end

@interface AGSelectNodeTouchHandler : AGTouchHandler
{
    AGUIMetaNodeSelector * _nodeSelector;
}

- (id)initWithViewController:(AGViewController *)viewController nodeSelector:(AGUIMetaNodeSelector *)selector;

@end

@interface AGEditTouchHandler : AGTouchHandler

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node;

@end

