//
//  AGTrainerView.m
//  Auraglyph
//
//  Created by Spencer Salazar on 12/3/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#import "AGTrainerView.h"

#include "LTKTypes.h"
#include "LTKTrace.h"
#include "LTKTraceGroup.h"


@interface AGTrainerView ()
{
    UIBezierPath *path;
    LTKTrace trace;
}


@end

@implementation AGTrainerView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    path = [UIBezierPath new];
}

- (void)drawRect:(CGRect)rect
{
    [[UIColor blackColor] setStroke];
    [path stroke];
}

- (void)clear
{
    [path removeAllPoints];
    trace = LTKTrace();
    
    [self setNeedsDisplay];
}

- (LTKTraceGroup)currentTraceGroup
{
    LTKTraceGroup traceGroup;
    traceGroup.addTrace(trace);
    
    return traceGroup;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    
    [path removeAllPoints];
    trace = LTKTrace();
    
    [path moveToPoint:p];
    
    vector<float> point;
    point.push_back(p.x);
    point.push_back(p.y);
    trace.addPoint(point);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    
    [path addLineToPoint:p];
    
    vector<float> point;
    point.push_back(p.x);
    point.push_back(p.y);
    trace.addPoint(point);
    
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}



@end

