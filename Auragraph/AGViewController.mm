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


#include <vector>

struct FeaturePoint
{
    GLvertex2f p;   // position
    float dp;  // direction (angle)
    float d2p; // curvature
};

struct Figure
{
public:
    
    Figure(){ }
    
    void addPoint(const FeaturePoint & fp)
    {
        m_points.push_back(fp);
    }
    
    // note: be sure to call calculateDirectionAndCurvature() later
    void addPoint(const GLvertex2f & p)
    {
        FeaturePoint fp;
        fp.p = p;
        fp.dp = fp.d2p = 0;
        m_points.push_back(fp);
    }
    
    void calculateDirectionAndCurvature(bool close)
    {
        // assume each point connects to its successor
        // if close==true, last point connects to first point
        
        // compute direction
        for(int curr = 0; curr < m_points.size(); curr++)
        {
            int prev = curr-1;
            int next = curr+1;
            
            if(curr == 0)
            {
                if(close)
                    prev = m_points.size()-1;
                else
                    prev = curr;
            }
            if(curr == m_points.size()-1)
            {
                if(close)
                    next = 0;
                else
                    next = curr;
            }
            
            m_points[curr].dp = (m_points[next].p - m_points[prev].p).angle();
        }
        
        // compute curvature
        for(int curr = 0; curr < m_points.size(); curr++)
        {
            int prev = curr-1;
            int next = curr+1;
            
            if(curr == 0)
            {
                if(close)
                    prev = m_points.size()-1;
                else
                    prev = curr;
            }
            if(curr == m_points.size()-1)
            {
                if(close)
                    next = 0;
                else
                    next = curr;
            }
            
            m_points[curr].d2p = m_points[next].dp - m_points[prev].dp;
        }
    }
    
    int numPoints() const
    {
        return m_points.size();
    }
    
    const FeaturePoint &point(int idx) const
    {
        return m_points[idx];
    }
    
    int closestPointTo(const GLvertex2f &p) const
    {
        int min = -1;
        float mindist = FLT_MAX;
        // linear brute force!
        for(int i = 0; i < m_points.size(); i++)
        {
            float dist = m_points[i].p.distanceSquaredTo(p);
            if(dist < mindist)
            {
                min = i;
                mindist = dist;
            }
        }
        
        return min;
    }
    
private:
    std::vector<FeaturePoint> m_points;
};



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


struct DrawPoint
{
    GLvncprimf geo; // GL geometry
    
    FeaturePoint fp;
};

const int nDrawline = 1024;
int nDrawlineUsed = 0;
DrawPoint drawline[nDrawline];


@interface AGViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelView;
    GLKMatrix4 _projection;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    float _osc;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    Figure circle;
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
    
    int N_CIRCLE_PTS = 32;
    for(int i = 0; i < N_CIRCLE_PTS; i++)
    {
        double theta = M_PI*2*((float)i)/((float)N_CIRCLE_PTS);
        circle.addPoint(GLvertex2f(cos(theta), sin(theta)));
    }
    circle.calculateDirectionAndCurvature(true);
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
    
//    float rho = 1;
//    float theta;
//    
//    for(int i = 0; i < nDrawline; i++)
//    {
//        theta = 2*M_PI*((float)i)/((float)nDrawline-1);
//        drawline[i].vertex.x = rho*cosf(theta);
//        drawline[i].vertex.y = rho*sinf(theta);
//        drawline[i].vertex.z = 0;
//        
//        drawline[i].normal = GLvertex3f(0,0,1);
//        drawline[i].color = hsv2rgb(GLcolor4f(theta/(2*M_PI), 0.5, 0.9, 1.0));
//    }
    
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
    
    _osc += self.timeSinceLastUpdate * 1.0f;
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(drawline), drawline, GL_DYNAMIC_DRAW);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
    glLineWidth(4.0f);
    if(nDrawlineUsed == 1)
        glDrawArrays(GL_POINTS, 0, nDrawlineUsed);
    else
        glDrawArrays(GL_LINE_STRIP, 0, nDrawlineUsed);
}


#pragma Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    nDrawlineUsed = 1;
    
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.frame.origin.x, (int)self.view.frame.origin.y,
        (int)self.view.frame.size.width, (int)self.view.frame.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0),
                                      _modelView, _projection, viewport, NULL);
    
    drawline[0].geo.vertex = GLvertex3f(vec.x, -vec.y, vec.z);
    drawline[0].geo.color = GLcolor4f(1, 1, 1, 1);
    drawline[0].geo.normal = GLvertex3f(0, 0, 1);
    
    drawline[0].fp.p = GLvertex2f(vec.x, vec.y);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:self.view];
    
    int viewport[] = { (int)self.view.frame.origin.x, (int)self.view.frame.origin.y,
        (int)self.view.frame.size.width, (int)self.view.frame.size.height };
    GLKVector3 vec = GLKMathUnproject(GLKVector3Make(p.x, p.y, 0),
                                      _modelView, _projection, viewport, NULL);
    
    drawline[nDrawlineUsed].geo.vertex = GLvertex3f(vec.x, -vec.y, vec.z);
    drawline[nDrawlineUsed].geo.color = GLcolor4f(1, 1, 1, 1);
    drawline[nDrawlineUsed].geo.normal = GLvertex3f(0, 0, 1);
    
    drawline[nDrawlineUsed].fp.p = GLvertex2f(vec.x, vec.y);
    if(nDrawlineUsed >= 2)
        drawline[nDrawlineUsed-1].fp.dp = (drawline[nDrawlineUsed].fp.p - drawline[nDrawlineUsed-2].fp.p).angle();
    else
        drawline[nDrawlineUsed-1].fp.dp = (drawline[nDrawlineUsed].fp.p - drawline[nDrawlineUsed-1].fp.p).angle();
    drawline[nDrawlineUsed].fp.dp = (drawline[nDrawlineUsed].fp.p - drawline[nDrawlineUsed-1].fp.p).angle();
    
    nDrawlineUsed++;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    // analysis
    
    // find center
    GLvertex2f sum;
    for(int i = 0; i < nDrawlineUsed; i++)
        sum = sum + drawline[i].fp.p;
    GLvertex2f center = sum / nDrawlineUsed;
    
    // find normalization
    float mag_sq_max = 0;
    for(int i = 0; i < nDrawlineUsed; i++)
    {
        float mag_sq = (drawline[i].fp.p - center).magnitudeSquared();
        if(mag_sq > mag_sq_max)
            mag_sq_max = mag_sq;
    }
    float norm = 1.0/sqrtf(mag_sq_max);
    
    float score = 0;
    // compare points to circle
    for(int i = 1; i < nDrawlineUsed-1; i++)
    {
        GLvertex2f p_draw = (drawline[i].fp.p-center)*norm;
        
        int p_fig_idx = circle.closestPointTo(p_draw);
        
        const FeaturePoint &fp = circle.point(p_fig_idx);
        
        float dist = p_draw.distanceTo(fp.p);
        float dist_dp = fabsf(fp.dp - drawline[i].fp.dp);
        float d2p_draw = drawline[i+1].fp.d2p - drawline[i-1].fp.d2p;
        float dist_d2p = fabsf(fp.d2p - d2p_draw);
        
        score += (powf(dist,4) * powf(dist_dp,2) * dist_d2p)*sinf(M_PI*((float)i)/((float)nDrawlineUsed));
    }
    
    score /= (nDrawlineUsed-2);
    
    NSLog(@"score: %f", score);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}



@end
