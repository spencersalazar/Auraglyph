//
//  AGUILoadDialog.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/17/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGUILoadDialog.h"
#include "AGDocumentManager.h"
#include "AGGenericShader.h"
#include "AGStyle.h"

//------------------------------------------------------------------------------
// ### AGUIConcreteLoadDialog ###
//------------------------------------------------------------------------------
#pragma mark - AGUIConcreteLoadDialog

class AGUIConcreteLoadDialog : public AGUILoadDialog
{
private:
    GLvertex2f m_size;
    
    float m_itemStart;
    float m_itemHeight;
    //clampf m_verticalScrollPos;
    momentum<float, clampf> m_verticalScrollPos;
    
    AGSqueezeAnimation m_squeeze;
    
    AGUIButton *m_cancelButton;
    
    GLvertex3f m_touchStart;
    GLvertex3f m_lastTouch;
    int m_selection;
    
    std::vector<AGDocumentManager::DocumentListing> m_documentList;
    
    std::function<void (const AGFile &file, AGDocument &doc)> m_onLoad;
    
public:
    AGUIConcreteLoadDialog(const GLvertex3f &pos, const std::vector<AGDocumentManager::DocumentListing> &list) :
    m_documentList(list)
    {
        setPosition(pos);
        
        m_selection = -1;
        
        m_onLoad = [](const AGFile &, AGDocument &){};
        m_size = GLvertex2f(500, 2*500/AGStyle::aspect16_9);
        m_itemStart = m_size.y/3.0f;
        m_itemHeight = m_size.y/3.0f;
        
        m_verticalScrollPos.raw().clampTo(0, max(0.0f, (m_documentList.size()-3.0f)*m_itemHeight));
        
        float buttonWidth = 100;
        float buttonHeight = 25;
        float buttonMargin = 10;
        
        m_cancelButton = new AGUIButton("Cancel",
                                        GLvertex3f(-m_size.x/2+buttonMargin,
                                                   -m_size.y/2+buttonMargin, 0),
                                        GLvertex2f(buttonWidth, buttonHeight));
        m_cancelButton->init();
        m_cancelButton->setRenderFixed(false);
        m_cancelButton->setAction(^{
            removeFromTopLevel();
        });
        addChild(m_cancelButton);
    }
    
    virtual ~AGUIConcreteLoadDialog() { }
    
    virtual GLKMatrix4 localTransform() override
    {
        GLKMatrix4 local = GLKMatrix4MakeTranslation(m_pos.x, m_pos.y, m_pos.z);
        local = m_squeeze.apply(local);
        return local;
    }
    
    virtual void update(float t, float dt) override
    {
        m_squeeze.update(t, dt);
        m_verticalScrollPos.update(t, dt);
        
        m_renderState.projection = projectionMatrix();
        m_renderState.modelview = GLKMatrix4Multiply(fixedModelViewMatrix(), localTransform());
        
        updateChildren(t, dt);
    }
    
    virtual void render() override
    {
        // draw inner box
        AGStyle::frameBackgroundColor().set();
        drawTriangleFan((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        AGStyle::foregroundColor().set();
        glLineWidth(4.0f);
        drawLineLoop((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        GLcolor4f whiteA = AGStyle::foregroundColor().withAlpha(0.75);
        float yPos = m_itemStart + m_verticalScrollPos;
        int i = 0;
        int len = (int) m_documentList.size();
        
        glLineWidth(4.0f);
        
        AGClipShader &shader = AGClipShader::instance();
        shader.useProgram();
        shader.setClip(m_pos.xy()-m_size/2, m_size);
        
        for(const AGDocumentManager::DocumentListing &document : m_documentList)
        {
            GLKMatrix4 xform = GLKMatrix4MakeTranslation(0, yPos, 0);
            shader.setLocalMatrix(xform);
            
            float margin = 0.9;
            
            if(i == m_selection)
            {
                // draw selection box
                glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor());
                
                drawTriangleFan(shader, (GLvertex3f[]){
                    { -m_size.x/2*margin,  m_itemHeight/2*margin, 0 },
                    { -m_size.x/2*margin, -m_itemHeight/2*margin, 0 },
                    {  m_size.x/2*margin, -m_itemHeight/2*margin, 0 },
                    {  m_size.x/2*margin,  m_itemHeight/2*margin, 0 },
                }, 4, xform);
                
                glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &AGStyle::frameBackgroundColor());
            }
            else
            {
                glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor());
            }
            
            // draw each "figure" in the "name"
            for(auto figure : document.name)
                drawLineStrip(shader, figure.data(), figure.size(), xform);
            
            // draw separating line between rows
            if(i != len-1 || len == 1)
            {
                glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &whiteA);
                drawLineStrip(shader, (GLvertex2f[]){
                    { -m_size.x/2*margin, -m_itemHeight/2 }, { m_size.x/2*margin, -m_itemHeight/2 },
                }, 2, xform);
            }
            
            yPos -= m_itemHeight;
            i++;
        }
        
        /* draw scroll bar */
        int nRows = (int) m_documentList.size();
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
            glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::foregroundColor());
            glLineWidth(1.0);
            drawLineStrip((GLvertex2f[]) {
                { m_size.x/2*scroll_bar_margin, m_size.y/2*scroll_bar_margin-scroll_bar_y },
                { m_size.x/2*scroll_bar_margin, m_size.y/2*scroll_bar_margin-(scroll_bar_y+scroll_bar_height) },
            }, 2);
        }
        
        // restore color
        glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor());
        
        AGInteractiveObject::render();
    }
    
    GLvrectf effectiveBounds() override
    {
        return GLvrectf(m_pos-m_size/2, m_pos+m_size/2);
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
        m_verticalScrollPos.on();
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
            //m_verticalScrollPos += (t.position.y - m_lastTouch.y);
        }
        
        if(m_selection >= 0)
        {
            const AGFile &file = m_documentList[m_selection].filename;
            AGDocument doc = AGDocumentManager::instance().load(file);
            m_onLoad(file, doc);
            removeFromTopLevel();
        }
        
        m_verticalScrollPos.off();
    }
    
    virtual void renderOut() override
    {
        m_squeeze.close();
    }
    
    virtual bool finishedRenderingOut() override
    {
        return m_squeeze.finishedClosing();
    }
    
    virtual void onLoad(const std::function<void (const AGFile &file, AGDocument &doc)> &_onLoad) override
    {
        m_onLoad = _onLoad;
    }
};

AGUILoadDialog *AGUILoadDialog::load(const GLvertex3f &pos)
{
    std::vector<AGDocumentManager::DocumentListing> list = AGDocumentManager::instance().list();
    std::sort(list.begin(), list.end(), [](const AGDocumentManager::DocumentListing &a,
                                           const AGDocumentManager::DocumentListing &b) {
        return a.filename.m_creationTime > b.filename.m_creationTime;
    });
    AGUILoadDialog *loadDialog = new AGUIConcreteLoadDialog(pos, list);
    loadDialog->init();
    return loadDialog;
}

AGUILoadDialog *AGUILoadDialog::loadExample(const GLvertex3f &pos)
{
    AGUILoadDialog *loadDialog = new AGUIConcreteLoadDialog(pos, AGDocumentManager::instance().examplesList());
    loadDialog->init();
    return loadDialog;
}

