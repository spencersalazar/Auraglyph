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
#import "AGNode.h"
#import "AGUserInterface.h"
#import "AGNodeSelector.h"

@interface AGMoveNodeTouchHandler : AGTouchHandler
{
    GLvertex3f _initialPos;
    GLvertex3f _anchorOffset;
    AGNode * _moveNode;
    
    GLvertex2f _firstPoint;
    float _maxTouchTravel;
}

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node;

@end


