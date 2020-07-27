//
//  AGUserInterface.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGUserInterface__
#define __Auragraph__AGUserInterface__

#include "gfx.h"
#include "Geometry.h"
#include "Animation.h"
#include "AGInteractiveObject.h"
#include "AGStyle.h"

#include <string>
#include <vector>
#include <functional>

// forward declaration
class AGUINodeEditor;


/*------------------------------------------------------------------------------
 - AGUIObject -
 Artifact of previous system design - replaced by AGInteractiveObject
 -----------------------------------------------------------------------------*/
class AGUIObject : public AGInteractiveObject
{
public:
    virtual ~AGUIObject() { }
    
    virtual void fadeOutAndRemove() { }
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

/*------------------------------------------------------------------------------
 - AGUILabel -
 Text label
 -----------------------------------------------------------------------------*/
class AGUILabel : public AGRenderObject
{
public:
    AGUILabel(const GLvertex3f &position = GLvertex3f(), const string &text = "");
    ~AGUILabel();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual GLvertex2f size();
    void setSize(const GLvertex2f &size);
    GLvertex2f naturalSize() const;
    
private:
    GLvertex2f m_size;
    GLvertex2f m_textSize;
    
    string m_text;
};


/*------------------------------------------------------------------------------
 - AGUIButton -
 Standard button.
 -----------------------------------------------------------------------------*/
class AGUIButton : public AGInteractiveObject
{
public:
    AGUIButton(const std::string &title, const GLvertex3f &pos, const GLvertex3f &size);
    virtual ~AGUIButton();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual GLvertex2f size() { return m_size.xy(); }
    
    void setAction(void (^action)());
    void setAction(const std::function<void ()>& action);
    bool isPressed();
    void setLatched(bool latched);
    
    void setRenderFixed(bool fixed) { m_renderFixed = fixed; }
    virtual bool renderFixed() { return m_renderFixed; }
    
    void setTitle(const std::string &title);
    const std::string &title();
    
    enum InteractionType
    {
        INTERACTION_UPDOWN,
        INTERACTION_LATCH,
    };
    
    void setInteractionType(InteractionType t) { m_interactionType = t; }
    InteractionType getInteractionType() { return m_interactionType; }
    
    /** Make a pin button that will cause the (optional) node editor argument
     to be pinned when pressed.
     */
    static AGUIButton *makePinButton(AGUINodeEditor *node = nullptr);
    
    /** Make a standard check mark button.
     */
    static AGUIButton *makeCheckButton();
    
protected:
    
    GLvrectf effectiveBounds();
    
    std::string m_title;
    
    GLvertex3f m_size;
    GLvertex3f m_geo[8];
    bool m_renderFixed = false;
    
    bool m_hit;
    bool m_hitOnTouchDown;
    bool m_latch;
    
    InteractionType m_interactionType;
    
    void (^m_actionBlock)();
    std::function<void ()> m_action;
};


/*------------------------------------------------------------------------------
 - AGTextButton -
 Text button - displays as just text, and showing a border when pressed.
 -----------------------------------------------------------------------------*/
class AGUITextButton : public AGUIButton
{
public:
    AGUITextButton(const std::string &title, const GLvertex3f &pos, const GLvertex3f &size) :
    AGUIButton(title, pos, size) { }
    
    virtual void render();
};


/*------------------------------------------------------------------------------
 - AGUIIconButton -
 Button that allows display of customized icon.
 -----------------------------------------------------------------------------*/
class AGUIIconButton : public AGUIButton
{
public:
    AGUIIconButton(const GLvertex3f &pos, const GLvertex2f &size, const AGRenderInfoV &iconRenderInfo);
    AGUIIconButton(const GLvertex3f &pos, const GLvertex2f &size,
                   const vector<GLvertex3f> &iconGeo, int geoType);
    ~AGUIIconButton();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual GLvertex2f size() { return m_size.xy(); }
    virtual GLvrectf effectiveBounds() { return GLvrectf(position()-size()*0.5, position()+size()*0.5); }
    
    enum IconMode
    {
        ICONMODE_SQUARE,
        ICONMODE_CIRCLE,
    };
    
    void setIconMode(IconMode m);
    IconMode getIconMode();
    
    void blink(bool blink);
    
private:
    GLvertex3f *m_boxGeo;
    AGRenderInfoV m_iconInfo;
    
    vector<GLvertex3f> m_iconGeo;
    int m_iconGeoType;
    
    IconMode m_iconMode;
    
    AGBlink m_blink;
};



/*------------------------------------------------------------------------------
 - AGUIButtonGroup -
 Button group for mode selector-type buttons.
 -----------------------------------------------------------------------------*/
class AGUIButtonGroup : public AGInteractiveObject
{
public:
    AGUIButtonGroup();
    ~AGUIButtonGroup();
    
    void addButton(AGUIButton *button, void (^action)(), bool isDefault);
    
    virtual bool renderFixed() { return true; }
    
private:
    std::list<AGUIButton *> m_buttons;
    std::list<void (^)()> m_actions;
};



/*------------------------------------------------------------------------------
 - AGUITrash -
 Node deletion interface.
 -----------------------------------------------------------------------------*/
class AGUITrash : public AGUIObject
{
public:
    static AGUITrash &instance();
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    virtual void touchDown(const GLvertex3f &t) override;
    virtual void touchMove(const GLvertex3f &t) override;
    virtual void touchUp(const GLvertex3f &t) override;
    
    void activate();
    void deactivate();
    
    virtual AGUIObject *hitTest(const GLvertex3f &t) override;
    
    virtual bool renderFixed() override { return true; }
    
private:
    AGUITrash();
    ~AGUITrash();
    
    bool m_active;
    slewf m_scale;
    
    float m_radius;
    GLuint m_tex;
    GLvertex3f m_geo[4];
    GLvertex2f m_uv[4];
};


/*------------------------------------------------------------------------------
 - AGUITrace -
 -----------------------------------------------------------------------------*/
class AGUITrace : public AGInteractiveObject
{
public:
    AGUITrace();
    
    void addPoint(const GLvertex3f &);
    const vector<GLvertex3f> points() const;
    
//    AGHandwritingRecognizerFigure recognizeNumeral();
    
private:
    AGRenderInfoVL m_renderInfo;
    std::vector<GLvertex3f> m_traceGeo;
};

#endif /* defined(__Auragraph__AGUserInterface__) */
