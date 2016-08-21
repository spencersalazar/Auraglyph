//
//  AGControlNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGControlNode__
#define __Auragraph__AGControlNode__

#include "AGNode.h"

//------------------------------------------------------------------------------
// ### AGControlNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlNode

class AGControlNode : public AGNode
{
public:
    static void initializeControlNode();
    
    AGControlNode(const AGNodeManifest *mf, GLvertex3f pos = GLvertex3f());
    AGControlNode(const AGNodeManifest *mf, const AGDocument::Node &docNode);
    virtual ~AGControlNode() { }
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    //    virtual HitTestResult hit(const GLvertex3f &hit);
    //    virtual void unhit();
    
    virtual GLvertex3f relativePositionForInputPort(int port) const { return GLvertex3f(-s_radius, 0, 0); }
    virtual GLvertex3f relativePositionForOutputPort(int port) const { return GLvertex3f(s_radius, 0, 0); }
    
    virtual AGDocument::Node serialize();
    
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static float s_radius;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
    
protected:
    GLvertex3f *m_iconGeo;
    GLuint m_geoSize;
    GLuint m_geoType;
};

#endif /* defined(__Auragraph__AGControlNode__) */
