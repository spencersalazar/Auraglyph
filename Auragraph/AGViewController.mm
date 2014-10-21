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
#import "AGTrainerViewController.h"
#import "AGGenericShader.h"
#import "AGTouchHandler.h"

#import <list>


#define AG_ENABLE_FBO 0


// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_SCREEN_MVPMATRIX,
    UNIFORM_SCREEN_TEX,
    UNIFORM_SCREEN_ORDERH,
    UNIFORM_SCREEN_ORDERV,
    UNIFORM_SCREEN_OFFSET,
    NUM_UNIFORMS,
};
GLint uniforms[NUM_UNIFORMS];


struct DrawPoint
{
    GLvncprimf geo; // GL geometry
};

static const int nDrawline = 1024;
static int nDrawlineUsed = 0;
static DrawPoint drawline[nDrawline];


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
    std::list<AGNode *> _nodeRemoveList;
//    std::list<AGFreeDraw *> _freeDraws;
//    std::list<AGConnection *> _connections;
    
    std::list<AGInteractiveObject *> _objects;
    std::list<AGInteractiveObject *> _removeList;
    
    TexFont * _font;
    
    AGUIButton * _testButton;
    
    AGInteractiveObject * _touchCapture;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;
@property (strong, nonatomic) AGAudioManager *audioManager;

@property (strong) IBOutlet AGTrainerViewController *trainer;


- (void)setupGL;
- (void)tearDownGL;
- (void)updateMatrices;

@end

static AGViewController * g_instance = nil;

@implementation AGViewController

+ (id)instance
{
    return g_instance;
}

- (GLKMatrix4)modelViewMatrix { return _modelView; }
- (GLKMatrix4)projectionMatrix { return _projection; }

- (void)viewDidLoad
{
    [super viewDidLoad];
        
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
    
    _testButton = new AGUIButton("Trainer", [self worldCoordinateForScreenCoordinate:CGPointMake(10, self.view.bounds.size.height-10)], GLvertex2f(0.028, 0.007));
    _testButton->setAction(^{
        [self presentViewController:self.trainer animated:YES completion:nil];
    });
    _objects.push_back(_testButton);
    
    AGUITrash::instance().setPosition([self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-30, self.view.bounds.size.height-20)]);
    
    g_instance = self;
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
    uniforms[UNIFORM_SCREEN_ORDERH] = glGetUniformLocation(_screenProgram, "orderH");
    uniforms[UNIFORM_SCREEN_ORDERV] = glGetUniformLocation(_screenProgram, "orderV");
    uniforms[UNIFORM_SCREEN_OFFSET] = glGetUniformLocation(_screenProgram, "offset");
    
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

- (void)removeNode:(AGNode *)node
{
    _nodeRemoveList.push_back(node);
}

- (void)addConnection:(AGConnection *)connection
{
    _objects.push_back(connection);
}

- (void)addFreeDraw:(AGFreeDraw *)freedraw
{
    _objects.push_back(freedraw);
}

- (void)removeFreeDraw:(AGFreeDraw *)freedraw
{
    _removeList.push_back(freedraw);
}

- (void)removeConnection:(AGConnection *)connection
{
    if(connection == _touchCapture)
        _touchCapture = NULL;
    
    _removeList.push_back(connection);
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
    if(_nodeRemoveList.size())
    {
        for(std::list<AGNode *>::iterator i = _nodeRemoveList.begin(); i != _nodeRemoveList.end(); i++)
        {
            _nodes.remove(*i);
            delete *i;
        }
        _nodeRemoveList.clear();
    }
    
    if(_removeList.size() > 0)
    {
        for(std::list<AGInteractiveObject *>::iterator i = _removeList.begin(); i != _removeList.end(); i++)
        {
            _objects.remove(*i);
            delete *i;
        }
        _removeList.clear();
    }
    
    [self updateMatrices];
    
    _osc += self.timeSinceLastUpdate * 1.0f;
    float dt = self.timeSinceLastUpdate;
    _t += dt;
    
    AGUITrash::instance().update(_t, dt);
    for(std::list<AGInteractiveObject *>::iterator i = _objects.begin(); i != _objects.end(); i++)
        (*i)->update(_t, dt);
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
        (*i)->update(_t, dt);
//    for(std::list<AGConnection *>::iterator i = _connections.begin(); i != _connections.end(); i++)
//        (*i)->update(_t, dt);
    
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
    _font->render("AURAGLPH", GLcolor4f::white, textMV, _projection);
    
    // render trash icon
    AGUITrash::instance().render();
    
    // render objects
    for(std::list<AGInteractiveObject *>::iterator i = _objects.begin(); i != _objects.end(); i++)
        (*i)->render();
    
    // render connections
//    for(std::list<AGConnection *>::iterator i = _connections.begin(); i != _connections.end(); i++)
//        (*i)->render();
//    
//    // render nodes
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
    
    glBindVertexArrayOES(0);
    
    [_touchHandler render];
    
    _testButton->render();
    
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
        
        glUniform1i(uniforms[UNIFORM_SCREEN_ORDERH], 8);
        glUniform1i(uniforms[UNIFORM_SCREEN_ORDERV], 0);
        glUniform2f(uniforms[UNIFORM_SCREEN_OFFSET], 1.0/768.0, 0);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        
        glUniform1i(uniforms[UNIFORM_SCREEN_ORDERH], 0);
        glUniform1i(uniforms[UNIFORM_SCREEN_ORDERV], 8);
        glUniform2f(uniforms[UNIFORM_SCREEN_OFFSET], 0, 1.0/1024.0);
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

- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)node port:(int *)port
{
    AGNode::HitTestResult hit;
    
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
    {
        hit = (*i)->hit(pos, port);
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
            
            AGInteractiveObject *hit = NULL;
            
            for(std::list<AGInteractiveObject *>::iterator i = _objects.begin(); i != _objects.end(); i++)
            {
                if((hit = (*i)->hitTest(pos))) break;
            }
            
            if(hit)
            {
                _touchCapture = hit;
                _touchCapture->touchDown(pos);
            }
            else
            {
                AGNode * node = NULL;
                int port;
                AGNode::HitTestResult result = [self hitTest:pos node:&node port:&port];
                
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
        }
        
        [_touchHandler touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if([touches count] == 1)
    {
        if(_touchCapture)
            _touchCapture->touchMove([self worldCoordinateForScreenCoordinate:[[touches anyObject] locationInView:self.view]]);
        else
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
        
//        GLvertex3f pos = [self worldCoordinateForScreenCoordinate:centroid];
//        GLvertex3f pos_1 = [self worldCoordinateForScreenCoordinate:centroid_1];
        GLvertex3f pos = [self worldCoordinateForScreenCoordinate:p1];
        GLvertex3f pos_1 = [self worldCoordinateForScreenCoordinate:p1_1];
        
        _camera = _camera + (pos - pos_1);
        
        [self clearLinePoints];
        _touchHandler = nil;
//        _camera.z += (dist - dist_1)*0.005;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if([touches count] == 1)
    {
        if(_touchCapture)
        {
            _touchCapture->touchUp([self worldCoordinateForScreenCoordinate:[[touches anyObject] locationInView:self.view]]);
            _touchCapture = NULL;
        }
        else
        {
            [_touchHandler touchesEnded:touches withEvent:event];
            
            if(_touchHandler)
                _touchHandler = [_touchHandler nextHandler];
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}


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
        AGControlNode * node = new AGControlTimerNode(centroidMVP);
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
    else
    {
        AGFreeDraw *freeDraw = new AGFreeDraw((GLvncprimf *) drawline, nDrawlineUsed);
        
        [_viewController addFreeDraw:freeDraw];
        [_viewController clearLinePoints];
    }
}

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

@end



