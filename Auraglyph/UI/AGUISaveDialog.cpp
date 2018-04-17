//
//  AGUISaveLoadDialog.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/15/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGUISaveDialog.h"
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
    GLvertex2f m_size;
    
    AGSqueezeAnimation m_squeeze;
    
    AGUIButton *m_saveButton;
    AGUIButton *m_clearButton;
    AGUIButton *m_cancelButton;
    
    AGDocument m_doc;
    vector<vector<GLvertex2f>> m_name;
    
    std::function<void (const std::string &, const vector<vector<GLvertex2f>> &)> m_onSave;
    
public:
    AGUIConcreteSaveDialog(const AGDocument &doc, const GLvertex3f &pos) :
    m_doc(doc)
    {
        setPosition(pos);
        
        m_onSave = [](const std::string &, const vector<vector<GLvertex2f>>&){};
        m_size = GLvertex2f(500, 500/AGStyle::aspect16_9);
        
        float buttonWidth = 100;
        float buttonHeight = 25;
        float buttonMargin = 10;
        m_saveButton = new AGUIButton("Save",
                                      GLvertex3f(m_size.x/2-buttonMargin-buttonWidth,
                                                 -m_size.y/2+buttonMargin,
                                                 0),
                                      GLvertex2f(buttonWidth, buttonHeight));
        m_saveButton->init();
        m_saveButton->setRenderFixed(false);
        
        m_saveButton->setAction(^{
            AGDocumentManager &manager = AGDocumentManager::instance();
            
            m_doc.setName(m_name);
            string filename = manager.save(m_name, m_doc);
            
            m_onSave(filename, m_name);
            
            removeFromTopLevel();
        });
        
        addChild(m_saveButton);
        
        m_cancelButton = new AGUIButton("Cancel",
                                        GLvertex3f(-m_size.x/2+buttonMargin,
                                                   -m_size.y/2+buttonMargin,
                                                   0),
                                        GLvertex2f(buttonWidth, buttonHeight));
        m_cancelButton->init();
        m_cancelButton->setRenderFixed(false);

        m_cancelButton->setAction(^{
            removeFromTopLevel();
        });
        addChild(m_cancelButton);
        
    }
    
    virtual ~AGUIConcreteSaveDialog() { }
    
    virtual GLKMatrix4 localTransform() override
    {
        GLKMatrix4 local = GLKMatrix4MakeTranslation(m_pos.x, m_pos.y, m_pos.z);
        local = m_squeeze.apply(local);
        return local;
    }
    
    virtual void update(float t, float dt) override
    {
        m_squeeze.update(t, dt);
        
        m_renderState.projection = projectionMatrix();
        m_renderState.modelview = GLKMatrix4Multiply(fixedModelViewMatrix(), localTransform());
        
        updateChildren(t, dt);
    }
    
    virtual void render() override
    {
        // draw inner box
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
        drawTriangleFan((GLvertex3f[]){
            { -m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2, -m_size.y/2, 0 },
            {  m_size.x/2,  m_size.y/2, 0 },
            { -m_size.x/2,  m_size.y/2, 0 },
        }, 4);
        
        // draw outer frame
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::foregroundColor());
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
        return GLvrectf(m_pos-m_size/2, m_pos+m_size/2);
    }
    
    bool renderFixed() override { return true; }
    
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
        m_squeeze.close();
    }
    
    virtual bool finishedRenderingOut() override
    {
        return m_squeeze.finishedClosing();
    }
    
    virtual void onSave(const std::function<void (const std::string &file, const vector<vector<GLvertex2f>> &name)> &_onSave) override
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


