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
#import "AGControlNode.h"
#import "AGAudioManager.h"
#import "AGUserInterface.h"
#import "TexFont.h"
#import "AGDef.h"
#import "AGTrainerViewController.h"
#import "AGGenericShader.h"
#import "AGTouchHandler.h"
#import "AGAboutBox.h"
#import "AGDocument.h"
#import "GeoGenerator.h"
#import "spstl.h"

#import <list>
#import <map>

using namespace std;


#define AG_ENABLE_FBO 0
#define AG_DEFAULT_FILENAME "_default"


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

enum DrawMode
{
    DRAWMODE_NODE,
    DRAWMODE_FREEDRAW
};


@interface AGViewController ()
{
    GLuint _program;
    
    GLKMatrix4 _modelView;
    GLKMatrix4 _fixedModelView;
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
    
//    AGDocument _defaultDocument;
//    AGDocument *_currentDocument;
    map<AGNode *, string> _nodeUUID;
    map<AGConnection *, string> _conectionUUID;
    map<AGFreeDraw *, string> _freedrawUUID;
    
    DrawMode _drawMode;
    
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
- (void)initUI;
- (void)updateMatrices;
- (void)save;

@end

static AGViewController * g_instance = nil;

@implementation AGViewController

+ (id)instance
{
    return g_instance;
}

+ (NSString *)styleFontPath
{
    return [[NSBundle mainBundle] pathForResource:@"Orbitron-Medium.ttf" ofType:@""];
}

- (GLKMatrix4)modelViewMatrix { return _modelView; }
- (GLKMatrix4)fixedModelViewMatrix { return _fixedModelView; }
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
    
    const char *fontPath = [[AGViewController styleFontPath] UTF8String];
    _font = new TexFont(fontPath, 96);
    
    /* preload hw recognizer */
    (void) [AGHandwritingRecognizer instance];
    /* preload audio node manager */
    (void) AGAudioNodeManager::instance();
    
//    _testButton = new AGUIButton("Trainer", [self worldCoordinateForScreenCoordinate:CGPointMake(10, self.view.bounds.size.height-10)], GLvertex2f(0.028, 0.007));
//    _testButton->setAction(^{
//        [self presentViewController:self.trainer animated:YES completion:nil];
//    });
//    _objects.push_back(_testButton);
    
    [self initUI];
    
    __block AGAudioOutputNode * outputNode = NULL;
    
    /* load default program */
    if(AGDocument::existsForTitle(AG_DEFAULT_FILENAME))
    {
        AGDocument defaultDoc;
        defaultDoc.load(AG_DEFAULT_FILENAME);
        
        __block map<string, AGNode *> uuid2node;
        
        defaultDoc.recreate(^(const AGDocument::Node &docNode) {
            AGNode *node = NULL;
            if(docNode._class == AGDocument::Node::AUDIO)
                node = AGAudioNodeManager::instance().createNodeType(docNode);
            if(docNode.type == "Output")
                // TODO: fix this hacky shit
                outputNode = dynamic_cast<AGAudioOutputNode *>(node);
            if(node != NULL)
            {
                uuid2node[node->uuid()] = node;
                [self addNode:node];
            }
        }, ^(const AGDocument::Connection &docConnection) {
            if(uuid2node.count(docConnection.srcUuid) && uuid2node.count(docConnection.dstUuid))
            {
                AGNode *srcNode = uuid2node[docConnection.srcUuid];
                AGNode *dstNode = uuid2node[docConnection.dstUuid];
                AGConnection *conn = new AGConnection(srcNode, dstNode, docConnection.dstPort);
                [self addConnection:conn];
            }
        }, ^(const AGDocument::Freedraw &docFreedraw) {
            AGFreeDraw *freedraw = new AGFreeDraw(docFreedraw);
            [self addTopLevelObject:freedraw];
        });
    }
    else
    {
        outputNode = new AGAudioOutputNode([self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)]);
        _nodes.push_back(outputNode);
    }
    
    self.audioManager.outputNode = outputNode;
    
    g_instance = self;
}

- (void)initUI
{
    __weak typeof(self) weakSelf = self;
    
    /* about button */
    float aboutButtonWidth = _font->width("AURAGLYPH")*1.05;
    float aboutButtonHeight = _font->height()*1.05;
//    AGUITextButton *aboutButton = new AGUITextButton("AURAGLYPH",
//                                                     GLvertex3f(-aboutButtonWidth/2, 0, 0) + [self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height-10)],
//                                                     GLvertex2f(aboutButtonWidth, aboutButtonHeight));
//    aboutButton->setAction(^{
//        AGAboutBox *aboutBox = new AGAboutBox([self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)]);
//        [weakSelf addTopLevelObject:aboutBox];
//    });
//    [self addTopLevelObject:aboutButton];
    
    /* save button */
    float saveButtonWidth = _font->width("  Save  ")*1.05;
    float saveButtonHeight = _font->height()*1.05;
    AGUIButton *saveButton = new AGUIButton("Save",
                                            GLvertex3f(0, -aboutButtonHeight/2, 0) + [self worldCoordinateForScreenCoordinate:CGPointMake(10, 10)],
                                            GLvertex2f(saveButtonWidth, saveButtonHeight));
    saveButton->setAction(^{
        //        AGViewController *strongSelf = weakSelf;
        //        if(strongSelf)
        //            strongSelf->_defaultDocument.save();
        [weakSelf save];
    });
    [self addTopLevelObject:saveButton];
    
    AGUIButtonGroup *modeButtonGroup = new AGUIButtonGroup();
    
    /* freedraw button */
    float freedrawButtonWidth = 0.0095;
    GLvertex3f modeButtonStartPos = [self worldCoordinateForScreenCoordinate:CGPointMake(27.5, self.view.bounds.size.height-20)];
    AGRenderInfoV freedrawRenderInfo;
    freedrawRenderInfo.numVertex = 5;
    freedrawRenderInfo.geoType = GL_LINE_LOOP;
//    freedrawRenderInfo.geoOffset = 0;
    freedrawRenderInfo.geo = new GLvertex3f[freedrawRenderInfo.numVertex];
    float w = freedrawButtonWidth*(G_RATIO-1), h = w*0.3, t = h*0.75, rot = -M_PI/4;
    freedrawRenderInfo.geo[0] = rotateZ(GLvertex2f(-w/2,   -h/2), rot);
    freedrawRenderInfo.geo[1] = rotateZ(GLvertex2f( w/2-t, -h/2), rot);
    freedrawRenderInfo.geo[2] = rotateZ(GLvertex2f( w/2,      0), rot);
    freedrawRenderInfo.geo[3] = rotateZ(GLvertex2f( w/2-t,  h/2), rot);
    freedrawRenderInfo.geo[4] = rotateZ(GLvertex2f(-w/2,    h/2), rot);
    freedrawRenderInfo.color = AGStyle::lightColor();
    AGUIIconButton *freedrawButton = new AGUIIconButton(modeButtonStartPos,
                                                        GLvertex2f(freedrawButtonWidth, freedrawButtonWidth),
                                                        freedrawRenderInfo);
    freedrawButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    freedrawButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(freedrawButton, ^{
        //NSLog(@"freedraw");
        _drawMode = DRAWMODE_FREEDRAW;
    }, false);
    
    /* node button */
    float nodeButtonWidth = freedrawButtonWidth;
    AGRenderInfoV nodeRenderInfo;
    nodeRenderInfo.numVertex = 10;
    nodeRenderInfo.geoType = GL_LINE_STRIP;
    nodeRenderInfo.geo = new GLvertex3f[nodeRenderInfo.numVertex];
    GeoGen::makeCircleStroke(nodeRenderInfo.geo, nodeRenderInfo.numVertex, nodeButtonWidth/2*(G_RATIO-1));
    nodeRenderInfo.color = AGStyle::lightColor();
    AGUIIconButton *nodeButton = new AGUIIconButton(modeButtonStartPos + GLvertex3f(0, nodeButtonWidth*1.25, 0),
                                                    GLvertex2f(nodeButtonWidth, nodeButtonWidth),
                                                    nodeRenderInfo);
    nodeButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    nodeButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(nodeButton, ^{
        //NSLog(@"node");
        _drawMode = DRAWMODE_NODE;
    }, true);
    
    [self addTopLevelObject:modeButtonGroup];
    _drawMode = DRAWMODE_NODE;
    
    /* trash */
    AGUITrash::instance().setPosition([self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-30, self.view.bounds.size.height-20)]);
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
    
//    AGDocument::Node docNode = node->serialize();
//    _defaultDocument.addNode(docNode);
}

- (void)removeNode:(AGNode *)node
{
//    _defaultDocument.removeNode(node->uuid());
    
    _nodeRemoveList.push_back(node);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object
{
    _objects.push_back(object);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object over:(AGInteractiveObject *)over
{
    list<AGInteractiveObject *>::iterator ov = find(_objects.begin(), _objects.end(), over);
    if(ov != _objects.end())
        _objects.insert(++ov, object);
    else
        _objects.push_back(object);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object under:(AGInteractiveObject *)under
{
    list<AGInteractiveObject *>::iterator un = find(_objects.begin(), _objects.end(), under);
    if(un != _objects.end())
        _objects.insert(un, object);
    else
        _objects.push_front(object);
}

- (void)removeTopLevelObject:(AGInteractiveObject *)object
{
    if(object == _touchCapture)
        _touchCapture = NULL;
    
    object->renderOut();
    _removeList.push_back(object);
}

- (void)addConnection:(AGConnection *)connection
{
    _objects.push_back(connection);
}

- (void)removeConnection:(AGConnection *)connection
{
    if(connection == _touchCapture)
        _touchCapture = NULL;
    
    _removeList.push_back(connection);
}

- (void)addFreeDraw:(AGFreeDraw *)freedraw
{
    _objects.push_back(freedraw);
}

- (void)removeFreeDraw:(AGFreeDraw *)freedraw
{
    _removeList.push_back(freedraw);
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
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    _modelView = modelViewMatrix;
    _fixedModelView = GLKMatrix4MakeTranslation(0, 0, -4.0f);
    _projection = projectionMatrix;
    
    AGRenderObject::setProjectionMatrix(projectionMatrix);
    AGRenderObject::setGlobalModelViewMatrix(modelViewMatrix);
    AGRenderObject::setFixedModelViewMatrix(_fixedModelView);
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
        for(std::list<AGInteractiveObject *>::iterator i = _removeList.begin(); i != _removeList.end(); )
        {
            std::list<AGInteractiveObject *>::iterator j = i++; // copy iterator to allow removal
            
            if((*j)->finishedRenderingOut())
            {
                _objects.remove(*j);
                delete *j;
                _removeList.erase(j);
            }
        }
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
    
    glEnable(GL_LINE_SMOOTH);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    // normal blending
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    // additive blending
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    
    glEnable(GL_TEXTURE_2D);
    glUseProgram(0);
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
//    GLKMatrix4 textMV = GLKMatrix4Translate(_fixedModelView, -_font->width("AURAGLYPH")/2, -0.1, 3.89);
//    _font->render("AURAGLYPH", GLcolor4f::black, textMV, _projection);
    
//    GLKMatrix4 textMapMV = GLKMatrix4Translate(_modelView, 0, 0.05, 3.89);
//    _font->renderTexmap(GLcolor4f::white, textMapMV, _projection);
    
    // render trash icon
    AGUITrash::instance().render();
    
    // render nodes
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
        (*i)->render();
    
    // render objects
    for(std::list<AGInteractiveObject *>::iterator i = _objects.begin(); i != _objects.end(); i++)
        (*i)->render();
    
    // render connections
//    for(std::list<AGConnection *>::iterator i = _connections.begin(); i != _connections.end(); i++)
//        (*i)->render();
//
    
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
                {
                    AGInteractiveObject *hit = NULL;
                    
                    for(std::list<AGInteractiveObject *>::iterator i = _objects.begin(); i != _objects.end(); i++)
                    {
                        hit = (*i)->hitTest(pos);
                        if(hit != NULL)
                            break;
                    }
                    
                    if(hit)
                    {
                        _touchCapture = hit;
                        _touchCapture->touchDown(pos);
                    }
                    else
                    {
                        switch (_drawMode)
                        {
                            case DRAWMODE_NODE:
                                _touchHandler = [[AGDrawNodeTouchHandler alloc] initWithViewController:self];
                                break;
                            case DRAWMODE_FREEDRAW:
                                _touchHandler = [[AGDrawFreedrawTouchHandler alloc] initWithViewController:self];
                                break;
                        }
                    }
                }
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
    [self touchesEnded:touches withEvent:event];
}



- (void)save
{
    __block AGDocument doc;
    
    itmap(_nodes, ^(AGNode *&node){
        AGDocument::Node docNode = node->serialize();
        doc.addNode(docNode);
    });
    
    itmap(_objects, ^(AGInteractiveObject *&obj){
        AGConnection *connection;
        AGFreeDraw *freedraw;
        
        if((connection = dynamic_cast<AGConnection *>(obj)) != NULL)
        {
            AGDocument::Connection docConnection = connection->serialize();
            doc.addConnection(docConnection);
        }
        
        if((freedraw = dynamic_cast<AGFreeDraw *>(obj)) != NULL)
        {
            AGDocument::Freedraw docFreedraw = freedraw->serialize();
            doc.addFreedraw(docFreedraw);
        }
    });
    
    doc.saveTo("_default");
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
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::audioNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
        [_viewController clearLinePoints];
    }
    else if(figure == AG_FIGURE_SQUARE)
    {
        AGUIMetaNodeSelector *nodeSelector = AGUIMetaNodeSelector::controlNodeSelector(centroidMVP);
        _nextHandler = [[AGSelectNodeTouchHandler alloc] initWithViewController:_viewController nodeSelector:nodeSelector];
//        AGControlNode * node = new AGControlTimerNode(centroidMVP);
//        [_viewController addNode:node];
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
//        AGFreeDraw *freeDraw = new AGFreeDraw((GLvncprimf *) drawline, nDrawlineUsed);
//        
//        [_viewController addFreeDraw:freeDraw];
//        [_viewController clearLinePoints];
    }
}

- (void)update:(float)t dt:(float)dt { }
- (void)render { }

@end



