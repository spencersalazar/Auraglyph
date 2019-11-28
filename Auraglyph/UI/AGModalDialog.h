//
//  AGModalDialog.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/30/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"
#include "Animation.h"
#include "AGStyle.h"

#include <string>
#include <vector>
#include <list>
#include <functional>


class AGViewController_;
class AGModalDialog;

class AGModalOverlay : public AGInteractiveObject
{
public:
    AGModalOverlay();
    
    bool renderFixed() override { return true; }
    GLvertex2f size() override { return m_size; }
    
    void setScreenSize(GLvertex2f size);

    void update(float t, float dt) override;
    void render() override;
    
    AGInteractiveObject *hitTest(const GLvertex3f &t) override;
    
    void addModalDialog(AGModalDialog *dialog);
    void removeModalDialog(AGModalDialog *dialog);

private:
    GLvertex2f m_size;
    std::list<AGModalDialog *> m_modalDialogs;
};


class AGModalDialog : public AGInteractiveObject
{
public:
    
    static void setGlobalModalOverlay(AGModalOverlay *modalOverlay);
    
    static void showModalDialog(const std::string &description,
                                const std::string &ok = "OK",
                                const std::function<void ()> &okAction = [](){},
                                const std::string &cancel = "",
                                const std::function<void ()> &cancelAction = [](){});
    
    AGModalDialog(const std::string &description,
                  const std::string &ok = "OK",
                  const std::function<void ()> &okAction = [](){},
                  const std::string &cancel = "",
                  const std::function<void ()> &cancelAction = [](){});
    ~AGModalDialog();
    
    bool renderFixed() override { return true; }
    GLvertex2f size() override { return m_size; }
    GLKMatrix4 localTransform() override;
    
    void update(float t, float dt) override;
    void render() override;
    
    void renderOut() override;
    bool finishedRenderingOut() const override;

private:
    
    static AGModalOverlay *s_globalOverlay;
    
    std::string m_description;
    std::vector<std::string> m_descriptionLines;
    std::string m_ok;
    std::string m_cancel;
    
    std::function<void ()> m_okAction;
    std::function<void ()> m_cancelAction;

    GLvertex2f m_size;
    
    AGSqueezeAnimation m_squeeze;
    
    std::vector<std::string> _splitIntoLines(const std::string &str, int numLines);
};
