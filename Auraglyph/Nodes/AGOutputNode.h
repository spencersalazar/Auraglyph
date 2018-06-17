//
//  AGOutputNode.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/21/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGOutputNode__
#define __Auragraph__AGOutputNode__

#include "AGNode.h"

//------------------------------------------------------------------------------
// ### AGOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGOutputNode

class AGOutputNode : public AGNode
{
public:
    
    static void initializeOutputNode();
    
    AGOutputNode(const AGNodeManifest *mf, const GLvertex3f &pos = GLvertex3f());
    
    AGDocument::Node::Class nodeClass() const override { return AGDocument::Node::OUTPUT; }

    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    virtual AGUIObject *hitTest(const GLvertex3f &t) override;
    
    virtual HitTestResult hit(const GLvertex3f &hit);
    virtual void unhit();
        
private:
    
    static bool s_init;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static float s_radius;
    
    static GLvncprimf *s_geo;
    static GLuint s_geoSize;
};

#endif /* __Auragraph__AGOutputNode__ */
