//
//  AGInputNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 4/13/15.
//  Copyright (c) 2015 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGInputNode__
#define __Auragraph__AGInputNode__

#include "AGNode.h"

//------------------------------------------------------------------------------
// ### AGInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGInputNode

class AGInputNode : public AGNode
{
public:
    
    static void initializeInputNode();
    
    AGInputNode(const AGNodeManifest *mf, const GLvertex3f &pos = GLvertex3f());
    AGInputNode(const AGNodeManifest *mf, const AGDocument::Node &docNode);
    
    AGDocument::Node::Class nodeClass() const override { return AGDocument::Node::INPUT; }
    
    void update(float t, float dt) override;
    void render() override;
    virtual void renderUI() { }
    
    AGInteractiveObject *hitTest(const GLvertex3f &t) override;
    
    virtual HitTestResult hit(const GLvertex3f &hit);
    virtual void unhit();
    
    GLvertex3f relativePositionForOutputPort(int port) const override;
        
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static float s_radius;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
};

#endif /* defined(__Auragraph__AGInputNode__) */
