//
//  AGTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGConnectTouchHandler.h"

#import "AGDef.h"

#import "Geometry.h"
#import "TexFont.h"
#import "GeoGenerator.h"
#import "spMath.h"

#include "AGStyle.h"
#import "AGViewController.h"
#import "AGNode.h"
#import "AGGenericShader.h"
#import "AGActivityManager.h"
#import "AGActivity.h"
#import "AGAnalytics.h"


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
        m_renderInfo.color = AGStyle::foregroundColor();
        
        sourcePoint() = srcPt;
        destPoint() = dstPt;
        
        m_renderList.push_back(&m_renderInfo);
    }
    
    void setActivation(int activation) // 0: neutral, 1: positive, -1: negative
    {
        if(activation > 0) m_renderInfo.color = AGStyle::proceedColor();
        else if(activation < 0) m_renderInfo.color = AGStyle::errorColor();
        else m_renderInfo.color = AGStyle::foregroundColor();
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
    
    AGPortBrowserPort(AGNode *node, const AGPortInfo &portInfo, const GLvertex3f &position, TextPosition textPosition) :
    m_node(node), m_portInfo(portInfo),
    m_textPosition(textPosition), m_activate(false), m_alpha(0.2, 0),
    m_posLerp(0.2, 0), m_textAlpha(0.4, -1), m_textPosLerp(0.4, 0)
    {
        setPosition(position);
        
        if(s_texFont == NULL)
        {
            const char *fontPath = [[AGViewController styleFontPath] UTF8String];
            s_texFont = new TexFont(fontPath, 32);
        }
        
        m_portRenderInfo.shader = &AGGenericShader::instance();
        m_portRenderInfo.geo = &(GeoGen::circle64())[1];
        m_portRenderInfo.geoType = GL_LINE_LOOP;
        m_portRenderInfo.numVertex = 64-1;
        m_portRenderInfo.color = AGStyle::foregroundColor();
        m_renderList.push_back(&m_portRenderInfo);
        
        m_textColor = AGStyle::foregroundColor();
        
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
        
        if(m_activate) m_portRenderInfo.color = m_textColor = AGStyle::proceedColor();
        else m_portRenderInfo.color = m_textColor = AGStyle::foregroundColor();
        m_portRenderInfo.color.a = m_alpha;
        m_textColor.a = m_textAlpha;
        
        GLvertex3f position = lerp(m_posLerp, m_node->position(), m_pos);
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
    enum Type
    {
        TYPE_INPUT,
        TYPE_OUTPUT,
    };
    
    AGPortBrowser(AGNode *node, Type type) : m_node(node), m_type(type), m_scale(0.2), m_alpha(0.1, 1),
    m_selectedPort(-1)
    {
        float radius = 0.0125f*AGStyle::oldGlobalScale;
        
        m_strokeInfo.shader = &AGGenericShader::instance();
        m_strokeInfo.geo = &(GeoGen::circle64())[1];
        m_strokeInfo.geoType = GL_LINE_LOOP;
        m_strokeInfo.numVertex = 64-1;
        m_strokeInfo.color = AGStyle::foregroundColor();
        
        m_fillInfo.shader = &AGGenericShader::instance();
        m_fillInfo.geo = GeoGen::circle64();
        m_fillInfo.geoType = GL_TRIANGLE_FAN;
        m_fillInfo.numVertex = 64;
        m_fillInfo.color = AGStyle::frameBackgroundColor();
        
        m_renderList.push_back(&m_fillInfo);
        m_renderList.push_back(&m_strokeInfo);
        
        m_scale = 1;
        m_alpha = 1;
        
        m_ports.reserve(numPorts());
        float angle = 3.0f*M_PI/4.0f;
        float portRadius = radius*0.62;
        for(int i = 0; i < numPorts(); i++)
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
            AGPortBrowserPort *port = new AGPortBrowserPort(m_node, portInfo(i), pos, textPos);
            port->init();
            addChild(port);
            m_ports.push_back(port);
            
            angle -= M_PI*2.0f/((float)numPorts());
        }
    }
    
    int numPorts()
    {
        if(m_type == TYPE_INPUT)
            return m_node->numInputPorts();
        else
            return m_node->numOutputPorts();
    }
    
    const AGPortInfo &portInfo(int portNum)
    {
        if(m_type == TYPE_INPUT)
            return m_node->inputPortInfo(portNum);
        else
            return m_node->outputPortInfo(portNum);
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
        
        // no dead-zone for single-port objects
        if(numPorts() > 1)
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
        float width = (M_PI*2)/numPorts();
        // starting rotation (from 0) of first port
        float rot = 3.0f*M_PI/4.0f;
        // angle of touch, mapped to [0, 2pi) => [port0, ..., portN-1]
        theta = normAngle(-(theta-rot-width/2.0f));
        // calculate bin => port number
        return (int) floorf(theta/(M_PI*2.0f)*numPorts());
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
    
    Type m_type;
    int m_selectedPort;
    
    vector<AGPortBrowserPort *> m_ports;
};


@interface AGConnectTouchHandler ()
{
    AGNode * _connectInput;
    AGNode * _connectOutput;
    AGNode * _originalHit;
    AGNode * _currentHit;
    
    int _srcPort;
    int _dstPort;
    AGNode::HitTestResult _hitResult;
    
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
    _hitResult = [_viewController hitTest:pos node:&hitNode port:&port];
    
    if(_hitResult == AGNode::HIT_INPUT_NODE)
    {
        _dstPort = port;
        _connectInput = hitNode;
        _connectInput->activateInputPort(1+_dstPort);
    }
    else
    {
        _srcPort = port;
        _connectOutput = hitNode;
        _connectOutput->activateOutputPort(1+_srcPort);
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
    [_viewController hitTest:pos node:&hitNode port:&port];
    
    if(hitNode != _currentHit && hitNode != _originalHit)
    {
        if(_browser)
            [_viewController fadeOutAndDelete:_browser];
        if(hitNode)
        {
            _browser = new AGPortBrowser(hitNode,
                                         _hitResult == AGNode::HIT_INPUT_NODE ?
                                         AGPortBrowser::TYPE_OUTPUT : AGPortBrowser::TYPE_INPUT);
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
            [_viewController fadeOutAndDelete:_browser];
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
    // CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    // GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController fadeOutAndDelete:_proto];
    _proto = NULL;
    
    if(_browser)
    {
        int port = _browser->selectedPort();
        if(port != -1)
        {
            AGNode *srcNode, *dstNode;
            int srcPort, dstPort;
            
            if(_hitResult == AGNode::HIT_INPUT_NODE)
            {
                srcNode = _currentHit;
                srcPort = port;
                dstNode = _originalHit;
                dstPort = _dstPort;
            }
            else
            {
                srcNode = _originalHit;
                srcPort = _srcPort;
                dstNode = _currentHit;
                dstPort = port;
            }
            
            AGAnalytics::instance().eventConnectNode(srcNode->type(), dstNode->type());
            
            AGConnection *connection = AGConnection::connect(srcNode, srcPort, dstNode, dstPort);
            
            AGActivity *action = AGActivity::createConnectionActivity(connection);
            AGActivityManager::instance().addActivity(action);
        }
    }
    
    if(_connectInput) _connectInput->activateInputPort(0);
    if(_connectOutput) _connectOutput->activateOutputPort(0);
    _connectInput = _connectOutput = _currentHit = NULL;
    
    if(_browser)
    {
        [_viewController fadeOutAndDelete:_browser];
        _browser = NULL;
    }
}

@end

