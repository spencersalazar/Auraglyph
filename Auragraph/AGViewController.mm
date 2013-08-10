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
#import "UIKitGL.h"
#import "AGHandwritingRecognizer.h"

#import <list>


#define BUFFER_OFFSET(i) ((char *)NULL + (i))

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



class AGNode
{
public:
        
    virtual void update(float t, float dt) = 0;
    virtual void render() = 0;
    
    static void setProjectionMatrix(const GLKMatrix4 &proj)
    {
        s_projectionMatrix = proj;
    }
    
    static GLKMatrix4 projectionMatrix() { return s_projectionMatrix; }
    
    static void setGlobalModelViewMatrix(const GLKMatrix4 &modelview)
    {
        s_modelViewMatrix = modelview;
    }
    
    static GLKMatrix4 globalModelViewMatrix() { return s_modelViewMatrix; }
    
private:
    
    static GLKMatrix4 s_projectionMatrix;
    static GLKMatrix4 s_modelViewMatrix;
};

GLKMatrix4 AGNode::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGNode::s_modelViewMatrix = GLKMatrix4Identity;

class AGAudioNode : public AGNode
{
public:
    
    static void initialize()
    {
        if(!s_init)
        {
            s_init = true;
            
            // generate circle
            s_geoSize = 64;
            s_geo = new GLvncprimf[s_geoSize];
            float radius = 0.01;
            for(int i = 0; i < s_geoSize; i++)
            {
                float theta = 2*M_PI*((float)i)/((float)(s_geoSize-1));
                s_geo[i].vertex = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
                s_geo[i].normal = GLvertex3f(0, 0, 1);
                s_geo[i].color = GLcolor4f(1, 1, 1, 1);
            }
            
            glGenVertexArraysOES(1, &s_vertexArray);
            glBindVertexArrayOES(s_vertexArray);
            
            glGenBuffers(1, &s_vertexBuffer);
            glBindBuffer(GL_ARRAY_BUFFER, s_vertexBuffer);
            glBufferData(GL_ARRAY_BUFFER, s_geoSize*sizeof(GLvncprimf), s_geo, GL_STATIC_DRAW);
            
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
            glEnableVertexAttribArray(GLKVertexAttribNormal);
            glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
            glEnableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
            
            glBindVertexArrayOES(0);
        }
    }
    
    AGAudioNode(GLvertex3f pos = GLvertex3f()) :
    m_pos(pos)
    {
        initialize();
        
        NSLog(@"pos: (%f, %f, %f)", pos.x, pos.y, pos.z);
    }
    
    virtual void renderAudio(float *input, float *output, int nFrames)
    {
    }
    
    virtual void update(float t, float dt)
    {
        GLKMatrix4 projection = projectionMatrix();
        GLKMatrix4 modelView = globalModelViewMatrix();

        //modelView = GLKMatrix4MakeTranslation(m_pos.x, m_pos.y, m_pos.z);
        modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
        //modelView = GLKMatrix4Multiply(trans, modelView);
        
        m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
        
        m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
        //m_modelViewProjectionMatrix = GLKMatrix4Multiply(trans, m_modelViewProjectionMatrix);
    }
    
    virtual void render()
    {
        glBindVertexArrayOES(s_vertexArray);
//        glBindBuffer(GL_ARRAY_BUFFER, s_vertexBuffer);
        
        // Render the object again with ES2
//        glUseProgram(_program);
        
        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, m_modelViewProjectionMatrix.m);
        glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, m_normalMatrix.m);
        
        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_STRIP, 0, s_geoSize);
    }
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
    GLvertex3f m_pos;
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
};

bool AGAudioNode::s_init = false;
GLuint AGAudioNode::s_vertexArray = 0;
GLuint AGAudioNode::s_vertexBuffer = 0;
GLvncprimf *AGAudioNode::s_geo = NULL;
GLuint AGAudioNode::s_geoSize = 0;



struct DrawPoint
{
    GLvncprimf geo; // GL geometry
};

const int nDrawline = 1024;
int nDrawlineUsed = 0;
DrawPoint drawline[nDrawline];


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
    
    AGHandwritingRecognizer *_hwRecognizer;
    LTKTrace _currentTrace;
    GLvertex3f _currentTraceSum;
    
    std::list<AGNode *> _nodes;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation AGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
    
    _nodes = std::list<AGNode *>();
    _t = 0;
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
    
    _program = [ShaderHelper createProgramForVertexShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]
                                           fragmentShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];
    
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

- (void)update
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
    
    _osc += self.timeSinceLastUpdate * 1.0f;
    _t += self.timeSinceLastUpdate;
    
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
    {
        (*i)->update(_t, self.timeSinceLastUpdate);
    }
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(drawline), drawline, GL_DYNAMIC_DRAW);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    for(std::list<AGNode *>::iterator i = _nodes.begin(); i != _nodes.end(); i++)
    {
        (*i)->render();
    }
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
    glBindVertexArrayOES(_vertexArray);
    
    glLineWidth(4.0f);
    if(nDrawlineUsed == 1)
        glDrawArrays(GL_POINTS, 0, nDrawlineUsed);
    else
        glDrawArrays(GL_LINE_STRIP, 0, nDrawlineUsed);
}


#pragma Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.frame.origin.x, (int)self.view.frame.origin.y,
        (int)self.view.frame.size.width, (int)self.view.frame.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);
    
    drawline[0].geo.vertex = GLvertex3f(vec.x, -vec.y, vec.z);
    drawline[0].geo.color = GLcolor4f(1, 1, 1, 1);
    drawline[0].geo.normal = GLvertex3f(0, 0, 1);
    
    floatVector point;
    point.push_back(p.x);
    point.push_back(p.y);
    _currentTrace.addPoint(point);
    
    _currentTraceSum = GLvertex3f(p.x, p.y, 0);
    
    nDrawlineUsed = 1;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.frame.origin.x, (int)self.view.frame.origin.y,
        (int)self.view.frame.size.width, (int)self.view.frame.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0.01),
                                      _modelView, _projection, viewport, NULL);
    
    drawline[nDrawlineUsed].geo.vertex = GLvertex3f(vec.x, -vec.y, vec.z);
    drawline[nDrawlineUsed].geo.color = GLcolor4f(0.75, 0.75, 0.75, 1);
    drawline[nDrawlineUsed].geo.normal = GLvertex3f(0, 0, 1);
    
    _currentTraceSum = _currentTraceSum + GLvertex3f(p.x, p.y, 0);
    
    floatVector point;
    point.push_back(p.x);
    point.push_back(p.y);
    _currentTrace.addPoint(point);
    
    nDrawlineUsed++;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    // analysis
    
    AGHandwritingRecognizerFigure figure = [_hwRecognizer recognizeShapeInView:self.view
                                                                         trace:_currentTrace];
    
    NSLog(@"figure: %i", figure);
    
    if(figure == AG_FIGURE_CIRCLE)
    {
        int viewport[] = { (int)self.view.frame.origin.x, (int)self.view.frame.origin.y,
            (int)self.view.frame.size.width, (int)self.view.frame.size.height };
        GLvertex3f centroid = _currentTraceSum/nDrawlineUsed;
        GLKVector3 vec = GLKMathUnproject(GLKVector3Make(centroid.x, centroid.y, 0.01),
                                          _modelView, _projection, viewport, NULL);
        
        AGAudioNode * node = new AGAudioNode(GLvertex3f(vec.x, -vec.y, vec.z));
        _nodes.push_back(node);
        nDrawlineUsed = 0;
    }
    
    // reset trace
    _currentTrace = LTKTrace();
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}



@end
