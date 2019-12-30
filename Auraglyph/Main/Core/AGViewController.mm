//
//  AGViewController.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGViewController.h"

// Basics
#import "AGDef.h"
#import "Geometry.h"
#import "GeoGenerator.h"
#import "spstl.h"
#import "TexFont.h"
#import "NSString+STLString.h"
#import "AGUtility.h"
#import "AGSettings.h"

// Data model
#import "AGInteractiveObject.h"
#import "AGNode.h"
#import "AGFreeDraw.h"

// Managers/etc
#import "AGHandwritingRecognizer.h"
#import "AGGraphManager.h"
#import "AGFileManager.h"
#import "AGGraph.h"
#import "AGAudioManager.h"
#import "AGGenericShader.h"
#import "AGActivityManager.h"
#import "AGUndoManager.h"
#import "AGAnalytics.h"
#import "AGNodeExporter.h"

// Touch handlers
#import "AGTouchHandler.h"
#import "AGConnectTouchHandler.h"
#import "AGMoveNodeTouchHandler.h"
#import "AGDrawNodeTouchHandler.h"
#import "AGDrawFreedrawTouchHandler.h"
#import "AGEraseFreedrawTouchHandler.h"

// Document management
#import "AGDocument.h"
#import "AGDocumentManager.h"

// UI
#import "AGUserInterface.h"
#import "AGTrainerViewController.h"
#import "AGDashboard.h"
#import "AGAboutBox.h"
#import "AGUISaveDialog.h"
#import "AGUILoadDialog.h"
#import "AGSettings.h"
#import "AGTutorial.h"
#import "AGModalDialog.h"

// MIDI (for some reason?)
#import "AGPGMidiContext.h"

// STL
#import <list>
#import <map>

using namespace std;


#define AG_EXPORT_NODES 1
#define AG_EXPORT_NODES_FILE "nodes.json"

#define AG_ZOOM_DEADZONE (15)


/** Basic model for Auraglyph sketch- nodes + freehand drawings
 */
class AGModel
{
public:
    
    AGGraph graph;
    std::list<AGFreeDraw *> freedraws;
};

/** Rendering model (things that are drawn to screen)
 */
class AGRenderModel
{
public:
    GLKMatrix4 modelView;
    GLKMatrix4 fixedModelView;
    GLKMatrix4 projection;
    
    float t;
    GLvertex3f camera;
    slewf cameraZ;
    
    AGInteractiveObjectList dashboard;
    AGInteractiveObjectList objects;
    AGInteractiveObjectList fadingOut;
    
    AGDashboard *uiDashboard;
    AGModalOverlay modalOverlay;
    AGTutorial *currentTutorial;
};

/** Top level touch handler - process touch input
 */
class AGBaseTouchHandler
{
public:
    AGBaseTouchHandler(AGViewController* viewController, AGModel& model, AGRenderModel& renderModel);
    
    void touchesBegan(NSSet<UITouch *> *touches, UIEvent *event);
    void touchesMoved(NSSet<UITouch *> *touches, UIEvent *event);
    void touchesEnded(NSSet<UITouch *> *touches, UIEvent *event);
    void touchesCancelled(NSSet<UITouch *> *touches, UIEvent *event);
    
    void addTouchOutsideHandler(AGTouchHandler* handler);
    void removeTouchOutsideHandler(AGTouchHandler* handler);
    void addTouchOutsideListener(AGInteractiveObject* object);
    void removeTouchOutsideListener(AGInteractiveObject* object);

    void resignTouchHandler(AGTouchHandler* handler);
    void objectRemovedFromSketchModel(AGInteractiveObject* object);
    void objectRemovedFromRenderModel(AGInteractiveObject* object);
    
    void setDrawMode(AGDrawMode mode) { m_drawMode = mode; }
    AGDrawMode drawMode() { return m_drawMode; }

    AGNode::HitTestResult hitTest(const GLvertex3f& pos, AGNode **hitNode, int* port);
    
    void update(float t, float dt);
    void render();
    
private:
    void _removeFromTouchCapture(AGInteractiveObject *object);
    
    AGViewController* m_viewController = nil;
    AGModel& m_model;
    AGRenderModel& m_renderModel;
    
    AGDrawMode m_drawMode = DRAWMODE_NODE;
    
    float _initialZoomDist = 0;
    bool _passedZoomDeadzone = false;
    
    map<UITouch *, UITouch *> _touches;
    map<UITouch *, UITouch *> _freeTouches;
    UITouch *_scrollZoomTouches[2];
    map<UITouch *, AGTouchHandler *> _touchHandlers;
    map<UITouch *, AGInteractiveObject *> _touchCaptures;
    AGTouchHandler *_touchHandlerQueue = nil;
            
    AGInteractiveObjectList _touchOutsideListeners;
    list<AGTouchHandler *> _touchOutsideHandlers;
};


@interface AGViewController ()
{
    AGModel _model;
    AGRenderModel _renderModel;
    std::unique_ptr<AGBaseTouchHandler> _baseTouchHandler;
    
    AGPGMidiContext *midiManager;
    
    AGFile _currentDocumentFile;
    std::vector<std::vector<GLvertex2f>> _currentDocName;
    
    AGViewController_ *_proxy;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) AGAudioManager *audioManager;
@property (nonatomic) AGDrawMode drawMode;

@property (strong) IBOutlet AGTrainerViewController *trainer;

- (void)setupGL;
- (void)tearDownGL;
- (void)initUI;
- (void)_updateFixedUIPosition;
- (void)updateMatrices;
- (void)renderEdit;

- (void)_save:(BOOL)saveAs;
- (void)_openLoad;
- (void)_clearDocument;
- (void)_newDocument:(BOOL)createDefaultOutputNode;
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

- (GLKMatrix4)modelViewMatrix { return _renderModel.modelView; }
- (GLKMatrix4)fixedModelViewMatrix { return _renderModel.fixedModelView; }
- (GLKMatrix4)projectionMatrix { return _renderModel.projection; }

- (AGDrawMode)drawMode{ return _baseTouchHandler->drawMode(); }
- (void)setDrawMode:(AGDrawMode)mode { _baseTouchHandler->setDrawMode(mode); }

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    g_instance = self;
        
    _renderModel.t = 0;
    
    _proxy = new AGViewController_(self);
    _baseTouchHandler.reset(new AGBaseTouchHandler(self, _model, _renderModel));
    
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
    
    _renderModel.camera = GLvertex3f(0, 0, 0);
    _renderModel.cameraZ.rate = 0.4;
    _renderModel.cameraZ.reset(0);
    
    AGGraphManager::instance().setViewController(_proxy);
    
    // Set up our MIDI context
    midiManager = new AGPGMidiContext;
    midiManager->setup();
    
    self.audioManager = [AGAudioManager new];
    // update matrices so that worldCoordinateForScreenCoordinate works
    [self updateMatrices];
    
    /* preload hw recognizer */
    (void) AGHandwritingRecognizer::instance();
    
    [self initUI];
    
    if (AGSettings::instance().showTutorialOnLaunch()) {
        _renderModel.currentTutorial = AGTutorial::createInitialTutorial(_proxy);
        [self _newDocument:NO];
    } else {
        /* load default program */
        AGFile _lastOpened = AGSettings::instance().lastOpenedDocument();
        if(_lastOpened.m_filename.size() != 0 && AGFileManager::instance().fileExists(_lastOpened))
        {
            _currentDocumentFile = _lastOpened;
            AGDocument doc = AGDocumentManager::instance().load(_lastOpened);
            [self _loadDocument:doc];
        }
        else
        {
            [self _newDocument:YES];
        }
        
        AGUtility::after(0.8, [self](){
            _renderModel.uiDashboard->unhide();
        });
    }
    
    g_instance = self;
    
#if AG_EXPORT_NODES
    AGNodeExporter::exportNodes(AG_EXPORT_NODES_FILE);
#endif // AG_EXPORT_NODES
    
    AGActivityManager::instance().addActivityListener(&AGUndoManager::instance());
}

- (void)initUI
{
    // needed for worldCoordinateForScreenCoordinate to work
    [self updateMatrices];
    
    _renderModel.uiDashboard = new AGDashboard(_proxy);
    _renderModel.uiDashboard->init();
     
    self.drawMode = DRAWMODE_NODE;
    
    /* modal dialog */
    _renderModel.modalOverlay.init();
    AGModalDialog::setGlobalModalOverlay(&_renderModel.modalOverlay);
    
    /* fade in */
    _renderModel.uiDashboard->hide(false);
}

- (void)_updateFixedUIPosition
{
    // needed for worldCoordinateForScreenCoordinate to work
    [self updateMatrices];
    
    _renderModel.uiDashboard->onInterfaceOrientationChange();
    
    _renderModel.modalOverlay.setScreenSize(GLvertex2f(self.view.bounds.size.width, self.view.bounds.size.height));
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
    
    _model.graph.addNode(node);
    _renderModel.objects.push_back(node);
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
    if(_model.graph.hasNode(node))
    {
        _model.graph.removeNode(node);
        _renderModel.objects.remove(node);
        
        _baseTouchHandler->objectRemovedFromSketchModel(node);
    }
}

- (AGGraph *)graph
{
    return &_model.graph;
}

- (void)addTopLevelObject:(AGInteractiveObject *)object
{
    assert([NSThread isMainThread]);
    assert(object);
    
    _renderModel.objects.push_back(object);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object over:(AGInteractiveObject *)over
{
    assert([NSThread isMainThread]);
    assert(object);
    
    insert_after(_renderModel.objects, object, over);
}

- (void)addTopLevelObject:(AGInteractiveObject *)object under:(AGInteractiveObject *)under
{
    assert([NSThread isMainThread]);
    assert(object);
    
    insert_before(_renderModel.objects, object, under);
}

- (void)fadeOutAndDelete:(AGInteractiveObject *)object
{
    assert([NSThread isMainThread]);
    assert(object);
//    assert(dynamic_cast<AGConnection *>(object) == NULL);
    
    dbgprint("fadeOutAndDelete: %s 0x%08lx\n", typeid(*object).name(), (unsigned long) object);
    
    _baseTouchHandler->objectRemovedFromRenderModel(object);
    
    assert(!contains(_renderModel.fadingOut, object));
    if(!contains(_renderModel.fadingOut, object)) {
        object->renderOut();
        _renderModel.fadingOut.push_back(object);
    }
    
    _renderModel.objects.remove(object);
    AGNode *node = dynamic_cast<AGNode *>(object);
    if(node)
        _model.graph.removeNode(node);
    _renderModel.dashboard.remove(object);
    
    AGFreeDraw *draw = dynamic_cast<AGFreeDraw *>(object);
    if(draw)
        _model.freedraws.remove(draw);
}

- (void)addFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    
    _model.freedraws.push_back(freedraw);
    _renderModel.objects.push_back(freedraw);
}

- (void)resignFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    assert(freedraw);
    
    _model.freedraws.remove(freedraw);
    _renderModel.objects.remove(freedraw);
}

- (void)removeFreeDraw:(AGFreeDraw *)freedraw
{
    assert([NSThread isMainThread]);
    assert(freedraw);
    
    _model.freedraws.remove(freedraw);
    _renderModel.fadingOut.push_back(freedraw);
}

- (const list<AGFreeDraw *> &)freedraws
{
    return _model.freedraws;
}

- (void) showDashboard
{
    _renderModel.uiDashboard->unhide();
}

- (void) hideDashboard
{
    _renderModel.uiDashboard->hide();
}

- (void)showTutorial:(AGTutorial *)tutorial
{
    if (tutorial != _renderModel.currentTutorial)
        SAFE_DELETE(_renderModel.currentTutorial);
    [self _newDocument:NO];
    _renderModel.currentTutorial = tutorial;
}

- (void)addTouchOutsideListener:(AGInteractiveObject *)listener
{
    assert([NSThread isMainThread]);
    _baseTouchHandler->addTouchOutsideListener(listener);
}

- (void)removeTouchOutsideListener:(AGInteractiveObject *)listener
{
    assert([NSThread isMainThread]);
    
    _baseTouchHandler->removeTouchOutsideListener(listener);
}

- (void)addTouchOutsideHandler:(AGTouchHandler *)listener
{
    dbgprint("addTouchOutsideHandler: %s 0x%08lx\n", [NSStringFromClass([listener class]) UTF8String], (unsigned long) listener);
    
    _baseTouchHandler->addTouchOutsideHandler(listener);
}

- (void)removeTouchOutsideHandler:(AGTouchHandler *)listener
{
    dbgprint("removeTouchOutsideHandler: %s 0x%08lx\n", [NSStringFromClass([listener class]) UTF8String], (unsigned long) listener);

    _baseTouchHandler->removeTouchOutsideHandler(listener);
}

- (void)resignTouchHandler:(AGTouchHandler *)handler
{
    _baseTouchHandler->resignTouchHandler(handler);
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)updateMatrices
{
    GLKMatrix4 projectionMatrix;
    projectionMatrix = GLKMatrix4MakeFrustum(-self.view.bounds.size.width/2, self.view.bounds.size.width/2,
                                             -self.view.bounds.size.height/2, self.view.bounds.size.height/2,
                                             10.0f, 10000.0f);
    
    _renderModel.fixedModelView = GLKMatrix4MakeTranslation(0, 0, -10.1f);
    
    dbgprint_off("cameraZ: %f\n", (float) _renderModel.cameraZ);
    
    float cameraScale = 1.0;
    if(_renderModel.cameraZ > 0)
        _renderModel.cameraZ.reset(0);
    if(_renderModel.cameraZ < -160)
        _renderModel.cameraZ.reset(-160);
    if(_renderModel.cameraZ <= 0)
        _renderModel.camera.z = -0.1-(-1+powf(2, -_renderModel.cameraZ*0.045));
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4Translate(_renderModel.fixedModelView, _renderModel.camera.x, _renderModel.camera.y, _renderModel.camera.z);
    if(cameraScale > 1.0f)
        baseModelViewMatrix = GLKMatrix4Scale(baseModelViewMatrix, cameraScale, cameraScale, 1.0f);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _renderModel.modelView = modelViewMatrix;
    _renderModel.projection = projectionMatrix;
    
    AGRenderObject::setProjectionMatrix(projectionMatrix);
    AGRenderObject::setGlobalModelViewMatrix(modelViewMatrix);
    AGRenderObject::setFixedModelViewMatrix(_renderModel.fixedModelView);
    AGRenderObject::setCameraMatrix(GLKMatrix4MakeTranslation(_renderModel.camera.x, _renderModel.camera.y, _renderModel.camera.z));
}

- (GLvertex3f)worldCoordinateForScreenCoordinate:(CGPoint)p
{
    int viewport[] = { (int)self.view.bounds.origin.x, (int)(self.view.bounds.origin.y),
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    bool success;
    
    // get window-z coordinate at (0, 0, 0)
    GLKVector3 probe = GLKMathProject(GLKVector3Make(0, 0, 0), _renderModel.modelView, _renderModel.projection, viewport);
    
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, self.view.bounds.size.height-p.y, probe.z),
                                      _renderModel.modelView, _renderModel.projection, viewport, &success);
    
    return GLvertex3f(vec.x, vec.y, 0);
}

- (GLvertex3f)fixedCoordinateForScreenCoordinate:(CGPoint)p
{
    int viewport[] = { (int)self.view.bounds.origin.x, (int)(self.view.bounds.origin.y),
        (int)self.view.bounds.size.width, (int)self.view.bounds.size.height };
    bool success;
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, self.view.bounds.size.height-p.y, 0.0f),
                                      _renderModel.fixedModelView,
                                      _renderModel.projection,
                                      viewport, &success);
    
    return GLvertex3f(vec.x, vec.y, 0);
}

- (void)update
{
    if(_renderModel.fadingOut.size() > 0) {
        filter_delete(_renderModel.fadingOut, [](AGInteractiveObject *&obj){
            assert(obj);
            return obj->finishedRenderingOut();
        });
    }
    
    _renderModel.cameraZ.interp();
    
    [self updateMatrices];
    
    float dt = self.timeSinceLastUpdate;
    _renderModel.t += dt;
    
    _renderModel.uiDashboard->update(_renderModel.t, dt);
    
    _renderModel.modalOverlay.update(_renderModel.t, dt);
    
    itmap_safe(_renderModel.dashboard, ^(AGInteractiveObject *&object){
        object->update(_renderModel.t, dt);
    });
    itmap_safe(_renderModel.objects, ^(AGInteractiveObject *&object){
        object->update(_renderModel.t, dt);
    });
    itmap_safe(_renderModel.fadingOut, ^(AGInteractiveObject *&object){
        object->update(_renderModel.t, dt);
    });
    
    _baseTouchHandler->update(_renderModel.t, dt);
    
    if(_renderModel.currentTutorial)
    {
        _renderModel.currentTutorial->update(_renderModel.t, dt);
        if(_renderModel.currentTutorial->isComplete())
            SAFE_DELETE(_renderModel.currentTutorial);
    }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(AGStyle::backgroundColor().r, AGStyle::backgroundColor().g, AGStyle::backgroundColor().b, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self renderEdit];
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
    
    // render objects
    for(AGInteractiveObject *object : _renderModel.objects)
        object->render();
    // render removeList
    for(AGInteractiveObject *removeObject : _renderModel.fadingOut)
        removeObject->render();
    // render user interface
    _renderModel.uiDashboard->render();
    for(AGInteractiveObject *object : _renderModel.dashboard)
        object->render();
    
    _baseTouchHandler->render();
    
    if(_renderModel.currentTutorial)
        _renderModel.currentTutorial->render();
    
    _renderModel.modalOverlay.render();
}

#pragma Touch handling

- (AGNode::HitTestResult)hitTest:(GLvertex3f)pos node:(AGNode **)hitNode port:(int *)port
{
    return _baseTouchHandler->hitTest(pos, hitNode, port);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    _baseTouchHandler->touchesBegan(touches, event);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    _baseTouchHandler->touchesMoved(touches, event);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _baseTouchHandler->touchesEnded(touches, event);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _baseTouchHandler->touchesCancelled(touches, event);
}

- (void)_save:(BOOL)saveAs
{
    __block AGDocument doc;
    
    for(AGNode *node : _model.graph.nodes())
    {
        AGDocument::Node docNode = node->serialize();
        doc.addNode(docNode);
    }
    
    itmap(_model.freedraws, ^(AGFreeDraw *&freedraw) {
        AGDocument::Freedraw docFreedraw = freedraw->serialize();
        doc.addFreedraw(docFreedraw);
    });
    
    if(_currentDocumentFile.m_filename.size() == 0 || saveAs)
    {
        AGUISaveDialog *saveDialog = AGUISaveDialog::save(doc);
        
        saveDialog->onSave([self](const AGFile &file, const vector<vector<GLvertex2f>> &name) {
            _currentDocumentFile = file;
            _currentDocName = name;
            AGSettings::instance().setLastOpenedDocument(_currentDocumentFile);
        });
        
        _renderModel.dashboard.push_back(saveDialog);
    }
    else
    {
        doc.setName(_currentDocName);
        AGDocumentManager::instance().update(_currentDocumentFile, doc);
    }
}

- (void)_openLoad
{
    AGUILoadDialog *loadDialog = AGUILoadDialog::load();
    
    loadDialog->onLoad([self](const AGFile &file, AGDocument &doc){
        _currentDocumentFile = file;
        [self _loadDocument:doc];
    });
    
    loadDialog->onUtility([self](const AGFile &file){
        AGDocumentManager::instance().remove(file);
    });

    _renderModel.dashboard.push_back(loadDialog);
}

- (void)_openLoadExample
{
    AGUILoadDialog *loadDialog = AGUILoadDialog::loadExample();
    
    loadDialog->onLoad([self](const AGFile &file, AGDocument &doc){
        _currentDocumentFile = AGFile::UserFile("");
        [self _loadDocument:doc];
    });
    
    _renderModel.dashboard.push_back(loadDialog);
}

- (void)_clearDocument
{
    // delete all objects
    itmap_safe(_renderModel.objects, ^(AGInteractiveObject *&object){
        [self fadeOutAndDelete:object];
    });
}

- (void)_newDocument:(BOOL)createDefaultOutputNode
{
    [self _clearDocument];
    
    _currentDocumentFile = AGFile::UserFile("");
    _currentDocName = std::vector<std::vector<GLvertex2f>>();
    
    if (createDefaultOutputNode) {
        // just create output node by itself
        AGNode *node = AGNodeManager::audioNodeManager().createNodeOfType("Output", GLvertex3f(0, 0, 0));
        AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
        outputNode->setOutputDestination([AGAudioManager instance].masterOut);
        [self addNode:node];
    }
}

- (void)_loadDocument:(AGDocument &)doc
{
    [self _clearDocument];
    
    _currentDocName = doc.name();
    AGSettings::instance().setLastOpenedDocument(_currentDocumentFile);
    
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


AGBaseTouchHandler::AGBaseTouchHandler(AGViewController* viewController, AGModel& model, AGRenderModel& renderModel)
: m_viewController(viewController), m_model(model), m_renderModel(renderModel)
{ }

AGNode::HitTestResult AGBaseTouchHandler::hitTest(const GLvertex3f& pos, AGNode **hitNode, int* port)
{
    AGNode::HitTestResult hit;
    
    for(AGNode *node : m_model.graph.nodes())
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

void AGBaseTouchHandler::touchesBegan(NSSet<UITouch *> *touches, UIEvent *event)
{
    dbgprint_off("touchesBegan, count = %lu\n", (unsigned long)[touches count]);
    
    // hit test each touch
    for(UITouch *touch in touches)
    {
        CGPoint p = [touch locationInView:m_viewController.view];
        GLvertex3f pos = [m_viewController worldCoordinateForScreenCoordinate:p];
        GLvertex3f fixedPos = [m_viewController fixedCoordinateForScreenCoordinate:p];
        AGTouchHandler *handler = nil;
        AGInteractiveObject *touchCapture = NULL;
        AGInteractiveObject *touchCaptureTopLevelObject = NULL;
        
        // check modal overlay
        touchCapture = m_renderModel.modalOverlay.hitTest(fixedPos);
        if(touchCapture)
        {
            touchCaptureTopLevelObject = &m_renderModel.modalOverlay;
        }
        
        if(touchCapture == NULL)
        {
            // search dashboard items
            // search in reverse order
            for(auto i = m_renderModel.dashboard.rbegin(); i != m_renderModel.dashboard.rend(); i++)
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
        }
        
        if(touchCapture == NULL)
        {
            touchCapture = m_renderModel.uiDashboard->hitTest(fixedPos);
            if(touchCapture)
                touchCaptureTopLevelObject = m_renderModel.uiDashboard;
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
            for(auto i = m_renderModel.objects.rbegin(); i != m_renderModel.objects.rend(); i++)
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
                            handler = [[AGConnectTouchHandler alloc] initWithViewController:m_viewController];
                        else if(result == AGNode::HIT_MAIN_NODE)
                            handler = [[AGMoveNodeTouchHandler alloc] initWithViewController:m_viewController node:node];
                        
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
            for(AGNode *node : m_model.graph.nodes())
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
                
                CGPoint p1 = [_scrollZoomTouches[0] locationInView:m_viewController.view];
                CGPoint p2 = [_scrollZoomTouches[1] locationInView:m_viewController.view];
                _initialZoomDist = GLvertex2f(p1).distanceTo(GLvertex2f(p2));
                _passedZoomDeadzone = NO;
            }
            else
            {
                switch (m_drawMode)
                {
                    case DRAWMODE_NODE:
                        handler = [[AGDrawNodeTouchHandler alloc] initWithViewController:m_viewController];
                        break;
                    case DRAWMODE_FREEDRAW:
                        handler = [[AGDrawFreedrawTouchHandler alloc] initWithViewController:m_viewController];
                        break;
                    case DRAWMODE_FREEDRAW_ERASE:
                        handler = [[AGEraseFreedrawTouchHandler alloc] initWithViewController:m_viewController];
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

void AGBaseTouchHandler::touchesMoved(NSSet<UITouch *> *touches, UIEvent *event)
{
    dbgprint_off("touchesMoved, count = %lu\n", (unsigned long)[touches count]);
    
    BOOL didScroll = NO;
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint screenPos = [touch locationInView:m_viewController.view];
                
                if(touchCapture->renderFixed())
                {
                    GLvertex3f fixedPos = [m_viewController fixedCoordinateForScreenCoordinate:screenPos];
                    touchCapture->touchMove(AGTouchInfo(fixedPos, screenPos, (TouchID) touch, touch));
                }
                else
                {
                    GLvertex3f localPos = [m_viewController worldCoordinateForScreenCoordinate:screenPos];
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
                CGPoint p1 = [_scrollZoomTouches[0] locationInView:m_viewController.view];
                CGPoint p1_1 = [_scrollZoomTouches[0] previousLocationInView:m_viewController.view];
                CGPoint p2 = [_scrollZoomTouches[1] locationInView:m_viewController.view];
                CGPoint p2_1 = [_scrollZoomTouches[1] previousLocationInView:m_viewController.view];
                
                CGPoint centroid = CGPointMake((p1.x+p2.x)/2, (p1.y+p2.y)/2);
                CGPoint centroid_1 = CGPointMake((p1_1.x+p2_1.x)/2, (p1_1.y+p2_1.y)/2);
                
                GLvertex3f pos = [m_viewController worldCoordinateForScreenCoordinate:centroid];
                GLvertex3f pos_1 = [m_viewController worldCoordinateForScreenCoordinate:centroid_1];
                
                m_renderModel.camera = m_renderModel.camera + (pos.xy() - pos_1.xy());
                dbgprint_off("camera: %f, %f, %f\n", m_renderModel.camera.x, m_renderModel.camera.y, m_renderModel.camera.z);
                
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
                    m_renderModel.cameraZ += zoom;
                }
            }
        }
    }
}

void AGBaseTouchHandler::touchesEnded(NSSet<UITouch *> *touches, UIEvent *event)
{
    dbgprint_off("touchEnded, count = %lu\n", (unsigned long)[touches count]);
    
    for(UITouch *touch in touches)
    {
        if(_touchCaptures.count(touch))
        {
            AGInteractiveObject *touchCapture = _touchCaptures[touch];
            if(touchCapture != NULL)
            {
                CGPoint screenPos = [touch locationInView:m_viewController.view];

                if(touchCapture->renderFixed())
                {
                    GLvertex3f fixedPos = [m_viewController fixedCoordinateForScreenCoordinate:screenPos];
                    touchCapture->touchUp(AGTouchInfo(fixedPos, screenPos, (TouchID) touch, touch));
                }
                else
                {
                    GLvertex3f localPos = [m_viewController worldCoordinateForScreenCoordinate:screenPos];
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
                dbgprint("queuing touchHandler: %s 0x%08lx\n", [NSStringFromClass([nextHandler class]) UTF8String], (unsigned long) nextHandler);
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

void AGBaseTouchHandler::touchesCancelled(NSSet<UITouch *> *touches, UIEvent *event)
{
    touchesCancelled(touches, event);
}

void AGBaseTouchHandler::addTouchOutsideHandler(AGTouchHandler* handler)
{
    _touchOutsideHandlers.push_back(handler);
}

void AGBaseTouchHandler::removeTouchOutsideHandler(AGTouchHandler* handler)
{
    _touchOutsideHandlers.remove(handler);
}

void AGBaseTouchHandler::addTouchOutsideListener(AGInteractiveObject* object)
{
    _touchOutsideListeners.push_back(object);
}

void AGBaseTouchHandler::removeTouchOutsideListener(AGInteractiveObject* object)
{
    _touchOutsideListeners.remove(object);
}

void AGBaseTouchHandler::objectRemovedFromSketchModel(AGInteractiveObject* object)
{
    _removeFromTouchCapture(object);
}

void AGBaseTouchHandler::objectRemovedFromRenderModel(AGInteractiveObject* object)
{
    _removeFromTouchCapture(object);
}

void AGBaseTouchHandler::update(float t, float dt)
{
    for(auto kv : _touchHandlers)
        [_touchHandlers[kv.first] update:t dt:dt];
    [_touchHandlerQueue update:t dt:dt];
}

void AGBaseTouchHandler::render()
{
    for(auto kv : _touchHandlers)
        [_touchHandlers[kv.first] render];
    [_touchHandlerQueue render];
}

void AGBaseTouchHandler::_removeFromTouchCapture(AGInteractiveObject *object)
{
    // remove object and all children from touch capture
    std::function<void (AGRenderObject *obj)> removeAll = [&removeAll, object, this] (AGRenderObject *obj)
    {
        AGInteractiveObject *intObj = dynamic_cast<AGInteractiveObject *>(obj);
        if(intObj)
            removevalues(_touchCaptures, intObj);
        for(auto child : obj->children())
            removeAll(child);
    };
    
    removeAll(object);
}

void AGBaseTouchHandler::resignTouchHandler(AGTouchHandler* handler)
{
    removevalues(_touchHandlers, handler);
    _touchOutsideHandlers.remove(handler);
    if(handler == _touchHandlerQueue)
        _touchHandlerQueue = nil;
}


AGViewController_::AGViewController_(AGViewController *viewController)
{
    m_viewController = viewController;
}

AGViewController_::~AGViewController_()
{ }
    
void AGViewController_::createNew()
{
    [m_viewController _newDocument:YES];
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

void AGViewController_::loadExample()
{
    [m_viewController _openLoadExample];
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

void AGViewController_::addTopLevelObject(AGInteractiveObject *object)
{
    [m_viewController addTopLevelObject:object];
}

void AGViewController_::fadeOutAndDelete(AGInteractiveObject *object)
{
    [m_viewController fadeOutAndDelete:object];
}

void AGViewController_::addNodeToTopLevel(AGNode *node)
{
    [m_viewController addNode:node];
}

AGGraph *AGViewController_::graph()
{
    return [m_viewController graph];
}

void AGViewController_::showDashboard()
{
    [m_viewController showDashboard];
}

void AGViewController_::hideDashboard()
{
    [m_viewController hideDashboard];
}

void AGViewController_::showTutorial(AGTutorial *tutorial)
{
    [m_viewController showTutorial:tutorial];
}

