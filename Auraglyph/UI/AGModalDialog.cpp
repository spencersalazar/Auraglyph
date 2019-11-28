//
//  AGModalDialog.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/30/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGModalDialog.h"
#include "AGViewController.h"


const float AGMODALOVERLAY_ALPHA = G_RATIO-1;


AGModalOverlay::AGModalOverlay()
{
    m_alpha.forceTo(0);
}

void AGModalOverlay::setScreenSize(GLvertex2f size)
{
    float maxScreenDimension = std::max(size.x, size.y);
    m_size = GLvertex2f(maxScreenDimension, maxScreenDimension);
    // hacky extra factor
    m_size = m_size*1.1;
}

AGInteractiveObject *AGModalOverlay::hitTest(const GLvertex3f &t)
{
    if(m_alpha > 0.001)
        return AGInteractiveObject::hitTest(t);
    else
        return nullptr;
}

void AGModalOverlay::update(float t, float dt)
{
    m_alpha.update(dt);
    
    m_renderState.projection = projectionMatrix();
    m_renderState.modelview = GLKMatrix4Multiply(fixedModelViewMatrix(), localTransform());
    
    updateChildren(t, dt);
}

void AGModalOverlay::render()
{
    AGStyle::frameBackgroundColor().withAlpha(m_alpha*AGMODALOVERLAY_ALPHA).set();
    fillCenteredRect(m_size.x, m_size.y);
    
    renderChildren();
}

void AGModalOverlay::addModalDialog(AGModalDialog *dialog)
{
    if(m_modalDialogs.size() == 0)
        m_alpha.reset(0, 1);
    m_modalDialogs.push_back(dialog);
    addChild(dialog);
}

void AGModalOverlay::removeModalDialog(AGModalDialog *dialog)
{
    m_modalDialogs.remove(dialog);
    removeChild(dialog);
    if(m_modalDialogs.size() == 0)
        m_alpha.reset(1, 0);
}


const float AGMODALDIALOG_DIALOG_WIDTH = 375;
const float AGMODALDIALOG_DIALOG_HEIGHT = AGMODALDIALOG_DIALOG_WIDTH/G_RATIO;
const float AGMODALDIALOG_DIALOG_MARGIN_RATIO = 0.9;

AGModalOverlay *AGModalDialog::s_globalOverlay = nullptr;

void AGModalDialog::setGlobalModalOverlay(AGModalOverlay *modalOverlay)
{
    s_globalOverlay = modalOverlay;
}

void AGModalDialog::showModalDialog(const std::string &description,
                                    const std::string &ok,
                                    const std::function<void ()> &okAction,
                                    const std::string &cancel,
                                    const std::function<void ()> &cancelAction)
{
    AGModalDialog *dialog = new AGModalDialog(description, ok, okAction, cancel, cancelAction);
    dialog->init();
    s_globalOverlay->addModalDialog(dialog);
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
        s_globalOverlay->removeModalDialog(this);
    });
    addChild(okButton);
    
    if(m_cancel.length() > 0)
    {
        AGUIButton *cancelButton = new AGUIButton(cancel,
                                                  GLvertex2f(-frameWidth/2*marginRatio, -frameHeight/2*marginRatio),
                                                  GLvertex2f(buttonWidth, buttonHeight));
        cancelButton->init();
        cancelButton->setAction(^(){
            m_cancelAction();
            s_globalOverlay->removeModalDialog(this);
        });
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

bool AGModalDialog::finishedRenderingOut() const
{
    return AGRenderObject::finishedRenderingOut() && m_squeeze.finishedClosing();
}

void AGModalDialog::update(float t, float dt)
{
    m_squeeze.update(t, dt);
    
    m_renderState.projection = projectionMatrix();
    m_renderState.modelview = GLKMatrix4Multiply(fixedModelViewMatrix(), localTransform());
    
    updateChildren(t, dt);
}

void AGModalDialog::render()
{
    float frameWidth = AGMODALDIALOG_DIALOG_WIDTH;
    float frameHeight = AGMODALDIALOG_DIALOG_HEIGHT;

    // draw dialog frame background
    AGStyle::frameBackgroundColor().set();
    fillCenteredRect(frameWidth, frameHeight);
    
    // draw dialog frame
    AGStyle::foregroundColor().set();
    strokeCenteredRect(frameWidth, frameHeight, 4.0f);

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

