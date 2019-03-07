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


@interface AGSelectNodeTouchHandler : AGTouchHandler
{
    AGUIMetaNodeSelector * _nodeSelector;
}

- (id)initWithViewController:(AGViewController *)viewController nodeSelector:(AGUIMetaNodeSelector *)selector;

@end
