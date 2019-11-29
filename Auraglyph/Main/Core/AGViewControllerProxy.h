//
//  AGViewControllerProxy.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/28/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

// necessary for now
#include "AGViewController.h"


/** AGViewController proxy/bridge for C++-only code
 */
class AGViewController_
{
public:
    AGViewController_(AGViewController *viewController);
    ~AGViewController_();
    
    void createNew();
    void save();
    void saveAs();
    void load();
    void loadExample();
    
    void showTrainer();
    void showAbout();
    
    void startRecording();
    void stopRecording();
    
    void setDrawMode(AGDrawMode mode);
    
    GLvertex3f worldCoordinateForScreenCoordinate(CGPoint p);
    GLvertex3f fixedCoordinateForScreenCoordinate(CGPoint p);
    
    CGRect bounds();
    
    void addTopLevelObject(AGInteractiveObject *object);
    void fadeOutAndDelete(AGInteractiveObject *object);
    
    void addNodeToTopLevel(AGNode *node);
    AGGraph *graph();
    
    void showDashboard();
    void hideDashboard();
    
    void showTutorial(AGTutorial *tutorial);
    
private:
    AGViewController *m_viewController = nil;
};

