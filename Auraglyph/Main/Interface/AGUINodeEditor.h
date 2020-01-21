//
//  AGNodeEditor.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/14/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGNodeEditor_hpp
#define AGNodeEditor_hpp


#include "gfx.h"
#include "Geometry.h"
#include "Animation.h"
#include "AGInteractiveObject.h"
#include "AGUserInterface.h"

#include "LTKTypes.h"
#include "LTKTrace.h"

#include <sstream>
#include <vector>
#include <map>


class AGNode;
class AGSlider;
class AGFileBrowser;

/*------------------------------------------------------------------------------
 - AGUINodeEditor -
 Abstract base class of node editors.
 -----------------------------------------------------------------------------*/
class AGUINodeEditor : public AGUIObject
{
public:
    AGUINodeEditor(AGNode *node);
    virtual ~AGUINodeEditor();
    
    virtual bool doneEditing() = 0;
    
    void pin(bool _pin = true);
    void unpin();
    bool isPinned() { return m_pinned; }
    
    /* will close on touchOutside unless pinned */
    virtual void touchOutside();
    
    AGNode* node() { return m_node; }

protected:
    AGNode* const m_node;

private:
    bool m_pinned;
};


/*------------------------------------------------------------------------------
 - AGUIStandardNodeEditor -
 Standard node editor.
 -----------------------------------------------------------------------------*/
class AGUIStandardNodeEditor : public AGUINodeEditor
{
public:
    AGUIStandardNodeEditor(AGNode *node);
    ~AGUIStandardNodeEditor();
    
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
    
    virtual GLvertex3f position() const;
    
    void renderOut();
    bool finishedRenderingOut();
    
    /** Blink specified item. Pass item = -1 to refer to all items.
     */
    void blink(int item, bool enableBlink = true);
    
protected:
    
    virtual GLvrectf effectiveBounds();
    
private:    
    void initializeNodeEditor();

    float m_radius;
    float m_radiusY;
    
    GLuint m_geoSize;
    GLvertex3f * m_geo;
    GLuint m_boundingOffset;
    GLuint m_innerboxOffset;
    GLuint m_buttonBoxOffset;
    GLuint m_itemEditBoxOffset;
    
    string m_title;
    
    bool m_doneEditing;
    
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    std::map<int, AGSlider *> m_editSliders;
    std::vector<GLvertex3f> m_pinInfoGeo;
    AGUIIconButton *m_pinButton;
    
    AGInteractiveObject *m_customItemEditor = NULL;
    
    int m_hit;
    int m_editingPort;
    
    std::list< std::vector<GLvertex3f> > m_drawline;
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
