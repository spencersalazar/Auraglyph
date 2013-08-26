//
//  AGViewController.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "Geometry.h"

class AGNode;
class AGConnection;

@interface AGViewController : GLKViewController

- (void)addNode:(AGNode *)node;
- (void)addConnection:(AGConnection *)connection;

- (void)addLinePoint:(GLvertex3f)point;
- (void)clearLinePoints;

- (GLKMatrix4)modelViewMatrix;
- (GLKMatrix4)projectionMatrix;

@end
