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
    AGUINodeEditor();
    virtual ~AGUINodeEditor();
    
    virtual bool doneEditing() = 0;
    
    void pin(bool _pin = true);
    void unpin();
    bool isPinned() { return m_pinned; }
    
    /* will close on touchOutside unless pinned */
    virtual void touchOutside();
    
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
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    void touchDown(const GLvertex3f &t, const CGPoint &screen);
    void touchMove(const GLvertex3f &t, const CGPoint &screen);
    void touchUp(const GLvertex3f &t, const CGPoint &screen);
    
    virtual void touchDown(const AGTouchInfo &t) override;
    virtual void touchMove(const AGTouchInfo &t) override;
    virtual void touchUp(const AGTouchInfo &t) override;
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t) override;
    
    virtual bool doneEditing() override { return m_doneEditing; }
    
    virtual GLvertex3f position() override;
    
    void renderOut() override;
    bool finishedRenderingOut() const override;
    
protected:
    
    virtual GLvrectf effectiveBounds() override;
    
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
    
    AGNode * const m_node;
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
