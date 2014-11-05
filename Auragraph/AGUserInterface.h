//
//  AGUserInterface.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGUserInterface__
#define __Auragraph__AGUserInterface__

#import <GLKit/GLKit.h>
#import "Geometry.h"
#import "Animation.h"
#import "AGRenderObject.h"

#include "LTKTypes.h"
#include "LTKTrace.h"


class AGNode;
class AGAudioNode;


class AGUIObject : public AGInteractiveObject
{
public:
    virtual ~AGUIObject() { }
    
    virtual void fadeOutAndRemove() { }
};


class TexFont;

class AGUINodeEditor : public AGUIObject
{
public:
    virtual bool doneEditing() = 0;
};

class AGUIStandardNodeEditor : public AGUINodeEditor
{
public:
    static void initializeNodeEditor();
    
    AGUIStandardNodeEditor(AGNode *node);
    
    virtual void update(float t, float dt);
    virtual void render();
    
    void touchDown(const GLvertex3f &t, const CGPoint &screen);
    void touchMove(const GLvertex3f &t, const CGPoint &screen);
    void touchUp(const GLvertex3f &t, const CGPoint &screen);
    
    virtual void touchDown(const AGTouchInfo &t);
    virtual void touchMove(const AGTouchInfo &t);
    virtual void touchUp(const AGTouchInfo &t);
    
    virtual bool doneEditing() { return m_doneEditing; }
    bool shouldRenderDrawline() { return false; }
    
private:
    
    static bool s_init;
    static TexFont *s_text;
    static float s_radius;
    static GLuint s_geoSize;
    static GLvertex3f * s_geo;
    static GLuint s_boundingOffset;
    static GLuint s_innerboxOffset;
    static GLuint s_buttonBoxOffset;
    static GLuint s_itemEditBoxOffset;
    
    AGNode * const m_node;
    string m_title;
    
    bool m_doneEditing;
    
    GLKMatrix4 m_modelViewProjectionMatrix;
    GLKMatrix4 m_modelView;
    GLKMatrix3 m_normalMatrix;

    int m_hit;
    int m_editingPort;
    
    std::list< std::vector<GLvertex3f> > m_drawline;
    LTKTrace m_currentTrace;
    float m_currentValue;
    bool m_lastTraceWasRecognized;
    bool m_decimal;
    float m_decimalFactor;
    
    bool m_startedInAccept;
    bool m_hitAccept;
    bool m_startedInDiscard;
    bool m_hitDiscard;
    
    float m_t;
    
    int hitTest(const GLvertex3f &t, bool *inBbox);
};



class AGUIFrame : public AGUIObject
{
public:
    AGUIFrame(const GLvertex2f &bottomLeft, const GLvertex2f &topRight);
    AGUIFrame(const GLvertex2f &bottomLeft, const GLvertex2f &bottomRight, const GLvertex2f &topRight, const GLvertex2f &topLeft);
    
    void update(float t, float dt);
    void render();
    
    void touchDown(const GLvertex3f &t);
    void touchMove(const GLvertex3f &t);
    void touchUp(const GLvertex3f &t);
    
    AGUIObject *hitTest(const GLvertex3f &t);
    
private:
    
    GLvertex2f m_geo[4];
};


class AGUIButton : public AGInteractiveObject
{
public:
    AGUIButton(const std::string &title, const GLvertex3f &pos, const GLvertex3f &size);
    ~AGUIButton();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual void setAction(void (^action)());
    
private:
    
    GLvrectf effectiveBounds();
    
    static TexFont *s_text;
    
    std::string m_title;
    
    GLvertex3f m_pos, m_size;
    GLvertex3f m_geo[8];
    
    bool m_hit;
    bool m_hitOnTouchDown;
    
    void (^m_action)();
};


class AGUITrash : public AGUIObject
{
public:
    static AGUITrash &instance();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    void activate();
    void deactivate();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    virtual void setPosition(const GLvertex3f &pos) { m_position = pos; }
    
    virtual bool renderFixed() { return true; }
    
private:
    AGUITrash();
    ~AGUITrash();
    
    bool m_active;
    slewf m_scale;
    
    float m_radius;
    GLvertex3f m_position;
    GLuint m_tex;
    GLvertex3f m_geo[4];
    GLvertex2f m_uv[4];
};


#endif /* defined(__Auragraph__AGUserInterface__) */
