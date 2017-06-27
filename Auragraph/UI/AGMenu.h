//
//  AGMenu.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"

#include <string>
#include <vector>
#include <functional>

class AGMenu : public AGInteractiveObject
{
public:
    AGMenu(const GLvertex3f &pos, const GLvertex2f &size);
    ~AGMenu();
    
    bool renderFixed() override { return true; }
    
    void setIcon(GLvertex3f *geo, int num, GLint kind);
    void addMenuItem(const std::string &title, const std::function<void ()> &action);
    
    void update(float t, float dt) override;
    void render() override;
    
    void touchDown(const AGTouchInfo &t) override;
    void touchMove(const AGTouchInfo &t) override;
    void touchUp(const AGTouchInfo &t) override;
    void touchOutside() override;
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t) override;
    
private:
    
    GLvrectf _boundingBoxForItem(int item);
    
    std::vector<GLvertex3f> m_frameGeo;
    
    std::vector<GLvertex3f> m_iconGeo;
    GLint m_iconGeoKind; // GL_LINES, etc.
    
    struct MenuItem
    {
        std::string title;
        std::function<void ()> action;
    };
    
    std::vector<MenuItem> m_items;
    
    GLvertex2f m_size;
    GLvertex3f m_pos;
    float m_maxTextWidth = 0;
    
    bool m_open = false;
    bool m_leftTab = false;
    int m_selectedItem = -1;
    powcurvef m_itemsAlpha;
};

