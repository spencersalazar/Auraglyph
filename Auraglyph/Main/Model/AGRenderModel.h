//
//  AGRenderModel.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "Geometry.h"
#include "Animation.h"
#include "AGInteractiveObject.h"
#include "AGModalDialog.h"

class AGDashboard;
class AGTutorial;

/** Rendering model (things that are drawn to screen)
 */
class AGRenderModel
{
public:
    GLKMatrix4 modelView;
    GLKMatrix4 fixedModelView;
    GLKMatrix4 projection;
    
    float t;
    GLvertex3f camera;
    slewf cameraZ;
    
    AGInteractiveObjectList dashboard;
    AGInteractiveObjectList objects;
    AGInteractiveObjectList fadingOut;
    
    AGDashboard *uiDashboard;
    AGModalOverlay modalOverlay;
    AGTutorial *currentTutorial;
};


