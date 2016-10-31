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
#import "AGNode.h"
#import <list>

class AGConnection;
class AGFreeDraw;
class AGInteractiveObject;


@interface AGViewController : GLKViewController

+ (id)instance;

- (void)addNode:(AGNode *)node;
- (void)removeNode:(AGNode *)node;
- (void)resignNode:(AGNode *)node;
- (const list<AGNode *> &)nodes;

- (void)addTopLevelObject:(AGInteractiveObject *)object;
- (void)addTopLevelObject:(AGInteractiveObject *)object over:(AGInteractiveObject *)over;
- (void)addTopLevelObject:(AGInteractiveObject *)object under:(AGInteractiveObject *)under;
- (void)fadeOutAndDelete:(AGInteractiveObject *)object;

- (void)addFreeDraw:(AGFreeDraw *)freedraw;
- (void)removeFreeDraw:(AGFreeDraw *)freedraw;

- (void)addTouchOutsideListener:(AGInteractiveObject *)listener;
- (void)removeTouchOutsideListener:(AGInteractiveObject *)listener;

- (GLKMatrix4)modelViewMatrix;
- (GLKMatrix4)fixedModelViewMatrix;
- (GLKMatrix4)projectionMatrix;
- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p;
- (GLvertex3f)fixedCoordinateForScreenCoordinate:(CGPoint)p;
- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)node port:(int *)port;

+ (NSString *)styleFontPath;

@end
