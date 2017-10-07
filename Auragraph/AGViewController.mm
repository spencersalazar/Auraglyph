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
#import "AGFreeDraw.h"
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
#import "AGDashboard.h"
#import "NSString+STLString.h"
#import "AGPGMidiContext.h"
#import "AGGraphManager.h"

#import <list>
#import <map>

using namespace std;


#define AG_ENABLE_FBO 0
#define AG_DEFAULT_FILENAME "_default"

#define AG_DO_TRAINER 0
#define AG_RESET_DOCUMENT 0

#define AG_EXPORT_NODES 1
#define AG_EXPORT_NODES_FILE @"nodes.json"

#define AG_ZOOM_DEADZONE (15)

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
    float _initialZoomDist;
    BOOL _passedZoomDeadzone;
    
    map<UITouch *, UITouch *> _touches;
    map<UITouch *, UITouch *> _freeTouches;
    UITouch *_scrollZoomTouches[2];
    map<UITouch *, AGTouchHandler *> _touchHandlers;
    map<UITouch *, AGInteractiveObject *> _touchCaptures;
    AGTouchHandler *_touchHandlerQueue;
    
    std::list<AGNode *> _nodes;
    std::map<std::string, AGNode *> _uuid2Node;
    std::list<AGFreeDraw *> _freedraws;
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
    
    AGPGMidiContext *midiManager;
    
    AGDrawMode _drawMode;
    InterfaceMode _interfaceMode;
    
    AGDashboard *_uiDashboard;
    
    std::string _currentDocumentFilename;
    
    AGViewController_ *_proxy;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) AGAudioManager *audioManager;
@property (nonatomic) AGDrawMode drawMode;

@property (strong) IBOutlet AGTrainerViewController *trainer;

- (void)removeFromTouchCapture:(AGInteractiveObject *)object;
- (void)setupGL;
- (void)tearDownGL;
- (void)initUI;
- (void)_updateFixedUIPosition;
- (void)updateMatrices;
- (void)renderEdit;
- (void)renderUser;

- (void)_save:(BOOL)saveAs;
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
    
    _proxy = new AGViewController_(self);
    
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
    _cameraZ.rate = 0.4;
    _cameraZ.reset(0);
    
    AGGraphManager::instance().setViewController(_proxy);
    
    // Set up our MIDI context
    midiManager = new AGPGMidiContext;
    midiManager->setup();
    
    self.audioManager = [AGAudioManager new];
    // update matrices so that worldCoordinateForScreenCoordinate works
    [self updateMatrices];
    
    /* preload hw recognizer */
    (void) [AGHandwritingRecognizer instance];
    
    [self initUI];
    
    /* load default program */
    std::string _lastOpened = AGPreferences::instance().lastOpenedDocument();
    if(_lastOpened.size() != 0)
    {
        _currentDocumentFilename = _lastOpened;
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
    
#if AG_EXPORT_NODES
    NSMutableArray *audioNodes = [NSMutableArray new];
    NSMutableArray *controlNodes = [NSMutableArray new];
    
    auto processNodes = [](const std::vector<const AGNodeManifest *> &nodeList, NSMutableArray *nodes) {
        for(auto node : nodeList)
        {
            NSMutableArray *params = [NSMutableArray new];
            NSMutableArray *ports = [NSMutableArray new];
            NSMutableDictionary *icon = [NSMutableDictionary new];
            
            for(auto param : node->editPortInfo())
                [params addObject:@{ @"name": [NSString stringWithSTLString:param.name],
                                     @"desc": [NSString stringWithSTLString:param.doc] }];
            
            for(auto port : node->inputPortInfo())
                [ports addObject:@{ @"name": [NSString stringWithSTLString:port.name],
                                    @"desc": [NSString stringWithSTLString:port.doc] }];
            
            NSMutableArray *iconGeo = [NSMutableArray new];
            for(auto pt : node->iconGeo())
                [iconGeo addObject:@{ @"x": @(pt.x), @"y": @(pt.y)}];
            icon[@"geo"] = iconGeo;
            
            switch(node->iconGeoType())
            {
                case GL_LINES: icon[@"type"] = @"lines"; break;
                case GL_LINE_STRIP: icon[@"type"] = @"line_strip"; break;
                case GL_LINE_LOOP: icon[@"type"] = @"line_loop"; break;
                default: assert(0);
            }
            
            [nodes addObject:@{
                               @"name": [NSString stringWithSTLString:node->type()],
                               @"desc": [NSString stringWithSTLString:node->description()],
                               @"icon": icon,
                               @"params": params,
                               @"ports": ports
                               }];
        }
    };
    
    processNodes(AGNodeManager::audioNodeManager().nodeTypes(), audioNodes);
    processNodes(AGNodeManager::controlNodeManager().nodeTypes(), controlNodes);
    
    NSDictionary *nodes = @{ @"audio": audioNodes, @"control": controlNodes };
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:nodes options:NSJSONWritingPrettyPrinted error:&error];
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *nodeInfoPath = [documentPath stringByAppendingPathComponent:AG_EXPORT_NODES_FILE];
    NSLog(@"writing node info to: %@", nodeInfoPath);
    [jsonData writeToFile:nodeInfoPath atomically:YES];
    
#endif // AG_EXPORT_NODES
    
    // force document list load
    (void) AGDocumentManager::instance().list();
    std::string filename = "jawharp.json";
    AGDocument doc = AGDocumentManager::instance().load(_currentDocumentFilename);
    _currentDocumentFilename = filename;
    [self _loadDocument:doc];
}

- (void)initUI
{
    // needed for worldCoordinateForScreenCoordinate to work
    [self updateMatrices];
    
    _uiDashboard = new AGDashboard(_proxy);
    _uiDashboard->init();
    
    _drawMode = DRAWMODE_NODE;
    
//    _interfaceMode = INTERFACEMODE_USER;
    _interfaceMode = INTERFACEMODE_EDIT;
    
    /* trash */
    AGUITrash::instance().setPosition([self fixedCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-30, self.view.bounds.size.height-20)]);
}

- (void)_updateFixedUIPosition
{
    // needed for worldCoordinateForScreenCoordinate to work
    [self updateMatrices];
    
    _uiDashboard->onInterfaceOrientationChange();
    
    AGUITrash::instance().setPosition([self fixedCoordinateForScreenCoordinate:CGPointMake(self.view.bounds.size.width-30, self.view.bounds.size.height-30)]);
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    SAFE_DELETE(_proxy);
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
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // 
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self _updateFixedUIPosition];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self _updateFixedUIPosition];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glEnable(GL_DEPTH_TEST);
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
    _uuid2Node[node->uuid()] = node;
    
    AGInteractiveObject * ui = node->userInterface();
    if(ui)
        _interfaceObjects.push_back(ui);
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
        _uuid2Node.erase(node->uuid());
    }
}

- (const list<AGNode *> &)nodes
{
    return _nodes;
}

- (AGNode *)nodeWithUUID:(const std::string &)uuid
{
    if(_uuid2Node.count(uuid))
        return _uuid2Node[uuid];
    else
        return NULL;
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
    {
        _nodes.remove(node);
        _uuid2Node.erase(node->uuid());
    }
    _dashboard.remove(object);
    
    AGFreeDraw *draw = dynamic_cast<AGFreeDraw *>(object);
    if(draw)
        _freedraws.remove(draw);
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
    
    _freedraws.push_back(freedraw);
    _objects.push_back(freedraw);
}

//- (void)replaceFreeDraw:(AGFreeDraw *)freedrawOld freedrawNew:(AGFreeDraw *)freedrawNew
//{
//    assert([NSThread isMainThread]);
//    assert(freedrawOld);
//    
//    _freedraws.remove(freedrawOld);
//    _objects.remove(freedrawOld);
//    
//    _freedraws.push_back(freedrawNew);
//    _objects.push_back(freedrawNew);
//}

- (void)resignFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    assert(freedraw);
    
    _freedraws.remove(freedraw);
    _objects.remove(freedraw);
}

- (void)removeFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    assert(freedraw);
    
    _freedraws.remove(freedraw);
    _fadingOut.push_back(freedraw);
}

- (const list<AGFreeDraw *> &)freedraws
{
    return _freedraws;
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
                                             -self.view.bounds.size.height/2, self.view.bounds.size.height/2,
                                             10.0f, 10000.0f);
//    else
//        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f)/aspect, aspect, 0.1f, 100.0f);
    
    _fixedModelView = GLKMatrix4MakeTranslation(0, 0, -10.1f);
    
    dbgprint_off("cameraZ: %f\n", (float) _cameraZ);
    
    float cameraScale = 1.0;
    if(_cameraZ > 0)
        _cameraZ.reset(0);
    if(_cameraZ < -160)
        _cameraZ.reset(-160);
    if(_cameraZ <= 0)
        _camera.z = -0.1-(-1+powf(2, -_cameraZ*0.045));
//    else
//        cameraScale = _cameraZ*0.045;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4Translate(_fixedModelView, _camera.x, _camera.y, _camera.z);
    if(_interfaceMode == INTERFACEMODE_USER)
        baseModelViewMatrix = GLKMatrix4Translate(baseModelViewMatrix, 0, 0, -(G_RATIO-1));
    if(cameraScale > 1.0f)
        baseModelViewMatrix = GLKMatrix4Scale(baseModelViewMatrix, cameraScale, cameraScale, 1.0f);
    
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
    
    // get window-z coordinate at (0, 0, 0)
    GLKVector3 probe = GLKMathProject(GLKVector3Make(0, 0, 0), _modelView, _projection, viewport);
    
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, self.view.bounds.size.height-p.y, probe.z),
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
    
    _uiDashboard->update(_t, dt);
    
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
    glClearColor(AGStyle::backgroundColor().r, AGStyle::backgroundColor().g, AGStyle::backgroundColor().b, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self renderEdit];
    
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
    _uiDashboard->render();
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
    
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(AGVertexAttribPosition);
    glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &overlayColor);
    glDisableVertexAttribArray(AGVertexAttribPosition);
    glVertexAttribPointer(0, 3, GL_FLOAT, FALSE, 0, &overlayGeo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
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
    dbgprint_off("touchesBegan, count = %i\n", [touches count]);
    
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
        
        if(touchCapture == NULL)
        {
            touchCapture = _uiDashboard->hitTest(fixedPos);
            if(touchCapture)
                touchCaptureTopLevelObject = _uiDashboard;
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
                
                CGPoint p1 = [_scrollZoomTouches[0] locationInView:self.view];
                CGPoint p2 = [_scrollZoomTouches[1] locationInView:self.view];
                _initialZoomDist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
                _passedZoomDeadzone = NO;
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
                    case DRAWMODE_FREEDRAW_ERASE:
                        handler = [[AGEraseFreedrawTouchHandler alloc] initWithViewController:self];
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
                touchCapture->touchDown(AGTouchInfo(fixedPos, p, (TouchID) touch, touch));
            else
            {
                GLvertex3f localPos = pos;
                if(touchCapture->parent())
                    // touchDown/Move/Up events treat the position as if it were in the parent coordinate space
                    localPos = touchCapture->parent()->globalToLocalCoordinateSpace(localPos);
                touchCapture->touchDown(AGTouchInfo(localPos, p, (TouchID) touch, touch));
            }
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
    dbgprint_off("touchesMoved, count = %i\n", [touches count]);
    
    BOOL didScroll = NO;
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint screenPos = [touch locationInView:self.view];
                
                if(touchCapture->renderFixed())
                {
                    GLvertex3f fixedPos = [self fixedCoordinateForScreenCoordinate:screenPos];
                    touchCapture->touchMove(AGTouchInfo(fixedPos, screenPos, (TouchID) touch, touch));
                }
                else
                {
                    GLvertex3f localPos = [self worldCoordinateForScreenCoordinate:screenPos];
                    if(touchCapture->parent())
                        // touchDown/Move/Up events treat the position as if it were in the parent coordinate space
                        localPos = touchCapture->parent()->globalToLocalCoordinateSpace(localPos);
                    touchCapture->touchMove(AGTouchInfo(localPos, screenPos, (TouchID) touch, touch));
                }
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
                dbgprint_off("camera: %f, %f, %f\n", _camera.x, _camera.y, _camera.z);
                
                float dist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
                float dist_1 = GLvertex2f(p1_1).distanceTo(GLvertex2f(p2_1));
                if(!_passedZoomDeadzone &&
                   (dist_1 > _initialZoomDist+AG_ZOOM_DEADZONE ||
                    dist_1 < _initialZoomDist-AG_ZOOM_DEADZONE))
                {
                    dbgprint("passed zoom deadzone\n");
                    _passedZoomDeadzone = YES;
                }
                if(_passedZoomDeadzone)
                {
                    float zoom = (dist - dist_1);
                    _cameraZ += zoom;
                }
            }
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    dbgprint_off("touchEnded, count = %i\n", [touches count]);
    
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint screenPos = [touch locationInView:self.view];

                if(touchCapture->renderFixed())
                {
                    GLvertex3f fixedPos = [self fixedCoordinateForScreenCoordinate:screenPos];
                    touchCapture->touchUp(AGTouchInfo(fixedPos, screenPos, (TouchID) touch, touch));
                }
                else
                {
                    GLvertex3f localPos = [self worldCoordinateForScreenCoordinate:screenPos];
                    if(touchCapture->parent())
                        // touchDown/Move/Up events treat the position as if it were in the parent coordinate space
                        localPos = touchCapture->parent()->globalToLocalCoordinateSpace(localPos);
                    touchCapture->touchUp(AGTouchInfo(localPos, screenPos, (TouchID) touch, touch));
                }

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



- (void)_save:(BOOL)saveAs
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
    
    if(_currentDocumentFilename.size() == 0 || saveAs)
    {
        AGUISaveDialog *saveDialog = AGUISaveDialog::save(doc);
        
        saveDialog->onSave([self](const std::string &filename){
            _currentDocumentFilename = filename;
            AGPreferences::instance().setLastOpenedDocument(_currentDocumentFilename);
        });
        
        _dashboard.push_back(saveDialog);
    }
    else
    {
        AGDocumentManager::instance().update(_currentDocumentFilename, doc);
    }
}

- (void)_openLoad
{
    AGUILoadDialog *loadDialog = AGUILoadDialog::load();
    
    loadDialog->onLoad([self](const std::string &filename, AGDocument &doc){
        _currentDocumentFilename = filename;
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
    
    AGPreferences::instance().setLastOpenedDocument(_currentDocumentFilename);
    
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
//        [self addTopLevelObject:freedraw];
        [self addFreeDraw:freedraw];

    });
}



@end


AGViewController_::AGViewController_(AGViewController *viewController)
{
    m_viewController = viewController;
}

AGViewController_::~AGViewController_()
{ }
    
void AGViewController_::createNew()
{
    [m_viewController _newDocument];
}

void AGViewController_::save()
{
    [m_viewController _save:NO];
}

void AGViewController_::saveAs()
{
    [m_viewController _save:YES];
}

void AGViewController_::load()
{
    [m_viewController _openLoad];
}

void AGViewController_::showTrainer()
{
    [m_viewController presentViewController:m_viewController.trainer animated:YES completion:nil];
}

void AGViewController_::showAbout()
{
    AGAboutBox *aboutBox = new AGAboutBox([m_viewController fixedCoordinateForScreenCoordinate:CGPointMake(m_viewController.view.bounds.size.width/2,
                                                                                                           m_viewController.view.bounds.size.height/2)]);
    aboutBox->init();
    [m_viewController addTopLevelObject:aboutBox];
}

void AGViewController_::startRecording()
{
    [[AGAudioManager instance] startSessionRecording];
}

void AGViewController_::stopRecording()
{
    [[AGAudioManager instance] stopSessionRecording];
}

void AGViewController_::setDrawMode(AGDrawMode mode)
{
    m_viewController.drawMode = mode;
}

GLvertex3f AGViewController_::worldCoordinateForScreenCoordinate(CGPoint p)
{
    return [m_viewController worldCoordinateForScreenCoordinate:p];
}

GLvertex3f AGViewController_::fixedCoordinateForScreenCoordinate(CGPoint p)
{
    return [m_viewController fixedCoordinateForScreenCoordinate:p];
}

CGRect AGViewController_::bounds()
{
    return m_viewController.view.bounds;
}

void AGViewController_::addNodeToTopLevel(AGNode *node)
{
    [m_viewController addNode:node];
}

AGNode *AGViewController_::nodeWithUUID(const std::string &uuid)
{
    return [m_viewController nodeWithUUID:uuid];
}
