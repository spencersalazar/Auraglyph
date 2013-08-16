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
    static GLvertex3f * s_geo;
    
    GLvertex3f m_pos;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;
    
    AGAudioNode m_audioNode;
    
    int m_hit;
    
    static void initializeNodeSelector();
};


class TexFont;

class AGUINodeEditor
{
public:
    static void initializeNodeEditor();
    
    AGUINodeEditor(AGNode *node);
    
    void update(float t, float dt);
    void render();
    
    void touchDown(const GLvertex3f &t);
    void touchMove(const GLvertex3f &t);
    void touchUp(const GLvertex3f &t);
    
private:
    
    static bool s_init;
    static TexFont *s_text;
    static float s_radius;
    static GLuint s_geoSize;
    static GLvertex3f * s_geo;
    static GLuint s_boundingOffset;
    static GLuint s_innerboxOffset;

    AGNode * const m_node;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix3 m_normalMatrix;

    int m_hit;
};


#endif /* defined(__Auragraph__AGUserInterface__) */
