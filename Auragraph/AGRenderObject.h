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

class AGGenericShader;

struct AGRenderState;

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

struct AGRenderState
{
    AGRenderState() : alpha(1) { }
    
    GLKMatrix4 projection;
    GLKMatrix4 modelview;
    GLKMatrix3 normal;
    float alpha;
};

//------------------------------------------------------------------------------
// ### AGRenderObject ###
// Base class for objects that are rendered on screen.
//------------------------------------------------------------------------------
class AGRenderObject
{
public:
    static void setProjectionMatrix(const GLKMatrix4 &proj) { s_projectionMatrix = proj; }
    static GLKMatrix4 projectionMatrix() { return s_projectionMatrix; }
    static void setGlobalModelViewMatrix(const GLKMatrix4 &modelview) { s_modelViewMatrix = modelview; }
    static GLKMatrix4 globalModelViewMatrix() { return s_modelViewMatrix; }
    static void setFixedModelViewMatrix(const GLKMatrix4 &modelview) { s_fixedModelViewMatrix = modelview; }
    static GLKMatrix4 fixedModelViewMatrix() { return s_fixedModelViewMatrix; }
    
    AGRenderObject();
    virtual ~AGRenderObject();
    
    /* init() should be used for most initialization other than zeroing/nulling
       member variables. Unfortunately virtual functions don't really work as 
       normal in C++ constructors, and vfuncs make the node/render object data 
       model a lot easier, so init() is used instead. */
    virtual void init();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void renderOut();
    virtual bool finishedRenderingOut();
    
    virtual void hide();
    virtual void unhide();
    
    void addChild(AGRenderObject *child);
    void removeChild(AGRenderObject *child);
    
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
    
protected:
    static GLKMatrix4 s_projectionMatrix;
    static GLKMatrix4 s_modelViewMatrix;
    static GLKMatrix4 s_fixedModelViewMatrix;
    
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


#ifdef __LP64__ // arm64
typedef uint64_t TouchID;
#else // arm32
typedef uint32_t TouchID;
#endif

struct AGTouchInfo
{
    AGTouchInfo() { }
    AGTouchInfo(const GLvertex3f &_position, const CGPoint &_screenPosition, TouchID _touchId) :
    position(_position), screenPosition(_screenPosition), touchId(_touchId)
    { }
    
    GLvertex3f position;
    CGPoint screenPosition;
    TouchID touchId;
};


//------------------------------------------------------------------------------
// ### AGInteractiveObject ###
// Base class for objects that support interaction in addition to rendering.
//------------------------------------------------------------------------------
class AGInteractiveObject : public AGRenderObject
{
public:
    AGInteractiveObject();
    virtual ~AGInteractiveObject();
    
    // DEPRECATED
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    // new version
    // subclasses generally should override these
    virtual void touchDown(const AGTouchInfo &t);
    virtual void touchMove(const AGTouchInfo &t);
    virtual void touchUp(const AGTouchInfo &t);
    
    // default implementation checks if touch is within this->effectiveBounds()
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);
    
    virtual AGInteractiveObject *userInterface() { return NULL; }
    
    void removeFromTopLevel();
};


#endif /* defined(__Auragraph__AGRenderObject__) */


