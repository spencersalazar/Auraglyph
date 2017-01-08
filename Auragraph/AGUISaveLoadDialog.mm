//
//  AGUISaveLoadDialog.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/15/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGUISaveLoadDialog.h"
#include "AGDocumentManager.h"
#include "AGGenericShader.h"
#include "AGStyle.h"

//------------------------------------------------------------------------------
// ### AGUIConcreteSaveDialog ###
//------------------------------------------------------------------------------
#pragma mark - AGUIConcreteSaveDialog

class AGUIConcreteSaveDialog : public AGUISaveDialog
{
private:
    GLvertex3f m_pos;
    GLvertex2f m_size;
    
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    AGUIButton *m_saveButton;
    AGUIButton *m_clearButton;
    AGUIButton *m_cancelButton;
    
    AGDocument m_doc;
    vector<vector<GLvertex2f>> m_name;
    
    std::function<void (const std::string &file)> m_onSave;
    
public:
    AGUIConcreteSaveDialog(const AGDocument &doc, const GLvertex3f &pos) :
    m_doc(doc),
    m_pos(pos)
    {
        m_onSave = [](const std::string &file){};
        m_size = GLvertex2f(500, 500/AGStyle::aspect16_9);
        m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
        m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
        
        float buttonWidth = 100;
        float buttonHeight = 25;
        float buttonMargin = 10;
        m_saveButton = new AGUIButton("Save",
                                      GLvertex3f(m_size.x/2-buttonMargin-buttonWidth,
                                                 -m_size.y/2+buttonMargin,
                                                 0),
                                      GLvertex2f(buttonWidth, buttonHeight));
        m_saveButton->init();
        
        m_saveButton->setAction(^{
            AGDocumentManager &manager = AGDocumentManager::instance();
            
            string filename = manager.save(m_name, m_doc);
            
            m_onSave(filename);
            
            removeFromTopLevel();
        });
        
        addChild(m_saveButton);
        
        m_cancelButton = new AGUIButton("Cancel",
                                        GLvertex3f(-m_size.x/2+buttonMargin,
                                                   -m_size.y/2+buttonMargin,
                                                   0),
                                        GLvertex2f(buttonWidth, buttonHeight));
        m_cancelButton->init();
        m_cancelButton->setAction(^{
            removeFromTopLevel();
        });
        addChild(m_cancelButton);
        
    }
    
    virtual ~AGUIConcreteSaveDialog() { }
    
    virtual void update(float t, float dt) override
    {
        AGInteractiveObject::update(t, dt);
        
        m_renderState.projection = projectionMatrix();
        
        m_renderState.modelview = fixedModelViewMatrix();
        m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
        
        if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
        if(m_xScale >= 0.99f) m_yScale.update(dt);
        
        m_renderState.modelview = GLKMatrix4Scale(m_renderState.modelview,
                                                  m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                                  m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                                  1);
    }
    
    virtual void render() override
    {
        // draw inner box
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
        drawTriangleFan((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        // draw outer frame
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::foregroundColor);
        glLineWidth(4.0f);
        drawLineLoop((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        glLineWidth(4.0f);
        for(auto figure : m_name)
            drawLineStrip(figure.data(), figure.size());
        
        AGInteractiveObject::render();
    }
    
    GLvrectf effectiveBounds() override
    {
        return GLvrectf(m_pos-m_size, m_pos+m_size);
    }
    
    bool renderFixed() override { return true; }
    
    virtual void touchDown(const AGTouchInfo &t) override
    {
        m_name.back().push_back(t.position.xy());
    }
    
    virtual void touchMove(const AGTouchInfo &t) override
    {
        m_name.back().push_back(t.position.xy());
    }
    
    virtual void touchUp(const AGTouchInfo &t) override
    {
        m_name.back().push_back(t.position.xy());
    }
    
    virtual void renderOut() override
    {
        m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
        m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
    }
    
    virtual bool finishedRenderingOut() override
    {
        return m_xScale <= AGStyle::open_squeezeHeight;
    }
    
    virtual void onSave(const std::function<void (const std::string &file)> &_onSave) override
    {
        m_onSave = _onSave;
    }
};

AGUISaveDialog *AGUISaveDialog::save(const AGDocument &doc, const GLvertex3f &pos)
{
    AGUISaveDialog *saveDialog = new AGUIConcreteSaveDialog(doc, pos);
    saveDialog->init();
    return saveDialog;
}


//------------------------------------------------------------------------------
// ### AGUIConcreteLoadDialog ###
//------------------------------------------------------------------------------
#pragma mark - AGUIConcreteLoadDialog

class AGUIConcreteLoadDialog : public AGUILoadDialog
{
private:
    GLvertex3f m_pos;
    GLvertex2f m_size;
    
    float m_itemStart;
    float m_itemHeight;
    clampf m_verticalScrollPos;

    lincurvef m_xScale;
    lincurvef m_yScale;
    
    AGUIButton *m_cancelButton;
    
    GLvertex3f m_touchStart;
    GLvertex3f m_lastTouch;
    int m_selection;
    
    const std::vector<AGDocumentManager::DocumentListing> &m_documentList;
    
    std::function<void (const std::string &file, AGDocument &doc)> m_onLoad;
    
public:
    AGUIConcreteLoadDialog(const GLvertex3f &pos) :
    m_pos(pos),
    m_documentList(AGDocumentManager::instance().list())
    {
        m_selection = -1;
        
        m_onLoad = [](const std::string &, AGDocument &){};
        m_size = GLvertex2f(500, 2*500/AGStyle::aspect16_9);
        m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
        m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
        m_itemStart = m_size.y/3.0f;
        m_itemHeight = m_size.y/3.0f;
        
        m_verticalScrollPos.clampTo(0, max(0.0f, (m_documentList.size()-3.0f)*m_itemHeight));
        
        float buttonWidth = 100;
        float buttonHeight = 25;
        float buttonMargin = 10;
        
        m_cancelButton = new AGUIButton("Cancel",
                                        GLvertex3f(-m_size.x/2+buttonMargin,
                                                   -m_size.y/2+buttonMargin, 0),
                                        GLvertex2f(buttonWidth, buttonHeight));
        m_cancelButton->init();
        m_cancelButton->setAction(^{
            removeFromTopLevel();
        });
        addChild(m_cancelButton);
    }
    
    virtual ~AGUIConcreteLoadDialog() { }
    
    virtual void update(float t, float dt) override
    {
        AGInteractiveObject::update(t, dt);
        
        m_renderState.projection = projectionMatrix();
        
        m_renderState.modelview = fixedModelViewMatrix();
        m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
        
        if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
        if(m_xScale >= 0.99f) m_yScale.update(dt);
        
        m_renderState.modelview = GLKMatrix4Scale(m_renderState.modelview,
                                                  m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                                  m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                                  1);
    }
    
    virtual void render() override
    {
        // draw inner box
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
        drawTriangleFan((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::foregroundColor);
        glLineWidth(4.0f);
        drawLineLoop((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        GLcolor4f whiteA = AGStyle::foregroundColor;
        whiteA.a = 0.75;
        float yPos = m_itemStart + m_verticalScrollPos;
        int i = 0;
        int len = m_documentList.size();
        
        glLineWidth(4.0f);
        
        AGClipShader &shader = AGClipShader::instance();
        shader.useProgram();
        shader.setClip(m_pos.xy()-m_size/2, m_size);
        
        for(auto document : m_documentList)
        {
            GLKMatrix4 xform = GLKMatrix4MakeTranslation(0, yPos, 0);
            shader.setLocalMatrix(xform);
            
            float margin = 0.9;
            
            if(i == m_selection)
            {
                // draw selection box
                glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor);
                
                drawTriangleFan(shader, (GLvertex3f[]){
                    { -m_size.x/2*margin,  m_itemHeight/2*margin, 0 },
                    { -m_size.x/2*margin, -m_itemHeight/2*margin, 0 },
                    {  m_size.x/2*margin, -m_itemHeight/2*margin, 0 },
                    {  m_size.x/2*margin,  m_itemHeight/2*margin, 0 },
                }, 4, xform);
                
                glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &AGStyle::frameBackgroundColor());
            }
            else
            {
                glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor);
            }
            
            // draw each "figure" in the "name"
            for(auto figure : document.name)
                drawLineStrip(shader, figure.data(), figure.size(), xform);
            
            // draw separating line between rows
            if(i != len-1 || len == 1)
            {
                glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &whiteA);
                drawLineStrip(shader, (GLvertex2f[]){
                    { -m_size.x/2*margin, -m_itemHeight/2 }, { m_size.x/2*margin, -m_itemHeight/2 },
                }, 2, xform);
            }
            
            yPos -= m_itemHeight;
            i++;
        }
        
        /* draw scroll bar */
        int nRows = m_documentList.size();
        if(nRows > 3)
        {
            float scroll_bar_margin = 0.95;
            // maximum distance that can be scrolled
            float scroll_max_scroll = (nRows-3)*m_itemHeight;
            // height of the scroll bar tray area
            float scroll_bar_tray_height = m_size.y*scroll_bar_margin;
            // percent of the total scroll area that is visible * tray height
            float scroll_bar_height = scroll_bar_tray_height/ceilf(nRows-2);
            // percent of scroll position * (tray height - bar height)
            float scroll_bar_y = m_verticalScrollPos/scroll_max_scroll*(scroll_bar_tray_height-scroll_bar_height);
            
            // load it up and draw
            glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
            glLineWidth(1.0);
            drawLineStrip((GLvertex2f[]) {
                { m_size.x/2*scroll_bar_margin, m_size.y/2*scroll_bar_margin-scroll_bar_y },
                { m_size.x/2*scroll_bar_margin, m_size.y/2*scroll_bar_margin-(scroll_bar_y+scroll_bar_height) },
            }, 2);
        }
        
        // restore color
        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor);
        
        AGInteractiveObject::render();
    }
    
    GLvrectf effectiveBounds() override
    {
        return GLvrectf(m_pos-m_size, m_pos+m_size);
    }
    
    bool renderFixed() override { return true; }
    
    virtual void touchDown(const AGTouchInfo &t) override
    {
        GLvertex3f relPos = t.position-m_pos;
        float yPos = m_itemStart+m_verticalScrollPos;
        
        for(int i = 0; i < m_documentList.size(); i++)
        {
            if(relPos.y < yPos+m_itemHeight/2.0f && relPos.y > yPos-m_itemHeight/2.0f &&
               relPos.x > -m_size.x/2 && relPos.x < m_size.x/2)
            {
                m_selection = i;
                break;
            }
            
            yPos -= m_itemStart;
        }
        
        m_touchStart = t.position;
        m_lastTouch = t.position;
    }
    
    virtual void touchMove(const AGTouchInfo &t) override
    {
        if((m_touchStart-t.position).magnitudeSquared() > AGStyle::maxTravel*AGStyle::maxTravel)
        {
            m_selection = -1;
            // start scrolling
            m_verticalScrollPos += (t.position.y - m_lastTouch.y);
        }
        
        m_lastTouch = t.position;
    }
    
    virtual void touchUp(const AGTouchInfo &t) override
    {
        if((m_touchStart-t.position).magnitudeSquared() > AGStyle::maxTravel*AGStyle::maxTravel)
        {
            m_selection = -1;
        }
        
        if(m_selection >= 0)
        {
            const string &filename = m_documentList[m_selection].filename;
            AGDocument doc = AGDocumentManager::instance().load(m_documentList[m_selection].filename);
            m_onLoad(filename, doc);
            removeFromTopLevel();
        }
    }
    
    virtual void renderOut() override
    {
        m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
        m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
    }
    
    virtual bool finishedRenderingOut() override
    {
        return m_xScale <= AGStyle::open_squeezeHeight;
    }
    
    virtual void onLoad(const std::function<void (const std::string &file, AGDocument &doc)> &_onLoad) override
    {
        m_onLoad = _onLoad;
    }
};

AGUILoadDialog *AGUILoadDialog::load(const GLvertex3f &pos)
{
    AGUILoadDialog *loadDialog = new AGUIConcreteLoadDialog(pos);
    loadDialog->init();
    return loadDialog;
}

