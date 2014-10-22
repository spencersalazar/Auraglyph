//
//  AGTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGTouchHandler.h"

#import "AGViewController.h"
#import "Geometry.h"
#import "ShaderHelper.h"
#import "hsv.h"
#import "ES2Render.h"
#import "AGHandwritingRecognizer.h"
#import "AGNode.h"
#import "AGAudioNode.h"
#import "AGAudioManager.h"
#import "AGUserInterface.h"
#import "TexFont.h"
#import "AGDef.h"
#import "AGTrainerViewController.h"
#import "AGGenericShader.h"
#import "GeoGenerator.h"


//------------------------------------------------------------------------------
// ### AGTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGTouchHandler

@implementation AGTouchHandler : UIResponder

- (id)initWithViewController:(AGViewController *)viewController
{
    if(self = [super init])
    {
        _viewController = viewController;
    }
    
    return self;
}

- (AGTouchHandler *)nextHandler { return _nextHandler; }

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

@end




//------------------------------------------------------------------------------
// ### AGMoveNodeTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGMoveNodeTouchHandler

@implementation AGMoveNodeTouchHandler

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node
{
    if(self = [super initWithViewController:viewController])
    {
        _moveNode = node;
    }
    
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _anchorOffset = pos - _moveNode->position();
    _moveNode->activate(1);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    float travel = _firstPoint.distanceSquaredTo(GLvertex2f(p.x, p.y));
    if(travel > _maxTouchTravel)
        _maxTouchTravel = travel;
    
    if(_maxTouchTravel >= 2*2) // TODO: #define constant for touch travel limit
    {
        _moveNode->setPosition(pos - _anchorOffset);
        _moveNode->activate(0);
    }
    
    AGUITrash &trash = AGUITrash::instance();
    if(trash.hitTest(pos))
    {
        trash.activate();
    }
    else
    {
        trash.deactivate();
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];

    AGUITrash &trash = AGUITrash::instance();
    trash.deactivate();
    
    if(_moveNode && _maxTouchTravel < 2*2)
    {
        _moveNode->activate(0);
        _nextHandler = [[AGEditTouchHandler alloc] initWithViewController:_viewController node:_moveNode];
    }
    else
    {
        if(trash.hitTest(pos))
        {
            _moveNode->fadeOutAndRemove();
        }
    }
}


@end


//------------------------------------------------------------------------------
// ### AGConnectTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGConnectTouchHandler


class AGProtoConnection : public AGInteractiveObject
{
public:
    AGProtoConnection(const GLvertex3f &srcPt, const GLvertex3f &dstPt)
    {
        m_renderInfo.shader = &AGGenericShader::instance();
        m_renderInfo.numVertex = 2;
        m_renderInfo.geoType = GL_LINES;
        m_renderInfo.geo = m_points;
        m_renderInfo.color = GLcolor4f::white;
        
        sourcePoint() = srcPt;
        destPoint() = dstPt;
        
        m_renderList.push_back(&m_renderInfo);
    }
    
    void setActivation(int activation) // 0: neutral, 1: positive, -1: negative
    {
        if(activation > 0) m_renderInfo.color = GLcolor4f::green;
        else if(activation < 0) m_renderInfo.color = GLcolor4f::red;
        else m_renderInfo.color = GLcolor4f::white;
    }
    
    const GLvertex3f &sourcePoint() const { return m_points[0]; }
    const GLvertex3f &destPoint() const { return m_points[1]; }
    
    GLvertex3f &sourcePoint() { return m_points[0]; }
    GLvertex3f &destPoint() { return m_points[1]; }
    
private:
    GLvertex3f m_points[2];
    AGRenderInfoV m_renderInfo;
};

class AGPortBrowser : public AGInteractiveObject
{
public:
    AGPortBrowser(AGNode *node) : m_node(node), m_geoSize(64)
    {
        GeoGen::makeCircle(m_geo, m_geoSize, 0.01);
    }
    
private:
    AGNode * const m_node;
    int m_geoSize;
    GLvertex3f m_geo[64];
};


@interface AGConnectTouchHandler ()
{
    AGNode * _connectInput;
    AGNode * _connectOutput;
    AGNode * _originalHit;
    AGNode * _currentHit;
    
    int srcPort;
    int dstPort;
    
    AGProtoConnection *_proto;
}

@end


@implementation AGConnectTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController clearLinePoints];
    //[_viewController addLinePoint:pos];
    
    _proto = new AGProtoConnection(pos, pos);
    [_viewController addTopLevelObject:_proto];
    
    AGNode *hitNode;
    int port;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode port:&port];
    
    if(hit == AGNode::HIT_INPUT_NODE)
    {
        dstPort = port;
        _connectInput = hitNode;
        _connectInput->activateInputPort(1+dstPort);
    }
    else
    {
        srcPort = port;
        _connectOutput = hitNode;
        _connectOutput->activateOutputPort(1+srcPort);
    }
    
    _originalHit = hitNode;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    //[_viewController addLinePoint:pos];
    _proto->destPoint() = pos;
    
    AGNode *hitNode;
    int port;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode port:&port];
    
    if(hit == AGNode::HIT_INPUT_NODE)
    {
        if(hitNode != _originalHit && (hitNode != _currentHit || hitNode != _connectInput))
        {
            // deactivate previous hit if needed
            if(_currentHit)
            {
                _currentHit->activateInputPort(0);
                _currentHit->activateOutputPort(0);
            }
            
            if(_connectInput)
            {
                // input node -> input node: invalid
                hitNode->activateInputPort(-1-port);
                _proto->setActivation(-1);
            }
            else
            {
                // output node -> input node: valid
                dstPort = port;
                hitNode->activateInputPort(1+dstPort);
                _proto->setActivation(1);
            }
            
            _currentHit = hitNode;
        }
    }
    else if(hit == AGNode::HIT_OUTPUT_NODE)
    {
        if(hitNode != _originalHit && (hitNode != _currentHit || hitNode != _connectInput))
        {
            // deactivate previous hit if needed
            if(_currentHit)
            {
                _currentHit->activateInputPort(0);
                _currentHit->activateOutputPort(0);
            }
            
            if(_connectOutput)
            {
                // output node -> output node: invalid
                hitNode->activateOutputPort(-1-port);
                _proto->setActivation(-1);
            }
            else
            {
                // input node -> output node: valid
                srcPort = port;
                hitNode->activateOutputPort(1+srcPort);
                _proto->setActivation(1);
            }
            
            _currentHit = hitNode;
        }
    }
    else
    {
        if(_currentHit)
        {
            _currentHit->activateInputPort(0);
            _currentHit->activateOutputPort(0);
        }
        
        _proto->setActivation(0);
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController removeTopLevelObject:_proto];
    _proto = NULL;
    
    AGNode *hitNode;
    int port;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode port:&port];
    
    if(hit == AGNode::HIT_INPUT_NODE)
    {
        if(_connectOutput != NULL && hitNode != _connectOutput)
        {
            dstPort = port;
            AGConnection * connection = new AGConnection(_connectOutput, hitNode, dstPort);
            
            [_viewController addConnection:connection];
            [_viewController clearLinePoints];
        }
    }
    else if(hit == AGNode::HIT_OUTPUT_NODE)
    {
        if(_connectInput != NULL && hitNode != _connectInput)
        {
            srcPort = port;
            AGConnection * connection = new AGConnection(hitNode, _connectInput, dstPort);
            
            [_viewController addConnection:connection];
            [_viewController clearLinePoints];
        }
    }
    
    if(_currentHit)
    {
        _currentHit->activateInputPort(0);
        _currentHit->activateOutputPort(0);
    }
    
    if(_connectInput) _connectInput->activateInputPort(0);
    if(_connectOutput) _connectOutput->activateOutputPort(0);
    _connectInput = _connectOutput = _currentHit = NULL;
}

@end


//------------------------------------------------------------------------------
// ### AGSelectNodeTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGSelectNodeTouchHandler

@implementation AGSelectNodeTouchHandler

- (id)initWithViewController:(AGViewController *)viewController position:(GLvertex3f)pos
{
    if(self = [super initWithViewController:viewController])
    {
        _nodeSelector = new AGUINodeSelector(pos);
    }
    
    return self;
}

- (void)dealloc
{
    SAFE_DELETE(_nodeSelector);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    _nextHandler = nil;
    
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeSelector->touchDown(pos);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeSelector->touchMove(pos);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeSelector->touchUp(pos);
    
    AGNode * newNode = _nodeSelector->createNode();
    if(newNode)
        [_viewController addNode:newNode];
    
    if(!_nodeSelector->done())
        _nextHandler = self;
}

- (void)update:(float)t dt:(float)dt
{
    _nodeSelector->update(t, dt);
}

- (void)render
{
    _nodeSelector->render();
}

@end


//------------------------------------------------------------------------------
// ### AGEditTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGEditTouchHandler

@implementation AGEditTouchHandler


- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node
{
    if(self = [super initWithViewController:viewController])
    {
        _nodeEditor = new AGUINodeEditor(node);
    }
    
    return self;
}

- (void)dealloc
{
    SAFE_DELETE(_nodeEditor);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeEditor->touchDown(pos, p);
    
    [_viewController clearLinePoints];
    
    if(_nodeEditor->shouldRenderDrawline())
        [_viewController addLinePoint:pos];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeEditor->touchMove(pos, p);
    
    if(_nodeEditor->shouldRenderDrawline())
        [_viewController addLinePoint:pos];
    else
        [_viewController clearLinePoints];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _nodeEditor->touchUp(pos, p);
    
    if(_nodeEditor->shouldRenderDrawline())
        [_viewController addLinePoint:pos];
    else
        [_viewController clearLinePoints];
    
    if(_nodeEditor->doneEditing())
        _nextHandler = nil;
    else
        _nextHandler = self;
}

- (void)update:(float)t dt:(float)dt
{
    _nodeEditor->update(t, dt);
}

- (void)render
{
    _nodeEditor->render();
}

@end

