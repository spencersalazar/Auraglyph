//
//  AGTouchHandler.h
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AGTouchHandler.h"
#import "AGViewController.h"
#import "AGNode.h"

@interface AGEditTouchHandler : AGTouchHandler

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node;

@end

