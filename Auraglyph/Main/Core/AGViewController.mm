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
#import "AGModel.h"
#import "AGRenderModel.h"

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
#import "AGBaseTouchHandler.h"

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
    _baseTouchHandler->addTouchOutsideHandler(listener);
}

- (void)removeTouchOutsideHandler:(AGTouchHandler *)listener
{
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

