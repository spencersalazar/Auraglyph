//
//  AGRenderObject.h
//  Auragraph
//
//  Created by Spencer Salazar on 10/14/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGRenderObject__
#define __Auragraph__AGRenderObject__

#import "Geometry.h"
#import "AGGenericShader.h"

#import <list>
using namespace std;

struct AGRenderInfo
{
public:
    AGRenderInfo() :
    shader(&AGGenericShader::instance()), numVertex(0), geoType(GL_LINES)
    { }
    
    virtual void set() = 0;
    
    AGGenericShader *shader;
    GLuint numVertex;
    GLuint geoType;
};

struct AGRenderInfoV : public AGRenderInfo
{
    AGRenderInfoV() : color(GLcolor4f::black), geo(NULL) { }
    
    virtual void set()
    {
        assert(geo != NULL);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo);
    }
    
    GLcolor4f color;
    GLvertex3f *geo;
};

struct AGRenderInfoVC : public AGRenderInfo
{
    virtual void set()
    {
        glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvcprimf), &geo->color);
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvcprimf), &geo->vertex);
    }
    
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
    virtual bool finishedRenderingOut() { return true; }
    
    void addChild(AGRenderObject *child);
    void removeChild(AGRenderObject *child);
    
    list<AGRenderInfo *> m_renderList;
    AGRenderState m_renderState;
    
    // override to force fixed-position rendering (e.g. ignores camera movement)
    virtual bool renderFixed() { return false; }
    
    virtual GLvertex3f position() { return GLvertex3f(); }
    virtual GLvertex2f size() { return GLvertex2f(); }
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
    
private:
    bool m_renderedBounds;
};


struct AGTouchInfo
{
    AGTouchInfo() { }
    AGTouchInfo(const GLvertex3f &_position, const CGPoint &_screenPosition, int _touchId) :
    position(_position), screenPosition(_screenPosition), touchId(_touchId)
    { }
    
    GLvertex3f position;
    CGPoint screenPosition;
    int touchId;
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


