//
//  AGTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGTouchHandler.h"

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

- (void)touchOutside
{
    
}

- (AGTouchHandler *)nextHandler { return _nextHandler; }

- (BOOL)hitTest:(GLvertex3f)t
{
    return NO;
}

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

@end


