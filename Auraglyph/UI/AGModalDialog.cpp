//
//  AGModalDialog.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/30/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGModalDialog.h"
#include "AGViewController.h"

const float AGMODALDIALOG_OVERLAY_ALPHA = G_RATIO-1;
const float AGMODALDIALOG_DIALOG_WIDTH = 375;
const float AGMODALDIALOG_DIALOG_HEIGHT = AGMODALDIALOG_DIALOG_WIDTH/G_RATIO;
const float AGMODALDIALOG_DIALOG_MARGIN_RATIO = 0.9;

AGViewController_ *AGModalDialog::s_viewController = nullptr;

void AGModalDialog::setGlobalViewController(AGViewController_ *viewController)
{
    s_viewController = viewController;
}

void AGModalDialog::showModalDialog(const std::string &description,
                                    const std::string &ok,
                                    const std::function<void ()> &okAction,
                                    const std::string &cancel,
                                    const std::function<void ()> &cancelAction)
{
    AGModalDialog *dialog = new AGModalDialog(description, ok, okAction, cancel, cancelAction);
    s_viewController->addTopLevelObject(dialog);
}

AGModalDialog::AGModalDialog(const std::string &description,
                             const std::string &ok,
                             const std::function<void ()> &okAction,
                             const std::string &cancel,
                             const std::function<void ()> &cancelAction)
: m_description(description),
  m_ok(ok.length() > 0 ? ok : "OK"), m_okAction(okAction),
  m_cancel(cancel), m_cancelAction(cancelAction)
{
    m_pos = GLvertex2f(0, 0);
    float maxScreenDimension = std::max(s_viewController->bounds().size.width, s_viewController->bounds().size.height);
    m_size = GLvertex2f(maxScreenDimension, maxScreenDimension);
    // hack: need to make it a little bigger
    m_size = m_size*1.1f;
    
    float frameWidth = AGMODALDIALOG_DIALOG_WIDTH;
    float frameHeight = AGMODALDIALOG_DIALOG_HEIGHT;
    float buttonWidth = 100;
    float buttonHeight = 25;
    float marginRatio = AGMODALDIALOG_DIALOG_MARGIN_RATIO;
    
    AGUIButton *okButton = new AGUIButton(ok,
                                          GLvertex2f(frameWidth/2*marginRatio-buttonWidth, -frameHeight/2*marginRatio),
                                          GLvertex2f(buttonWidth, buttonHeight));
    okButton->init();
    okButton->setAction(^(){
        m_okAction();
        s_viewController->fadeOutAndDelete(this);
    });
    addChild(okButton);
    
    if(m_cancel.length() > 0)
    {
        AGUIButton *cancelButton = new AGUIButton(cancel,
                                                  GLvertex2f(-frameWidth/2*marginRatio, -frameHeight/2*marginRatio),
                                                  GLvertex2f(buttonWidth, buttonHeight));
        cancelButton->init();
        cancelButton->setAction(^(){ m_cancelAction(); });
        addChild(cancelButton);
    }
    
    // split description text
    TexFont *text = AGStyle::standardFont64();
    float textWidth = text->width(m_description);
    int textLines = textWidth/(frameWidth*marginRatio);
    m_descriptionLines = _splitIntoLines(m_description, textLines);
}

AGModalDialog::~AGModalDialog()
{ }

GLKMatrix4 AGModalDialog::localTransform()
{
    GLKMatrix4 local = GLKMatrix4MakeTranslation(m_pos.x, m_pos.y, m_pos.z);
    local = m_squeeze.apply(local);
    return local;
}

void AGModalDialog::renderOut()
{
    AGRenderObject::renderOut();
    
    m_squeeze.close();
}

bool AGModalDialog::finishedRenderingOut()
{
    return AGRenderObject::finishedRenderingOut() && m_squeeze.finishedClosing();
}

void AGModalDialog::update(float t, float dt)
{
    m_squeeze.update(t, dt);
    m_alpha.update(dt);
    
    m_renderState.projection = projectionMatrix();
    m_renderState.modelview = GLKMatrix4Multiply(fixedModelViewMatrix(), localTransform());
    
    updateChildren(t, dt);
}

void AGModalDialog::render()
{
    // draw overlay
    // save squeezed modelview
    GLKMatrix4 modelview = m_renderState.modelview;
    // use un-squeezed model view matrix
    m_renderState.modelview = fixedModelViewMatrix();
    // render it
    AGStyle::frameBackgroundColor().withAlpha(m_alpha*AGMODALDIALOG_OVERLAY_ALPHA).set();
    fillCenteredRect(m_size.x, m_size.y);
    
    // restore squeezed matrix
    m_renderState.modelview = modelview;
    float frameWidth = AGMODALDIALOG_DIALOG_WIDTH;
    float frameHeight = AGMODALDIALOG_DIALOG_HEIGHT;

    // draw dialog frame background
    AGStyle::frameBackgroundColor().set();
    fillCenteredRect(frameWidth, frameHeight);
    
    // draw dialog frame
    AGStyle::foregroundColor().set();
    glLineWidth(4.0f);
    strokeCenteredRect(frameWidth, frameHeight);

    // render description
    TexFont *text = AGStyle::standardFont64();
    for(int line = 0; line < m_descriptionLines.size(); line++)
    {
        float textScale = G_RATIO-1;
        float textWidth = text->width(m_descriptionLines[line]);
        float height = frameHeight/5-line*text->height()*1.1;
        
        GLKMatrix4 lineMatrix = GLKMatrix4Translate(m_renderState.modelview, 0, height, 0);
        lineMatrix = GLKMatrix4Scale(lineMatrix, textScale, textScale, textScale);
        lineMatrix = GLKMatrix4Translate(lineMatrix, -textWidth/2, 0, 0);
        
        text->render(m_descriptionLines[line], AGStyle::foregroundColor(), lineMatrix, m_renderState.projection);
    }
    
    renderChildren();
}

std::vector<std::string> AGModalDialog::_splitIntoLines(const std::string &str, int numLines)
{
    std::vector<std::string> lines;
    
    std::string remaining = str;
    
    for(int split = numLines; split > 0; split--)
    {
        if(split == 1)
            lines.push_back(remaining);
        else
        {
            int pos = (int) remaining.length()/split;
            for(int i = 0; ; i++)
            {
                pos += (i%2 ? i : -i); // +1, -1, +2, -2, etc.
                if(pos < 0 || pos >= remaining.length() || isspace(remaining[pos]))
                    break;
            }
            
            lines.push_back(remaining.substr(0, pos));
            remaining = remaining.substr(pos);
        }
    }
    
    for(int i = 0; i < lines.size(); i++)
        fprintf(stderr, "%i: %s\n", i, lines[i].c_str());
    
    return lines;
}

