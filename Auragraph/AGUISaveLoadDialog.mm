//
//  AGUISaveLoadDialog.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/15/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGUISaveLoadDialog.h"
#include "AGDocumentManager.h"
#include "AGStyle.h"


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
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::foregroundColor);
        glLineWidth(4.0f);
        drawLineLoop((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        glLineWidth(2.0f);
        for(auto figure : m_name)
            drawLineStrip(figure.data(), figure.size());
        
        AGInteractiveObject::render();
    }
    
    virtual GLvrectf effectiveBounds() override
    {
        return GLvrectf(m_pos-m_size, m_pos+m_size);
    }
    
    virtual void touchDown(const AGTouchInfo &t) override
    {
        m_name.push_back(vector<GLvertex2f>());
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
