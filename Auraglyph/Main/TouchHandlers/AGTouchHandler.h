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

/* TODO: convert all of this to C++ */

@class AGViewController;

@interface AGTouchHandler : UIResponder
{
    AGViewController *_viewController;
    AGTouchHandler * _nextHandler;
}

- (id)initWithViewController:(AGViewController *)viewController;
- (AGTouchHandler *)nextHandler;

- (void)touchOutside;

- (BOOL)hitTest:(GLvertex3f)t;

- (void)update:(float)t dt:(float)dt;
- (void)render;

@end


