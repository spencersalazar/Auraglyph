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
#import "spMath.h"


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
        
        float radius = 0.00275;
        float margin = 0.001;
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
        float radius = 0.00275;
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
        float radius = 0.0125f;
        
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
        float portRadius = radius * 0.62;
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
        float radius = 0.0125f;
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
            float radius = 0.0125f * 0.1f;
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
    
    if(hitNode != _currentHit && hitNode != _originalHit)
    {
        if(_browser)
            [_viewController removeTopLevelObject:_browser];
        if(hitNode)
        {
            _browser = new AGPortBrowser(hitNode);
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

