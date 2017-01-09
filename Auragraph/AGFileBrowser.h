//
//  AGFileBrowser.h
//  Auragraph
//
//  Created by Spencer Salazar on 1/7/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"

#include <vector>
#include <string>
#include <functional>

class AGUIButton;

class AGFileBrowser : public AGInteractiveObject
{
public:
    AGFileBrowser(const GLvertex3f &position = GLvertex3f());
    ~AGFileBrowser();
    
    void update(float t, float dt) override;
    void render() override;
    
    void renderOut() override;
    bool finishedRenderingOut() override;

    void touchDown(const AGTouchInfo &t) override;
    void touchMove(const AGTouchInfo &t) override;
    void touchUp(const AGTouchInfo &t) override;
    
    void setPosition(const GLvertex3f &position);
    virtual GLvertex3f position() override;
    void setSize(const GLvertex2f &size);
    virtual GLvertex2f size() override;
    
    void setDirectoryPath(const string &directoryPath);
    string selectedFile() const;
    
    void onChooseFile(const std::function<void (const string &)> &choose);
    void onCancel(const std::function<void (void)> &cancel);
    
    /*
     Filter function takes filepath as an argument and returns whether or not
     to display that file.
     */
    void setFilter(const std::function<bool (const string &)> &filter);
    
private:
    
    GLvertex3f m_pos = GLvertex3f();
    GLvertex2f m_size = GLvertex2f();
    
    string m_file = "";
    
    std::function<void (const string &)> m_choose = [](const string &){};
    std::function<void (void)> m_cancel = [](){};
    std::function<bool (const string &)> m_filter = [](const string &){ return true; };
    
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    vector<string> m_paths;
    
    float m_itemStart;
    float m_itemHeight;
    clampf m_verticalScrollPos;
    
    AGUIButton *m_cancelButton;
    
    GLvertex3f m_touchStart;
    GLvertex3f m_lastTouch;
    int m_selection = -1;
    
    float m_fontScale;
};


