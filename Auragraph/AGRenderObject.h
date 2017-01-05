//
//  AGRenderObject.h
//  Auragraph
//
//  Created by Spencer Salazar on 10/14/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGRenderObject__
#define __Auragraph__AGRenderObject__

#include "Geometry.h"
#include "Animation.h"
#include <GLKit/GLKit.h>

#include <list>
using namespace std;

//------------------------------------------------------------------------------
// ### AGRenderable ###
// Basic pure virtual class for things that can be drawn.
//------------------------------------------------------------------------------
class AGRenderable
{
public:
    virtual ~AGRenderable() { }
    virtual void update(float t, float dt) = 0;
    virtual void render() = 0;
};

// forward declaration
class AGGenericShader;

//------------------------------------------------------------------------------
// ### AGRenderState ###
// Encapsulates current state related to rendering an object
//------------------------------------------------------------------------------
struct AGRenderState
{
    GLKMatrix4 projection;
    GLKMatrix4 modelview;
    GLKMatrix3 normal;
    float alpha;
};

//------------------------------------------------------------------------------
// ### AGRenderInfo ###
// Encapsulates all info needed to glDrawArrays
// set() function sets up vertex arrays, color, texcoords, etc. 
//------------------------------------------------------------------------------
struct AGRenderInfo
{
public:
    AGRenderInfo();
    
    virtual void set() = 0;
    virtual void set(const AGRenderState &) = 0;
    
    AGGenericShader *shader;
    GLuint numVertex;
    GLuint geoType;
    GLuint geoOffset;
};

//------------------------------------------------------------------------------
// ### AGRenderObject ###
// Base class for objects that are rendered on screen.
//------------------------------------------------------------------------------
class AGRenderObject : public AGRenderable
{
public:
    static void setProjectionMatrix(const GLKMatrix4 &proj) { s_projectionMatrix = proj; }
    static GLKMatrix4 projectionMatrix() { return s_projectionMatrix; }
    static void setGlobalModelViewMatrix(const GLKMatrix4 &modelview) { s_modelViewMatrix = modelview; }
    static GLKMatrix4 globalModelViewMatrix() { return s_modelViewMatrix; }
    static void setFixedModelViewMatrix(const GLKMatrix4 &modelview) { s_fixedModelViewMatrix = modelview; }
    static GLKMatrix4 fixedModelViewMatrix() { return s_fixedModelViewMatrix; }
    static void setCameraMatrix(const GLKMatrix4 &camera) { s_camera = camera; }
    static GLKMatrix4 cameraMatrix() { return s_camera; }
    
    AGRenderObject();
    virtual ~AGRenderObject();
    
    /* init() should be used for most initialization other than zeroing/nulling
       member variables. Unfortunately virtual functions don't really work as 
       normal in C++ constructors, and vfuncs make the node/render object data 
       model a lot easier, so init() is used instead. */
    virtual void init();
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    virtual void renderOut();
    virtual bool finishedRenderingOut();
    
    virtual void hide();
    virtual void unhide();
    
    void addChild(AGRenderObject *child);
    void removeChild(AGRenderObject *child);
    const list<AGRenderObject *> &children() { return m_children; }
    
    list<AGRenderInfo *> m_renderList;
    AGRenderState m_renderState;
    
    const GLKMatrix4 &modelview() const { return m_renderState.modelview; }
    const GLKMatrix4 &projection() const { return m_renderState.projection; }
    
    // override to force fixed-position rendering (e.g. ignores camera movement)
    virtual bool renderFixed() { return false; }
    
    virtual GLvertex3f position() { return GLvertex3f(); }
    virtual GLvertex2f size() { return GLvertex2f(); }
    // TODO: make non-virtual
    virtual GLvrectf effectiveBounds() { return GLvrectf(position()-size()*0.5, position()+size()*0.5); }
    AGRenderObject *parent() const { return m_parent; }
    
    // draw functions
    void drawTriangleFan(GLvertex3f geo[], int size);
    void drawTriangleFan(GLvertex3f geo[], int size, const GLKMatrix4 &xform);
    void drawTriangleFan(AGGenericShader &shader, GLvertex3f geo[], int size, const GLKMatrix4 &xform);
    void drawLineLoop(GLvertex3f geo[], int size);
    void drawLineStrip(GLvertex2f geo[], int size);
    void drawLineStrip(GLvertex2f geo[], int size, const GLKMatrix4 &xform);
    void drawLineStrip(AGGenericShader &shader, GLvertex2f geo[], int size, const GLKMatrix4 &xform);
    void drawLineStrip(GLvertex3f geo[], int size);
    void drawWaveform(float waveform[], int size, GLvertex2f from, GLvertex2f to, float gain = 1.0f, float yScale = 1.0f);
    
protected:
    static GLKMatrix4 s_projectionMatrix;
    static GLKMatrix4 s_modelViewMatrix;
    static GLKMatrix4 s_fixedModelViewMatrix;
    static GLKMatrix4 s_camera;
    
    void updateChildren(float t, float dt);
    void renderPrimitive(AGRenderInfo *info);
    void renderPrimitives();
    void renderChildren();
    void debug_renderBounds();
    
    AGRenderObject *m_parent;
    list<AGRenderObject *> m_children;
    
    powcurvef m_alpha;
    
    bool m_debug_initCalled;
    
private:
    bool m_renderedBounds;
};


struct AGRenderInfoV : public AGRenderInfo
{
    AGRenderInfoV();
    
    virtual void set();
    virtual void set(const AGRenderState &);
    
    GLcolor4f color;
    GLvertex3f *geo;
};

struct AGRenderInfoVL : public AGRenderInfo
{
    AGRenderInfoVL();
    
    virtual void set();
    virtual void set(const AGRenderState &);
    
    GLfloat lineWidth;
    GLcolor4f color;
    GLvertex3f *geo;
};

struct AGRenderInfoVC : public AGRenderInfo
{
    virtual void set();
    virtual void set(const AGRenderState &);
    
    GLvcprimf *geo;
};



#endif /* defined(__Auragraph__AGRenderObject__) */


