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

#include "LTKTypes.h"
#include "LTKTrace.h"


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
    
    float m_t;
    
    GLvertex3f m_pos;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix4 m_modelView;
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
    
    void touchDown(const GLvertex3f &t, const CGPoint &screen);
    void touchMove(const GLvertex3f &t, const CGPoint &screen);
    void touchUp(const GLvertex3f &t, const CGPoint &screen);
    
    bool doneEditing() { return m_doneEditing; }
    bool shouldRenderDrawline() { return m_editingPort >= 0; }
    
private:
    
    static bool s_init;
    static TexFont *s_text;
    static float s_radius;
    static GLuint s_geoSize;
    static GLvertex3f * s_geo;
    static GLuint s_boundingOffset;
    static GLuint s_innerboxOffset;

    AGNode * const m_node;
    
    bool m_doneEditing;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix4 m_modelView;
    GLKMatrix3 m_normalMatrix;

    int m_hit;
    int m_editingPort;
    LTKTrace m_currentTrace;
    float m_currentValue;
    int m_currentDigit;
    
    float m_t;
    
    int hitTest(const GLvertex3f &t, bool *inBbox);
};


#endif /* defined(__Auragraph__AGUserInterface__) */
