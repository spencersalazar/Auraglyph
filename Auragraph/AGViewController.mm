//
//  AGViewController.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGViewController.h"
#import "Geometry.h"
//#import "ShaderHelper.h"
//#import "ES2Render.h"
#import "AGHandwritingRecognizer.h"
#import "AGInteractiveObject.h"
#import "AGNode.h"
#import "AGAudioManager.h"
#import "AGUserInterface.h"
#import "TexFont.h"
#import "AGDef.h"
#import "AGTrainerViewController.h"
#import "AGGenericShader.h"
#import "AGTouchHandler.h"
#import "AGAboutBox.h"
#import "AGDocument.h"
#import "AGDocumentManager.h"
#import "GeoGenerator.h"
#import "spstl.h"
#import "AGAnalytics.h"
#import "AGUISaveLoadDialog.h"
#import "AGPreferences.h"

#import <list>
#import <map>

using namespace std;


#define AG_ENABLE_FBO 0
#define AG_DEFAULT_FILENAME "_default"

#define AG_DO_TRAINER 0
#define AG_RESET_DOCUMENT 0


// Uniform index.
enum
{
    UNIFORM_SCREEN_MVPMATRIX,
    UNIFORM_SCREEN_TEX,
    UNIFORM_SCREEN_ORDERH,
    UNIFORM_SCREEN_ORDERV,
    UNIFORM_SCREEN_OFFSET,
    NUM_UNIFORMS,
};
GLint uniforms[NUM_UNIFORMS];


enum DrawMode
{
    DRAWMODE_NODE,
    DRAWMODE_FREEDRAW
};

enum InterfaceMode
{
    INTERFACEMODE_EDIT,
    INTERFACEMODE_USER,
};


@interface AGViewController ()
{
    GLKMatrix4 _modelView;
    GLKMatrix4 _fixedModelView;
    GLKMatrix4 _projection;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    float _t;
    float _osc;
    
    GLuint _screenTexture;
    GLuint _screenFBO;
    GLuint _screenProgram;
    
    GLvertex3f _camera;
    slewf _cameraZ;
    
    map<UITouch *, UITouch *> _touches;
    map<UITouch *, UITouch *> _freeTouches;
    UITouch *_scrollZoomTouches[2];
    map<UITouch *, AGTouchHandler *> _touchHandlers;
    map<UITouch *, AGInteractiveObject *> _touchCaptures;
    AGTouchHandler *_touchHandlerQueue;
    
    std::list<AGNode *> _nodes;
    std::list<AGInteractiveObject *> _dashboard;
    std::list<AGInteractiveObject *> _objects;
    std::list<AGInteractiveObject *> _interfaceObjects;
    std::list<AGInteractiveObject *> _fadingOut;
    
    list<AGInteractiveObject *> _touchOutsideListeners;
    list<AGTouchHandler *> _touchOutsideHandlers;
    
//    AGDocument _defaultDocument;
//    AGDocument *_currentDocument;
    map<AGNode *, string> _nodeUUID;
    map<AGConnection *, string> _conectionUUID;
    map<AGFreeDraw *, string> _freedrawUUID;
    
    DrawMode _drawMode;
    InterfaceMode _interfaceMode;
    
    TexFont * _font;
    
    AGUIButton *_saveButton;
    AGUIButton *_loadButton;
    AGUIButton *_newButton;
    AGUIButton *_testButton;
    AGUIIconButton *_nodeButton;
    AGUIIconButton *_freedrawButton;
    
    std::string _currentDocumentFilename;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) AGAudioManager *audioManager;

@property (strong) IBOutlet AGTrainerViewController *trainer;

- (void)removeFromTouchCapture:(AGInteractiveObject *)object;
- (void)setupGL;
- (void)tearDownGL;
- (void)initUI;
- (void)_updateFixedUIPosition;
- (void)updateMatrices;
- (void)renderEdit;
- (void)renderUser;

- (void)_save;
- (void)_openLoad;
- (void)_clearDocument;
- (void)_newDocument;
- (void)_loadDocument:(AGDocument &)doc;

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
    
    g_instance = self;
        
    _t = 0;
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
#ifdef RENDER_HIGHQUALITY
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    self.preferredFramesPerSecond = 60;
#endif

    [self setupGL];
    
    _camera = GLvertex3f(0, 0, 0);
    _cameraZ.rate = 0.5;
    _cameraZ.reset(0);
    
    self.audioManager = [AGAudioManager new];
    // update matrices so that worldCoordinateForScreenCoordinate works
    [self updateMatrices];
    
    const char *fontPath = [[AGViewController styleFontPath] UTF8String];
    _font = new TexFont(fontPath, 96);
    
    /* preload hw recognizer */
    (void) [AGHandwritingRecognizer instance];
    
    [self initUI];
    
    /* load default program */
    std::string _lastOpened = AGPreferences::instance().lastOpenedDocument();
    if(_lastOpened.size() != 0)
    {
        AGDocument doc = AGDocumentManager::instance().load(_lastOpened);
        [self _loadDocument:doc];
    }
    else
    {
        // just create output node by itself
        GLvertex3f pos = [self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
        AGNode *node = AGNodeManager::audioNodeManager().createNodeOfType("Output", pos);
        AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
        outputNode->setOutputDestination([AGAudioManager instance].masterOut);
        
        [self addNode:node];
    }
    
    g_instance = self;
}

- (void)initUI
{
    __weak typeof(self) weakSelf = self;
    
    // needed for worldCoordinateForScreenCoordinate to work
    [self updateMatrices];
    
    /* about button */
//    float aboutButtonWidth = _font->width("AURAGLYPH")*1.05;
//    float aboutButtonHeight = _font->height()*1.05;
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
    _saveButton = new AGUIButton("Save",
                                 [self worldCoordinateForScreenCoordinate:CGPointMake(10, 20+saveButtonHeight/2)],
                                 GLvertex2f(saveButtonWidth, saveButtonHeight));
    _saveButton->init();
    _saveButton->setRenderFixed(true);
    _saveButton->setAction(^{
        AGAnalytics::instance().eventSave();
        [weakSelf _save];
    });
    _dashboard.push_back(_saveButton);
    
    /* load button */
    float loadButtonWidth = saveButtonWidth;
    float loadButtonHeight = saveButtonHeight;
    _loadButton = new AGUIButton("Load",
                                 [self fixedCoordinateForScreenCoordinate:CGPointMake(10, 20+saveButtonHeight*1+loadButtonHeight/2)],
                                 GLvertex2f(loadButtonWidth, loadButtonHeight));
    _loadButton->init();
    _loadButton->setRenderFixed(true);
    _loadButton->setAction(^{
        // AGAnalytics::instance().eventSave();
        [weakSelf _openLoad];
    });
    _dashboard.push_back(_loadButton);
    
    /* new button */
    float newButtonWidth = saveButtonWidth;
    float newButtonHeight = saveButtonHeight;
    _newButton = new AGUIButton("New",
                                [self fixedCoordinateForScreenCoordinate:CGPointMake(10, 20+saveButtonHeight*1.05+loadButtonHeight*1.2+newButtonHeight/2)],
                                GLvertex2f(newButtonWidth, newButtonHeight));
    _newButton->init();
    _newButton->setRenderFixed(true);
    _newButton->setAction(^{
        // AGAnalytics::instance().eventSave();
        [weakSelf _newDocument];
    });
    _dashboard.push_back(_newButton);
    
    float testButtonWidth = saveButtonWidth;
    float testButtonHeight = saveButtonHeight;
    _testButton = new AGUIButton("Trainer",
                                 [self fixedCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-testButtonWidth-10, 20+testButtonHeight/2)],
                                 GLvertex2f(testButtonWidth, testButtonHeight));
    _testButton->init();
    _testButton->setRenderFixed(true);
    _testButton->setAction(^{
        AGAnalytics::instance().eventTrainer();
        [self presentViewController:self.trainer animated:YES completion:nil];
    });
    _dashboard.push_back(_testButton);
    
    AGUIButtonGroup *modeButtonGroup = new AGUIButtonGroup();
    modeButtonGroup->init();
    
    /* freedraw button */
    float freedrawButtonWidth = 0.0095*AGStyle::oldGlobalScale;
    GLvertex3f modeButtonStartPos = [self fixedCoordinateForScreenCoordinate:CGPointMake(27.5, self.view.bounds.size.height-20)];
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
    _freedrawButton = new AGUIIconButton(modeButtonStartPos,
                                         GLvertex2f(freedrawButtonWidth, freedrawButtonWidth),
                                         freedrawRenderInfo);
    _freedrawButton->init();
    _freedrawButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    _freedrawButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(_freedrawButton, ^{
        //NSLog(@"freedraw");
        AGAnalytics::instance().eventFreedrawMode();
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
    _nodeButton = new AGUIIconButton(modeButtonStartPos + GLvertex3f(0, nodeButtonWidth*1.25, 0),
                                     GLvertex2f(nodeButtonWidth, nodeButtonWidth),
                                     nodeRenderInfo);
    _nodeButton->init();
    _nodeButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    _nodeButton->setIconMode(AGUIIconButton::ICONMODE_CIRCLE);
    modeButtonGroup->addButton(_nodeButton, ^{
        //NSLog(@"node");
        AGAnalytics::instance().eventNodeMode();
        _drawMode = DRAWMODE_NODE;
    }, true);
    
    _dashboard.push_back(modeButtonGroup);
    _drawMode = DRAWMODE_NODE;
    
//    _interfaceMode = INTERFACEMODE_USER;
    _interfaceMode = INTERFACEMODE_EDIT;
    
    /* trash */
    AGUITrash::instance().setPosition([self fixedCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-30, self.view.bounds.size.height-20)]);
    
//    GLvertex3f vert = [self worldCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
}

- (void)_updateFixedUIPosition
{
    // needed for worldCoordinateForScreenCoordinate to work
    [self updateMatrices];
    
    CGPoint savePos = CGPointMake(10, 20+_saveButton->size().y/2);
    _saveButton->setPosition([self fixedCoordinateForScreenCoordinate:savePos]);
    
    CGPoint loadPos = CGPointMake(10, 20+_saveButton->size().y*1.1+_loadButton->size().y/2);
    _loadButton->setPosition([self fixedCoordinateForScreenCoordinate:loadPos]);
    
    CGPoint newPos = CGPointMake(10, 20+_saveButton->size().y*1.05+_loadButton->size().y*1.2+_newButton->size().y/2);
    _newButton->setPosition([self fixedCoordinateForScreenCoordinate:newPos]);
    
    CGPoint testPos = CGPointMake(self.view.bounds.size.width-_testButton->size().x-10, 20+_testButton->size().y/2);
    _testButton->setPosition([self fixedCoordinateForScreenCoordinate:testPos]);
    
    GLvertex3f modeButtonStartPos = [self fixedCoordinateForScreenCoordinate:CGPointMake(27.5, self.view.bounds.size.height-7.5-_freedrawButton->size().y/2)];
    _freedrawButton->setPosition(modeButtonStartPos);
    _nodeButton->setPosition(modeButtonStartPos + GLvertex3f(0, _freedrawButton->size().y*1.25, 0));
    
    AGUITrash::instance().setPosition([self fixedCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-30, self.view.bounds.size.height-30)]);
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

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    _saveButton->hide();
    _testButton->hide();
    _freedrawButton->hide();
    _nodeButton->hide();
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self _updateFixedUIPosition];
        
        _saveButton->unhide();
        _testButton->unhide();
        _freedrawButton->unhide();
        _nodeButton->unhide();
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self _updateFixedUIPosition];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    _screenProgram = [ShaderHelper createProgram:@"Screen" withAttributes:SHADERHELPER_PTC];
    uniforms[UNIFORM_SCREEN_MVPMATRIX] = glGetUniformLocation(_screenProgram, "modelViewProjectionMatrix");
    uniforms[UNIFORM_SCREEN_TEX] = glGetUniformLocation(_screenProgram, "tex");
    uniforms[UNIFORM_SCREEN_ORDERH] = glGetUniformLocation(_screenProgram, "orderH");
    uniforms[UNIFORM_SCREEN_ORDERV] = glGetUniformLocation(_screenProgram, "orderV");
    uniforms[UNIFORM_SCREEN_OFFSET] = glGetUniformLocation(_screenProgram, "offset");
    
    glEnable(GL_DEPTH_TEST);
    
    float scale = [UIScreen mainScreen].scale;
    glGenTextureFromFramebuffer(&_screenTexture, &_screenFBO,
                                self.view.bounds.size.width*scale,
                                self.view.bounds.size.height*scale);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
}


- (void)addNode:(AGNode *)node
{
    assert([NSThread isMainThread]);
    
    _nodes.push_back(node);
    _objects.push_back(node);
    
    AGInteractiveObject * ui = node->userInterface();
    if(ui)
        _interfaceObjects.push_back(ui);
    
//    AGDocument::Node docNode = node->serialize();
//    _defaultDocument.addNode(docNode);
}

- (void)removeNode:(AGNode *)node
{
    [self fadeOutAndDelete:node];
}

- (void)resignNode:(AGNode *)node
{
    assert([NSThread isMainThread]);
    
    // remove without fading out or destroying
    
    // only process for removal if it is part of the node list in the first place
    bool hasNode = (std::find(_nodes.begin(), _nodes.end(), node) != _nodes.end());
    
    if(hasNode)
    {
        [self removeFromTouchCapture:node];
        
        AGInteractiveObject * ui = node->userInterface();
        if(ui)
            _interfaceObjects.remove(ui);
        
        _nodes.remove(node);
        _objects.remove(node);
    }
}

- (const list<AGNode *> &)nodes
{
    return _nodes;
}

- (void)addTopLevelObject:(AGInteractiveObject *)object
{
    assert([NSThread isMainThread]);
    assert(object);
    
    _objects.push_back(object);
    
    AGInteractiveObject * ui = object->userInterface();
    if(ui)
        _interfaceObjects.push_back(ui);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object over:(AGInteractiveObject *)over
{
    assert([NSThread isMainThread]);
    assert(object);
    
    list<AGInteractiveObject *>::iterator ov = find(_objects.begin(), _objects.end(), over);
    if(ov != _objects.end())
        _objects.insert(++ov, object);
    else
        _objects.push_back(object);
    
    AGInteractiveObject * ui = object->userInterface();
    if(ui)
        _interfaceObjects.push_back(ui);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object under:(AGInteractiveObject *)under
{
    assert([NSThread isMainThread]);
    assert(object);
    
    list<AGInteractiveObject *>::iterator un = find(_objects.begin(), _objects.end(), under);
    if(un != _objects.end())
        _objects.insert(un, object);
    else
        _objects.push_front(object);
    
    AGInteractiveObject * ui = object->userInterface();
    if(ui)
        _interfaceObjects.push_back(ui);
}

- (void)fadeOutAndDelete:(AGInteractiveObject *)object
{
    assert([NSThread isMainThread]);
    assert(object);
//    assert(dynamic_cast<AGConnection *>(object) == NULL);
    
    dbgprint("fadeOutAndDelete: %s 0x%08x\n", typeid(*object).name(), (unsigned int) object);
    
    [self removeFromTouchCapture:object];
    
    AGInteractiveObject * ui = object->userInterface();
    if(ui)
        _interfaceObjects.remove(ui);
    
    assert(find(_fadingOut.begin(), _fadingOut.end(), object) == _fadingOut.end());
    if(find(_fadingOut.begin(), _fadingOut.end(), object) == _fadingOut.end())
    {
        object->renderOut();
        _fadingOut.push_back(object);
    }
    
    _objects.remove(object);
    AGNode *node = dynamic_cast<AGNode *>(object);
    if(node)
        _nodes.remove(node);
    _dashboard.remove(object);
}

- (void)removeFromTouchCapture:(AGInteractiveObject *)object
{
    // remove object and all children from touch capture
    std::function<void (AGRenderObject *obj)> removeAll = [&removeAll, object, self] (AGRenderObject *obj)
    {
        AGInteractiveObject *intObj = dynamic_cast<AGInteractiveObject *>(obj);
        if(intObj)
            removevalues(_touchCaptures, intObj);
        for(auto child : obj->children())
            removeAll(child);
    };
    
    removeAll(object);
}

- (void)addFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    
    _objects.push_back(freedraw);
}

- (void)removeFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    assert(freedraw);
    
    _fadingOut.push_back(freedraw);
}

- (void)addTouchOutsideListener:(AGInteractiveObject *)listener
{
    assert([NSThread isMainThread]);
    
    _touchOutsideListeners.push_back(listener);
}

- (void)removeTouchOutsideListener:(AGInteractiveObject *)listener
{
    assert([NSThread isMainThread]);
    
    _touchOutsideListeners.remove(listener);
}

- (void)addTouchOutsideHandler:(AGTouchHandler *)listener
{
    dbgprint("addTouchOutsideHandler: %s 0x%08x\n", [NSStringFromClass([listener class]) UTF8String], (unsigned int) listener);
    
    _touchOutsideHandlers.push_back(listener);
}

- (void)removeTouchOutsideHandler:(AGTouchHandler *)listener
{
    dbgprint("removeTouchOutsideHandler: %s 0x%08x\n", [NSStringFromClass([listener class]) UTF8String], (unsigned int) listener);

    _touchOutsideHandlers.remove(listener);
}

- (void)resignTouchHandler:(AGTouchHandler *)handler
{
    removevalues(_touchHandlers, handler);
    _touchOutsideHandlers.remove(handler);
    if(handler == _touchHandlerQueue)
        _touchHandlerQueue = nil;
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)updateMatrices
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix;
//    if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
//        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
//    else
//        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f)/aspect, aspect, 0.1f, 100.0f);
//    if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
//    NSLog(@"width %f height %f", self.view.bounds.size.width, self.view.bounds.size.height);
    projectionMatrix = GLKMatrix4MakeFrustum(-self.view.bounds.size.width/2, self.view.bounds.size.width/2,
                                             -self.view.bounds.size.height/2, self.view.bounds.size.height/2, 10.0f, 1000.0f);
//    else
//        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f)/aspect, aspect, 0.1f, 100.0f);
    
    _fixedModelView = GLKMatrix4MakeTranslation(0, 0, -10.1f);
    
    if(_cameraZ < 0)
        _camera.z = _cameraZ;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4Translate(_fixedModelView, _camera.x, _camera.y, _camera.z);
    if(_interfaceMode == INTERFACEMODE_USER)
        baseModelViewMatrix = GLKMatrix4Translate(baseModelViewMatrix, 0, 0, -(G_RATIO-1));
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    _modelView = modelViewMatrix;
    _projection = projectionMatrix;
    
    AGRenderObject::setProjectionMatrix(projectionMatrix);
    AGRenderObject::setGlobalModelViewMatrix(modelViewMatrix);
    AGRenderObject::setFixedModelViewMatrix(_fixedModelView);
    AGRenderObject::setCameraMatrix(GLKMatrix4MakeTranslation(_camera.x, _camera.y, _camera.z));
}

- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p
{
    int viewport[] = { (int)self.view.bounds.origin.x, (int)(self.view.bounds.origin.y),
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    bool success;
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, self.view.bounds.size.height-p.y, 0.01f),
                                      _modelView, _projection, viewport, &success);
    
    //    vec = GLKMatrix4MultiplyVector3(GLKMatrix4MakeTranslation(_camera.x, _camera.y, _camera.z), vec);
    
    return GLvertex3f(vec.x, vec.y, 0);
}

- (GLvertex3f)fixedCoordinateForScreenCoordinate:(CGPoint)p
{
    int viewport[] = { (int)self.view.bounds.origin.x, (int)(self.view.bounds.origin.y),
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    bool success;
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, self.view.bounds.size.height-p.y, 0.0f),
                                      _fixedModelView, _projection, viewport, &success);
    
    //    vec = GLKMatrix4MultiplyVector3(GLKMatrix4MakeTranslation(_camera.x, _camera.y, _camera.z), vec);
    
    return GLvertex3f(vec.x, vec.y, 0);
}

- (void)update
{
    if(_fadingOut.size() > 0)
    {
        for(std::list<AGInteractiveObject *>::iterator i = _fadingOut.begin(); i != _fadingOut.end(); )
        {
            std::list<AGInteractiveObject *>::iterator j = i++; // copy iterator to allow removal
            
            AGInteractiveObject *obj = *j;
            assert(obj);
            if(obj->finishedRenderingOut())
            {
                delete *j;
                _fadingOut.erase(j);
            }
        }
    }
    
    _cameraZ.interp();
    
    [self updateMatrices];
    
    _osc += self.timeSinceLastUpdate * 1.0f;
    float dt = self.timeSinceLastUpdate;
    _t += dt;
    
    AGUITrash::instance().update(_t, dt);
    
    itmap_safe(_dashboard, ^(AGInteractiveObject *&object){
        object->update(_t, dt);
    });
    itmap_safe(_objects, ^(AGInteractiveObject *&object){
        object->update(_t, dt);
    });
    itmap_safe(_fadingOut, ^(AGInteractiveObject *&object){
        object->update(_t, dt);
    });
    itmap_safe(_interfaceObjects, ^(AGInteractiveObject *&object){
        object->update(_t, dt);
    });
    
    for(auto kv : _touchHandlers)
        [_touchHandlers[kv.first] update:_t dt:dt];
    [_touchHandlerQueue update:_t dt:dt];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    GLint sysFBO;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &sysFBO);
    
    /* render scene to FBO texture */
    
    if(AG_ENABLE_FBO)
        glBindFramebuffer(GL_FRAMEBUFFER, _screenFBO);
    
    //glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    if(AG_ENABLE_FBO)
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    else
        glClearColor(AGStyle::backgroundColor.r, AGStyle::backgroundColor.g, AGStyle::backgroundColor.b, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self renderEdit];
    
    if(AG_ENABLE_FBO)
    {
        /* render screen texture */
        
        glBindFramebuffer(GL_FRAMEBUFFER, sysFBO);
        
//        [((GLKView *) self.view) bindDrawable];
        
        //glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClearColor(AGStyle::backgroundColor.r, AGStyle::backgroundColor.g, AGStyle::backgroundColor.b, 1.0f);
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
    
    if(_interfaceMode == INTERFACEMODE_USER)
        [self renderUser];
}

- (void)renderEdit
{
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
    
    // render trash icon
    AGUITrash::instance().render();
    
    // render objects
    for(AGInteractiveObject *object : _objects)
        object->render();
    // render removeList
    for(AGInteractiveObject *removeObject : _fadingOut)
        removeObject->render();
    // render user interface
    for(AGInteractiveObject *object : _dashboard)
        object->render();
    
    for(auto kv : _touchHandlers)
        [_touchHandlers[kv.first] render];
    [_touchHandlerQueue render];
}

- (void)renderUser
{
    CGSize size = self.view.bounds.size;
    GLvertex3f overlayGeo[4];
    overlayGeo[0] = [self worldCoordinateForScreenCoordinate:CGPointMake(size.width*0.1, size.width*0.1)];
    overlayGeo[1] = [self worldCoordinateForScreenCoordinate:CGPointMake(size.width*0.9, size.width*0.1)];
    overlayGeo[2] = [self worldCoordinateForScreenCoordinate:CGPointMake(size.width*0.1, size.height-size.width*0.1)];
    overlayGeo[3] = [self worldCoordinateForScreenCoordinate:CGPointMake(size.width*0.9, size.height-size.width*0.1)];
    GLcolor4f overlayColor = GLcolor4f(12.0f/255.0f, 16.0f/255.0f, 33.0f/255.0f, 0.45);
//    GLcolor4f overlayColor = GLcolor4f(1.0, 1.0, 1.0, 0.45);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(_modelViewProjectionMatrix);
    shader.setNormalMatrix(_normalMatrix);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &overlayColor);
    glDisableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(0, 3, GL_FLOAT, FALSE, 0, &overlayGeo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    for(std::list<AGInteractiveObject *>::iterator i = _interfaceObjects.begin(); i != _interfaceObjects.end(); i++)
        (*i)->render();
}


- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)hitNode port:(int *)port
{
    AGNode::HitTestResult hit;
    
    for(AGNode *node : _nodes)
    {
        hit = node->hit(pos, port);
        if(hit != AGNode::HIT_NONE)
        {
            if(node)
                *hitNode = node;
            return hit;
        }
    }
    
    if(hitNode)
        *hitNode = NULL;
    return AGNode::HIT_NONE;
}


#pragma Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    dbgprint("touchesBegan, count = %i\n", [touches count]);
    
    // hit test each touch
    for(UITouch *touch in touches)
    {
        CGPoint p = [touch locationInView:self.view];
        GLvertex3f pos = [self worldCoordinateForScreenCoordinate:p];
        GLvertex3f fixedPos = [self fixedCoordinateForScreenCoordinate:p];
        AGTouchHandler *handler = nil;
        AGInteractiveObject *touchCapture = NULL;
        AGInteractiveObject *touchCaptureTopLevelObject = NULL;
        
        // search dashboard items
        // search in reverse order
        for(auto i = _dashboard.rbegin(); i != _dashboard.rend(); i++)
        {
            AGInteractiveObject *object = *i;
            
            // check regular interactive object
            if(object->renderFixed())
                touchCapture = object->hitTest(fixedPos);
            else
                touchCapture = object->hitTest(pos);
            
            if(touchCapture)
            {
                touchCaptureTopLevelObject = object;
                break;
            }
        }
        
        // search pending handlers
        if(touchCapture == NULL)
        {
            if(_touchHandlerQueue && [_touchHandlerQueue hitTest:pos])
            {
                handler = _touchHandlerQueue;
                _touchHandlerQueue = nil;
            }
        }
        
        // search the rest of the objects
        if(touchCapture == NULL && handler == nil)
        {
            // search in reverse order
            for(auto i = _objects.rbegin(); i != _objects.rend(); i++)
            {
                AGInteractiveObject *object = *i;
                
                // check if its a node
                // todo: check node ports first
                AGNode *node = dynamic_cast<AGNode *>(object);
                if(node)
                {
                    // nodes require special hit testing
                    // in addition to regular hit testing
                    int port;
                    AGNode::HitTestResult result = node->hit(pos, &port);
                    if(result != AGNode::HIT_NONE)
                    {
                        if(result == AGNode::HIT_INPUT_NODE || result == AGNode::HIT_OUTPUT_NODE)
                            handler = [[AGConnectTouchHandler alloc] initWithViewController:self];
                        else if(result == AGNode::HIT_MAIN_NODE)
                            handler = [[AGMoveNodeTouchHandler alloc] initWithViewController:self node:node];
                        
                        break;
                    }
                }
                
                // check regular interactive object
                if(object->renderFixed())
                    touchCapture = object->hitTest(fixedPos);
                else
                    touchCapture = object->hitTest(pos);
                
                if(touchCapture)
                {
                    touchCaptureTopLevelObject = object;
                    break;
                }
            }
        }
        
        // search node connections
        if(touchCapture == NULL && handler == nil)
        {
            for(AGNode *node : _nodes)
            {
                for(AGConnection *connection : node->outbound())
                {
                    touchCapture = connection->hitTest(pos);
                    if(touchCapture)
                        break;
                }
                
                if(touchCapture)
                    break;
            }
        }
        
        // deal with drawing
        if(touchCapture == NULL && handler == nil)
        {
            if(_freeTouches.size() == 1)
            {
                // zoom gesture
                UITouch *firstTouch = _freeTouches.begin()->first;
                UITouch *secondTouch = touch;
                
                _scrollZoomTouches[0] = firstTouch;
                _freeTouches.erase(firstTouch);
                if(_touchHandlers.count(firstTouch))
                {
                    [_touchHandlers[firstTouch] touchesCancelled:[NSSet setWithObject:secondTouch] withEvent:event];
                    _touchHandlers.erase(firstTouch);
                }
                
                _scrollZoomTouches[1] = secondTouch;
            }
            else
            {
                switch (_drawMode)
                {
                    case DRAWMODE_NODE:
                        handler = [[AGDrawNodeTouchHandler alloc] initWithViewController:self];
                        break;
                    case DRAWMODE_FREEDRAW:
                        handler = [[AGDrawFreedrawTouchHandler alloc] initWithViewController:self];
                        break;
                }
                
                [handler touchesBegan:touches withEvent:event];
                
                _freeTouches[touch] = touch;
            }
        }
        
        // record touch
        _touches[touch] = touch;
        
        // process handler (if any)
        if(handler)
        {
            _touchHandlers[touch] = handler;
            [handler touchesBegan:[NSSet setWithObject:touch] withEvent:event];
        }
        // process capture (if any)
        else if(touchCapture)
        {
            _touchCaptures[touch] = touchCapture;
            if(touchCapture->renderFixed())
                touchCapture->touchDown(AGTouchInfo(fixedPos, p, (TouchID) touch));
            else
                // TODO: should this transform to coordinate space of the object?
                touchCapture->touchDown(AGTouchInfo(pos, p, (TouchID) touch));
        }
        
        // has
        // is obj or one of its N-children equal to test?
        std::function<bool (AGRenderObject *obj, AGRenderObject *test)> has = [&has] (AGRenderObject *obj, AGRenderObject *test)
        {
            if(obj == test) return true;
            for(auto child : obj->children())
                if(has(child, test))
                    return true;
            return false;
        };
        
        itmap_safe(_touchOutsideListeners, ^(AGInteractiveObject *&touchOutsideListener){
            if(!has(touchOutsideListener, touchCapture))
                touchOutsideListener->touchOutside();
        });
        
        // TODO: what does __strong here really mean
        // TODO: convert AGTouchHandler to C++ class
        itmap_safe(_touchOutsideHandlers, ^(__strong AGTouchHandler *&outsideHandler){
            if(handler != outsideHandler)
                [outsideHandler touchOutside];
        });
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    dbgprint("touchesMoved, count = %i\n", [touches count]);
    
    BOOL didScroll = NO;
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint p = [touch locationInView:self.view];
                GLvertex3f pos = [self worldCoordinateForScreenCoordinate:p];
                GLvertex3f fixedPos = [self fixedCoordinateForScreenCoordinate:p];
                
                if(touchCapture->renderFixed())
                    touchCapture->touchMove(AGTouchInfo(fixedPos, p, (TouchID) touch));
                else
                    touchCapture->touchMove(AGTouchInfo(pos, p, (TouchID) touch));
            }
        }
        else if(_touchHandlers.count(touch))
        {
            AGTouchHandler *touchHandler = _touchHandlers[touch];
            [touchHandler touchesMoved:[NSSet setWithObject:touch] withEvent:event];
        }
        else if(_scrollZoomTouches[0] == touch || _scrollZoomTouches[1] == touch)
        {
            if(!didScroll)
            {
                didScroll = YES;
                CGPoint p1 = [_scrollZoomTouches[0] locationInView:self.view];
                CGPoint p1_1 = [_scrollZoomTouches[0] previousLocationInView:self.view];
                CGPoint p2 = [_scrollZoomTouches[1] locationInView:self.view];
                CGPoint p2_1 = [_scrollZoomTouches[1] previousLocationInView:self.view];
                
                CGPoint centroid = CGPointMake((p1.x+p2.x)/2, (p1.y+p2.y)/2);
                CGPoint centroid_1 = CGPointMake((p1_1.x+p2_1.x)/2, (p1_1.y+p2_1.y)/2);
                
                GLvertex3f pos = [self worldCoordinateForScreenCoordinate:centroid];
                GLvertex3f pos_1 = [self worldCoordinateForScreenCoordinate:centroid_1];
                
                _camera = _camera + (pos.xy() - pos_1.xy());
                dbgprint("camera: %f, %f, %f\n", _camera.x, _camera.y, _camera.z);
                
//                float dist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
//                float dist_1 = GLvertex2f(p1_1).distanceTo(GLvertex2f(p2_1));
//                float zoom = (dist - dist_1)*0.05;
//                _cameraZ += zoom;
            }
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    dbgprint("touchEnded, count = %i\n", [touches count]);
    
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint p = [touch locationInView:self.view];
                GLvertex3f pos = [self worldCoordinateForScreenCoordinate:p];
                GLvertex3f fixedPos = [self fixedCoordinateForScreenCoordinate:p];
                
                if(touchCapture->renderFixed())
                    touchCapture->touchUp(AGTouchInfo(fixedPos, p, (TouchID) touch));
                else
                    touchCapture->touchUp(AGTouchInfo(pos, p, (TouchID) touch));

                _touchCaptures.erase(touch);
            }
        }
        else if(_touchHandlers.count(touch))
        {
            AGTouchHandler *touchHandler = _touchHandlers[touch];
            [touchHandler touchesEnded:[NSSet setWithObject:touch] withEvent:event];
            AGTouchHandler *nextHandler = [touchHandler nextHandler];
            if(nextHandler)
            {
                dbgprint("queuing touchHandler: %s 0x%08x\n", [NSStringFromClass([nextHandler class]) UTF8String], (unsigned int) nextHandler);
                _touchHandlerQueue = nextHandler;
            }
            _touchHandlers.erase(touch);
        }
        else if(touch == _scrollZoomTouches[0] || touch == _scrollZoomTouches[1])
        {
            // return remaining touch to freetouches
            if(touch == _scrollZoomTouches[0])
                _freeTouches[_scrollZoomTouches[1]] = _scrollZoomTouches[1];
            else
                _freeTouches[_scrollZoomTouches[0]] = _scrollZoomTouches[0];
            _scrollZoomTouches[0] = _scrollZoomTouches[1] = NULL;
        }
        
        _freeTouches.erase(touch);
        _touches.erase(touch);
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}



- (void)_save
{
    __block AGDocument doc;
    
    itmap(_nodes, ^(AGNode *&node){
        AGDocument::Node docNode = node->serialize();
        doc.addNode(docNode);
    });
    
    itmap(_objects, ^(AGInteractiveObject *&obj){
        AGFreeDraw *freedraw;
        
        if((freedraw = dynamic_cast<AGFreeDraw *>(obj)) != NULL)
        {
            AGDocument::Freedraw docFreedraw = freedraw->serialize();
            doc.addFreedraw(docFreedraw);
        }
    });
    
    if(_currentDocumentFilename.size())
    {
        AGDocumentManager::instance().update(_currentDocumentFilename, doc);
    }
    else
    {
        AGUISaveDialog *saveDialog = AGUISaveDialog::save(doc);
        
        saveDialog->onSave([self](const std::string &filename){
            _currentDocumentFilename = filename;
            AGPreferences::instance().setLastOpenedDocument(_currentDocumentFilename);
        });
        
        _dashboard.push_back(saveDialog);
    }
}

- (void)_openLoad
{
    AGUILoadDialog *loadDialog = AGUILoadDialog::load();
    
    loadDialog->onLoad([self](const std::string &filename, AGDocument &doc){
        _currentDocumentFilename = filename;
        AGPreferences::instance().setLastOpenedDocument(_currentDocumentFilename);
        [self _loadDocument:doc];
    });
    
    _dashboard.push_back(loadDialog);
}

- (void)_clearDocument
{
    // delete all objects
    itmap_safe(_objects, ^(AGInteractiveObject *&object){
        [self fadeOutAndDelete:object];
    });
}

- (void)_newDocument
{
    [self _clearDocument];
    
    _currentDocumentFilename = "";
    
    // just create output node by itself
    AGNode *node = AGNodeManager::audioNodeManager().createNodeOfType("Output", GLvertex3f(0, 0, 0));
    AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
    outputNode->setOutputDestination([AGAudioManager instance].masterOut);
    [self addNode:node];
}

- (void)_loadDocument:(AGDocument &)doc
{
    [self _clearDocument];
    
    __block map<string, AGNode *> uuid2node;
    
    doc.recreate(^(const AGDocument::Node &docNode) {
        AGNode *node = NULL;
        if(docNode._class == AGDocument::Node::AUDIO)
            node = AGNodeManager::audioNodeManager().createNodeType(docNode);
        else if(docNode._class == AGDocument::Node::CONTROL)
            node = AGNodeManager::controlNodeManager().createNodeType(docNode);
        else if(docNode._class == AGDocument::Node::INPUT)
            node = AGNodeManager::inputNodeManager().createNodeType(docNode);
        else if(docNode._class == AGDocument::Node::OUTPUT)
            node = AGNodeManager::outputNodeManager().createNodeType(docNode);
        
        if(node != NULL)
        {
            uuid2node[node->uuid()] = node;
            [self addNode:node];
            
            if(node->type() == "Output")
            {
                AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
                outputNode->setOutputDestination([AGAudioManager instance].masterOut);
            }
        }
    }, ^(const AGDocument::Connection &docConnection) {
        if(uuid2node.count(docConnection.srcUuid) && uuid2node.count(docConnection.dstUuid))
        {
            AGNode *srcNode = uuid2node[docConnection.srcUuid];
            AGNode *dstNode = uuid2node[docConnection.dstUuid];
            assert(docConnection.dstPort >= 0 && docConnection.dstPort < dstNode->numInputPorts());
            assert(docConnection.srcPort >= 0 && docConnection.srcPort < srcNode->numOutputPorts());
            AGConnection::connect(srcNode, docConnection.srcPort, dstNode, docConnection.dstPort);
        }
    }, ^(const AGDocument::Freedraw &docFreedraw) {
        AGFreeDraw *freedraw = new AGFreeDraw(docFreedraw);
        freedraw->init();
        [self addTopLevelObject:freedraw];
    });
}



@end


