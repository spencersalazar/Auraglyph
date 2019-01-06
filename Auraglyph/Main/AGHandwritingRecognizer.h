//
//  AGHandwritingRecognizer.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/9/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#pragma once

#if __OBJC__
#import <Foundation/Foundation.h>
#endif // __OBJC__

#include "LTKTypes.h"
#include "LTKTrace.h"
#include "LTKTraceGroup.h"


enum AGHandwritingRecognizerFigure
{
    AG_FIGURE_NONE = 0,
    
    AG_FIGURE_0 = '0',
    AG_FIGURE_1 = '1',
    AG_FIGURE_2 = '2',
    AG_FIGURE_3 = '3',
    AG_FIGURE_4 = '4',
    AG_FIGURE_5 = '5',
    AG_FIGURE_6 = '6',
    AG_FIGURE_7 = '7',
    AG_FIGURE_8 = '8',
    AG_FIGURE_9 = '9',
    
    AG_FIGURE_PERIOD = '.',
    
    // start geometric figures after ASCII range
    AG_FIGURE_CIRCLE = 128,
    AG_FIGURE_SQUARE,
    AG_FIGURE_TRIANGLE_UP,
    AG_FIGURE_TRIANGLE_DOWN,
};

// TODO: refactor as C++

#if __OBJC__

@interface AGHandwritingRecognizer : NSObject

@property (nonatomic, weak) UIView *view;

+ (id)instance;

- (BOOL)figureIsNumeral:(AGHandwritingRecognizerFigure)figure;
- (BOOL)figureIsShape:(AGHandwritingRecognizerFigure)figure;

- (AGHandwritingRecognizerFigure)recognizeNumeral:(const LTKTrace &)trace;
- (void)addSample:(const LTKTraceGroup &)tg forNumeral:(AGHandwritingRecognizerFigure)num;

- (AGHandwritingRecognizerFigure)recognizeShape:(const LTKTrace &)trace;
- (void)addSample:(const LTKTraceGroup &)tg forShape:(AGHandwritingRecognizerFigure)num;

@end

#endif // __OBJC__
