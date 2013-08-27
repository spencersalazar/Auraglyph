//
//  AGViewController.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

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

#import <list>


#define AG_ENABLE_FBO 0


// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_SCREEN_MVPMATRIX,
    UNIFORM_SCREEN_TEX,
    NUM_UNIFORMS,
};
GLint uniforms[NUM_UNIFORMS];


struct DrawPoint
{
    GLvncprimf geo; // GL geometry
};

const int nDrawline = 1024;
int nDrawlineUsed = 0;
DrawPoint drawline[nDrawline];


enum TouchMode
{
    TOUCHMODE_NONE = 0,
    TOUCHMODE_DRAWNODE,
    TOUCHMODE_MOVENODE,
    TOUCHMODE_CONNECT,
    TOUCHMODE_SELECTNODETYPE,
    TOUCHMODE_EDITNODE,
};


@interface AGTouchHandler : UIResponder
{
    AGViewController *_viewController;
    AGTouchHandler * _nextHandler;
}

- (id)initWithViewController:(AGViewController *)viewController;
- (AGTouchHandler *)nextHandler;

- (void)update:(float)t dt:(float)dt;
- (void)render;

@end

@interface AGDrawNodeTouchHandler : AGTouchHandler
{
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
}

@end

@interface AGMoveNodeTouchHandler : AGTouchHandler
{
    GLvertex3f _anchorOffset;
    AGNode * _moveNode;
    
    GLvertex2f _firstPoint;
    float _maxTouchTravel;
}

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node;

@end

@interface AGConnectTouchHandler : AGTouchHandler
{
    AGNode * _connectInput;
    AGNode * _connectOutput;
    AGNode * _currentHit;
}

@end

@interface AGSelectNodeTouchHandler : AGTouchHandler
{
    AGUINodeSelector * _nodeSelector;
}

- (id)initWithViewController:(AGViewController *)viewController position:(GLvertex3f)pos;

@end

@interface AGEditTouchHandler : AGTouchHandler
{
    AGUINodeEditor * _nodeEditor;
}

- (id)initWithViewController:(AGViewController *)viewController node:(AGNode *)node;

@end

@interface AGViewController ()
{
    GLuint _program;
    
    GLKMatrix4 _modelView;
    GLKMatrix4 _projection;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    float _t;
    float _osc;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    GLuint _screenTexture;
    GLuint _screenFBO;
    GLuint _screenProgram;
    
    GLvertex3f _camera;
    
    AGTouchHandler * _touchHandler;
    
    std::list<AGNode *> _nodes;
    std::list<AGConnection *> _connections;
    
    TexFont * _font;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;
@property (strong, nonatomic) AGAudioManager *audioManager;

- (void)setupGL;
- (void)tearDownGL;
- (void)updateMatrices;
- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p;
- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)node;

@end

@implementation AGViewController

- (GLKMatrix4)modelViewMatrix { return _modelView; }
- (GLKMatrix4)projectionMatrix { return _projection; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _nodes = std::list<AGNode *>();
    _connections = std::list<AGConnection *>();
    _t = 0;
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    _camera = GLvertex3f(0, 0, 0);
    
    self.audioManager = [AGAudioManager new];
    [self updateMatrices];
    AGAudioOutputNode * outputNode = new AGAudioOutputNode([self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)]);
    self.audioManager.outputNode = outputNode;
    
    _nodes.push_back(outputNode);
    
//    const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Consolas.ttf" ofType:@""] UTF8String];
    const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Perfect DOS VGA 437.ttf" ofType:@""] UTF8String];
//    const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"SourceCodePro-Regular.ttf" ofType:@""] UTF8String];
    _font = new TexFont(fontPath, 96);
    
    // ensure the hw recognizer is preloaded
    (void) [AGHandwritingRecognizer instance];
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
        
    _program = [ShaderHelper createProgram:@"Shader"
                            withAttributes:SHADERHELPER_PNC];
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    
    _screenProgram = [ShaderHelper createProgram:@"Screen" withAttributes:SHADERHELPER_PTC];
    uniforms[UNIFORM_SCREEN_MVPMATRIX] = glGetUniformLocation(_screenProgram, "modelViewProjectionMatrix");
    uniforms[UNIFORM_SCREEN_TEX] = glGetUniformLocation(_screenProgram, "tex");
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(drawline), drawline, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(DrawPoint), BUFFER_OFFSET(0));
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glBindVertexArrayOES(0);
    
    float scale = [UIScreen mainScreen].scale;
    glGenTextureFromFramebuffer(&_screenTexture, &_screenFBO,
                                self.view.bounds.size.width*scale,
                                self.view.bounds.size.height*scale);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


- (void)addNode:(AGNode *)node
{
    _nodes.push_back(node);
}

- (void)addConnection:(AGConnection *)connection
{
    _connections.push_back(connection);
}

- (void)addLinePoint:(GLvertex3f)point
{
    drawline[nDrawlineUsed].geo.vertex = point;
    nDrawlineUsed++;
}

- (void)clearLinePoints
{
    nDrawlineUsed = 0;
}


#pragma mark - GLKView and GLKViewController delegate methods

- (void)updateMatrices
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix;
    if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    else
        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f)/aspect, aspect, 0.1f, 100.0f);
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(_camera.x, _camera.y, _camera.z-4.0f);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    _modelView = modelViewMatrix;
    _projection = projectionMatrix;
    
    AGNode::setProjectionMatrix(projectionMatrix);
    AGNode::setGlobalModelViewMatrix(modelViewMatrix);    
}

- (void)update
{
    [self updateMatrices];
    
    _osc += self.timeSinceLastUpdate * 1.0f;
    float dt = self.timeSinceLastUpdate;
    _t += dt;
    
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
        (*i)->update(_t, dt);
    for(std::list<AGConnection *>::iterator i = _connections.begin(); i != _connections.end(); i++)
        (*i)->update(_t, dt);
    
    [_touchHandler update:_t dt:dt];

    glBindVertexArrayOES(_vertexArray);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(drawline), drawline, GL_DYNAMIC_DRAW);
    glBindVertexArrayOES(0);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    GLint sysFBO;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &sysFBO);
    
    /* render scene to FBO texture */
    
    if(AG_ENABLE_FBO)
        glBindFramebuffer(GL_FRAMEBUFFER, _screenFBO);
    
    //glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClearColor(12.0f/255.0f, 16.0f/255.0f, 33.0f/255.0f, 1.0f);
//    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    // normal blending
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    // additive blending
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    
    GLKMatrix4 textMV = GLKMatrix4Translate(_modelView, -0.02, -0.07, 3.89);
    _font->render("AURAGRPH", GLcolor4f::white, textMV, _projection);
    
    // render connections
    for(std::list<AGConnection *>::iterator i = _connections.begin(); i != _connections.end(); i++)
        (*i)->render();
    
    // render nodes
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
        (*i)->render();
    
    // render drawing outline    
    glUseProgram(_program);

    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
    glBindVertexArrayOES(_vertexArray);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &GLcolor4f::white);
    
    glPointSize(4.0f);
    glLineWidth(4.0f);
    if(nDrawlineUsed == 1)
        glDrawArrays(GL_POINTS, 0, nDrawlineUsed);
    else
        glDrawArrays(GL_LINE_STRIP, 0, nDrawlineUsed);
    
    [_touchHandler render];
    
    if(AG_ENABLE_FBO)
    {
        /* render screen texture */
        
        glBindFramebuffer(GL_FRAMEBUFFER, sysFBO);
        
        //glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClearColor(12.0f/255.0f, 16.0f/255.0f, 33.0f/255.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        // normal blending
        //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        // additive blending
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        
        glUseProgram(_screenProgram);
        
        glEnable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _screenTexture);
        
        float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
        GLKMatrix4 ortho = GLKMatrix4MakeOrtho(-1, 1, -1.0/aspect, 1.0/aspect, -1, 1);
        
        glUniformMatrix4fv(uniforms[UNIFORM_SCREEN_MVPMATRIX], 1, 0, ortho.m);
        glUniform1i(uniforms[UNIFORM_SCREEN_TEX], 0);
        
        // GL_TRIANGLE_FAN quad
        GLvertex3f screenGeo[] = {
            GLvertex3f(-1, -1/aspect, 0),
            GLvertex3f(1, -1/aspect, 0),
            GLvertex3f(1, 1/aspect, 0),
            GLvertex3f(-1, 1/aspect, 0),
        };
        
        GLvertex2f screenUV[] = {
            GLvertex2f(0, 0),
            GLvertex2f(1, 0),
            GLvertex2f(1, 1),
            GLvertex2f(0, 1),
        };
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), screenGeo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLvertex2f), screenUV);
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        glDisableVertexAttribArray(GLKVertexAttribColor);
        
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
}


- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p
{
    int viewport[] = { (int)self.view.bounds.origin.x, (int)self.view.bounds.origin.y,
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, self.view.bounds.size.height-p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);
    
//    vec = GLKMatrix4MultiplyVector3(GLKMatrix4MakeTranslation(_camera.x, _camera.y, _camera.z), vec);
    
    return GLvertex3f(vec.x, vec.y, vec.z);
}

- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)node
{
    AGNode::HitTestResult hit;
    
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
    {
        hit = (*i)->hit(pos);
        if(hit != AGNode::HIT_NONE)
        {
            if(node)
                *node = *i;
            return hit;
        }
    }
    
    if(node)
        *node = NULL;
    return AGNode::HIT_NONE;
}


#pragma Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if([touches count] == 1)
    {
        if(_touchHandler == nil)
        {
            CGPoint p = [[touches anyObject] locationInView:self.view];
            GLvertex3f pos = [self worldCoordinateForScreenCoordinate:p];
            
            AGNode * node = NULL;
            AGNode::HitTestResult result = [self hitTest:pos node:&node];
            
            switch(result)
            {
                case AGNode::HIT_INPUT_NODE:
                case AGNode::HIT_OUTPUT_NODE:
                    _touchHandler = [[AGConnectTouchHandler alloc] initWithViewController:self];
                    break;
                    
                case AGNode::HIT_MAIN_NODE:
                    _touchHandler = [[AGMoveNodeTouchHandler alloc] initWithViewController:self node:node];
                    break;
                    
                case AGNode::HIT_NONE:
                    _touchHandler = [[AGDrawNodeTouchHandler alloc] initWithViewController:self];
                    break;
            }
        }
        
        [_touchHandler touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if([touches count] == 1)
    {
        [_touchHandler touchesMoved:touches withEvent:event];
    }
    else if([touches count] == 2)
    {
        UITouch *t1 = [[touches allObjects] objectAtIndex:0];
        UITouch *t2 = [[touches allObjects] objectAtIndex:1];
        CGPoint p1 = [t1 locationInView:self.view];
        CGPoint p1_1 = [t1 previousLocationInView:self.view];
        CGPoint p2 = [t2 locationInView:self.view];
        CGPoint p2_1 = [t2 previousLocationInView:self.view];
        
        CGPoint centroid = CGPointMake((p1.x+p2.x)/2, (p1.y+p2.y)/2);
        CGPoint centroid_1 = CGPointMake((p1_1.x+p2_1.x)/2, (p1_1.y+p2_1.y)/2);
        
        float dist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
        float dist_1 = GLvertex2f(p1_1).distanceTo(GLvertex2f(p2_1));
        
        GLvertex3f pos = [self worldCoordinateForScreenCoordinate:centroid];
        GLvertex3f pos_1 = [self worldCoordinateForScreenCoordinate:centroid_1];
        
        _camera = _camera + (pos - pos_1);
        _camera.z += (dist - dist_1)*0.005;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if([touches count] == 1)
    {
        [_touchHandler touchesEnded:touches withEvent:event];
        
        if(_touchHandler)
            _touchHandler = [_touchHandler nextHandler];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}


@end


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

@implementation AGDrawNodeTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _currentTrace = LTKTrace();
    _currentTraceSum = GLvertex3f();
    
    [_viewController clearLinePoints];
    [_viewController addLinePoint:pos];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController addLinePoint:pos];
    
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
    
    GLvertex3f centroid = _currentTraceSum/nDrawlineUsed;
    GLvertex3f centroidMVP = [_viewController worldCoordinateForScreenCoordinate:CGPointMake(centroid.x, centroid.y)];
    
    if(figure == AG_FIGURE_CIRCLE)
    {
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController position:centroidMVP];
        [_viewController clearLinePoints];
    }
    else if(figure == AG_FIGURE_SQUARE)
    {
        AGControlNode * node = new AGControlNode(centroidMVP);
        [_viewController addNode:node];
        [_viewController clearLinePoints];
    }
    else if(figure == AG_FIGURE_TRIANGLE_DOWN)
    {
        AGInputNode * node = new AGInputNode(centroidMVP);
        [_viewController addNode:node];
        [_viewController clearLinePoints];
    }
    else if(figure == AG_FIGURE_TRIANGLE_UP)
    {
        AGOutputNode * node = new AGOutputNode(centroidMVP);
        [_viewController addNode:node];
        [_viewController clearLinePoints];
    }
}

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
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_moveNode && _maxTouchTravel < 2*2)
    {
        _moveNode->activate(0);
        _nextHandler = [[AGEditTouchHandler alloc] initWithViewController:_viewController node:_moveNode];
    }
}


@end


//------------------------------------------------------------------------------
// ### AGConnectTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGConnectTouchHandler

@implementation AGConnectTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController clearLinePoints];
    [_viewController addLinePoint:pos];
    
    AGNode *hitNode;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode];
    
    if(hit == AGNode::HIT_INPUT_NODE)
    {
        _connectInput = hitNode;
        _connectInput->activateInputPort(1);
    }
    else
    {
        _connectOutput = hitNode;
        _connectOutput->activateOutputPort(1);
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    [_viewController addLinePoint:pos];
    
    AGNode *hitNode;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode];

    if(hit == AGNode::HIT_INPUT_NODE)
    {
        if(hitNode != _currentHit && hitNode != _connectInput)
        {
            // deactivate previous hit if needed
            if(_currentHit)
            {
                _currentHit->activateInputPort(0);
                _currentHit->activateOutputPort(0);
            }
            
            if(_connectInput)
                // input node -> input node: invalid
                hitNode->activateInputPort(-1);
            else
                // output node -> input node: valid
                hitNode->activateInputPort(1);
            
            _currentHit = hitNode;
        }
    }
    else if(hit == AGNode::HIT_OUTPUT_NODE)
    {
        if(hitNode != _currentHit && hitNode != _connectOutput)
        {
            // deactivate previous hit if needed
            if(_currentHit)
            {
                _currentHit->activateInputPort(0);
                _currentHit->activateOutputPort(0);
            }
            
            if(_connectOutput)
                // output node -> output node: invalid
                hitNode->activateOutputPort(-1);
            else
                // input node -> output node: valid
                hitNode->activateOutputPort(1);
            
            _currentHit = hitNode;
        }
    }

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];

    AGNode *hitNode;
    AGNode::HitTestResult hit = [_viewController hitTest:pos node:&hitNode];
    
    if(hit == AGNode::HIT_INPUT_NODE)
    {
        if(_connectOutput != NULL && hitNode != _connectOutput)
        {
            AGConnection * connection = new AGConnection(_connectOutput, hitNode, 0);
            
            [_viewController addConnection:connection];
            [_viewController clearLinePoints];
        }
    }
    else if(hit == AGNode::HIT_OUTPUT_NODE)
    {
        if(_connectInput != NULL && hitNode != _connectInput)
        {
            AGConnection * connection = new AGConnection(hitNode, _connectInput, 0);
            
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

