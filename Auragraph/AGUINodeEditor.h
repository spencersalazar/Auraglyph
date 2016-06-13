//
//  AGNodeEditor.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/14/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGNodeEditor_hpp
#define AGNodeEditor_hpp


#import <GLKit/GLKit.h>
#import "Geometry.h"
#import "Animation.h"
#import "AGRenderObject.h"
#import "AGUserInterface.h"

#include "LTKTypes.h"
#include "LTKTrace.h"

#include <sstream>


class AGNode;
class AGSlider;


/*------------------------------------------------------------------------------
 - AGUINodeEditor -
 Abstract base class of node editors.
 -----------------------------------------------------------------------------*/
class AGUINodeEditor : public AGUIObject
{
public:
    virtual bool doneEditing() = 0;
};


/*------------------------------------------------------------------------------
 - AGUIStandardNodeEditor -
 Standard node editor.
 -----------------------------------------------------------------------------*/
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
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);

    virtual bool doneEditing() { return m_doneEditing; }
    bool shouldRenderDrawline() { return false; }
    
    virtual GLvertex3f position();
    
    void renderOut();
    bool finishedRenderingOut();
    
protected:
    
    virtual GLvrectf effectiveBounds();
    
private:
    
    static bool s_init;
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
    
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    std::vector<AGSlider *> m_editSliders;
    
    int m_hit;
    int m_editingPort;
    
    std::list< std::vector<GLvertex3f> > m_drawline;
    //    std::vector<GLvertex3f> m_currentDrawline;
    LTKTrace m_currentTrace;
    bool m_lastTraceWasRecognized;
    powcurvef m_currentDrawlineAlpha;
    
    float m_currentValue;
    std::stringstream m_currentValueStream;
    std::string m_currentValueString;
    
    bool m_decimal;
    float m_decimalFactor;
    
    bool m_startedInAccept;
    bool m_hitAccept;
    bool m_startedInDiscard;
    bool m_hitDiscard;
    
    float m_t;
    
    int hitTestX(const GLvertex3f &t, bool *inBbox);
};




#endif /* AGNodeEditor_hpp */
