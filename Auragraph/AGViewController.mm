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

#import <list>


// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};


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
};


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
    
    TouchMode _mode;
  
    // DRAWNODE mode state
    AGHandwritingRecognizer *_hwRecognizer;
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
    
    // CONNECT mode state
    AGNode * _connectInput;
    AGNode * _connectOutput;
    AGNode * _currentHit;
    
    // MOVENODE state
    GLvertex3f _anchorOffset;
    AGNode * _moveNode;
    
    // SELECTNODETYPE
    AGUINodeSelector * _nodeSelector;
    
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

@end

@implementation AGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _nodes = std::list<AGNode *>();
    _connections = std::list<AGConnection *>();
    _t = 0;
    _mode = TOUCHMODE_NONE;
    _connectInput = _connectOutput = _currentHit = NULL;
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
        
    _hwRecognizer = [AGHandwritingRecognizer new];
    _currentTrace = LTKTrace();
    
    self.audioManager = [AGAudioManager new];
    [self updateMatrices];
    AGAudioOutputNode * outputNode = new AGAudioOutputNode([self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)]);
    self.audioManager.outputNode = outputNode;
    
    _nodes.push_back(outputNode);
    
    
    const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Consolas.ttf" ofType:@""] UTF8String];
    //const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Perfect DOS VGA 437.ttf" ofType:@""] UTF8String];
    _font = new TexFont(fontPath, 96);
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
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(drawline), drawline, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(DrawPoint), BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(DrawPoint), BUFFER_OFFSET(sizeof(GLvertex3f)));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(DrawPoint), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
    
    glBindVertexArrayOES(0);
    
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

#pragma mark - GLKView and GLKViewController delegate methods

- (void)updateMatrices
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    
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
    
    if(_nodeSelector)
        _nodeSelector->update(_t, dt);

    glBindVertexArrayOES(_vertexArray);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(drawline), drawline, GL_DYNAMIC_DRAW);
    glBindVertexArrayOES(0);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    // normal blending
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    // additive blending
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    
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
    
    glPointSize(4.0f);
    glLineWidth(4.0f);
    if(nDrawlineUsed == 1)
        glDrawArrays(GL_POINTS, 0, nDrawlineUsed);
    else
        glDrawArrays(GL_LINE_STRIP, 0, nDrawlineUsed);
    
    // render node selector
    if(_nodeSelector)
        _nodeSelector->render();
    
    GLKMatrix4 textMV = GLKMatrix4Translate(_modelView, -0.0225, -0.07, 3.89);
    _font->render("auragraph", GLcolor4f::white, textMV, _projection);
}


#pragma Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.bounds.origin.x, (int)self.view.bounds.origin.y,
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);
    
    if(_mode == TOUCHMODE_SELECTNODETYPE)
    {
        GLvertex3f pos(vec.x, -vec.y, vec.z);
        
        _nodeSelector->touchDown(pos);
        
        return;
    }
    
    AGNode::HitTestResult hit;
    GLvertex2f pos(vec.x, -vec.y);
    AGNode * hitNode = NULL;
    
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
    {
        hit = (*i)->hit(pos);
        if(hit != AGNode::HIT_NONE)
        {
            hitNode = *i;
            break;
        }
    }
    
    if(hit == AGNode::HIT_INPUT_NODE || hit == AGNode::HIT_OUTPUT_NODE)
    {
        _mode = TOUCHMODE_CONNECT;
        
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
    else if(hit == AGNode::HIT_MAIN_NODE)
    {
        _mode = TOUCHMODE_MOVENODE;
        
        GLvertex3f pos2(vec.x, -vec.y, vec.z);
        _anchorOffset = pos2 - hitNode->position();
        
        _moveNode = hitNode;
    }
    else
    {
        _mode = TOUCHMODE_DRAWNODE;

        // reset trace
        _currentTrace = LTKTrace();
        
        floatVector point;
        point.push_back(p.x);
        point.push_back(p.y);
        _currentTrace.addPoint(point);
        
        _currentTraceSum = GLvertex3f(p.x, p.y, 0);
    }
    
    if(_mode == TOUCHMODE_DRAWNODE || _mode == TOUCHMODE_CONNECT)
    {
        drawline[0].geo.vertex = GLvertex3f(vec.x, -vec.y, vec.z);
        drawline[0].geo.color = GLcolor4f(1, 1, 1, 1);
        drawline[0].geo.normal = GLvertex3f(0, 0, 1);
        nDrawlineUsed = 1;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.bounds.origin.x, (int)self.view.bounds.origin.y,
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);
    
    // continue drawline
    if(_mode == TOUCHMODE_CONNECT || _mode == TOUCHMODE_DRAWNODE)
    {
        drawline[nDrawlineUsed].geo.vertex = GLvertex3f(vec.x, -vec.y, vec.z);
        drawline[nDrawlineUsed].geo.color = GLcolor4f(0.75, 0.75, 0.75, 1);
        drawline[nDrawlineUsed].geo.normal = GLvertex3f(0, 0, 1);
        
        nDrawlineUsed++;
    }
    
    if(_mode == TOUCHMODE_SELECTNODETYPE)
    {
        GLvertex3f pos(vec.x, -vec.y, vec.z);
        
        _nodeSelector->touchMove(pos);
    }
    else if(_mode == TOUCHMODE_CONNECT)
    {
        AGNode::HitTestResult hit;
        GLvertex2f pos(vec.x, -vec.y);
        AGNode * hitNode = NULL;
        
        for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
        {
            hit = (*i)->hit(pos);
            if(hit != AGNode::HIT_NONE)
            {
                hitNode = *i;
                break;
            }
        }
        
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
    else if(_mode == TOUCHMODE_MOVENODE)
    {
        GLvertex3f pos(vec.x, -vec.y, vec.z);
        _moveNode->setPosition(pos - _anchorOffset);
    }
    else if(_mode == TOUCHMODE_DRAWNODE)
    {
        _currentTraceSum = _currentTraceSum + GLvertex3f(p.x, p.y, 0);
        
        floatVector point;
        point.push_back(p.x);
        point.push_back(p.y);
        _currentTrace.addPoint(point);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.bounds.origin.x, (int)self.view.bounds.origin.y,
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);

    TouchMode newMode = TOUCHMODE_NONE;
    
    if(_mode == TOUCHMODE_SELECTNODETYPE)
    {
        GLvertex3f pos(vec.x, -vec.y, vec.z);
        
        _nodeSelector->touchUp(pos);
        
        AGNode * newNode = _nodeSelector->createNode();
        if(newNode)
            _nodes.push_back(newNode);
        
        delete _nodeSelector;
        _nodeSelector = NULL;
    }
    else if(_mode == TOUCHMODE_CONNECT)
    {
        AGNode::HitTestResult hit;
        GLvertex2f pos(vec.x, -vec.y);
        AGNode * hitNode = NULL;
        
        for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
        {
            hit = (*i)->hit(pos);
            if(hit != AGNode::HIT_NONE)
            {
                hitNode = *i;
                break;
            }
        }
        
        if(hit == AGNode::HIT_INPUT_NODE)
        {
            if(_connectOutput != NULL && hitNode != _connectOutput)
            {
                AGConnection * connection = new AGConnection(_connectOutput, hitNode, 0);
                _connections.push_back(connection);
                nDrawlineUsed = 0;
            }
        }
        else if(hit == AGNode::HIT_OUTPUT_NODE)
        {
            if(_connectInput != NULL && hitNode != _connectInput)
            {
                AGConnection * connection = new AGConnection(hitNode, _connectInput, 0);
                _connections.push_back(connection);
                nDrawlineUsed = 0;
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
    else if(_mode == TOUCHMODE_DRAWNODE)
    {
        // analysis
        
        AGHandwritingRecognizerFigure figure = [_hwRecognizer recognizeShapeInView:self.view
                                                                             trace:_currentTrace];
        
        NSLog(@"figure: %i", figure);
        
        GLvertex3f centroid = _currentTraceSum/nDrawlineUsed;
        GLKVector3 centroidMVP = GLKMathUnproject(GLKVector3Make(centroid.x, centroid.y, 0.01),
                                                  _modelView, _projection, viewport, NULL);
        
        if(figure == AG_FIGURE_CIRCLE)
        {
            GLvertex3f pos = GLvertex3f(centroidMVP.x, -centroidMVP.y, centroidMVP.z);
            
//            AGAudioNode * node;
//            int r = rand();
//            if(r > RAND_MAX/4*3)
//                node = new AGAudioTriangleWaveNode(pos);
//            else if(r > RAND_MAX/2)
//                node = new AGAudioSineWaveNode(pos);
//            else if(r > RAND_MAX/4)
//                node = new AGAudioSawtoothWaveNode(pos);
//            else
//                node = new AGAudioSquareWaveNode(pos);
//            _nodes.push_back(node);
            
            _nodeSelector = new AGUINodeSelector(pos);
            newMode = TOUCHMODE_SELECTNODETYPE;
            
            nDrawlineUsed = 0;
        }
        else if(figure == AG_FIGURE_SQUARE)
        {
            AGControlNode * node = new AGControlNode(GLvertex3f(centroidMVP.x, -centroidMVP.y, centroidMVP.z));
            _nodes.push_back(node);
            nDrawlineUsed = 0;
        }
        else if(figure == AG_FIGURE_TRIANGLE_DOWN)
        {
            AGInputNode * node = new AGInputNode(GLvertex3f(centroidMVP.x, -centroidMVP.y, centroidMVP.z));
            _nodes.push_back(node);
            nDrawlineUsed = 0;
        }
        else if(figure == AG_FIGURE_TRIANGLE_UP)
        {
            AGOutputNode * node = new AGOutputNode(GLvertex3f(centroidMVP.x, -centroidMVP.y, centroidMVP.z));
            _nodes.push_back(node);
            nDrawlineUsed = 0;
        }
    }
    else if(_mode == TOUCHMODE_SELECTNODETYPE)
    {
        delete _nodeSelector;
        _nodeSelector = NULL;
    }
    
    _mode = newMode;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}


- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p
{
    int viewport[] = { (int)self.view.bounds.origin.x, (int)self.view.bounds.origin.y,
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);
    
    return GLvertex3f(vec.x, -vec.y, vec.z);
}



@end
