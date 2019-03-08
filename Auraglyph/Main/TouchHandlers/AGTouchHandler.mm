//
//  AGTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGTouchHandler.h"

//------------------------------------------------------------------------------
// ### AGTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGTouchHandler

@implementation AGTouchHandler : UIResponder

- (id)initWithViewController:(AGViewController *)viewController
{
    if(self = [super init])
    {
        _viewController = viewController;
    }
    
    return self;
}

- (void)touchOutside { }

- (AGTouchHandler *)nextHandler { return _nextHandler; }

- (BOOL)hitTest:(GLvertex3f)t
{
    return NO;
}

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

@end


