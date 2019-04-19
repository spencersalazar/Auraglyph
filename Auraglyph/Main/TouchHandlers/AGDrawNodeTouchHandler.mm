//
//  AGDrawNodeTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGDrawNodeTouchHandler.h"

#import "AGDef.h"
#import "Geometry.h"

#import "AGViewController.h"
#import "AGNode.h"
#import "AGCompositeNode.h"
#import "AGHandwritingRecognizer.h"
#import "AGAnalytics.h"
#import "AGActivity.h"
#import "AGActivityManager.h"

#import "AGSelectNodeTouchHandler.h"

#import <set>


//------------------------------------------------------------------------------
// ### AGDrawNodeTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGDrawNodeTouchHandler

@interface AGDrawNodeTouchHandler ()
{
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
    AGUITrace *_trace;
    
    GLvertex2f _traceBottomLeft, _traceTopRight;
}

- (void)coalesceComposite:(AGAudioCompositeNode *)compositeNode withNodes:(const set<AGNode *> &)subnodes;

@end

@implementation AGDrawNodeTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _currentTrace = LTKTrace();
    _currentTraceSum = GLvertex3f();
    _traceBottomLeft = pos.xy();
    _traceTopRight = pos.xy();
    
    _trace = new AGUITrace;
    _trace->init();
    _trace->addPoint(pos);
    [_viewController addTopLevelObject:_trace];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _trace->addPoint(pos);
//    NSLog(@"trace: %f %f %f", pos.x, pos.y, pos.z);
    
    _currentTraceSum = _currentTraceSum + GLvertex3f(p.x, p.y, 0);
    
    if(pos.x < _traceBottomLeft.x) _traceBottomLeft.x = pos.x;
    if(pos.y < _traceBottomLeft.y) _traceBottomLeft.y = pos.y;
    if(pos.x > _traceTopRight.x) _traceTopRight.x = pos.x;
    if(pos.y > _traceTopRight.y) _traceTopRight.y = pos.y;
    
    floatVector point;
    point.push_back(p.x);
    point.push_back(p.y);
    _currentTrace.addPoint(point);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    /* analysis */
    
    GLvertex3f centroid = _currentTraceSum/_currentTrace.getNumberOfPoints();
    GLvertex3f centroidMVP = [_viewController worldCoordinateForScreenCoordinate:CGPointMake(centroid.x, centroid.y)];
    
#if AG_ENABLE_COMPOSITE
    float traceArea = area(_trace->points().data(), _trace->points().size());
    dbgprint("trace area: %f\n", traceArea);
    if(traceArea > 15000)
    {
        // treat as composite if nodes are inside
        
        // check if nodes are inside
        set<AGNode *> subnodes;
        for(AGNode *node : [_viewController nodes])
        {
            // first check square bounding box
            if(pointInRectangle(node->position().xy(), _traceBottomLeft, _traceTopRight) &&
               // check entire polygon
               pointInPolygon(node->position(), _trace->points().data(), _trace->points().size()))
            {
                subnodes.insert(node);
            }
        }
        
        if(subnodes.size())
        {
            // treat as composite
            AGNode *node = AGNodeManager::audioNodeManager().createNodeOfType("Composite", centroidMVP);
            AGAudioCompositeNode *compositeNode = static_cast<AGAudioCompositeNode *>(node);
            [self coalesceComposite:compositeNode withNodes:subnodes];
            [_viewController addNode:compositeNode];
            
            _trace->removeFromTopLevel();
            
            return;
        }
    }
#endif // AG_ENABLE_COMPOSITE
    
    AGHandwritingRecognizerFigure figure = AGHandwritingRecognizer::instance().recognizeShape(_currentTrace);
    AGActivityManager::instance().addActivity(AGActivity::drawNodeActivity(figure, centroidMVP));

    if(figure == AG_FIGURE_CIRCLE)
    {
        AGAnalytics::instance().eventDrawNodeCircle();
        
        {
            AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::audioNodeSelector(centroidMVP);
            _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
        }
    }
    else if(figure == AG_FIGURE_SQUARE)
    {
        AGAnalytics::instance().eventDrawNodeSquare();
        
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::controlNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
    }
    else if(figure == AG_FIGURE_TRIANGLE_DOWN)
    {
        AGAnalytics::instance().eventDrawNodeTriangleDown();
        
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::inputNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
    }
    else if(figure == AG_FIGURE_TRIANGLE_UP)
    {
        AGAnalytics::instance().eventDrawNodeTriangleUp();
        
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::outputNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
    }
    else
    {
        AGAnalytics::instance().eventDrawNodeUnrecognized();
    }
    
    _trace->removeFromTopLevel();
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _trace->removeFromTopLevel();
}

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

- (void)coalesceComposite:(AGAudioCompositeNode *)compositeNode withNodes:(const set<AGNode *> &)subnodes
{
    // save broken input/output connections
    list<tuple<AGNode *, int, AGNode *, int>> inbound;
    list<tuple<AGNode *, int, AGNode *, int>> outbound;
    
    for(AGNode *node : subnodes)
    {
        // trim connections
        const list<AGConnection *> &nodeInbound = node->inbound();
        const list<AGConnection *> &nodeOutbound = node->outbound();
        
        for(auto i = nodeInbound.begin(); i != nodeInbound.end(); )
        {
            auto j = i++;
            if(!subnodes.count((*j)->src()))
            {
                outbound.push_back(std::make_tuple((*j)->src(), (*j)->srcPort(), node, (*j)->dstPort()));
                (*j)->removeFromTopLevel();
            }
        }
        
        for(auto i = nodeOutbound.begin(); i != nodeOutbound.end(); )
        {
            auto j = i++;
            if(!subnodes.count((*j)->dst()))
            {
                outbound.push_back(std::make_tuple(node, (*j)->srcPort(), (*j)->dst(), (*j)->dstPort()));
                (*j)->removeFromTopLevel();
            }
        }
        
        [_viewController resignNode:node];
        
        compositeNode->addSubnode(node);
        
        if(node->type() == "Output")
        {
            AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
            outputNode->setOutputDestination(compositeNode);
        }
            
//        if(node->type() == "Input")
//            compositeNode->addInputNode(dynamic_cast<AGAudioCapturer *>(node));
    }
    
    // relink broken connections across composite boundary
    // TODO: multiple outbound connections
    if(outbound.size() && compositeNode->numOutputPorts() == 0)
    {
        AGNode *src = std::get<0>(outbound.front());
        int srcPort = std::get<1>(outbound.front());
        AGNode *dst = std::get<2>(outbound.front());
        int dstPort = std::get<3>(outbound.front());
        
        // create output within composite
        AGNode *internalNode = AGNodeManager::audioNodeManager().createNodeOfType("Output", dst->position());
        AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(internalNode);
        outputNode->setOutputDestination(compositeNode);
        
        // make connection within composite
        AGConnection *internalConnection = new AGConnection(src, srcPort, internalNode, 0);
        internalConnection->init();
        // make connection outside composite
        AGConnection *externalConnection = new AGConnection(compositeNode, 0, dst, dstPort);
        externalConnection->init();
    }
}

@end

