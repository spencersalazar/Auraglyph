//
//  AGDashboard.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/27/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"

class AGViewController_;
class AGMenu;
class AGUIButton;
class AGUIIconButton;
class AGDocumentationViewer;

class AGDashboard : public AGInteractiveObject
{
public:
    AGDashboard(AGViewController_ *viewController);
    ~AGDashboard();
    
    void onInterfaceOrientationChange();
    
    bool renderFixed() override { return true; }
    
    void update(float t, float dt) override;
    
private:
    AGViewController_ *m_viewController = nullptr;
    
    AGMenu *m_fileMenu = nullptr;
    AGMenu *m_editMenu = nullptr;
    AGMenu *m_settingsMenu = nullptr;
    AGMenu *m_helpMenu = nullptr;

    // AGUIButton *m_recordButton;
    AGUIIconButton *m_nodeButton;
    AGUIIconButton *m_freedrawButton;
    AGUIIconButton *m_freedrawEraseButton;
    
    AGDocumentationViewer *m_docsViewer = nullptr;
    
    bool m_isRecording = false;
};

