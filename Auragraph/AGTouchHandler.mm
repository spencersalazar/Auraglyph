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
#import "AGCompositeNode.h"
#import "AGAudioCapturer.h"
#import "AGAudioManager.h"
#import "AGUserInterface.h"
#import "TexFont.h"
#import "AGDef.h"
#import "AGTrainerViewController.h"
#import "AGNodeSelector.h"
#import "AGUINodeEditor.h"
#import "AGGenericShader.h"

#import "GeoGenerator.h"
#import "spMath.h"

#include "AGStyle.h"

#import <set>


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
// ### AGDrawNodeTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGDrawNodeTouchHandler

@interface AGDrawNodeTouchHandler ()
{
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
    AGUITrace *_trace;
}

- (void)coalesceComposite:(AGAudioCompositeNode *)node;

@end

@implementation AGDrawNodeTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _currentTrace = LTKTrace();
    _currentTraceSum = GLvertex3f();
    
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
    
    floatVector point;
    point.push_back(p.x);
    point.push_back(p.y);
    _currentTrace.addPoint(point);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    /* analysis */
    
    AGHandwritingRecognizerFigure figure = [[AGHandwritingRecognizer instance] recognizeShape:_currentTrace];
    
    GLvertex3f centroid = _currentTraceSum/_currentTrace.getNumberOfPoints();
    GLvertex3f centroidMVP = [_viewController worldCoordinateForScreenCoordinate:CGPointMake(centroid.x, centroid.y)];
    
    BOOL animateOut = NO;
    
    if(figure == AG_FIGURE_CIRCLE)
    {
        // first check average polar length
        float sumPolarLength = 0;
        // compute centroid
        for(GLvertex3f point : _trace->points())
        {
            float dx = point.x-centroidMVP.x, dy = point.y-centroidMVP.y;
            sumPolarLength += sqrtf(dx*dx+dy*dy);
        }
        
        float avgPolarLength = sumPolarLength/_currentTrace.getNumberOfPoints();
        dbgprint("avgPolarLength: %f\n", avgPolarLength);
        
        if(avgPolarLength > 180.0f)
        {
            // treat as composite
            AGAudioCompositeNode *compositeNode = static_cast<AGAudioCompositeNode *>(AGNodeManager::audioNodeManager().createNodeOfType("Composite", centroidMVP));
            [self coalesceComposite:compositeNode];
            [_viewController addNode:compositeNode];
        }
        else
        {
            AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::audioNodeSelector(centroidMVP);
            _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
        }
    }
    else if(figure == AG_FIGURE_SQUARE)
    {
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::controlNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
    }
    else if(figure == AG_FIGURE_TRIANGLE_DOWN)
    {
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::inputNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
    }
    else if(figure == AG_FIGURE_TRIANGLE_UP)
    {
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::outputNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
    }
    else
    {
        animateOut = YES;
    }
    
    _trace->removeFromTopLevel();
}

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

- (void)coalesceComposite:(AGAudioCompositeNode *)compositeNode
{
    float sumPolarLength = 0;
    // compute centroid
    GLvertex3f centroid = _currentTraceSum/_currentTrace.getNumberOfPoints();
    centroid = [_viewController worldCoordinateForScreenCoordinate:CGPointMake(centroid.x, centroid.y)];
    for(GLvertex3f point : _trace->points())
    {
        float dx = point.x-centroid.x, dy = point.y-centroid.y;
        sumPolarLength += sqrtf(dx*dx+dy*dy);
    }
    
    float avgPolarLength = sumPolarLength/_currentTrace.getNumberOfPoints();
    
    set<AGNode *> subnodes;
    
    // collect all nodes within avg polar length
    for(AGNode *node : [_viewController nodes])
    {
        float dist = (compositeNode->position()-node->position()).magnitude();
        if(dist < avgPolarLength)
            subnodes.insert(node);
    }
    
    for(AGNode *node : subnodes)
    {
        node->trimConnectionsToNodes(subnodes);
        [_viewController resignNode:node];
        
        if(node->type() == "Output")
        {
            AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
            outputNode->setOutputDestination(compositeNode);
        }
            
//        if(node->type() == "Input")
//            compositeNode->addInputNode(dynamic_cast<AGAudioCapturer *>(node));
    }
}

@end



//------------------------------------------------------------------------------
// ### AGDrawFreedrawTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGDrawFreedrawTouchHandler

@implementation AGDrawFreedrawTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _currentTrace = LTKTrace();
    _linePoints.push_back(pos);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _linePoints.push_back(pos);
    
    floatVector point;
    point.push_back(p.x);
    point.push_back(p.y);
    _currentTrace.addPoint(point);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_linePoints.size() > 1)
    {
        AGFreeDraw *freeDraw = new AGFreeDraw(&_linePoints[0], _linePoints.size());
        freeDraw->init();
        [_viewController addFreeDraw:freeDraw];
    }
}

- (void)update:(float)t dt:(float)dt { }

- (void)render
{
    if(_linePoints.size() > 1)
    {
        GLKMatrix4 proj = AGNode::projectionMatrix();
        GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
        
        AGGenericShader &shader = AGGenericShader::instance();
        shader.useProgram();
        shader.setProjectionMatrix(proj);
        shader.setModelViewMatrix(modelView);
        shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, &_linePoints[0]);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &GLcolor4f::white);
        
        glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
        glDisableVertexAttribArray(GLKVertexAttribTexCoord1);
        glDisable(GL_TEXTURE_2D);
        
        glDrawArrays(GL_LINE_STRIP, 0, _linePoints.size());
    }
}

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

#define AGPortBrowserPort_TextScale (0.62)

class AGPortBrowserPort : public AGInteractiveObject
{
public:
    
    enum TextPosition
    {
        TEXTPOSITION_TOP,
        TEXTPOSITION_BOTTOM,
        TEXTPOSITION_LEFT,
        TEXTPOSITION_RIGHT
    };
    
    AGPortBrowserPort(AGNode *node, int portNum, const GLvertex3f &position, TextPosition textPosition) :
    m_node(node), m_portNum(portNum), m_portInfo(m_node->inputPortInfo(portNum)),
    m_position(position), m_textPosition(textPosition), m_activate(false),
    m_alpha(0.2, 0), m_posLerp(0.2, 0), m_textAlpha(0.4, -1), m_textPosLerp(0.4, 0)
    {
        if(s_texFont == NULL)
        {
            const char *fontPath = [[AGViewController styleFontPath] UTF8String];
            s_texFont = new TexFont(fontPath, 32);
        }
        
        m_portRenderInfo.shader = &AGGenericShader::instance();
        m_portRenderInfo.geo = &(GeoGen::circle64())[1];
        m_portRenderInfo.geoType = GL_LINE_LOOP;
        m_portRenderInfo.numVertex = 64-1;
        m_portRenderInfo.color = GLcolor4f::white;
        m_renderList.push_back(&m_portRenderInfo);
        
        m_textColor = GLcolor4f::white;
        
        float textScale = AGPortBrowserPort_TextScale;
        float textWidth = s_texFont->width(m_portInfo.name)*textScale;
        float textHeight = s_texFont->height()*textScale;
        m_textOriginOffset = GLvertex3f(-textWidth/2.0, -textHeight/2, 0);
        
        float radius = 0.00275*AGStyle::oldGlobalScale;
        float margin = 0.001*AGStyle::oldGlobalScale;
        switch(m_textPosition)
        {
            case TEXTPOSITION_LEFT:
                m_textOffset = GLvertex3f(-radius-margin-textWidth, -textHeight/2, 0);
                break;
            case TEXTPOSITION_RIGHT:
                m_textOffset = GLvertex3f(radius+margin, -textHeight/2, 0);
                break;
            case TEXTPOSITION_TOP:
                m_textOffset = GLvertex3f(-textWidth/2, radius+margin, 0);
                break;
            case TEXTPOSITION_BOTTOM:
                m_textOffset = GLvertex3f(-textWidth/2, -radius-margin-textHeight, 0);
                break;
        }
        
        m_alpha = 1;
        m_posLerp = 1;
        m_textAlpha = 1;
        m_textPosLerp = 1;
    }
    
    virtual void update(float t, float dt)
    {
        AGRenderObject::update(t, dt);
        
        GLKMatrix4 baseModelView = m_renderState.modelview;
        
        m_alpha.interp();
        m_textAlpha.interp();
        m_posLerp.interp();
        m_textPosLerp.interp();
        
        if(m_activate) m_portRenderInfo.color = m_textColor = GLcolor4f::green;
        else m_portRenderInfo.color = m_textColor = GLcolor4f::white;
        m_portRenderInfo.color.a = m_alpha;
        m_textColor.a = m_textAlpha;
        
        GLvertex3f position = lerp(m_posLerp, m_node->position(), m_position);
        m_renderState.modelview = GLKMatrix4Multiply(baseModelView, GLKMatrix4MakeTranslation(position.x, position.y, position.z));
        float radius = 0.00275*AGStyle::oldGlobalScale;
        m_renderState.modelview = GLKMatrix4Multiply(m_renderState.modelview, GLKMatrix4MakeScale(radius, radius, radius));
        
        GLvertex3f textPosition = lerp(m_textPosLerp, position+m_textOriginOffset, position+m_textOffset);
        m_textMV = GLKMatrix4Multiply(baseModelView, GLKMatrix4MakeTranslation(textPosition.x, textPosition.y, textPosition.z));
        float textScale = AGPortBrowserPort_TextScale;
        m_textMV = GLKMatrix4Multiply(m_textMV, GLKMatrix4MakeScale(textScale, textScale, textScale));
    }
    
    virtual void render()
    {
        glLineWidth(2.0f);
        
        AGRenderObject::render();
        
        s_texFont->render(m_portInfo.name, m_textColor, m_textMV, m_renderState.projection);
    }
    
    virtual void renderOut()
    {
        m_alpha = 0;
        m_textAlpha = 0;
        m_posLerp = 0;
        m_textPosLerp = 0;
    }
    
    virtual bool finishedRenderingOut()
    {
        return m_alpha < 0.1;
    }
    
    void activate(bool activate)
    {
        m_activate = activate;
    }
    
private:
    static TexFont *s_texFont;
    
    AGNode * const m_node;
    const AGPortInfo &m_portInfo;
    const int m_portNum;
    const GLvertex3f m_position;
    
    bool m_activate;
    
    const TextPosition m_textPosition;
    GLvertex3f m_textOffset;
    GLvertex3f m_textOriginOffset;
    GLKMatrix4 m_textMV;
    GLcolor4f m_textColor;
    
    AGRenderInfoV m_portRenderInfo;
    
    slewf m_alpha;
    slewf m_posLerp;
    slewf m_textAlpha;
    slewf m_textPosLerp;
};

TexFont *AGPortBrowserPort::s_texFont = NULL;

class AGPortBrowser : public AGInteractiveObject
{
public:
    AGPortBrowser(AGNode *node) : m_node(node), m_scale(0.2), m_alpha(0.1, 1),
    m_selectedPort(-1)
    {
        float radius = 0.0125f*AGStyle::oldGlobalScale;
        
        m_strokeInfo.shader = &AGGenericShader::instance();
        m_strokeInfo.geo = &(GeoGen::circle64())[1];
        m_strokeInfo.geoType = GL_LINE_LOOP;
        m_strokeInfo.numVertex = 64-1;
        m_strokeInfo.color = GLcolor4f::white;
        
        m_fillInfo.shader = &AGGenericShader::instance();
        m_fillInfo.geo = GeoGen::circle64();
        m_fillInfo.geoType = GL_TRIANGLE_FAN;
        m_fillInfo.numVertex = 64;
        m_fillInfo.color = GLcolor4f::black;
        
        m_renderList.push_back(&m_fillInfo);
        m_renderList.push_back(&m_strokeInfo);
        
        m_scale = 1;
        m_alpha = 1;
        
        int numPorts = node->numInputPorts();
        m_ports.reserve(numPorts);
        float angle = 3.0f*M_PI/4.0f;
        float portRadius = radius*0.62;
        for(int i = 0; i < numPorts; i++)
        {
            float _cos = cosf(angle);
            float _sin = sinf(angle);
            
            AGPortBrowserPort::TextPosition textPos;
            if(fabsf(_cos) >= fabsf(_sin))
            {
                if(_cos < 0) textPos = AGPortBrowserPort::TEXTPOSITION_LEFT;
                else textPos = AGPortBrowserPort::TEXTPOSITION_RIGHT;
            }
            else
            {
                if(_sin > 0) textPos = AGPortBrowserPort::TEXTPOSITION_TOP;
                else textPos = AGPortBrowserPort::TEXTPOSITION_BOTTOM;
            }
            
            GLvertex3f pos = m_node->position() + GLvertex3f(portRadius*_cos, portRadius*_sin, 0);
            AGPortBrowserPort *port = new AGPortBrowserPort(m_node, i, pos, textPos);
            port->init();
            addChild(port);
            m_ports.push_back(port);
            
            angle -= M_PI*2.0f/((float)numPorts);
        }
    }
    
    virtual void update(float t, float dt)
    {
        AGRenderObject::update(t, dt);
        
        m_scale.interp();
        m_alpha.interp();
        
        m_fillInfo.color.a = 0.62*m_alpha;
        m_strokeInfo.color.a = 0.9*m_alpha;
        
        m_renderState.modelview = GLKMatrix4Multiply(m_renderState.modelview, GLKMatrix4MakeTranslation(m_node->position().x, m_node->position().y, m_node->position().z));
        m_renderState.modelview = GLKMatrix4Multiply(m_renderState.modelview, GLKMatrix4MakeScale(m_scale, m_scale, m_scale));
        float radius = 0.0125f*AGStyle::oldGlobalScale;
        m_renderState.modelview = GLKMatrix4Multiply(m_renderState.modelview, GLKMatrix4MakeScale(radius, radius, radius));
    }
    
    virtual void render()
    {
        glLineWidth(2.0f);
        
        AGRenderObject::render();
    }
    
    virtual void renderOut()
    {
        AGRenderObject::renderOut();
        
        m_scale = 0;
        m_alpha = 0;
    }
    
    virtual bool finishedRenderingOut()
    {
        return m_scale < 0.01;
    }
    
    int selectedPort(const GLvertex3f &t)
    {
        // location relative to this object's center point
        GLvertex3f relativeLocation = t - m_node->position();
        
        int numPorts = m_node->numInputPorts();
        // no dead-zone for single-port objects
        if(numPorts > 1)
        {
            // squared-distance from center
            float rho_sq = relativeLocation.magnitudeSquared();
            // central dead-zone
            float radius = 0.0125f*0.1f*AGStyle::oldGlobalScale;
            // too close to dead-zone!
            if(rho_sq < radius*radius)
                return -1;
        }
        
        // angle around that center point
        float theta = atan2f(relativeLocation.y, relativeLocation.x);
        // angle-width of each port's hit area
        float width = (M_PI*2)/m_node->numInputPorts();
        // starting rotation (from 0) of first port
        float rot = 3.0f*M_PI/4.0f;
        // angle of touch, mapped to [0, 2pi) => [port0, ..., portN-1]
        theta = normAngle(-(theta-rot-width/2.0f));
        // calculate bin => port number
        return (int) floorf(theta/(M_PI*2.0f)*m_node->numInputPorts());
    }
    
    int selectedPort() { return m_selectedPort; }
    
    virtual void touchMove(const GLvertex3f &t)
    {
        int p = selectedPort(t);
        
        if(p != m_selectedPort && m_selectedPort >= 0)
            m_ports[m_selectedPort]->activate(false);
        
        if(p >= 0)
            m_ports[p]->activate(true);
        
        m_selectedPort = p;
    }
    
private:
    AGNode * const m_node;
    AGRenderInfoV m_strokeInfo, m_fillInfo;
    slewf m_scale;
    slewf m_alpha;
    
    int m_selectedPort;
    
    vector<AGPortBrowserPort *> m_ports;
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
    AGPortBrowser *_browser;
}

@end


@implementation AGConnectTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _proto = new AGProtoConnection(pos, pos);
    _proto->init();
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
    
    _proto->destPoint() = pos;
    
    AGNode *hitNode;
    int port;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode port:&port];
    
    if(hitNode != _currentHit && hitNode != _originalHit)
    {
        if(_browser)
            [_viewController removeTopLevelObject:_browser];
        if(hitNode)
        {
            _browser = new AGPortBrowser(hitNode);
            _browser->init();
            [_viewController addTopLevelObject:_browser under:_proto];
        }
        else
            _browser = NULL;
        
        _currentHit = hitNode;
    }
    else if(hitNode == NULL)
    {
        if(_browser)
        {
            [_viewController removeTopLevelObject:_browser];
            _browser = NULL;
        }
        
        _currentHit = hitNode;
    }
    
    if(_browser)
    {
        _browser->touchMove(pos);
        if(_browser->selectedPort() >= 0)
            _proto->setActivation(1);
        else
            _proto->setActivation(0);
    }
    else
    {
        _proto->setActivation(0);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController removeTopLevelObject:_proto];
    _proto = NULL;
    
    if(_browser)
    {
        int port = _browser->selectedPort();
        if(port != -1)
        {
            AGConnection * connection = new AGConnection(_originalHit, _currentHit, port);
            connection->init();
            
            [_viewController addConnection:connection];
        }
    }
    
    if(_connectInput) _connectInput->activateInputPort(0);
    if(_connectOutput) _connectOutput->activateOutputPort(0);
    _connectInput = _connectOutput = _currentHit = NULL;
    
    if(_browser)
    {
        [_viewController removeTopLevelObject:_browser];
        _browser = NULL;
    }
}

@end


//------------------------------------------------------------------------------
// ### AGSelectNodeTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGSelectNodeTouchHandler

@implementation AGSelectNodeTouchHandler

- (id)initWithViewController:(AGViewController *)viewController nodeSelector:(AGUIMetaNodeSelector *)selector;
{
    if(self = [super initWithViewController:viewController])
    {
        _nodeSelector = selector;
        [_viewController addTopLevelObject:_nodeSelector];
    }
    
    return self;
}

- (void)dealloc
{
//    SAFE_DELETE(_nodeSelector);
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
    {
        [_viewController addNode:newNode];
        
        if(newNode->type() == "Output")
        {
            AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(newNode);
            outputNode->setOutputDestination([AGAudioManager instance].masterOut);
        }
    }
    
    if(!_nodeSelector->done())
        _nextHandler = self;
    else
        [_viewController removeTopLevelObject:_nodeSelector];
}

//- (void)update:(float)t dt:(float)dt
//{
//    _nodeSelector->update(t, dt);
//}
//
//- (void)render
//{
//    _nodeSelector->render();
//}

@end


//------------------------------------------------------------------------------
// ### AGEditTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGEditTouchHandler

@interface AGEditTouchHandler ()
{
    AGUINodeEditor * _nodeEditor;
    AGInteractiveObject *_touchCapture;
    BOOL _done;
}
@end

@implementation AGEditTouchHandler


- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node
{
    if(self = [super initWithViewController:viewController])
    {
        _done = NO;
        _touchCapture = NULL;
        _nodeEditor = node->createCustomEditor();
        if(_nodeEditor == NULL)
        {
            _nodeEditor = new AGUIStandardNodeEditor(node);
            _nodeEditor->init();
        }
    }
    
    return self;
}

- (void)dealloc
{
//    SAFE_DELETE(_nodeEditor);
    // _nodeEditor will be automatically deallocated after it fades out
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_done) return;
    
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _touchCapture = _nodeEditor->hitTest(pos);
    
    if(_touchCapture)
    {
        _touchCapture->touchDown(AGTouchInfo(pos, p, (TouchID) [touches anyObject]));
    }
    else
    {
        // add object
        [_viewController addTopLevelObject:_nodeEditor];
        // immediately remove (cause to fade out/collapse and then deallocate)
        [_viewController removeTopLevelObject:_nodeEditor];
        _nodeEditor = NULL;
        
        _done = YES;
        _nextHandler = nil;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_done) return;
    
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _touchCapture->touchMove(AGTouchInfo(pos, p, (TouchID) [touches anyObject]));
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_done) return;
    
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _touchCapture->touchUp(AGTouchInfo(pos, p, (TouchID) [touches anyObject]));
    
    _done = _nodeEditor->doneEditing();
    
    if(_done)
    {
        // add object
        [_viewController addTopLevelObject:_nodeEditor];
        // immediately remove (cause to fade out/collapse and then deallocate)
        [_viewController removeTopLevelObject:_nodeEditor];
        _nodeEditor = NULL;

        _nextHandler = nil;
    }
    else
        _nextHandler = self;
}

- (void)update:(float)t dt:(float)dt
{
    if(_nodeEditor) _nodeEditor->update(t, dt);
}

- (void)render
{
    if(_nodeEditor) _nodeEditor->render();
}

@end

