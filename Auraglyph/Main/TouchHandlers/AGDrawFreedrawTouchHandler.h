//
//  AGTouchHandler.h
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AGTouchHandler.h"
#import "Geometry.h"
#import "AGHandwritingRecognizer.h"


@interface AGDrawFreedrawTouchHandler : AGTouchHandler
{
    vector<GLvertex3f> _linePoints;
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
}

@end
