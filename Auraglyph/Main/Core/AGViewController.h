//
//  AGViewController.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#endif // __OBJC__

#include <CoreGraphics/CoreGraphics.h>
#include "Geometry.h"
#include "AGNode.h"
#include <list>

class AGConnection;
class AGFreeDraw;
class AGInteractiveObject;
class AGGraph;
class AGTutorial;
#ifdef __OBJC__
@class AGTouchHandler;
#endif // __OBJC__


enum AGDrawMode
{
    DRAWMODE_NODE,
    DRAWMODE_FREEDRAW,
    DRAWMODE_FREEDRAW_ERASE
};

#ifdef __OBJC__

@interface AGViewController : GLKViewController

+ (id)instance;

- (void)addNode:(AGNode *)node;
- (void)removeNode:(AGNode *)node;
- (void)resignNode:(AGNode *)node;
- (AGGraph *)graph;

- (void)addTopLevelObject:(AGInteractiveObject *)object;
- (void)addTopLevelObject:(AGInteractiveObject *)object over:(AGInteractiveObject *)over;
- (void)addTopLevelObject:(AGInteractiveObject *)object under:(AGInteractiveObject *)under;
- (void)fadeOutAndDelete:(AGInteractiveObject *)object;

- (void)addFreeDraw:(AGFreeDraw *)freedraw;
//- (void)replaceFreeDraw:(AGFreeDraw *)freedrawOld freedrawNew:(AGFreeDraw *)freedrawNew;
- (void)resignFreeDraw:(AGFreeDraw *)freedraw;
- (void)removeFreeDraw:(AGFreeDraw *)freedraw;
- (const list<AGFreeDraw *> &)freedraws;

- (void)addTouchOutsideListener:(AGInteractiveObject *)listener;
- (void)addTouchOutsideHandler:(AGTouchHandler *)listener;
- (void)removeTouchOutsideListener:(AGInteractiveObject *)listener;
- (void)removeTouchOutsideHandler:(AGTouchHandler *)listener;

- (void)resignTouchHandler:(AGTouchHandler *)handler;

- (GLKMatrix4)modelViewMatrix;
- (GLKMatrix4)fixedModelViewMatrix;
- (GLKMatrix4)projectionMatrix;
- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p;
- (GLvertex3f)fixedCoordinateForScreenCoordinate:(CGPoint)p;
- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)node port:(int *)port;

- (void) showDashboard;
- (void) hideDashboard;

- (void)showTutorial:(AGTutorial *)tutorial;

+ (NSString *)styleFontPath;

@end

#else

typedef void AGViewController;

#endif // __OBJC__

// bridge for C++-only code
class AGViewController_
{
public:
    AGViewController_(AGViewController *viewController);
    ~AGViewController_();
    
    void createNew();
    void save();
    void saveAs();
    void load();
    void loadExample();

    void showTrainer();
    void showAbout();
    
    void startRecording();
    void stopRecording();
    
    void setDrawMode(AGDrawMode mode);
    
    GLvertex3f worldCoordinateForScreenCoordinate(CGPoint p);
    GLvertex3f fixedCoordinateForScreenCoordinate(CGPoint p);
    
    CGRect bounds();
    
    void addTopLevelObject(AGInteractiveObject *object);
    void fadeOutAndDelete(AGInteractiveObject *object);

    void addNodeToTopLevel(AGNode *node);
    AGGraph *graph();
    
    void showDashboard();
    void hideDashboard();
    
    void showTutorial(AGTutorial *tutorial);

private:
    AGViewController *m_viewController = nil;
};

