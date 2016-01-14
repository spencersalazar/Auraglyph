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

struct AGRenderInfo
{
public:
    AGRenderInfo();
    
    virtual void set() = 0;
    
    AGGenericShader *shader;
    GLuint numVertex;
    GLuint geoType;
    GLuint geoOffset;
};

struct AGRenderInfoV : public AGRenderInfo
{
    AGRenderInfoV();
    
    virtual void set();
    
    GLcolor4f color;
    GLvertex3f *geo;
};

struct AGRenderInfoVC : public AGRenderInfo
{
    virtual void set();
    
    GLvcprimf *geo;
};

struct AGRenderState
{
    GLKMatrix4 projection;
    GLKMatrix4 modelview;
    GLKMatrix3 normal;
};

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
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void renderOut();
    virtual bool finishedRenderingOut();
    
    void addChild(AGRenderObject *child);
    void removeChild(AGRenderObject *child);
    
    list<AGRenderInfo *> m_renderList;
    AGRenderState m_renderState;
    
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


class AGInteractiveObject : public AGRenderObject
{
public:
    AGInteractiveObject();
    virtual ~AGInteractiveObject();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    // new version
    virtual void touchDown(const AGTouchInfo &t);
    virtual void touchMove(const AGTouchInfo &t);
    virtual void touchUp(const AGTouchInfo &t);
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);
    
    void removeFromTopLevel();
};


#endif /* defined(__Auragraph__AGRenderObject__) */


