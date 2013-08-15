//
//  AGUserInterface.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGUserInterface__
#define __Auragraph__AGUserInterface__

#import "Geometry.h"
#import <GLKit/GLKit.h>
#import "AGAudioNode.h"

class AGUINodeSelector
{
public:
    AGUINodeSelector(const GLvertex3f &pos);
    
    void update(float t, float dt);
    void render();
    
    void touchDown(const GLvertex3f &t);
    void touchMove(const GLvertex3f &t);
    void touchUp(const GLvertex3f &t);
    
    AGAudioNode *createNode();
    
private:
    static bool s_initNodeSelector;
    
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    
    static GLuint s_geoSize;
    static GLvncprimf * s_geo;
    
    static GLuint s_geoOutlineOffset;
    static GLuint s_geoOutlineSize;
    static GLuint s_geoFillOffset;
    static GLuint s_geoFillSize;
    
    static GLuint s_program;
    static GLint s_uniformMVPMatrix;
    static GLint s_uniformNormalMatrix;
    static GLint s_uniformColor2;
    
    GLvertex3f m_pos;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
    
    AGAudioNode m_audioNode;
    
    int m_hit;
    
    static void initializeNodeSelector();
};

#endif /* defined(__Auragraph__AGUserInterface__) */
